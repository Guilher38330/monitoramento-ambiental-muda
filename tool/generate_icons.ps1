Add-Type -AssemblyName System.Drawing

$outputPath = "c:\Users\weisg\AndroidStudioProjects\trabalho_final\assets\icon"
if (!(Test-Path $outputPath)) {
    New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
}

function Create-AppIcons {
    $width = 1024
    $height = 1024

    # 1. Background Bitmap
    $bgBmp = New-Object System.Drawing.Bitmap($width, $height)
    $bgG = [System.Drawing.Graphics]::FromImage($bgBmp)
    $bgG.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $bgG.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    
    $rect = New-Object System.Drawing.Rectangle(0, 0, $width, $height)
    $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.PointF(0, 0)),
        (New-Object System.Drawing.PointF($width, $height)),
        [System.Drawing.Color]::FromArgb(255, 27, 94, 32),   # #1B5E20
        [System.Drawing.Color]::FromArgb(255, 0, 77, 64)     # #004D40
    )
    $bgG.FillRectangle($bgBrush, $rect)
    $bgBrush.Dispose()

    # Subtle concentric radial ambient glow in the center
    $glowPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $glowPath.AddEllipse(112, 112, 800, 800)
    $glowBrush = New-Object System.Drawing.Drawing2D.PathGradientBrush($glowPath)
    $glowBrush.CenterColor = [System.Drawing.Color]::FromArgb(40, 200, 230, 201) # light green soft glow
    $glowBrush.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 27, 94, 32))
    $bgG.FillPath($glowBrush, $glowPath)
    $glowBrush.Dispose()
    $glowPath.Dispose()
    $bgG.Dispose()

    $bgFile = Join-Path $outputPath "app_icon_background.png"
    $bgBmp.Save($bgFile, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host "Generated $bgFile"

    # Function to draw the core emblem (Drop + Seedling)
    # isMonochrome: if true, uses white tones for Material You themed icons
    function Draw-Emblem($g, $isMonochrome) {
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

        # Safe area center is (512, 512). Artwork fits within ~560x560 bounding box.
        # Safe zone radius is 340px (from 172 to 852).
        
        # 1. Back droplet (representing Hydrology / Water Resources / PSA)
        # Droplet coordinates: Top peak at (570, 240), bulb curving down to (690, 560), base at (570, 740), left curve at (450, 560)
        $dropPath = New-Object System.Drawing.Drawing2D.GraphicsPath
        $dropPoints = @(
            (New-Object System.Drawing.PointF(575, 235)), # Top tip
            (New-Object System.Drawing.PointF(640, 360)), # Upper right curve
            (New-Object System.Drawing.PointF(710, 490)), # Right bulge
            (New-Object System.Drawing.PointF(700, 640)), # Lower right
            (New-Object System.Drawing.PointF(580, 745)), # Bottom base
            (New-Object System.Drawing.PointF(470, 680)), # Lower left
            (New-Object System.Drawing.PointF(460, 510)), # Left bulge
            (New-Object System.Drawing.PointF(520, 360))  # Upper left curve
        )
        $dropPath.AddClosedCurve($dropPoints, 0.6)

        if ($isMonochrome) {
            $dropBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(160, 255, 255, 255))
            $g.FillPath($dropBrush, $dropPath)
            $dropBrush.Dispose()
        } else {
            # Rich Teal to Aqua gradient
            $dropBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
                (New-Object System.Drawing.PointF(520, 235)),
                (New-Object System.Drawing.PointF(700, 745)),
                [System.Drawing.Color]::FromArgb(245, 0, 150, 136),   # #009688
                [System.Drawing.Color]::FromArgb(245, 77, 208, 225)   # #4DD0E1
            )
            $g.FillPath($dropBrush, $dropPath)
            $dropBrush.Dispose()

            # Specular highlight inside droplet
            $specPath = New-Object System.Drawing.Drawing2D.GraphicsPath
            $specPoints = @(
                (New-Object System.Drawing.PointF(585, 290)),
                (New-Object System.Drawing.PointF(635, 380)),
                (New-Object System.Drawing.PointF(660, 480)),
                (New-Object System.Drawing.PointF(640, 485)),
                (New-Object System.Drawing.PointF(615, 390)),
                (New-Object System.Drawing.PointF(575, 300))
            )
            $specPath.AddClosedCurve($specPoints, 0.5)
            $specBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(120, 255, 255, 255))
            $g.FillPath($specBrush, $specPath)
            $specBrush.Dispose()
            $specPath.Dispose()
        }

        # 2. Main Seedling / Plant Stem (Recomposição Florestal / Muda)
        # Rising from bottom (440, 770) curving smoothly up to (480, 460)
        $stemPath = New-Object System.Drawing.Drawing2D.GraphicsPath
        $stemPoints = @(
            (New-Object System.Drawing.PointF(445, 775)),
            (New-Object System.Drawing.PointF(475, 680)),
            (New-Object System.Drawing.PointF(490, 570)),
            (New-Object System.Drawing.PointF(480, 430))
        )
        if ($isMonochrome) {
            $stemPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 255, 255, 255), 24)
            $stemPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
            $stemPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
            $g.DrawCurve($stemPen, $stemPoints)
            $stemPen.Dispose()
        } else {
            $stemPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 46, 125, 50), 24) # #2E7D32
            $stemPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
            $stemPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
            $g.DrawCurve($stemPen, $stemPoints)
            $stemPen.Dispose()
        }

        # 3. Primary Leaf (Large, arching proudly to the left)
        # Tip at (295, 390), base at (480, 520)
        $leaf1Path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $leaf1Points = @(
            (New-Object System.Drawing.PointF(480, 520)), # Stem joint
            (New-Object System.Drawing.PointF(410, 450)), # Top boundary
            (New-Object System.Drawing.PointF(320, 400)), # Near tip
            (New-Object System.Drawing.PointF(285, 410)), # Leaf apex
            (New-Object System.Drawing.PointF(330, 485)), # Lower boundary
            (New-Object System.Drawing.PointF(420, 560)), # Return to base
            (New-Object System.Drawing.PointF(480, 565))  # Base
        )
        $leaf1Path.AddClosedCurve($leaf1Points, 0.45)

        if ($isMonochrome) {
            $leaf1Brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 255, 255))
            $g.FillPath($leaf1Brush, $leaf1Path)
            $leaf1Brush.Dispose()
        } else {
            $leaf1Brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
                (New-Object System.Drawing.PointF(480, 565)),
                (New-Object System.Drawing.PointF(285, 410)),
                [System.Drawing.Color]::FromArgb(255, 46, 125, 50),   # #2E7D32
                [System.Drawing.Color]::FromArgb(255, 129, 199, 132)  # #81C784
            )
            $g.FillPath($leaf1Brush, $leaf1Path)
            $leaf1Brush.Dispose()

            # Leaf 1 center rib / highlight
            $rib1Path = New-Object System.Drawing.Drawing2D.GraphicsPath
            $rib1Points = @(
                (New-Object System.Drawing.PointF(475, 540)),
                (New-Object System.Drawing.PointF(390, 475)),
                (New-Object System.Drawing.PointF(300, 415))
            )
            $rib1Pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(180, 232, 245, 233), 7)
            $rib1Pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
            $rib1Pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
            $g.DrawCurve($rib1Pen, $rib1Points)
            $rib1Pen.Dispose()
            $rib1Path.Dispose()
        }
        $leaf1Path.Dispose()

        # 4. Secondary Leaf (Young sprouting leaf, curving up to the top-right over the drop)
        # Tip at (560, 310), base at (480, 440)
        $leaf2Path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $leaf2Points = @(
            (New-Object System.Drawing.PointF(475, 455)), # Stem joint
            (New-Object System.Drawing.PointF(510, 395)), # Left curve
            (New-Object System.Drawing.PointF(545, 330)), # Tip apex
            (New-Object System.Drawing.PointF(555, 390)), # Right curve
            (New-Object System.Drawing.PointF(515, 465)), # Lower side
            (New-Object System.Drawing.PointF(480, 470))  # Base
        )
        $leaf2Path.AddClosedCurve($leaf2Points, 0.4)

        if ($isMonochrome) {
            $leaf2Brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(235, 255, 255, 255))
            $g.FillPath($leaf2Brush, $leaf2Path)
            $leaf2Brush.Dispose()
        } else {
            $leaf2Brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
                (New-Object System.Drawing.PointF(475, 470)),
                (New-Object System.Drawing.PointF(545, 330)),
                [System.Drawing.Color]::FromArgb(255, 67, 160, 71),   # #43A047
                [System.Drawing.Color]::FromArgb(255, 165, 214, 167) # #A5D6A7
            )
            $g.FillPath($leaf2Brush, $leaf2Path)
            $leaf2Brush.Dispose()

            # Leaf 2 rib
            $rib2Path = New-Object System.Drawing.Drawing2D.GraphicsPath
            $rib2Points = @(
                (New-Object System.Drawing.PointF(485, 450)),
                (New-Object System.Drawing.PointF(515, 395)),
                (New-Object System.Drawing.PointF(540, 340))
            )
            $rib2Pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(190, 241, 248, 233), 5)
            $rib2Pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
            $rib2Pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
            $g.DrawCurve($rib2Pen, $rib2Points)
            $rib2Pen.Dispose()
            $rib2Path.Dispose()
        }
        $leaf2Path.Dispose()

        # 5. Base soil / fertile ground arc (subtle foundation for the seedling)
        $groundPath = New-Object System.Drawing.Drawing2D.GraphicsPath
        $groundPoints = @(
            (New-Object System.Drawing.PointF(370, 775)),
            (New-Object System.Drawing.PointF(445, 790)),
            (New-Object System.Drawing.PointF(530, 775)),
            (New-Object System.Drawing.PointF(445, 765))
        )
        $groundPath.AddClosedCurve($groundPoints, 0.5)
        if ($isMonochrome) {
            $groundBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(180, 255, 255, 255))
            $g.FillPath($groundBrush, $groundPath)
            $groundBrush.Dispose()
        } else {
            $groundBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 139, 195, 74)) # #8BC34A
            $g.FillPath($groundBrush, $groundPath)
            $groundBrush.Dispose()
        }
        $groundPath.Dispose()
        $stemPath.Dispose()
        $dropPath.Dispose()
    }

    # 2. Foreground Bitmap (Transparent with full emblem)
    $fgBmp = New-Object System.Drawing.Bitmap($width, $height)
    $fgG = [System.Drawing.Graphics]::FromImage($fgBmp)
    $fgG.Clear([System.Drawing.Color]::Transparent)
    Draw-Emblem $fgG $false
    $fgG.Dispose()
    $fgFile = Join-Path $outputPath "app_icon_foreground.png"
    $fgBmp.Save($fgFile, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host "Generated $fgFile"

    # 3. Monochrome Bitmap (Material You / Android 13+)
    $monoBmp = New-Object System.Drawing.Bitmap($width, $height)
    $monoG = [System.Drawing.Graphics]::FromImage($monoBmp)
    $monoG.Clear([System.Drawing.Color]::Transparent)
    Draw-Emblem $monoG $true
    $monoG.Dispose()
    $monoFile = Join-Path $outputPath "app_icon_monochrome.png"
    $monoBmp.Save($monoFile, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host "Generated $monoFile"

    # 4. Full Icon Bitmap (Background + Subtle drop shadow + Foreground)
    $fullBmp = New-Object System.Drawing.Bitmap($width, $height)
    $fullG = [System.Drawing.Graphics]::FromImage($fullBmp)
    # Draw background
    $fullG.DrawImage($bgBmp, 0, 0, $width, $height)
    # Draw foreground
    $fullG.DrawImage($fgBmp, 0, 0, $width, $height)
    $fullG.Dispose()
    $fullFile = Join-Path $outputPath "app_icon.png"
    $fullBmp.Save($fullFile, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host "Generated $fullFile"

    # Clean up
    $bgBmp.Dispose()
    $fgBmp.Dispose()
    $monoBmp.Dispose()
    $fullBmp.Dispose()
    Write-Host "All master icons generated successfully in $outputPath!"
}

Create-AppIcons
