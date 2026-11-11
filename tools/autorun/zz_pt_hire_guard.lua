-- TEMPORARY test aid for the unattended Trickster-pawn runs (not part of any mod; delete after the run).
-- A rift pawn's hire dialog can open by itself (or from the Space taps that load the save) and would block the tests:
-- whenever a talk-select list with "Hire" and "Cancel" is on screen, pick Cancel and hide the pawn details panel.
if not _G.__pt_hire_guard then
_G.__pt_hire_guard = { closed = 0 }
do local f = io.open("pt_dev/hire_pause.flag", "r"); if f then f:close(); _G.__pt_hire_guard.pause = true end end
local tick = 0
local function guard()
    tick = tick + 1
    if tick % 15 ~= 0 then return end
    if _G.__pt_hire_guard.pause then return end
    local gm = sdk.get_managed_singleton("app.GuiManager"); if not gm then return end
    local ts = gm:get_field("TalkSelect"); if not ts or not ts:get_field("IsDisp") then return end
    if ts:get_field("FlowNow") ~= 0 then return end -- app.ui021601.FlowId: Exec=0 (open), End=1 (the IsDisp flag stays set after it closed)
    local infos = ts:get_field("ScrCtrl"); infos = infos and infos:get_field("InfoList"); if not infos then return end
    local cancel, hire
    for i = 0, infos:call("get_Count") - 1 do
        local m = tostring(infos:call("get_Item", i):get_field("Msg"))
        if m == "Cancel" then cancel = i elseif m == "Hire" then hire = true end
    end
    if not (cancel and hire) then return end
    ts:set_field("SelectedIndex", cancel); ts:call("reqEnd")
    local l = gm:get_field("_GUIList")
    for i = 0, l:call("get_Count") - 1 do
        local g = l:call("get_Item", i)
        if g and g:get_type_definition():get_full_name() == "app.ui041701" then pcall(function() g:call("reqHide") end) end
    end
    _G.__pt_hire_guard.closed = _G.__pt_hire_guard.closed + 1
end
re.on_frame(function() pcall(guard) end)
end

-- tutorial windows (app.ui080101) pause nothing but cover the screen and wait for a key: send an open one (flow Exec=3)
-- to its Out flow (4).
if not _G.__pt_tut_guard then
    _G.__pt_tut_guard = { closed = 0 }
    local ttick = 0
    local function tguard()
        ttick = ttick + 1
        if ttick % 30 ~= 0 then return end
        local gm = sdk.get_managed_singleton("app.GuiManager"); if not gm then return end
        local l = gm:get_field("_GUIList"); if not l then return end
        for i = 0, l:call("get_Count") - 1 do
            local g = l:call("get_Item", i)
            if g and g:get_type_definition():get_full_name() == "app.ui080101" and g:get_field("FlowNow") == 3 then
                g:call("setFlowId(app.ui080101.FlowId)", 4)
                _G.__pt_tut_guard.closed = _G.__pt_tut_guard.closed + 1
            end
        end
    end
    re.on_frame(function() pcall(tguard) end)
end
