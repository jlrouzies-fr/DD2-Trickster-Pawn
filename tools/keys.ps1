# Send a few key presses to DD2 (scan codes, only while the game really has focus), then give focus back.
# usage: keys.ps1 -Keys "C,RIGHT,F" [-DelayMs 500]
param([string]$Keys = "", [int]$DelayMs = 500)
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class K2 {
  [DllImport("user32.dll")] public static extern IntPtr FindWindow(string c, string t);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, IntPtr pid);
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  public static void Front(IntPtr h) {
    uint fg = GetWindowThreadProcessId(GetForegroundWindow(), IntPtr.Zero), me = GetCurrentThreadId();
    AttachThreadInput(me, fg, true);
    keybd_event(0x12, 0, 0, UIntPtr.Zero); keybd_event(0x12, 0, 2, UIntPtr.Zero);
    SetForegroundWindow(h);
    AttachThreadInput(me, fg, false);
  }
}
"@
$map = @{ 'Z' = @(0x2C,0); 'C' = @(0x2E,0); 'F' = @(0x21,0); 'Q' = @(0x10,0); 'E' = @(0x12,0); 'W' = @(0x11,0); 'A' = @(0x1E,0); 'S' = @(0x1F,0); 'D' = @(0x20,0);
          'V' = @(0x2F,0); 'G' = @(0x22,0); 'X' = @(0x2D,0); 'SPACE' = @(0x39,0); 'ENTER' = @(0x1C,0); 'ESC' = @(0x01,0); 'TAB' = @(0x0F,0);
          'UP' = @(0x48,1); 'DOWN' = @(0x50,1); 'LEFT' = @(0x4B,1); 'RIGHT' = @(0x4D,1) }
$game = [K2]::FindWindow("via", "Dragon's Dogma 2")
if ($game -eq [IntPtr]::Zero) { Write-Output "no game window"; exit 1 }
$prev = [K2]::GetForegroundWindow()
$sent = 0
foreach ($k in ($Keys -split ',')) {
  $k = $k.Trim().ToUpper(); if (-not $map.ContainsKey($k)) { Write-Output "unknown key $k"; continue }
  $tries = 0
  while ([K2]::GetForegroundWindow() -ne $game -and $tries -lt 10) { [K2]::Front($game); Start-Sleep -Milliseconds 300; $tries++ }
  if ([K2]::GetForegroundWindow() -ne $game) { Write-Output "game not in front"; break }
  $sc = [byte]$map[$k][0]; $ext = [uint32]$map[$k][1]
  [K2]::keybd_event(0, $sc, (8 -bor $ext), [UIntPtr]::Zero); Start-Sleep -Milliseconds 110
  [K2]::keybd_event(0, $sc, (10 -bor $ext), [UIntPtr]::Zero); Start-Sleep -Milliseconds $DelayMs
  $sent++
}
if ($prev -ne [IntPtr]::Zero -and $prev -ne $game) { [K2]::Front($prev) }
Write-Output "keys sent: $sent"
