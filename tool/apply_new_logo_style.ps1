Add-Type -AssemblyName System.Drawing

$assetsDir = "c:\Users\weisg\AndroidStudioProjects\trabalho_final\assets\icon"
$fgSrcPath = Join-Path $assetsDir "generated_reference_foreground.png"

$rawFg = [System.Drawing.Bitmap]::FromFile($fgSrcPath)

# We want the artwork to fit within ~720px safe bounding box centered at (512, 512)
# Original bounding box: X=[112, 988] W=876, Y=[76, 936] H=860. Center=(550, 506)
$origCenterX = 550.0
$origCenterY = 506.0
$targetSize = 720.0
$origMaxDim = [Math]::Max(876.0, 860.0)
$scale = $targetSize / $origMaxDim # ~0.822

$w = 1024
$h = 1024

# 1. Foreground Bitmap (Transparent with scaled, centered artwork)
$fgBmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$fgG = [System.Drawing.Graphics]::FromImage($fgBmp)
$fgG.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$fgG.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$fgG.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$fgG.Clear([System.Drawing.Color]::Transparent)

$fgG.TranslateTransform(512.0, 512.0)
$fgG.ScaleTransform($scale, $scale)
$fgG.TranslateTransform(-$origCenterX, -$origCenterY)

$fgG.DrawImage($rawFg, 0, 0, $rawFg.Width, $rawFg.Height)
$fgG.Dispose()

$fgDestPath = Join-Path $assetsDir "app_icon_foreground.png"
$fgBmp.Save($fgDestPath, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "Generated $fgDestPath"

# 2. Background Bitmap (Pure White #FFFFFF for clean contrast)
$bgBmp = New-Object System.Drawing.Bitmap($w, $h)
$bgG = [System.Drawing.Graphics]::FromImage($bgBmp)
$bgG.Clear([System.Drawing.Color]::White)
$bgG.Dispose()

$bgDestPath = Join-Path $assetsDir "app_icon_background.png"
$bgBmp.Save($bgDestPath, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "Generated $bgDestPath"

# 3. Master Full Icon (White background + soft shadow + foreground)
$fullBmp = New-Object System.Drawing.Bitmap($w, $h)
$fullG = [System.Drawing.Graphics]::FromImage($fullBmp)
$fullG.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$fullG.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$fullG.Clear([System.Drawing.Color]::White)

# Soft floor shadow under the base
$shadowPath = New-Object System.Drawing.Drawing2D.GraphicsPath
$shadowPath.AddEllipse([float]320, [float]830, [float]384, [float]44)
$shadowBrush = New-Object System.Drawing.Drawing2D.PathGradientBrush($shadowPath)
$shadowBrush.CenterColor = [System.Drawing.Color]::FromArgb(45, 0, 77, 64)
$shadowBrush.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 255, 255, 255))
$fullG.FillPath($shadowBrush, $shadowPath)
$shadowBrush.Dispose()
$shadowPath.Dispose()

$fullG.DrawImage($fgBmp, 0, 0, $w, $h)
$fullG.Dispose()

$fullDestPath = Join-Path $assetsDir "app_icon.png"
$fullBmp.Save($fullDestPath, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "Generated $fullDestPath"

# 4. Monochrome Mask Bitmap (for Android 13+ Material You themed icons)
$monoBmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
        $pixel = $fgBmp.GetPixel($x, $y)
        if ($pixel.A -gt 15) {
            # Map darkness to opacity: darker lines become fully opaque white, lighter fills slightly translucent white
            $brightness = [int](($pixel.R + $pixel.G + $pixel.B) / 3)
            $alpha = [int]($pixel.A * (255 - ($brightness * 0.4)) / 255)
            if ($alpha -gt 255) { $alpha = 255 }
            if ($alpha -lt 60) { $alpha = 60 }
            $monoBmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($alpha, 255, 255, 255))
        } else {
            $monoBmp.SetPixel($x, $y, [System.Drawing.Color]::Transparent)
        }
    }
}
$monoDestPath = Join-Path $assetsDir "app_icon_monochrome.png"
$monoBmp.Save($monoDestPath, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "Generated $monoDestPath"

$rawFg.Dispose()
$fgBmp.Dispose()
$bgBmp.Dispose()
$fullBmp.Dispose()
$monoBmp.Dispose()
Write-Host "All assets prepared successfully!"
