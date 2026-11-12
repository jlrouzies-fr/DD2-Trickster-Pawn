local gm = sdk.get_managed_singleton("app.GuiManager"); local ts = gm:get_field("TalkSelect")
local infos = ts:get_field("ScrCtrl"):get_field("InfoList"); local want = _G.__pick_text or "Cancel"; local idx
for i = 0, infos:call("get_Count")-1 do local m = tostring(infos:call("get_Item", i):get_field("Msg")); if m == want then idx = i end end
if idx and ts:get_field("IsDisp") then ts:set_field("SelectedIndex", idx); local ok, err = pcall(function() ts:call("reqEnd") end); out("pick", want, "index", idx, ok, err or "")
else out("pick", want, "NOT FOUND (IsDisp " .. tostring(ts:get_field("IsDisp")) .. ")") end
