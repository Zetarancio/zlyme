-- Run the policy and volume hooks without the io library.
-- WirePlumber's sandbox does not provide it. A passing CLI policy
-- test does not load this path.

local policy_path, volume_path = arg[1], arg[2]
local hooks = {}

function SimpleEventHook(spec)
  return {
    register = function()
      hooks[spec.name] = spec.execute
    end,
  }
end

function EventInterest()
  return {}
end

function Constraint()
  return {}
end

Log = {
  open_topic = function()
    return {
      info = function() end,
    }
  end,
}

Json = {
  Raw = function(text)
    return {
      parse = function()
        local name = text:match('"name"%s*:%s*"([^"]+)"')
        return { name = name }
      end,
    }
  end,
}

local function metadata_from(keys)
  return {
    find = function(_, _, key)
      return keys[key]
    end,
  }
end

local function source_from(keys)
  return {
    call = function()
      return {
        lookup = function()
          return metadata_from(keys)
        end,
      }
    end,
  }
end

local function run_policy(nodes, keys)
  local selected
  local event = {
    get_properties = function()
      return { ["default-node.type"] = "audio.sink" }
    end,
    get_data = function(_, key)
      if key ~= "available-nodes" then
        return nil
      end
      return {
        parse = function()
          return nodes
        end,
      }
    end,
    set_data = function(_, key, value)
      if key == "selected-node" then
        selected = value
      end
    end,
    get_source = function()
      return source_from(keys)
    end,
  }
  hooks["zlyme/select-sink"](event)
  return selected
end

local stderr = io.stderr
io = nil
dofile(policy_path)
if hooks["zlyme/select-sink"] == nil then
    stderr:write("policy hook was not registered\n")
  os.exit(1)
end

local codec = {
  ["node.name"] = "alsa_output._sys_devices_platform_rk817-sound_sound_card1.stereo-fallback",
}
local hdmi = {
  ["node.name"] = "alsa_output._sys_devices_platform_hdmi-sound_sound_card0.stereo-fallback",
}
local bt = {
  ["node.name"] = "bluez_output.TEST",
}

local function expect(label, got, want)
  if got ~= want then
    stderr:write(label .. ": got " .. tostring(got) .. "\n")
    os.exit(1)
  end
end

expect("valid ELD", run_policy({ codec, hdmi }, {
  ["zlyme.hdmi"] = "yes",
  ["zlyme.pref"] = "auto",
  ["default.audio.sink"] = '{"name":"alsa_output._sys_devices_platform_rk817-sound_sound_card1.stereo-fallback"}',
}), hdmi["node.name"])

expect("silent ELD", run_policy({ codec, hdmi }, {
  ["zlyme.hdmi"] = "no",
  ["zlyme.pref"] = "auto",
}), codec["node.name"])

expect("explicit codec", run_policy({ codec, hdmi, bt }, {
  ["zlyme.hdmi"] = "yes",
  ["zlyme.pref"] = "codec",
}), codec["node.name"])

expect("headset", run_policy({ codec, hdmi, bt }, {
  ["zlyme.hdmi"] = "yes",
  ["zlyme.pref"] = "auto",
}), bt["node.name"])

hooks = {}
dofile(volume_path)
if hooks["zlyme/apply-saved-volume"] == nil then
  stderr:write("volume hook was not registered\n")
  os.exit(1)
end
local node = {
  properties = {
    ["node.name"] = "bluez_output.TEST",
    ["audio.channels"] = "2",
  },
}
hooks["zlyme/apply-saved-volume"]({
  get_subject = function()
    return node
  end,
  get_source = function()
    return source_from({})
  end,
})
