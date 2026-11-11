# Burst capture of the game window (works while it is behind other windows) into an animated GIF and a contact sheet.
#   capture.ps1 -Out x.gif [-Seconds 6] [-Fps 10] [-Width 480]
#   capture.ps1 -Out x.gif -TriggerFile <file> [-PreRoll 1] [-PostRoll 4] [-MaxWait 90]
# With -TriggerFile the capture runs in a ring until that file is written (tools/lua/cam.lua writes it when the filmed
# character starts a given action), then keeps PreRoll seconds from before and PostRoll seconds after.
# No external program: frames come from PrintWindow, the GIF from WPF's encoder (a palette per frame), and the frame
# delays and the loop flag are written into the file afterwards (the encoder leaves them out).
param([string]$Out, [double]$Seconds = 6, [double]$Fps = 10, [int]$Width = 480, [string]$TriggerFile = "",
      [double]$PreRoll = 1.0, [double]$PostRoll = 4.0, [double]$MaxWait = 90, [string]$Process = "DD2")
Add-Type -AssemblyName System.Drawing, PresentationCore, WindowsBase
Add-Type -ReferencedAssemblies System.Drawing @"
using System; using System.IO; using System.Runtime.InteropServices; using System.Drawing;
public static class Cap {
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string c, string t);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint f);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  public struct RECT { public int L, T, R, B; }
  public static Bitmap Full;
  public static Bitmap Grab(IntPtr h, int width) {
    RECT r; GetClientRect(h, out r); int w = r.R - r.L, hh = r.B - r.T; if (w <= 0 || hh <= 0) return null;
    if (Full == null || Full.Width != w || Full.Height != hh) { if (Full != null) Full.Dispose(); Full = new Bitmap(w, hh); }
    using (Graphics g = Graphics.FromImage(Full)) { IntPtr dc = g.GetHdc(); PrintWindow(h, dc, 3); g.ReleaseHdc(dc); }
    int sh = (int)Math.Round(hh * (double)width / w); if (sh % 2 == 1) sh++;
    Bitmap s = new Bitmap(width, sh, System.Drawing.Imaging.PixelFormat.Format24bppRgb);
    using (Graphics g = Graphics.FromImage(s)) { g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.Bilinear; g.DrawImage(Full, 0, 0, width, sh); }
    return s;
  }
  // GIF89a with a loop flag and a delay (1/100 s) on every frame; the input may have neither
  public static byte[] Patch(byte[] d, int delay) {
    MemoryStream o = new MemoryStream(); int p = 0;
    o.Write(new byte[] { 0x47, 0x49, 0x46, 0x38, 0x39, 0x61 }, 0, 6); p = 6;
    o.Write(d, p, 7); int packed = d[p + 4]; p += 7;
    if ((packed & 0x80) != 0) { int n = 3 * (1 << ((packed & 7) + 1)); o.Write(d, p, n); p += n; }
    o.Write(new byte[] { 0x21, 0xFF, 0x0B, 0x4E, 0x45, 0x54, 0x53, 0x43, 0x41, 0x50, 0x45, 0x32, 0x2E, 0x30, 0x03, 0x01, 0x00, 0x00, 0x00 }, 0, 19);
    bool gce = false;
    while (p < d.Length) {
      byte b = d[p];
      if (b == 0x3B) { o.WriteByte(b); break; }
      if (b == 0x21) {
        byte label = d[p + 1]; int q = p + 2; while (d[q] != 0) q += d[q] + 1; q++;
        if (label == 0xF9) { byte[] blk = new byte[q - p]; Array.Copy(d, p, blk, 0, q - p); blk[4] = (byte)(delay & 255); blk[5] = (byte)(delay >> 8); o.Write(blk, 0, blk.Length); gce = true; }
        else if (label == 0xFF && q - p >= 14 && d[p + 3] == 0x4E && d[p + 4] == 0x45) { /* an existing loop block: dropped, ours is in */ }
        else o.Write(d, p, q - p);
        p = q; continue;
      }
      if (b == 0x2C) {
        if (!gce) o.Write(new byte[] { 0x21, 0xF9, 0x04, 0x00, (byte)(delay & 255), (byte)(delay >> 8), 0x00, 0x00 }, 0, 8);
        gce = false; int q = p + 10; int pk = d[p + 9];
        if ((pk & 0x80) != 0) q += 3 * (1 << ((pk & 7) + 1));
        q++; while (d[q] != 0) q += d[q] + 1; q++;
        o.Write(d, p, q - p); p = q; continue;
      }
      throw new Exception("unexpected GIF block " + b + " at " + p);
    }
    return o.ToArray();
  }
}
"@
[Cap]::SetProcessDPIAware() | Out-Null
$proc = Get-Process $Process -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $proc) { "no $Process process"; exit 1 }
# the game's own window by its class (the process's "main window" is whichever of its windows is on top: after the
# game window went behind, that was REFramework's minimized console, which has no client area)
$h = [Cap]::FindWindow('via', "Dragon's Dogma 2"); if ($h -eq [IntPtr]::Zero) { $h = $proc.MainWindowHandle }
$frames = New-Object System.Collections.ArrayList   # each: @(time, Bitmap)
$sw = [Diagnostics.Stopwatch]::StartNew(); $step = 1.0 / $Fps; $next = 0.0
$trigAt = $null
$t0file = [DateTime]::MinValue
if ($TriggerFile -and (Test-Path $TriggerFile)) { $t0file = (Get-Item $TriggerFile).LastWriteTimeUtc }
while ($true) {
  $t = $sw.Elapsed.TotalSeconds
  if ($t -lt $next) { Start-Sleep -Milliseconds ([int][Math]::Max(1, ($next - $t) * 1000)); continue }
  $next = [Math]::Max($next + $step, $t)
  $b = [Cap]::Grab($h, $Width); if ($b -eq $null) { "the window has no client area"; exit 1 }
  [void]$frames.Add(@($t, $b))
  if ($TriggerFile) {
    if ($trigAt -eq $null) {
      if ((Test-Path $TriggerFile) -and (Get-Item $TriggerFile).LastWriteTimeUtc -gt $t0file) { $trigAt = $t }
      while ($frames.Count -gt 0 -and $frames[0][0] -lt $t - $PreRoll) { $frames[0][1].Dispose(); $frames.RemoveAt(0) }
      if ($trigAt -eq $null -and $t -gt $MaxWait) { "no trigger in $MaxWait s"; exit 2 }
    } elseif ($t -ge $trigAt + $PostRoll) { break }
  } elseif ($t -ge $Seconds) { break }
}
$n = $frames.Count; $dur = $frames[$n - 1][0] - $frames[0][0]
$real = $Fps; if ($dur -gt 0) { $real = ($n - 1) / $dur }
$delay = [int][Math]::Max(2, [Math]::Round(100.0 / $real))
$enc = New-Object System.Windows.Media.Imaging.GifBitmapEncoder
foreach ($f in $frames) {
  $ms = New-Object IO.MemoryStream; $f[1].Save($ms, [Drawing.Imaging.ImageFormat]::Png); $ms.Position = 0
  $src = [System.Windows.Media.Imaging.BitmapFrame]::Create($ms, 'None', 'OnLoad')
  $pal = New-Object System.Windows.Media.Imaging.BitmapPalette($src, 256)
  $ix = New-Object System.Windows.Media.Imaging.FormatConvertedBitmap($src, [System.Windows.Media.PixelFormats]::Indexed8, $pal, 0)
  $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($ix)); $ms.Dispose()
}
$raw = New-Object IO.MemoryStream; $enc.Save($raw)
[IO.File]::WriteAllBytes($Out, [Cap]::Patch($raw.ToArray(), $delay))
# contact sheet: up to 12 frames, evenly spread, each with its time (from the trigger when there was one)
$k = [Math]::Min(12, $n); $cols = 4; $rows = [int][Math]::Ceiling($k / $cols); $fw = $frames[0][1].Width; $fh = $frames[0][1].Height
$sheet = New-Object Drawing.Bitmap ($cols * $fw), ($rows * $fh); $g = [Drawing.Graphics]::FromImage($sheet)
$font = New-Object Drawing.Font "Consolas", 14
$tb = $frames[0][0]; if ($trigAt -ne $null) { $tb = $trigAt }
for ($i = 0; $i -lt $k; $i++) {
  $j = 0; if ($k -gt 1) { $j = [int][Math]::Round($i * ($n - 1) / ($k - 1)) }
  $x = ($i % $cols) * $fw; $y = [int][Math]::Floor($i / $cols) * $fh
  $g.DrawImage($frames[$j][1], $x, $y, $fw, $fh)
  $label = "{0:+0.0;-0.0}s" -f ($frames[$j][0] - $tb)
  $g.FillRectangle([Drawing.Brushes]::Black, $x, $y, 78, 24); $g.DrawString($label, $font, [Drawing.Brushes]::White, ($x + 2), ($y + 1))
}
$g.Dispose()
$sheetPath = [IO.Path]::Combine([IO.Path]::GetDirectoryName($Out), [IO.Path]::GetFileNameWithoutExtension($Out) + "_sheet.jpg")
$sheet.Save($sheetPath, [Drawing.Imaging.ImageFormat]::Jpeg); $sheet.Dispose()
foreach ($f in $frames) { $f[1].Dispose() }
$trig = ""; if ($trigAt -ne $null) { $trig = ", triggered" }
"{0} frames, {1:N1} s, {2:N1} fps, {3}x{4}, gif {5:N0} kB{6}" -f $n, $dur, $real, $fw, $fh, ((Get-Item $Out).Length / 1024), $trig
