_G.__ptp = nil
_G.__ptp2 = { on = true, t = os.clock() + 150 }
if not _G.__ptp2_hooked then _G.__ptp2_hooked = true
  re.on_frame(function()
    local T = _G.__ptp2; if not (T and T.on) then return end
    if os.clock() > T.t then T.on = false; return end
    local ok, e = pcall(function()
      imgui.set_next_window_pos(Vector2f.new(2200, 1700), 1)
      imgui.set_next_window_size(Vector2f.new(1500, 420), 1)
      if imgui.begin_window("PT panel test 2", true, 0) then
        imgui.set_next_item_open(true, 1)
        PawnTrickster.draw_panel()
      end
      imgui.end_window()
      T.frames = (T.frames or 0) + 1
    end)
    if not ok then T.err = tostring(e) end
  end)
end
out("panel test 2 on", "err", tostring(_G.__ptp2.err))
