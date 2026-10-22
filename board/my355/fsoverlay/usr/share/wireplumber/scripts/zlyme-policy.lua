-- WirePlumber owns which sink is the default. This hook runs after the
-- stock priority and configured-default hooks and replaces their choice.
-- wpctl set-default stores default.configured.audio.sink, and that name
-- outranks priority.session by 30000, so automatic mode must not call it.
--
-- The shell publishes the ELD (yes, no, or pending) and the saved
-- preference as metadata. This script does not choose by reading
-- files: the WirePlumber sandbox does not provide io. A pending ELD
-- is a modeset with no parsed format: do not enter HDMI, and do not
-- leave it when the graph is already there. The effective sink name
-- is published to the route file by zlyme-audio follow, after apply.

local policy = {}

local function has_role(nodes, role)
  for _, n in ipairs(nodes) do
    if n.role == role then
      return true
    end
  end
  return false
end

function policy.choose(pref, nodes, eld, current)
  if eld ~= "yes" and eld ~= "no" and eld ~= "pending" then
    eld = "pending"
  end
  if pref ~= "codec" and pref ~= "hdmi" and pref ~= "bt" then
    pref = "auto"
  end

  if pref == "codec" and has_role(nodes, "codec") then
    return "codec"
  end
  if pref == "bt" and has_role(nodes, "bt") then
    return "bt"
  end
  if pref == "hdmi" and has_role(nodes, "hdmi") and eld == "yes" then
    return "hdmi"
  end
  if pref == "hdmi" and has_role(nodes, "hdmi") and eld == "pending" and current == "hdmi" then
    return "hdmi"
  end

  if pref == "auto" then
    if has_role(nodes, "bt") then
      return "bt"
    end
    if has_role(nodes, "hdmi") and eld == "yes" then
      return "hdmi"
    end
    if has_role(nodes, "hdmi") and eld == "pending" and current == "hdmi" then
      return "hdmi"
    end
    if has_role(nodes, "codec") then
      return "codec"
    end
    return "codec"
  end

  -- The saved preference stays. Playback still needs a node that can play.
  if has_role(nodes, "codec") then
    return "codec"
  end
  if has_role(nodes, "hdmi") and eld == "yes" then
    return "hdmi"
  end
  if has_role(nodes, "hdmi") and eld == "pending" and current == "hdmi" then
    return "hdmi"
  end
  if has_role(nodes, "bt") then
    return "bt"
  end
  return "codec"
end

function policy.name_for(nodes, role)
  for _, n in ipairs(nodes) do
    if n.role == role and n.name and n.name ~= "" then
      return n.name
    end
  end
  return nil
end

local function wp_loaded()
  return type(SimpleEventHook) == "function"
end

if not wp_loaded() then
  local pref = arg[1] or "auto"
  local eld = arg[2] or "pending"
  local current = arg[3] or "-"
  if current == "-" then
    current = ""
  end
  local nodes = {}
  for line in io.lines() do
    local role = line:match("^(%S+)")
    if role == "codec" or role == "hdmi" or role == "bt" then
      nodes[#nodes + 1] = { role = role }
    end
  end
  io.write(policy.choose(pref, nodes, eld, current), "\n")
  os.exit(0)
end

log = Log.open_topic("s-zlyme")

local function role_of(props)
  local name = props["node.name"] or ""
  if name:find("null", 1, true) or name:find("dummy", 1, true) then
    return nil
  end
  if name:sub(1, 13) == "bluez_output." then
    return "bt"
  end
  local card = props["alsa.id"] or ""
  if card == "rk817ext" or name:find("rk817-sound", 1, true) then
    return "codec"
  end
  if card == "HDMI" or name:find("hdmi-sound", 1, true) then
    return "hdmi"
  end
  return nil
end

local function meta_value(metadata, key)
  if not metadata then
    return nil
  end
  local value = metadata:find(0, key)
  if type(value) ~= "string" or value == "" then
    return nil
  end
  return value
end

local function saved_pref(metadata)
  local pref = meta_value(metadata, "zlyme.pref")
  if pref == "auto" or pref == "codec" or pref == "hdmi" or pref == "bt" then
    return pref
  end
  return "auto"
end

local function read_eld(metadata)
  local eld = meta_value(metadata, "zlyme.hdmi")
  if eld == "yes" or eld == "no" or eld == "pending" then
    return eld
  end
  return "pending"
end

local function current_role(metadata, by_name)
  if not metadata then
    return ""
  end
  local obj = metadata:find(0, "default.audio.sink")
  if not obj then
    return ""
  end
  local ok, parsed = pcall(function()
    return Json.Raw(obj):parse()
  end)
  if not ok or type(parsed) ~= "table" then
    return ""
  end
  local name = parsed.name
  if type(name) ~= "string" then
    return ""
  end
  return by_name[name] or ""
end

SimpleEventHook {
  name = "zlyme/select-sink",
  after = { "default-nodes/find-best-default-node" },
  before = "default-nodes/apply-default-node",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "select-default-node" },
    },
  },
  execute = function(event)
    local props = event:get_properties()
    if props["default-node.type"] ~= "audio.sink" then
      return
    end
    local available = event:get_data("available-nodes")
    available = available and available:parse()
    if not available then
      return
    end
    local nodes = {}
    local by_name = {}
    for _, node_props in ipairs(available) do
      local role = role_of(node_props)
      local name = node_props["node.name"]
      if role and name then
        nodes[#nodes + 1] = { role = role, name = name }
        by_name[name] = role
      end
    end
    if #nodes == 0 then
      return
    end
    local source = event:get_source()
    local metadata = nil
    local metadata_om = source:call("get-object-manager", "metadata")
    if metadata_om then
      metadata = metadata_om:lookup {
        Constraint { "metadata.name", "=", "default" },
      }
    end
    local choice = policy.choose(saved_pref(metadata), nodes, read_eld(metadata), current_role(metadata, by_name))
    local name = policy.name_for(nodes, choice)
    if not name then
      return
    end
    event:set_data("selected-node", name)
    log:info(string.format("sink %s (%s)", choice, name))
  end
}:register()

-- A DRM event or a saved preference writes one metadata key. That is
-- the rescan. The hook above reads those keys. It does not read files.
SimpleEventHook {
  name = "zlyme/rescan-hint",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "metadata-changed" },
      Constraint { "metadata.name", "=", "default" },
      Constraint { "event.subject.key", "c", "zlyme.hdmi", "zlyme.pref" },
    },
  },
  execute = function(event)
    event:get_source():call("schedule-rescan", "default-nodes")
  end
}:register()
