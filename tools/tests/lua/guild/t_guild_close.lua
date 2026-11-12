local gm = sdk.get_managed_singleton("app.GuiManager"); local l = gm:get_field("_GUIList"); local g
for i = 0, l:call("get_Count")-1 do local x = l:call("get_Item", i); if x and x:get_type_definition():get_full_name() == "app.ui040101_00" then g = x end end
if not g then out("no guild gui"); return end
local ok, err = pcall(function() g:call("setFlowId", 24) end); out("setFlowId(End)", ok, err or "", "flow", tostring(g:get_field("_FlowNow")))
