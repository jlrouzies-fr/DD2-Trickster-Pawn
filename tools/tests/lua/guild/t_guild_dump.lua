local gm = sdk.get_managed_singleton("app.GuiManager"); local l = gm:get_field("_GUIList"); local g
for i = 0, l:call("get_Count")-1 do local x = l:call("get_Item", i); if x and x:get_type_definition():get_full_name() == "app.ui040101_00" then g = x end end
if not g then out("no guild gui"); return end
local td = g:get_type_definition()
local fs = {}
for _, f in ipairs(td:get_fields()) do local n = f:get_name(); local tn = f:get_type():get_name()
  if tn == "Boolean" or tn == "Int32" or tn == "UInt32" or tn:find("Enum") or tn:find("Kind") or tn:find("Flow") or tn:find("CharacterID") or n:lower():find("pawn") or n:lower():find("job") or n:lower():find("chara") then
    local v; pcall(function() v = g:get_field(n) end); local s = tostring(v); if type(v) == "userdata" then pcall(function() s = v:get_type_definition():get_full_name() end); pcall(function() s = s .. "#" .. tostring(v:call("get_Count")) end) end
    fs[#fs+1] = n .. ":" .. tn .. "=" .. s end end
out("guild fields", table.concat(fs, " | "))
local dl = g:get_field("_DisableJobList"); local s = {}; pcall(function() for i = 0, dl:call("get_Count")-1 do s[#s+1] = tostring(dl:call("get_Item", i)) end end); out("_DisableJobList", table.concat(s, ","))
local jd = g:get_field("JobInformationData"); pcall(function() local ps = jd:get_field("_Params"); local t = {}; for i = 0, ps:get_size()-1 do local p = ps:get_element(i); t[#t+1] = tostring(p:get_field("_JobID")) .. ":" .. tostring(p:get_field("_EnablePawn")) end; out("JobInfo _EnablePawn", table.concat(t, " ")) end)
local ms = {}
for _, m in ipairs(td:get_methods()) do local n = m:get_name(); if n:lower():find("pawn") or n:lower():find("chara") or n:lower():find("select") or n:lower():find("decide") or n:lower():find("flow") or n:lower():find("tab") then local ps = {}; for _, p in ipairs(m:get_param_types()) do ps[#ps+1] = p:get_name() end; ms[#ms+1] = n .. "(" .. table.concat(ps, ",") .. ")" end end
out("guild methods", table.concat(ms, " "))
local et = sdk.find_type_definition("app.ui040101_00.FlowId"); if et then local e = {}; for _, f in ipairs(et:get_fields()) do if f:is_static() then e[#e+1] = f:get_name() .. "=" .. tostring(f:get_data(nil)) end end; out("FlowId", table.concat(e, " ")) end
et = sdk.find_type_definition("app.ui040101_00.MenuKind"); if et then local e = {}; for _, f in ipairs(et:get_fields()) do if f:is_static() then e[#e+1] = f:get_name() .. "=" .. tostring(f:get_data(nil)) end end; out("MenuKind", table.concat(e, " ")) end
