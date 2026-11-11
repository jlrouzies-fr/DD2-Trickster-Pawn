# A dense contact sheet from a capture's GIF: every frame from -From to -To (0-based), optionally cropped to
# -Crop "x,y,w,h" and enlarged by -Zoom, -Cols per row, each frame numbered. For looking at a movement frame by frame
# when the twelve frames of the capture's own sheet are too far apart.
# usage: powershell -File gifsheet.ps1 -In clip.gif -Out sheet.jpg -From 10 -To 29 -Crop "40,60,240,240" -Zoom 2
param([string]$In, [string]$Out, [int]$From = 0, [int]$To = 19, [string]$Crop = "", [double]$Zoom = 1, [int]$Cols = 5)
Add-Type -AssemblyName System.Drawing
$gif = [Drawing.Image]::FromFile($In)
$dim = New-Object Drawing.Imaging.FrameDimension ($gif.FrameDimensionsList[0])
$n = $gif.GetFrameCount($dim); if ($To -ge $n) { $To = $n - 1 }
$x = 0; $y = 0; $w = $gif.Width; $h = $gif.Height
if ($Crop) { $p = $Crop.Split(','); $x = [int]$p[0]; $y = [int]$p[1]; $w = [int]$p[2]; $h = [int]$p[3] }
$fw = [int]($w * $Zoom); $fh = [int]($h * $Zoom)
$count = $To - $From + 1; $rows = [int][math]::Ceiling($count / $Cols)
$sheet = New-Object Drawing.Bitmap ($Cols * $fw), ($rows * $fh); $g = [Drawing.Graphics]::FromImage($sheet)
$g.InterpolationMode = 'HighQualityBicubic'
$font = New-Object Drawing.Font 'Consolas', 14
for ($i = $From; $i -le $To; $i++) {
  [void]$gif.SelectActiveFrame($dim, $i)
  $k = $i - $From; $dx = ($k % $Cols) * $fw; $dy = [int][math]::Floor($k / $Cols) * $fh
  $g.DrawImage($gif, (New-Object Drawing.Rectangle $dx, $dy, $fw, $fh), (New-Object Drawing.Rectangle $x, $y, $w, $h), 'Pixel')
  $g.DrawString("$i", $font, [Drawing.Brushes]::White, $dx + 3, $dy + 2)
}
$g.Dispose(); $sheet.Save($Out, [Drawing.Imaging.ImageFormat]::Jpeg); $sheet.Dispose(); $gif.Dispose()
"frames $From-$To of $n -> $Out"
