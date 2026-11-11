-- test runs: hold the frame rate cap (engine call, nothing is saved to the player's options). _G.__fps = n (default 30)
-- Another mod or the game's own option code can set the cap again, so it is checked once a second for the session.
local app = sdk.get_native_singleton("via.Application"); local td = sdk.find_type_definition("via.Application")
local before = sdk.call_native_func(app, td, "get_MaxFps")
_G.__fps_hold = _G.__fps or _G.__fps_hold or 30.0
sdk.call_native_func(app, td, "set_MaxFps", _G.__fps_hold)
if not _G.__fps_hook then _G.__fps_hook = true; _G.__fps_resets = 0
  local t = 0
  re.on_frame(function()
    local now = os.clock(); if now - t < 1.0 then return end; t = now
    pcall(function() local a = sdk.get_native_singleton("via.Application")
      if math.abs(sdk.call_native_func(a, td, "get_MaxFps") - _G.__fps_hold) > 0.5 then sdk.call_native_func(a, td, "set_MaxFps", _G.__fps_hold); _G.__fps_resets = _G.__fps_resets + 1 end end)
  end)
end
out("MaxFps", tostring(before), "->", tostring(sdk.call_native_func(app, td, "get_MaxFps")), "held, set again so far", tostring(_G.__fps_resets))
