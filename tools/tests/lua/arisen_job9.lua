-- TEST: the Arisen becomes a Trickster (setJobQualified + requestChangeJob, the calls the mod uses on the pawn)
local pl = sdk.get_managed_singleton("app.CharacterManager"):call("get_ManualPlayer"); local human = pl:call("get_Human")
local jc = human:get_field("<JobContext>k__BackingField"); local before = jc:get_field("CurrentJob")
if before ~= 9 then
  jc:call("setJobQualified", 9)
  local ch = human:get_field("<JobChanger>k__BackingField")
  local ok, e = pcall(function() ch:call("requestChangeJob", 9) end)
  out("Arisen job", tostring(before), "-> requestChangeJob(9)", tostring(ok), tostring(e))
else out("Arisen is already Job09") end
