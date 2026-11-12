if not _G.__inn_cam_hook then
  local m = sdk.find_type_definition("app.InteractiveObject.Work"):get_method("isInCamera")
  local ok, err = pcall(function()
    sdk.hook(m, function(args) if _G.__inn_cam_skip then return sdk.PreHookResult.SKIP_ORIGINAL end end, function(retval) if _G.__inn_cam_skip then return sdk.to_ptr(1) end return retval end)
  end)
  _G.__inn_cam_hook = ok; out("isInCamera hook", ok, err or "")
end
_G.__inn_cam_skip = true; out("cam skip on")
