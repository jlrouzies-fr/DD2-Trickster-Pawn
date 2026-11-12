local im = sdk.get_managed_singleton("app.InteractManager")
local pl = sdk.get_managed_singleton("app.CharacterManager"):call("get_ManualPlayer")
local ip = _G.__force_ip; if not ip then out("no forced point"); return end
local ok, err = pcall(function() im:call("addActiveInteract", pl, ip) end); out("addActiveInteract", ok, err or "")
out("ActiveInteracts", im:get_field("ActiveInteracts"):call("get_Count"), "isInteracting", tostring(im:call("isInteracting", pl)))
local ok2, err2 = pcall(function() im:call("executeInteract", pl) end); out("executeInteract", ok2, err2 or "")
