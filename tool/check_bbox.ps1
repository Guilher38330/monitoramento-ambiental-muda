Add-Type -AssemblyName System.Drawing
$fg = [System.Drawing.Bitmap]::FromFile('assets\icon\generated_reference_foreground.png')
$minX = $fg.Width
$maxX = 0
$minY = $fg.Height
$maxY = 0

for ($y = 0; $y -lt $fg.Height; $y += 4) {
    for ($x = 0; $x -lt $fg.Width; $x += 4) {
        if ($fg.GetPixel($x, $y).A -gt 25) {
            if ($x -lt $minX) { $minX = $x }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
}
$w = $maxX - $minX
$h = $maxY - $minY
Write-Host "Bounding box: X=[$minX, $maxX] W=$w, Y=[$minY, $maxY] H=$h"
$fg.Dispose()
