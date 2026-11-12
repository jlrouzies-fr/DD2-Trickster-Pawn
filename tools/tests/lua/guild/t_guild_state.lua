local gm = sdk.get_managed_singleton("app.GuiManager"); local im = sdk.get_managed_singleton("app.InteractManager")
out("talking", tostring(im:get_field("IsPlayerTalking")), "isDispTalkSelect", tostring(gm:call("isDispTalkSelect")))
local l = gm:get_field("_GUIList"); local vis = {}; local guild
for i = 0, l:call("get_Count")-1 do local g = l:call("get_Item", i); if g then local tn = g:get_type_definition():get_full_name(); if tn == "app.ui040101_00" then guild = g end; pcall(function() local go = g:call("get_GameObject"); if go:call("get_DrawSelf") then vis[#vis+1] = tn end end) end end
out("drawn GUIs", table.concat(vis, " "))
out("guild gui present", tostring(guild ~= nil))
if guild then
  local fs = {}
  for _, fn in ipairs({"MenuKind", "_MenuKind", "<MenuKind>k__BackingField", "FlowNow", "_FlowNow", "IsPawn", "<IsPawn>k__BackingField", "TargetChara", "_DisableJobList", "JobInformationData", "SelectJob", "CurrentJob", "<CurrentJob>k__BackingField"}) do local ok, v = pcall(function() return guild:get_field(fn) end); if ok and v ~= nil then local s = tostring(v); if type(v) == "userdata" then pcall(function() s = v:get_type_definition():get_full_name() end) end; fs[#fs+1] = fn .. "=" .. s end end
  out("guild fields", table.concat(fs, " "))
end
