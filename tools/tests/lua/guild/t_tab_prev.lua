_G.__gui_dir = "prev"
local gm = sdk.get_managed_singleton("app.GuiManager"); local l = gm:get_field("_GUIList"); local g
for i = 0, l:call("get_Count")-1 do local x = l:call("get_Item", i); if x and x:get_type_definition():get_full_name() == "app.ui040101_00" then g = x end end
local tab = g:get_field("_CharaTab"); local lc = tab:get_field("_ListCtrl"); local gis = lc:get_field("Input") or g:get_field("_Main_ContentsListCtrl"):get_field("Input"); local ui = gis:get_field("Input")
local mask = (_G.__gui_dir == "next") and lc:get_field("InputKeyNext") or lc:get_field("InputKeyPrev")
ui:set_field("ButtonTriggerFlags", (ui:get_field("ButtonTriggerFlags") or 0) | mask); ui:set_field("ButtonOnFlags", (ui:get_field("ButtonOnFlags") or 0) | mask)
out("before", tostring(tab:call("get_SelectedCharaID")), "level", tostring(gis:call("get_GlobalInputLevel")), "isTrigger", tostring(gis:call("isButtonTrigger", mask, 0)))
local ok, err = pcall(function() tab:call("updateInput") end); out("CharaTab.updateInput()", _G.__gui_dir, ok, err or "", "after", tostring(tab:call("get_SelectedCharaID")), "gui chara", tostring(g:call("getCharaId")))
