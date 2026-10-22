-- Saved playback gain for sinks that appear after the graph is up.
-- main-embedded does not restore route volume. The route default is only
-- the level used before this hook runs. A stored 0 stays silent.
-- The curve matches linear_gain() in zlyme-audio: (percent/100)^3.
-- Sink choice is zlyme-policy.lua. This hook does not spawn a router.
-- The percent is metadata zlyme.volume. The sandbox has no io library.

log = Log.open_topic("s-zlyme")

local function saved_percent(metadata)
  if not metadata then
    return nil
  end
  local value = metadata:find(0, "zlyme.volume")
  if type(value) ~= "string" then
    return nil
  end
  return tonumber(value)
end

local function gain_of(percent)
  if percent <= 0 then
    return 0.0
  end
  if percent >= 100 then
    return 1.0
  end
  local x = percent / 100.0
  return x * x * x
end

local function apply(node, source)
  local props = node.properties
  local name = props["node.name"] or ""
  if name:find("null", 1, true) or name:find("dummy", 1, true) then
    return
  end
  local metadata = nil
  if source then
    local metadata_om = source:call("get-object-manager", "metadata")
    if metadata_om then
      metadata = metadata_om:lookup {
        Constraint { "metadata.name", "=", "default" },
      }
    end
  end
  local percent = saved_percent(metadata)
  if percent == nil then
    return
  end
  local gain = gain_of(percent)
  local channels = tonumber(props["audio.channels"]) or 2
  if channels < 1 then
    channels = 2
  end
  local vols = { "Spa:Float" }
  for _ = 1, channels do
    vols[#vols + 1] = gain
  end
  local param = Pod.Object {
    "Spa:Pod:Object:Param:Props", "Props",
    volume = gain,
    mute = false,
    channelVolumes = Pod.Array(vols),
  }
  log:info(node, string.format("saved volume %d gain %f on %s", percent, gain, name))
  node:set_param("Props", param)
end

SimpleEventHook {
  name = "zlyme/apply-saved-volume",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "node-added" },
      Constraint { "media.class", "=", "Audio/Sink" },
    },
  },
  execute = function(event)
    local node = event:get_subject()
    if node then
      apply(node, event:get_source())
    end
  end
}:register()
