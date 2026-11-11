_G.__menu_do = "title"
local gm = sdk.get_managed_singleton("app.GuiManager"); local l = gm:get_field("_GUIList"); local menu
for i = 0, l:call("get_Count")-1 do local g = l:call("get_Item", i); if g and g:get_type_definition():get_full_name() == "app.ui060101" then menu = g end end
local mf = sdk.get_managed_singleton("app.MainFlowManager")
out("menu flow", tostring(menu:get_field("FlowNow")), "init", tostring(menu:get_field("IsInit")), "IsReturnTitle", tostring(menu:get_field("IsReturnTitle")), "phase", tostring(mf:call("get_FlowPhase")))
if _G.__menu_do == "title" then _G.__menu_do = nil; out("returnTitle", pcall(function() return menu:call("returnTitle") end)) end
if _G.__menu_do == "end" then _G.__menu_do = nil; out("requestEndMenu", pcall(function() return menu:call("requestEndMenu") end)) end
