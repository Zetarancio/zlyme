-- Saved playback gain for sinks that appear after the graph is up.
-- main-embedded does not restore route volume. The route default is only
-- the level used before this hook runs. A stored 0 stays silent.
-- The curve matches linear_gain() in zlyme-audio: (percent/100)^3.

log = Log.open_topic("s-zlyme")

local CONF = "/storage/.config/audio.conf"

local function saved_percent()
  local f = io.open(CONF, "r")
  if not f then
    return nil
  end
  local percent = nil
  for line in f:lines() do
    local v = line:match("^ZLYME_VOLUME=(%d+)$")
    if v then
      percent = tonumber(v)
    end
  end
  f:close()
  return percent
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

local function apply(node)
  local props = node.properties
  local name = props["node.name"] or ""
  if name:find("null", 1, true) or name:find("dummy", 1, true) then
    return
  end
  local percent = saved_percent()
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
      apply(node)
    end
    -- The pinned 0.5.14 scripts only read default.configured.audio.sink.
    -- wpctl set-default is the writer, and it cannot run on this thread:
    -- the client would wait for WirePlumber while this hook waits for
    -- the client. The shell returns immediately. The ELD is not an ACP
    -- port, so a priority rule cannot replace this call.
    os.execute("( /usr/sbin/zlyme-audio route >/dev/null 2>&1 & )")
  end
}:register()
