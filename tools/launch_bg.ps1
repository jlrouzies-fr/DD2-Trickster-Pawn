param([string]$GameDir = $env:DD2_DIR, [switch]$UntilHook)
# -UntilHook: return as soon as REFramework's window hook is done (the caller fronts the window itself right after);
# without it the script stays up to 100 s to hand the focus back when the booting game takes it.
# Launch DD2 through Steam without ever leaving it in front: REFramework's console is minimized (no activation), the
# game window is sent to the bottom, and focus goes back to whatever the user had. No minimize of the game window (a
# swapchain resize crashed a graphics mod once), no key presses.
Add-Type @"
using System; using System.Text; using System.Runtime.InteropServices; using System.Collections.Generic;
public static class W4 {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc p, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  public static List<IntPtr> Of(uint pid) { var r = new List<IntPtr>(); EnumWindows((h, l) => { uint p; GetWindowThreadProcessId(h, out p); if (p == pid && IsWindowVisible(h)) r.Add(h); return true; }, IntPtr.Zero); return r; }
  public static string Cls(IntPtr h) { var s = new StringBuilder(128); GetClassName(h, s, 128); return s.ToString(); }
}
"@
# REFramework suspends every game thread (loader lock held) while it hooks the window. Touching the game window's thread
# then (AttachThreadInput, SetWindowPos) deadlocked the boot once (2026-11-01 17:22), so wait until its log shows the
# window hook done: "WindowsMessageHook" followed by a "Resuming" line.
$log = Join-Path $GameDir 're2_framework_log.txt'
$launched = Get-Date
function Hook-Done {
  if (-not (Test-Path $log) -or (Get-Item $log).LastWriteTime -lt $launched) { return $false }
  try {
    $fs = [IO.File]::Open($log, 'Open', 'Read', 'ReadWrite'); $t = (New-Object IO.StreamReader($fs)).ReadToEnd(); $fs.Close()
  } catch { return $false }
  $i = $t.LastIndexOf('WindowsMessageHook')
  return $i -ge 0 -and $t.IndexOf('Resuming', $i) -ge 0
}
$prev = [W4]::GetForegroundWindow()
Start-Process 'steam://rungameid/2054970'
$deadline = (Get-Date).AddSeconds(100); $handed = 0
while ((Get-Date) -lt $deadline) {
  $p = Get-Process DD2 -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($p) {
    $fg = [W4]::GetForegroundWindow(); $mine = $false
    foreach ($h in [W4]::Of([uint32]$p.Id)) {
      if ([W4]::Cls($h) -eq 'ConsoleWindowClass') { if (-not [W4]::IsIconic($h)) { [W4]::ShowWindow($h, 7) | Out-Null } }
      if ($h -eq $fg) { $mine = $true }
    }
    if ($mine -and $prev -ne [IntPtr]::Zero -and (Hook-Done)) {
      $pid0 = [uint32]0; $t = [W4]::GetWindowThreadProcessId($fg, [ref]$pid0); $me = [W4]::GetCurrentThreadId()
      [W4]::AttachThreadInput($me, $t, $true) | Out-Null
      foreach ($h in [W4]::Of([uint32]$p.Id)) { if ([W4]::Cls($h) -ne 'ConsoleWindowClass') { [W4]::SetWindowPos($h, [IntPtr]1, 0, 0, 0, 0, 0x13) | Out-Null } }
      [W4]::SetForegroundWindow($prev) | Out-Null
      [W4]::AttachThreadInput($me, $t, $false) | Out-Null
      $handed++
      # stop soon after the boot grabs, so the user can still switch to the game by hand
      if ($handed -eq 1) { $deadline = (Get-Date).AddSeconds(15) }
    }
  }
  if ($UntilHook -and $p -and (Hook-Done)) { break }
  Start-Sleep -Milliseconds 100
}
$fg = [W4]::GetForegroundWindow()
"focus handed back $handed time(s); a DD2 window has focus now: $((Get-Process DD2 -ErrorAction SilentlyContinue | ForEach-Object { [W4]::Of([uint32]$_.Id) }) -contains $fg)"
