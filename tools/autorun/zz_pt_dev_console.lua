-- Dev console for working on the Trickster pawn mod (not part of the mod; remove it when you are done).
-- Runs reframework/data/pt_dev/cmd.lua whenever its first line ("-- seq N") changes;
-- the result goes to reframework/data/pt_dev/out.txt. `out(...)` inside the command adds a line to that file.
-- The console runs the last cmd.lua again at every game start: leave an idle command behind (tools/lua.sh --idle).
local last_seq = nil
local tick = 0
local function run()
    tick = tick + 1
    if tick % 10 ~= 0 then return end
    local f = io.open("pt_dev/cmd.lua", "r")
    if not f then return end
    local src = f:read("a")
    f:close()
    local seq = src:match("^%-%- seq (%d+)")
    if not seq or seq == last_seq then return end
    last_seq = seq
    local out = {}
    local env = setmetatable({ out = function(...)
        local t = {}
        for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
        out[#out + 1] = table.concat(t, "\t")
    end }, { __index = _G })
    local chunk, err = load(src, "cmd", "t", env)
    local ok, res
    if chunk then ok, res = pcall(chunk) else ok, res = false, err end
    out[#out + 1] = ("[seq %s] %s %s"):format(seq, ok and "ok" or "ERR", tostring(res))
    local o = io.open("pt_dev/out.txt", "w")
    if o then o:write(table.concat(out, "\n")); o:close() end
end
-- The game's main flow phase (3 StartUp, 8 TitleMenu, 9-26 loading, 27 InGame), written to pt_dev/phase.txt whenever
-- it changes and appended with the time to pt_dev/phase_log.txt: the launcher reads the file to press Space only
-- while the title menu is up (tools/load_space.ps1 -PhaseFile), instead of holding the focus for the whole boot.
local last_phase = nil
local phase_frames = 0
local function phase()
    phase_frames = phase_frames + 1; if phase_frames < 30 or phase_frames % 5 ~= 0 then return end -- (not in the first frames of the boot; six reads a second at 30 FPS)
    local mf = sdk.get_managed_singleton("app.MainFlowManager")
    local p = mf and mf:call("get_FlowPhase") or 0
    if p == last_phase then return end
    last_phase = p
    local f = io.open("pt_dev/phase.txt", "w"); if f then f:write(tostring(p)); f:close() end
    local g = io.open("pt_dev/phase_log.txt", "a"); if g then g:write(os.date("%H:%M:%S") .. " phase " .. tostring(p) .. "\n"); g:close() end
end
re.on_pre_application_entry("LateUpdateBehavior", function() pcall(phase); pcall(run) end)
