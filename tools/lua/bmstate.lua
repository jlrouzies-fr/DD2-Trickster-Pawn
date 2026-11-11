-- read only: the main pawn's battle state controller, weapon drawn flag and battle mode timer
local function flat(o)
  if o == nil then return "nil" end; local t = {}
  pcall(function() local td = o:get_type_definition()
    while td and td:get_full_name() ~= "System.Object" do
      for _, f in ipairs(td:get_fields()) do if not f:is_static() then local v = o:get_field(f:get_name()); local n = f:get_name():gsub("k__BackingField", "")
        t[#t + 1] = n .. "=" .. (type(v) == "userdata" and ("obj:" .. f:get_type():get_name()) or tostring(v)) end end
      td = td:get_parent_type() end end)
  return table.concat(t, ", ")
end
local pawn = sdk.get_managed_singleton("app.PawnManager"):get_field("_MainPawn"); local ch = pawn:call("get_CachedCharacter"); local hm = ch:call("get_Human")
local bsc = ch:get_field("BattleStateCtrl")
out("drawn", tostring(ch:call("get_IsDrawedWeapon")), "human battle mode", tostring(hm:call("get_IsBattleMode")), "timer", tostring(hm:get_field("TimerBattleMode")), "party battle", tostring(sdk.get_managed_singleton("app.PawnManager"):call("get_BattleController"):get_field("_CurrentState")))
out("BattleStateController", bsc and bsc:get_type_definition():get_full_name() or "nil", flat(bsc))
local td = bsc and bsc:get_type_definition(); local t = {}
if td then for _, m in ipairs(td:get_methods()) do local ps = {}; for _, p in ipairs(m:get_param_types()) do ps[#ps + 1] = p:get_name() end; t[#t + 1] = m:get_name() .. "(" .. table.concat(ps, ",") .. "):" .. m:get_return_type():get_name() end end
out("methods", table.concat(t, " ; "))
