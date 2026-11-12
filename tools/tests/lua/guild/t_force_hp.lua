local im = sdk.get_managed_singleton("app.InteractManager")
-- which gimmick wins now
local hp = im:get_field("HighestPriorityObjectForPlayer")
if hp then pcall(function() local o = hp:get_field("Object"); local go = o:get_field("<Owner>k__BackingField"); local d = o:get_field("DataList"):call("get_Item", hp:get_field("PointNo") or 0)
  local w = o:get_field("Works"); local wt = {}; for i = 0, w:call("get_Count")-1 do wt[#wt+1] = w:call("get_Item", i):get_type_definition():get_full_name() end
  out("current highest", go:call("get_Name"), "prio", tostring(d:get_field("PriorityForPlayer")), "dist", tostring(d:get_field("Distance")), "works", table.concat(wt, ",")) end) end
-- keep the innkeeper's point as the highest-priority object right after the game recomputes it
if not _G.__force_hp_hook then
  local ok, err = pcall(function()
    sdk.hook(sdk.find_type_definition("app.InteractManager"):get_method("processHighestPriorityObjectForPlayer"), function(args) thread.get_hook_storage().this = sdk.to_managed_object(args[2]) end, function(retval)
      if _G.__force_hp and _G.__force_ip then local m = thread.get_hook_storage().this; if m then m:set_field("HighestPriorityObjectForPlayer", _G.__force_ip) end end
      return retval
    end)
  end)
  _G.__force_hp_hook = ok; out("processHighest hook", ok, err or "")
end
local target; local hs = im:get_field("InteractiveObjects"); local en = hs:call("GetEnumerator")
while en:call("MoveNext") do local o = en:call("get_Current"); local go = o:get_field("<Owner>k__BackingField"); if go and go:call("get_Name") == "ch300059" then target = o end end
local ip = sdk.create_instance("app.InteractManager.InteractPoint"); ip:add_ref_permanent(); ip:set_field("Object", target); ip:set_field("PointNo", 0)
_G.__force_ip = ip; _G.__force_hp = true; out("force highest = innkeeper on")
