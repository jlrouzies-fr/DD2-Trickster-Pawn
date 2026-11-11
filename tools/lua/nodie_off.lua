local cm = sdk.get_managed_singleton("app.CharacterManager"); local pl = cm:call("get_ManualPlayer"); local hit = pl:call("get_Hit")
hit:call("set_IsNoDie", false); out("nodie", tostring(hit:call("get_IsNoDie")))
