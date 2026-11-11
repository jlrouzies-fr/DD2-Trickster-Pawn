-- read only: conditions and evaluation criteria of some live main decisions (wrapper side)
local st = PawnTrickster.state
local function gk(g) return tostring(g:get_field("mData1")) .. ":" .. tostring(g:get_field("mData2")) end
local function short(ap) local s = "?"; pcall(function() s = tostring(ap:call("ToString")) end); return (s:match("ActInterPackData/(.-)%.user") or s) end
local function simple(o, depth)
  local t = {}; local td = o:get_type_definition()
  while td and td:get_full_name() ~= "System.Object" do
    for _, f in ipairs(td:get_fields()) do if not f:is_static() then
      local n = f:get_name(); local ok, v = pcall(function() return o:get_field(n) end)
      if ok and v ~= nil then
        if type(v) ~= "userdata" then t[#t + 1] = n .. "=" .. tostring(v)
        else local tn = ""; pcall(function() tn = v:get_type_definition():get_full_name() end)
          if tn == "via.Range" then local off = f:get_offset_from_base(); t[#t + 1] = string.format("%s={%.1f,%.1f}", n, o:read_float(off), o:read_float(off + 4))
          elseif (depth or 0) < 1 and tn ~= "" and not tn:find("%[%]") and not tn:find("^System") then t[#t + 1] = n .. ":" .. tn:gsub("^app%.", "") .. "(" .. simple(v, (depth or 0) + 1) .. ")"
          else t[#t + 1] = n .. ":" .. tn:gsub("^app%.", "") end end end end end
    td = td:get_parent_type() end
  return table.concat(t, " ")
end
local function listdesc(l)
  local r = {}; if not l then return "nil" end
  local n = l:call("get_Count")
  for i = 0, n - 1 do local c = l:call("get_Item", i); if c then r[#r + 1] = c:get_type_definition():get_full_name():gsub("app%.decision%.", "") .. "{" .. simple(c) .. "}" end end
  return "[" .. #r .. "] " .. table.concat(r, " || ")
end
local want = _G.__wc_want or { "MoveToPosition_Walk_Target", "Job03_KeepDistance_01", "Move_Fix_Dash_Target", "OURS:rally" }
local pawn = sdk.get_managed_singleton("app.PawnManager"):get_field("_MainPawn")
local mod = pawn:get_field("CachedAIDecisionMaker"):get_field("<DecisionModule>k__BackingField")
local list = mod:get_field("<MainDecisions>k__BackingField"); local items = list:get_field("_items")
for i = 0, list:call("get_Count") - 1 do local w = items[i]; if w then
  local nm = st.guid_names and st.guid_names[gk(w:get_field("<UniqueID>k__BackingField"))]; local name = nm and ("OURS:" .. nm) or short(w:get_field("<ActionPack>k__BackingField"))
  for _, s in ipairs(want) do if name:find(s, 1, true) then
    out("== " .. i .. " " .. name .. " rank " .. tostring(w:get_field("<Priority>k__BackingField"):get_field("_Rank")))
    out("  PRE " .. listdesc(w:get_field("<Preconditions>k__BackingField")))
    out("  TPRE (asCondition " .. tostring(w:get_field("<TargetPreconditionsAsCondition>k__BackingField")) .. ") " .. listdesc(w:get_field("<TargetPreconditions>k__BackingField")))
    out("  TCOND " .. listdesc(w:get_field("<TargetConditions>k__BackingField")))
    local ec = w:get_field("<EvaluationCriteria>k__BackingField"); local r = {}
    if ec then for k = 0, ec:call("get_Count") - 1 do local e = ec:call("get_Item", k); local cr = e:get_field("_Criteria"); cr = cr and cr:get_field("_Process")
      r[#r + 1] = "w=" .. tostring(e:get_field("_Weight")) .. " " .. (cr and (cr:get_type_definition():get_name() .. "{" .. simple(cr) .. "}") or "nil") end end
    out("  EVAL " .. table.concat(r, " || "))
  end end
end end
