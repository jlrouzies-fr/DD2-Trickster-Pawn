-- read only: is a talk on, is a main-flow menu open, the talk select's texts, the guild screen's flow and character
local gm = sdk.get_managed_singleton("app.GuiManager"); local im = sdk.get_managed_singleton("app.InteractManager"); local ts = gm:get_field("TalkSelect")
local msgs = {}
pcall(function() if ts:get_field("IsDisp") then local infos = ts:get_field("ScrCtrl"):get_field("InfoList"); for i = 0, infos:call("get_Count") - 1 do msgs[#msgs + 1] = tostring(infos:call("get_Item", i):get_field("Msg")) end end end)
local l = gm:get_field("_GUIList"); local g
for i = 0, l:call("get_Count") - 1 do local x = l:call("get_Item", i); if x and x:get_type_definition():get_full_name() == "app.ui040101_00" then g = x end end
local gs = "no guild screen"
if g then pcall(function() local drawn = g:call("get_GameObject"):call("get_DrawSelf"); gs = "guild screen flow " .. tostring(g:get_field("_FlowNow")) .. " drawn " .. tostring(drawn) .. " chara " .. tostring(g:call("getCharaId")) end) end
local mo = "?"; pcall(function() mo = tostring(gm:call("IsOpenMainFlowUI")) end)
out("IsPlayerTalking", tostring(im:get_field("IsPlayerTalking")), "IsOpenMainFlowUI", mo, "talk select shown", tostring(ts:get_field("IsDisp")), "flow", tostring(ts:get_field("FlowNow")), "[" .. table.concat(msgs, " / ") .. "]", "|", gs)
