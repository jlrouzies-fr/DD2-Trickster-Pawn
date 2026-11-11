-- pick "Hire" in an open hire dialog (the same two calls the guard uses for Cancel)
local gm = sdk.get_managed_singleton("app.GuiManager"); local ts = gm:get_field("TalkSelect")
if not (ts and ts:get_field("IsDisp") and ts:get_field("FlowNow") == 0) then out("no open dialog") return end
local infos = ts:get_field("ScrCtrl"):get_field("InfoList"); local hire
for i = 0, infos:call("get_Count") - 1 do if tostring(infos:call("get_Item", i):get_field("Msg")) == "Hire" then hire = i end end
if not hire then out("no Hire entry") return end
ts:set_field("SelectedIndex", hire); ts:call("reqEnd")
out("picked Hire at index", hire)
