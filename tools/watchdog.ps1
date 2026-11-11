# Watchdog for unattended DD2 test runs: every 5 s, look at every visible top-level window of DD2.exe. A window that is
# not the game window ("via" class) nor REFramework's console and whose title mentions a crash / error, or any dialog
# box (#32770), means the game is sitting on a fatal-error box: log it and kill the process. Writes a state line to
# dd2_state.txt each pass. Stop it by deleting watchdog.run.
param([string]$Dir)
Add-Type @"
using System; using System.Text; using System.Runtime.InteropServices; using System.Collections.Generic;
public static class WD {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc p, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  public static List<string> Of(uint pid) { var r = new List<string>(); EnumWindows((h, l) => { uint p; GetWindowThreadProcessId(h, out p);
    if (p == pid && IsWindowVisible(h)) { var c = new StringBuilder(128); GetClassName(h, c, 128); var t = new StringBuilder(256); GetWindowText(h, t, 256); r.Add(c.ToString() + "|" + t.ToString()); } return true; }, IntPtr.Zero); return r; }
}
"@
$run = Join-Path $Dir 'watchdog.run'; $state = Join-Path $Dir 'dd2_state.txt'; $log = Join-Path $Dir 'watchdog.log'
Set-Content $run 'running'
while (Test-Path $run) {
  $now = Get-Date -Format 'HH:mm:ss'
  $ps = @(Get-Process DD2 -ErrorAction SilentlyContinue)
  if ($ps.Count -eq 0) { Set-Content $state "$now NOT_RUNNING" }
  else {
    $bad = $null; $titles = @()
    foreach ($p in $ps) { foreach ($w in [WD]::Of([uint32]$p.Id)) { $titles += $w
      $cls, $title = $w.Split('|', 2)
      if ($cls -eq '#32770' -or ($cls -ne 'via' -and $cls -ne 'ConsoleWindowClass' -and $title -match 'Crash|Fatal|Error')) { $bad = $w } } }
    if ($bad) {
      Add-Content $log "$now CRASH DIALOG: $bad -> killing DD2"
      Stop-Process -Name DD2 -Force -ErrorAction SilentlyContinue
      Set-Content $state "$now KILLED_CRASH_DIALOG $bad"
    } else { Set-Content $state ("$now RUNNING " + ($titles -join ' ; ')) }
  }
  Start-Sleep -Seconds 5
}
Set-Content $state ((Get-Date -Format 'HH:mm:ss') + ' WATCHDOG_STOPPED')
