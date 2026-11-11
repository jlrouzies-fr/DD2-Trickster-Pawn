-- read only: every main decision of the pawn with its priority, policy, tags, overwriter, situation; module settings
local st = PawnTrickster.state
local function gk(g) return tostring(g:get_field("mData1")) .. ":" .. tostring(g:get_field("mData2")) end
local function short(ap) local s = "?"; pcall(function() s = tostring(ap:call("ToString")) end); return (s:match("ActInterPackData/(.-)%.user") or s) end
local function flat(o)
  if o == nil then return "nil" end
  if type(o) ~= "userdata" then return tostring(o) end
  local t = {}
  local ok = pcall(function() for _, f in ipairs(o:get_type_definition():get_fields()) do if not f:is_static() then local v = o:get_field(f:get_name()); t[#t + 1] = f:get_name():gsub("k__BackingField", "") .. "=" .. (type(v) == "userdata" and "obj" or tostring(v)) end end end)
  return "{" .. table.concat(t, ",") .. "}"
end
local pawn = sdk.get_managed_singleton("app.PawnManager"):get_field("_MainPawn")
local mod = pawn:get_field("CachedAIDecisionMaker"):get_field("<DecisionModule>k__BackingField")
out("module situation", flat(mod:get_field("<Situation>k__BackingField")), "method", tostring(mod:get_field("_EvaluationMethod")), "invalid tags", flat(mod:get_field("_InvalidControlTags")), "limit", flat(mod:get_field("<ProcessingLimit>k__BackingField")), "stageEval", tostring(mod:get_field("<StageEvaluation>k__BackingField")), "useTargetSection", tostring(mod:call("get_UseTargetSection")))
for _, ln in ipairs({ "Pre", "Main", "Post" }) do
  local list = mod:get_field("<" .. ln .. "Decisions>k__BackingField"); local items = list:get_field("_items")
  for i = 0, list:call("get_Count") - 1 do local w = items[i]; if w then
    local nm = st.guid_names and st.guid_names[gk(w:get_field("<UniqueID>k__BackingField"))]
    out(string.format("%s %2d %-52s prio %s policy %s tags %s over %s sit %s target %s cd %.0f/%.0f pen %s", ln, i, nm and ("OURS:" .. nm) or short(w:get_field("<ActionPack>k__BackingField")),
      flat(w:get_field("<Priority>k__BackingField")), flat(w:get_field("<Policy>k__BackingField")), flat(w:get_field("<ControlTags>k__BackingField")), flat(w:get_field("<Overwriter>k__BackingField")),
      flat(w:get_field("<Situation>k__BackingField")), flat(w:get_field("<Target>k__BackingField")), w:get_field("<CooldownTimer>k__BackingField") or -1, w:get_field("<CooldownTime>k__BackingField") or -1, tostring(w:get_field("<IsPenalizeConsecutiveChoice>k__BackingField"))))
  end end
end
