local im = sdk.get_managed_singleton("app.InteractManager")
local hs = im:get_field("InteractiveObjects"); local en = hs:call("GetEnumerator")
while en:call("MoveNext") do
  local o = en:call("get_Current")
  local go = o:get_field("<Owner>k__BackingField"); local n = go and go:call("get_Name") or ""
  if n == "ch300059" then
    local d = o:get_field("DataList"):call("get_Item", 0); local wk = o:get_field("Works"):call("get_Item", 0)
    out("IsDisableTerrainCheck", tostring(d:get_field("IsDisableTerrainCheck")), "work._canPlayerInteract", tostring(wk:get_field("_canPlayerInteract")), "canPlayer", tostring(o:call("canPlayerInteract", 0)))
  end
end
out("InteractivesForPlayer", im:get_field("InteractivesForPlayer"):call("get_Count"))
local hp = im:get_field("HighestPriorityObjectForPlayer"); if hp then pcall(function() out("highest owner", hp:get_field("Object"):get_field("<Owner>k__BackingField"):call("get_Name")) end) else out("highest nil") end
