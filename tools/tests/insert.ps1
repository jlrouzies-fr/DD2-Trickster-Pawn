# open / close REFramework's menu without the focus (a posted Insert key)
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class PM { [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string c, string t);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l); }
"@
$h = [PM]::FindWindow("via", "Dragon's Dogma 2"); if ($h -eq [IntPtr]::Zero) { "no game window"; exit 1 }
[PM]::PostMessage($h, 0x100, [IntPtr]0x2D, [IntPtr]0x01520001) | Out-Null; Start-Sleep -Milliseconds 80
[PM]::PostMessage($h, 0x101, [IntPtr]0x2D, [IntPtr]([int64]0xC1520001)) | Out-Null; "Insert posted"
