Add-Type -AssemblyName System.Drawing

$artifactDir = "C:\Users\weisg\.gemini\antigravity\brain\a7e05489-803b-463f-87ed-956f01bd7fd3"
$assetsDir = "c:\Users\weisg\AndroidStudioProjects\trabalho_final\assets\icon"

$canvasW = 1600
$canvasH = 920
$bmp = New-Object System.Drawing.Bitmap($canvasW, $canvasH)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

# Modern dark studio background
$bgRect = New-Object System.Drawing.Rectangle(0, 0, $canvasW, $canvasH)
$bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.PointF(0, 0)),
    (New-Object System.Drawing.PointF($canvasW, $canvasH)),
    [System.Drawing.Color]::FromArgb(255, 18, 24, 20),
    [System.Drawing.Color]::FromArgb(255, 10, 14, 12)
)
$g.FillRectangle($bgBrush, $bgRect)
$bgBrush.Dispose()

# Ambient green halo in background
$haloPath = New-Object System.Drawing.Drawing2D.GraphicsPath
$haloPath.AddEllipse(200, 100, 1200, 700)
$haloBrush = New-Object System.Drawing.Drawing2D.PathGradientBrush($haloPath)
$haloBrush.CenterColor = [System.Drawing.Color]::FromArgb(35, 27, 94, 32)
$haloBrush.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 10, 14, 12))
$g.FillPath($haloBrush, $haloPath)
$haloBrush.Dispose()
$haloPath.Dispose()

# Title and Subtitle
$titleFont = New-Object System.Drawing.Font("Segoe UI", 28, [System.Drawing.FontStyle]::Bold)
$subFont = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Regular)
$labelFont = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$detailFont = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)

$whiteBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 240, 246, 240))
$greenBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 129, 199, 132))
$mutedBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 160, 175, 165))

$g.DrawString("EcoMonitor — Muda & PSA", $titleFont, $whiteBrush, 80, 50)
$g.DrawString("Visualização Oficial do Ícone do Aplicativo — Paleta #1B5E20 (Verde Floresta) & #00695C (Teal Hidrológico)", $subFont, $greenBrush, 82, 100)

# Load master images
$appIcon = [System.Drawing.Image]::FromFile((Join-Path $assetsDir "app_icon.png"))
$monoIcon = [System.Drawing.Image]::FromFile((Join-Path $assetsDir "app_icon_monochrome.png"))

# Card specifications (4 cards)
$cards = @(
    @{
        Title = "1. Arte Master";
        Subtitle = "Store & PWA Web (1024x1024)";
        Shape = "rounded";
        Type = "master"
    },
    @{
        Title = "2. Android Círculo";
        Subtitle = "Pixel, Motorola & Samsung";
        Shape = "circle";
        Type = "master"
    },
    @{
        Title = "3. Android Squircle";
        Subtitle = "Xiaomi, ASUS & OnePlus";
        Shape = "squircle";
        Type = "master"
    },
    @{
        Title = "4. Material You";
        Subtitle = "Android 13+ (Ícone Temático)";
        Shape = "circle";
        Type = "material_you"
    }
)

$cardWidth = 320
$cardHeight = 620
$startX = 80
$gap = 60
$cardY = 160

for ($i = 0; $i -lt $cards.Count; $i++) {
    $c = $cards[$i]
    $x = $startX + $i * ($cardWidth + $gap)
    
    # Card Background Panel
    $cardPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $cr = 20
    $cw = $cardWidth
    $ch = $cardHeight
    $cardPath.AddArc($x, $cardY, $cr*2, $cr*2, 180, 90)
    $cardPath.AddArc($x + $cw - $cr*2, $cardY, $cr*2, $cr*2, 270, 90)
    $cardPath.AddArc($x + $cw - $cr*2, $cardY + $ch - $cr*2, $cr*2, $cr*2, 0, 90)
    $cardPath.AddArc($x, $cardY + $ch - $cr*2, $cr*2, $cr*2, 90, 90)
    $cardPath.CloseFigure()

    $panelBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(210, 26, 34, 28))
    $panelBorder = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(120, 50, 80, 55), 1.5)
    $g.FillPath($panelBrush, $cardPath)
    $g.DrawPath($panelBorder, $cardPath)
    $panelBrush.Dispose()
    $panelBorder.Dispose()
    $cardPath.Dispose()

    # Icon preview bounding box inside card
    $iconSize = 220
    $iconX = $x + ($cardWidth - $iconSize) / 2
    $iconY = $cardY + 50

    # Draw shadow under icon
    $shadowPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $shadowPath.AddEllipse($iconX - 10, $iconY + $iconSize - 15, $iconSize + 20, 36)
    $shadowBrush = New-Object System.Drawing.Drawing2D.PathGradientBrush($shadowPath)
    $shadowBrush.CenterColor = [System.Drawing.Color]::FromArgb(120, 0, 0, 0)
    $shadowBrush.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
    $g.FillPath($shadowBrush, $shadowPath)
    $shadowBrush.Dispose()
    $shadowPath.Dispose()

    # Create temporary clipped bitmap for shape preview
    $iconBmp = New-Object System.Drawing.Bitmap($iconSize, $iconSize)
    $ig = [System.Drawing.Graphics]::FromImage($iconBmp)
    $ig.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $ig.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $ig.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    # Clipping mask
    $clipPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    if ($c.Shape -eq "circle") {
        $clipPath.AddEllipse(0, 0, $iconSize, $iconSize)
    } elseif ($c.Shape -eq "squircle") {
        # Squircle via high-curvature bezier
        $r = 54
        $clipPath.AddArc(0, 0, $r*2, $r*2, 180, 90)
        $clipPath.AddArc($iconSize - $r*2, 0, $r*2, $r*2, 270, 90)
        $clipPath.AddArc($iconSize - $r*2, $iconSize - $r*2, $r*2, $r*2, 0, 90)
        $clipPath.AddArc(0, $iconSize - $r*2, $r*2, $r*2, 90, 90)
        $clipPath.CloseFigure()
    } else {
        # Rounded rect
        $r = 44
        $clipPath.AddArc(0, 0, $r*2, $r*2, 180, 90)
        $clipPath.AddArc($iconSize - $r*2, 0, $r*2, $r*2, 270, 90)
        $clipPath.AddArc($iconSize - $r*2, $iconSize - $r*2, $r*2, $r*2, 0, 90)
        $clipPath.AddArc(0, $iconSize - $r*2, $r*2, $r*2, 90, 90)
        $clipPath.CloseFigure()
    }

    $ig.SetClip($clipPath)

    if ($c.Type -eq "material_you") {
        # Material You Dark Theme: System dynamic tinted background
        $myBg = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 30, 48, 42)) # dynamic tint
        $ig.FillRectangle($myBg, 0, 0, $iconSize, $iconSize)
        $myBg.Dispose()

        # Monochrome foreground drawn with dynamic accent tint (#A5D6A7)
        $ia = New-Object System.Drawing.Imaging.ImageAttributes
        $cm = New-Object System.Drawing.Imaging.ColorMatrix
        # Tint white to #81C784 (129/255, 199/255, 132/255)
        $cm.Matrix00 = 0.50
        $cm.Matrix11 = 0.78
        $cm.Matrix22 = 0.52
        $cm.Matrix33 = 1.00
        $ia.SetColorMatrix($cm)
        $ig.DrawImage($monoIcon, (New-Object System.Drawing.Rectangle(0, 0, $iconSize, $iconSize)), 0, 0, $monoIcon.Width, $monoIcon.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
        $ia.Dispose()
    } else {
        $ig.DrawImage($appIcon, 0, 0, $iconSize, $iconSize)
    }

    $ig.ResetClip()
    $ig.Dispose()
    $clipPath.Dispose()

    # Draw icon onto master canvas
    $g.DrawImage($iconBmp, $iconX, $iconY)
    $iconBmp.Dispose()

    # Draw card text
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center

    $g.DrawString($c.Title, $labelFont, $whiteBrush, $x + $cardWidth/2, $iconY + $iconSize + 30, $sf)
    $g.DrawString($c.Subtitle, $detailFont, $mutedBrush, $x + $cardWidth/2, $iconY + $iconSize + 56, $sf)

    # Mini info badge
    $badgeX = [int]($x + 25)
    $badgeY = [int]($iconY + $iconSize + 100)
    $badgeW = [int]($cardWidth - 50)
    $badgeH = [int](140)
    $badgeRect = New-Object System.Drawing.Rectangle($badgeX, $badgeY, $badgeW, $badgeH)
    $badgeBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(90, 16, 22, 18))
    $badgeBorder = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(80, 60, 90, 65), 1)
    $g.FillRectangle($badgeBrush, $badgeRect)
    $g.DrawRectangle($badgeBorder, $badgeRect)
    $badgeBrush.Dispose()
    $badgeBorder.Dispose()

    $badgeSf = New-Object System.Drawing.StringFormat
    $badgeSf.Alignment = [System.Drawing.StringAlignment]::Near
    $badgeSf.LineAlignment = [System.Drawing.StringAlignment]::Near

    $badgeDesc = ""
    if ($i -eq 0) {
        $badgeDesc = "• Formato 1024x1024`n• Gradiente florestal`n• Gota d'agua PSA`n• Broto / muda verde`n• Ideal para App Stores"
    } elseif ($i -eq 1) {
        $badgeDesc = "• Mascara circular`n• Camada adaptativa`n• 16% inset nativo`n• Sem distorcao`n• Pixel / Samsung OneUI"
    } elseif ($i -eq 2) {
        $badgeDesc = "• Formato Squircle`n• Curvatura adaptativa`n• Alinhamento central`n• Densidades mipmap`n• MIUI / OxygenOS"
    } else {
        $badgeDesc = "• Android 13+ (API 33)`n• Adapta-se ao tema`n• Camada monocromatica`n• Cores dinamicas`n• Estilo Material You"
    }

    $g.DrawString($badgeDesc, $detailFont, $greenBrush, [float]($badgeX + 15), [float]($badgeY + 15), $badgeSf)
}

# Footer palette preview bar
$paletteY = 825
$g.DrawString("Paleta Oficial do Projeto:", $detailFont, $mutedBrush, 80, $paletteY + 5)

$colors = @(
    @{ Name = "#1B5E20 (Verde Floresta)"; Color = [System.Drawing.Color]::FromArgb(255, 27, 94, 32) },
    @{ Name = "#004D40 (Teal Profundo)"; Color = [System.Drawing.Color]::FromArgb(255, 0, 77, 64) },
    @{ Name = "#009688 (Teal PSA Hidrico)"; Color = [System.Drawing.Color]::FromArgb(255, 0, 150, 136) },
    @{ Name = "#4DD0E1 (Aqua Gota)"; Color = [System.Drawing.Color]::FromArgb(255, 77, 208, 225) },
    @{ Name = "#43A047 (Folha Primaria)"; Color = [System.Drawing.Color]::FromArgb(255, 67, 160, 71) },
    @{ Name = "#81C784 (Muda Broto)"; Color = [System.Drawing.Color]::FromArgb(255, 129, 199, 132) },
    @{ Name = "#C8E6C9 (Verde Claro AM-02)"; Color = [System.Drawing.Color]::FromArgb(255, 200, 230, 201) }
)

$swatchX = 270
foreach ($col in $colors) {
    $swatchRect = New-Object System.Drawing.Rectangle($swatchX, $paletteY, 24, 24)
    $sBrush = New-Object System.Drawing.SolidBrush($col.Color)
    $sPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(100, 255, 255, 255), 1)
    $g.FillEllipse($sBrush, $swatchRect)
    $g.DrawEllipse($sPen, $swatchRect)
    $sBrush.Dispose()
    $sPen.Dispose()

    $g.DrawString($col.Name, $detailFont, $whiteBrush, ($swatchX + 30), ($paletteY + 4))
    $swatchX += 185
}

# Save image in assets and artifact directory
$previewAssetsPath = Join-Path $assetsDir "icon_preview_mockup.png"
$previewArtifactPath = Join-Path $artifactDir "icon_preview_mockup.png"

$bmp.Save($previewAssetsPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Save($previewArtifactPath, [System.Drawing.Imaging.ImageFormat]::Png)

Write-Host "Generated mockup in: $previewAssetsPath and $previewArtifactPath"

$appIcon.Dispose()
$monoIcon.Dispose()
$g.Dispose()
$bmp.Dispose()
