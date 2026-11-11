# Load the last save from DD2's title screen: the user's recipe is "spam space for 20 s", from game start (that also
# skips the intros). Brings the game window to the front, taps Space (scan code, only while the game really has focus),
# then gives focus back to the previous window.
# -Launch: start DD2 through Steam first. Before touching the window it waits for REFramework's window hook ("Windows
# MessageHook" then "Resuming" in its log): fronting the window during that hook deadlocked a boot once.
# The focus is taken ONCE: if the user takes it back during the taps, the script waits and never fronts the game again.
# -StopFile: stop as soon as this file exists (the caller writes it when the save is loaded); -Seconds is then the limit.
# -PhaseFile: the file the dev console writes the game's main flow phase to (pt_dev/phase.txt). With it the game is
# fronted only when the title menu is up (phase 8), Space is tapped until the save starts loading (phase 9 or more),
# and the focus goes back at once: a few seconds of focus instead of the whole boot. The intros are left to play.
# If the title has not come -IntroWait seconds after the file appeared, Space is tapped in the intros as well.
param([int]$Seconds = 20, [switch]$Launch, [string]$GameDir = $env:DD2_DIR, [string]$StopFile = '', [string]$PhaseFile = '', [int]$IntroWait = 60)
$prevUser = $null
$log = Join-Path $GameDir 're2_framework_log.txt'
Add-Type @"
using System; using System.Text; using System.Runtime.InteropServices;
public static class K {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc p, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  // REFramework's console (ConsoleWindowClass, owned by the game process) stays minimized without activation
  public static void MinimizeConsole(uint pid) {
    EnumWindows((h, l) => {
      uint p; GetWindowThreadProcessId(h, out p);
      var c = new StringBuilder(64); GetClassName(h, c, 64);
      if (p == pid && IsWindowVisible(h) && c.ToString() == "ConsoleWindowClass" && !IsIconic(h)) ShowWindow(h, 7);
      return true;
    }, IntPtr.Zero);
  }
  [DllImport("user32.dll")] public static extern IntPtr FindWindow(string c, string t);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, IntPtr pid);
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  public static bool IsGame(IntPtr h, uint pid) { uint p; GetWindowThreadProcessId(h, out p); return p == pid; }
  // the game's windows go behind and the user's window comes back (Alt+Esc when that window is not known)
  public static void GiveBack(IntPtr to) {
    if (to != IntPtr.Zero) { Front(to); return; }
    keybd_event(0x12, 0, 0, UIntPtr.Zero); keybd_event(0x1B, 0, 0, UIntPtr.Zero); keybd_event(0x1B, 0, 2, UIntPtr.Zero); keybd_event(0x12, 0, 2, UIntPtr.Zero);
  }
  public static void Front(IntPtr h) {
    uint fg = GetWindowThreadProcessId(GetForegroundWindow(), IntPtr.Zero), me = GetCurrentThreadId();
    AttachThreadInput(me, fg, true);
    keybd_event(0x12, 0, 0, UIntPtr.Zero); keybd_event(0x12, 0, 2, UIntPtr.Zero);  // Alt tap unlocks SetForegroundWindow
    SetForegroundWindow(h);
    AttachThreadInput(me, fg, false);
  }
}
"@
if ($Launch) {
  $launched = Get-Date
  $prevUser = [K]::GetForegroundWindow()
  Start-Process 'steam://rungameid/2054970'
  $deadline = (Get-Date).AddSeconds(120)
  while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 500
    if (-not (Test-Path $log) -or (Get-Item $log).LastWriteTime -lt $launched) { continue }
    try { $fs = [IO.File]::Open($log, 'Open', 'Read', 'ReadWrite'); $t = (New-Object IO.StreamReader($fs)).ReadToEnd(); $fs.Close() } catch { continue }
    $i = $t.LastIndexOf('WindowsMessageHook')
    if ($i -ge 0 -and $t.IndexOf('Resuming', $i) -ge 0) { break }
  }
}
$game = [K]::FindWindow("via", "Dragon's Dogma 2")
if ($game -eq [IntPtr]::Zero) { Write-Output "no game window"; exit 1 }
$prev = [K]::GetForegroundWindow()
if ($prevUser -is [IntPtr]) { $prev = $prevUser }
$dd2 = Get-Process DD2 -ErrorAction SilentlyContinue | Select-Object -First 1
$end = (Get-Date).AddSeconds($Seconds)
$taps = 0; $had = $false; $tries = 0; $seen = $null; $t0 = $null; $t1 = $null
# The user's window: the last foreground window that is not the game's. The booting game takes the focus by itself
# (sometimes again after the launcher gave it back): while this script waits for the title, and for 15 s after its
# taps, the focus goes back to the user's window whenever a window of the game has it.
$gpid = [uint32]0; if ($dd2) { $gpid = [uint32]$dd2.Id }
$userWin = [IntPtr]::Zero; $returned = 0
if ($prev -ne [IntPtr]::Zero -and -not [K]::IsGame($prev, $gpid)) { $userWin = $prev }
function Keep-UserFocus {
  $f = [K]::GetForegroundWindow()
  if ($f -eq [IntPtr]::Zero) { return }
  if ([K]::IsGame($f, $gpid)) { [K]::GiveBack($script:userWin); $script:returned++; Start-Sleep -Milliseconds 300 } else { $script:userWin = $f }
}
function Read-Phase { try { return [int]([IO.File]::ReadAllText($PhaseFile).Trim()) } catch { return -1 } }
while ((Get-Date) -lt $end) {
  if ($StopFile -and (Test-Path $StopFile)) { break }
  if ($dd2 -and $dd2.HasExited) { Write-Output 'the game process ended'; break }
  if ($PhaseFile) {
    $ph = Read-Phase
    if ($ph -ge 0 -and -not $seen) { $seen = Get-Date }
    if ($ph -ge 9) { break }                                  # the save is loading (or loaded): nothing more to press
    $want = ($ph -eq 8) -or ($seen -and $ph -ge 0 -and ((Get-Date) - $seen).TotalSeconds -gt $IntroWait)
    if (-not $want) { Keep-UserFocus; Start-Sleep -Milliseconds 150; continue }   # scripts not up yet, or the intros: no focus taken, and given back if the game takes it
  }
  if ($dd2) { [K]::MinimizeConsole([uint32]$dd2.Id) }
  if ([K]::GetForegroundWindow() -ne $game) {
    # front it until it has had the focus once (five tries at the most); after that the focus is never taken again
    if (-not $had -and $tries -lt 5) { [K]::Front($game); $tries++ }
    Start-Sleep -Milliseconds 300; continue
  }
  if (-not $had) { $t0 = Get-Date }
  $had = $true
  [K]::keybd_event(0x20, 0x39, 8, [UIntPtr]::Zero); Start-Sleep -Milliseconds 120
  [K]::keybd_event(0x20, 0x39, 10, [UIntPtr]::Zero); Start-Sleep -Milliseconds 250
  $taps++
}
$tEnd = Get-Date
if ($PhaseFile) {
  # hand the focus back, and keep handing it back for 15 s (the game can take it again while the save loads)
  $until = (Get-Date).AddSeconds(15)
  while ((Get-Date) -lt $until) { if ($dd2 -and $dd2.HasExited) { break }; Keep-UserFocus; Start-Sleep -Milliseconds 250 }
} elseif ($prev -ne [IntPtr]::Zero -and $prev -ne $game -and [K]::GetForegroundWindow() -eq $game) { [K]::Front($prev) }
$held = 0; if ($t0) { $held = [math]::Round(($tEnd - $t0).TotalSeconds, 1) }
Write-Output "space taps: $taps, focus held $held s (one focus session); focus given back $returned time(s) when the game took it by itself"
