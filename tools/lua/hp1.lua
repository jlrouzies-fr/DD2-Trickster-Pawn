local cm = sdk.get_managed_singleton("app.CharacterManager")
local pl = cm and cm:call("get_ManualPlayer")
local hit
for _, g in ipairs({"get_Hit", "get_HitController"}) do
    local ok, h = pcall(function() return pl:call(g) end)
    if ok and h then hit = h; out("getter", g); break end
end
if not hit then out("no hit controller"); return end
out("type", hit:get_type_definition():get_full_name(), "hp before", tostring(hit:call("get_Hp")))
hit:call("setHpValue(System.Single, System.Boolean)", 1.0, false)
out("hp after", tostring(hit:call("get_Hp")), "guard", tostring(PawnTrickster.cfg.test_guard))
