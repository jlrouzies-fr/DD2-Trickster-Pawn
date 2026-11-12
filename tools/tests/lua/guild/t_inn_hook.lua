-- test-only: make the talk interact's terrain ray always miss (the inn counter blocks it from this spot)
if not _G.__inn_terrain_hook then
  local m = sdk.find_type_definition("app.InteractiveObject.Work"):get_method("isTerrainFound")
  local ok, err = pcall(function()
    sdk.hook(m, function(args) if _G.__inn_terrain_skip then return sdk.PreHookResult.SKIP_ORIGINAL end end, function(retval) if _G.__inn_terrain_skip then return sdk.to_ptr(0) end return retval end)
  end)
  _G.__inn_terrain_hook = ok; out("isTerrainFound hook", ok, err or "")
end
_G.__inn_terrain_skip = true; out("skip on")
