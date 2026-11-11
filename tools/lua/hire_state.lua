local gm = sdk.get_managed_singleton("app.GuiManager"); local ts = gm and gm:get_field("TalkSelect")
local msgs = {}
if ts and ts:get_field("IsDisp") then
  local infos = ts:get_field("ScrCtrl"); infos = infos and infos:get_field("InfoList")
  if infos then for i = 0, infos:call("get_Count") - 1 do msgs[#msgs + 1] = i .. "=" .. tostring(infos:call("get_Item", i):get_field("Msg")) end end
end
out("talksel disp", tostring(ts and ts:get_field("IsDisp")), "flow", tostring(ts and ts:get_field("FlowNow")), "sel", tostring(ts and ts:get_field("SelectedIndex")), "msgs", table.concat(msgs, ","),
  "guard paused", tostring(_G.__pt_hire_guard and _G.__pt_hire_guard.pause), "closed", tostring(_G.__pt_hire_guard and _G.__pt_hire_guard.closed))
