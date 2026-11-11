local gm = sdk.get_managed_singleton("app.GuiManager")
local ok, e = pcall(function() return gm:call("requestGuiType", 12) end)
out("requestGuiType(12)", tostring(ok), tostring(e))
