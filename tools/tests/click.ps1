# ONE focus session: front the game, left-click at client pixel (X, Y) N times (Gap ms apart), give the focus back
param([int]$X, [int]$Y, [int]$N = 1, [int]$Gap = 900)
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class CK {
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string c, string t);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, IntPtr pid);
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, UIntPtr e);
  public struct POINT { public int X, Y; }
  public static void Front(IntPtr h) {
    uint fg = GetWindowThreadProcessId(GetForegroundWindow(), IntPtr.Zero), me = GetCurrentThreadId();
    AttachThreadInput(me, fg, true); keybd_event(0x12, 0, 0, UIntPtr.Zero); keybd_event(0x12, 0, 2, UIntPtr.Zero); SetForegroundWindow(h); AttachThreadInput(me, fg, false);
  }
}
"@
[CK]::SetProcessDPIAware() | Out-Null
$g = [CK]::FindWindow("via", "Dragon's Dogma 2"); if ($g -eq [IntPtr]::Zero) { "no game window"; exit 1 }
$prev = [CK]::GetForegroundWindow(); $old = New-Object CK+POINT; [CK]::GetCursorPos([ref]$old) | Out-Null
$p = New-Object CK+POINT; $p.X = $X; $p.Y = $Y; [CK]::ClientToScreen($g, [ref]$p) | Out-Null
$t0 = Get-Date; [CK]::Front($g); Start-Sleep -Milliseconds 500
$ok = ([CK]::GetForegroundWindow() -eq $g)
for ($i = 0; $i -lt $N -and $ok; $i++) {
  [CK]::SetCursorPos($p.X, $p.Y) | Out-Null; Start-Sleep -Milliseconds 250
  [CK]::mouse_event(1, 0, 0, 0, [UIntPtr]::Zero); [CK]::SetCursorPos($p.X + 1, $p.Y) | Out-Null; Start-Sleep -Milliseconds 120   # (a small move so ImGui sees the cursor there)
  [CK]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 80; [CK]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)
  if ($i -lt $N - 1) { Start-Sleep -Milliseconds $Gap }
}
Start-Sleep -Milliseconds 300
if ($prev -ne [IntPtr]::Zero -and $prev -ne $g) { [CK]::Front($prev) }
[CK]::SetCursorPos($old.X, $old.Y) | Out-Null
"game had the focus: $ok; clicks: $i at screen ($($p.X), $($p.Y)); focus held $([math]::Round(((Get-Date) - $t0).TotalSeconds, 1)) s"
