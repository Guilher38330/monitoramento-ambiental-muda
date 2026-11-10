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

# Dark studio background
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
$haloPath.AddEllipse(250, 120, 1100, 680)
$haloBrush = New-Object System.Drawing.Drawing2D.PathGradientBrush($haloPath)
$haloBrush.CenterColor = [System.Drawing.Color]::FromArgb(35, 38, 166, 154) # teal ambient
$haloBrush.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 10, 14, 12))
$g.FillPath($haloBrush, $haloPath)
$haloBrush.Dispose()
$haloPath.Dispose()

# Fonts & Brushes
$titleFont = New-Object System.Drawing.Font("Segoe UI", 28, [System.Drawing.FontStyle]::Bold)
$subFont = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Regular)
$labelFont = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
$detailFont = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)

$whiteBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 240, 246, 240))
$tealBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 77, 208, 225))
$mutedBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 160, 175, 165))

$g.DrawString("Adaptação do Ícone — Estilo Solicitado", $titleFont, $whiteBrush, [float]80, [float]50)
$g.DrawString("Gota d'Água Central + Muda/Árvore em Primeiro Plano com Telemetria e Contornos Expressivos", $subFont, $tealBrush, [float]82, [float]100)

# Load Images
$userRefPath = "C:\Users\weisg\.gemini\antigravity\brain\a7e05489-803b-463f-87ed-956f01bd7fd3\.user_uploaded\media_1794351937341_9088ce87.jpg"
$userRefImg = [System.Drawing.Image]::FromFile($userRefPath)
$genIconImg = [System.Drawing.Image]::FromFile((Join-Path $assetsDir "generated_reference_icon.png"))
$fgImg = [System.Drawing.Image]::FromFile((Join-Path $assetsDir "generated_reference_foreground.png"))

# 4 Cards Configuration
$cards = @(
    @{
        Title = "1. Sua Referência";
        Subtitle = "Imagem Original Enviada";
        Type = "reference";
        Badge = "• Sua referência base`n• Gota azul + muda verde`n• Borda branca na folha`n• Traços de telemetria`n• Estilo plano moderno"
    },
    @{
        Title = "2. Arte 1024×1024";
        Subtitle = "Vetor em Alta Resolução";
        Type = "master_gen";
        Badge = "• Resolução 1024x1024`n• Linhas nítidas anti-alias`n• Gradiente ciano rico`n• Folhagem detalhada`n• Perfeito para App Stores"
    },
    @{
        Title = "3. Ícone Fundo Branco";
        Subtitle = "Círculo Android / Squircle";
        Type = "launcher_white";
        Badge = "• Círculo branco clean`n• Realce da gota e folhas`n• Sombra suave flutuante`n• Padrão Material Design`n• Alta legibilidade"
    },
    @{
        Title = "4. Ícone Fundo Verde";
        Subtitle = "Paleta #1B5E20 Floresta";
        Type = "launcher_green";
        Badge = "• Fundo verde #1B5E20`n• Contraste com a gota ciano`n• Identidade visual oficial`n• Seguro p/ corte Android`n• Destaque na gaveta"
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

    $panelBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(210, 24, 32, 28))
    $panelBorder = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(120, 40, 75, 65), 1.5)
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
    $shadowPath.AddEllipse([float]($iconX - 10), [float]($iconY + $iconSize - 12), [float]($iconSize + 20), [float]34)
    $shadowBrush = New-Object System.Drawing.Drawing2D.PathGradientBrush($shadowPath)
    $shadowBrush.CenterColor = [System.Drawing.Color]::FromArgb(140, 0, 0, 0)
    $shadowBrush.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
    $g.FillPath($shadowBrush, $shadowPath)
    $shadowBrush.Dispose()
    $shadowPath.Dispose()

    # Render Icon according to Card Type
    $iconBmp = New-Object System.Drawing.Bitmap($iconSize, $iconSize)
    $ig = [System.Drawing.Graphics]::FromImage($iconBmp)
    $ig.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $ig.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $ig.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    if ($c.Type -eq "reference") {
        # Rounded card with user reference
        $clipPath = New-Object System.Drawing.Drawing2D.GraphicsPath
        $r = 32
        $clipPath.AddArc(0, 0, $r*2, $r*2, 180, 90)
        $clipPath.AddArc($iconSize - $r*2, 0, $r*2, $r*2, 270, 90)
        $clipPath.AddArc($iconSize - $r*2, $iconSize - $r*2, $r*2, $r*2, 0, 90)
        $clipPath.AddArc(0, $iconSize - $r*2, $r*2, $r*2, 90, 90)
        $clipPath.CloseFigure()
        $ig.SetClip($clipPath)
        $ig.Clear([System.Drawing.Color]::White)
        $ig.DrawImage($userRefImg, 0, 0, $iconSize, $iconSize)
        $ig.ResetClip()
        $clipPath.Dispose()
    } elseif ($c.Type -eq "master_gen") {
        # High-res generated master
        $clipPath = New-Object System.Drawing.Drawing2D.GraphicsPath
        $r = 32
        $clipPath.AddArc(0, 0, $r*2, $r*2, 180, 90)
        $clipPath.AddArc($iconSize - $r*2, 0, $r*2, $r*2, 270, 90)
        $clipPath.AddArc($iconSize - $r*2, $iconSize - $r*2, $r*2, $r*2, 0, 90)
        $clipPath.AddArc(0, $iconSize - $r*2, $r*2, $r*2, 90, 90)
        $clipPath.CloseFigure()
        $ig.SetClip($clipPath)
        $ig.Clear([System.Drawing.Color]::White)
        $ig.DrawImage($genIconImg, 0, 0, $iconSize, $iconSize)
        $ig.ResetClip()
        $clipPath.Dispose()
    } elseif ($c.Type -eq "launcher_white") {
        # Circular adaptive icon on White container
        $clipPath = New-Object System.Drawing.Drawing2D.GraphicsPath
        $clipPath.AddEllipse(0, 0, $iconSize, $iconSize)
        $ig.SetClip($clipPath)
        $ig.Clear([System.Drawing.Color]::White)
        # Draw foreground centered with margin
        $pad = 12
        $ig.DrawImage($fgImg, $pad, $pad, ($iconSize - $pad*2), ($iconSize - $pad*2))
        $ig.ResetClip()
        $clipPath.Dispose()
    } elseif ($c.Type -eq "launcher_green") {
        # Circular adaptive icon on Forest Green (#1B5E20) gradient
        $clipPath = New-Object System.Drawing.Drawing2D.GraphicsPath
        $clipPath.AddEllipse(0, 0, $iconSize, $iconSize)
        $ig.SetClip($clipPath)
        $greenGrad = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            (New-Object System.Drawing.PointF(0, 0)),
            (New-Object System.Drawing.PointF($iconSize, $iconSize)),
            [System.Drawing.Color]::FromArgb(255, 27, 94, 32),
            [System.Drawing.Color]::FromArgb(255, 0, 77, 64)
        )
        $ig.FillRectangle($greenGrad, 0, 0, $iconSize, $iconSize)
        $greenGrad.Dispose()
        # Draw foreground centered with margin
        $pad = 12
        $ig.DrawImage($fgImg, $pad, $pad, ($iconSize - $pad*2), ($iconSize - $pad*2))
        $ig.ResetClip()
        $clipPath.Dispose()
    }

    $ig.Dispose()
    $g.DrawImage($iconBmp, [float]$iconX, [float]$iconY)
    $iconBmp.Dispose()

    # Draw card text
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center

    $g.DrawString($c.Title, $labelFont, $whiteBrush, [float]($x + $cardWidth/2), [float]($iconY + $iconSize + 28), $sf)
    $g.DrawString($c.Subtitle, $detailFont, $mutedBrush, [float]($x + $cardWidth/2), [float]($iconY + $iconSize + 54), $sf)

    # Mini info badge
    $badgeX = [int]($x + 25)
    $badgeY = [int]($iconY + $iconSize + 95)
    $badgeW = [int]($cardWidth - 50)
    $badgeH = [int](145)
    $badgeRect = New-Object System.Drawing.Rectangle($badgeX, $badgeY, $badgeW, $badgeH)
    $badgeBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(90, 16, 22, 18))
    $badgeBorder = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(80, 50, 85, 70), 1)
    $g.FillRectangle($badgeBrush, $badgeRect)
    $g.DrawRectangle($badgeBorder, $badgeRect)
    $badgeBrush.Dispose()
    $badgeBorder.Dispose()

    $badgeSf = New-Object System.Drawing.StringFormat
    $badgeSf.Alignment = [System.Drawing.StringAlignment]::Near
    $badgeSf.LineAlignment = [System.Drawing.StringAlignment]::Near

    $g.DrawString($c.Badge, $detailFont, $tealBrush, [float]($badgeX + 15), [float]($badgeY + 14), $badgeSf)
}

# Footer palette preview bar
$paletteY = 825
$g.DrawString("Paleta Extraída da Imagem:", $detailFont, $mutedBrush, [float]80, [float]($paletteY + 5))

$colors = @(
    @{ Name = "#1B5E20 Floresta"; Color = [System.Drawing.Color]::FromArgb(255, 27, 94, 32) },
    @{ Name = "#00695C Teal PSA"; Color = [System.Drawing.Color]::FromArgb(255, 0, 105, 92) },
    @{ Name = "#26A69A Água Base"; Color = [System.Drawing.Color]::FromArgb(255, 38, 166, 154) },
    @{ Name = "#80DEEA Ciano Topo"; Color = [System.Drawing.Color]::FromArgb(255, 128, 222, 234) },
    @{ Name = "#4CAF50 Folha Viva"; Color = [System.Drawing.Color]::FromArgb(255, 76, 175, 80) },
    @{ Name = "#81C784 Broto"; Color = [System.Drawing.Color]::FromArgb(255, 129, 199, 132) },
    @{ Name = "#FFFFFF Contorno"; Color = [System.Drawing.Color]::FromArgb(255, 255, 255, 255) }
)

$swatchX = 280
foreach ($col in $colors) {
    $swatchRect = New-Object System.Drawing.Rectangle($swatchX, $paletteY, 24, 24)
    $sBrush = New-Object System.Drawing.SolidBrush($col.Color)
    $sPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(100, 255, 255, 255), 1)
    $g.FillEllipse($sBrush, $swatchRect)
    $g.DrawEllipse($sPen, $swatchRect)
    $sBrush.Dispose()
    $sPen.Dispose()

    $g.DrawString($col.Name, $detailFont, $whiteBrush, [float]($swatchX + 30), [float]($paletteY + 4))
    $swatchX += 185
}

# Save image in assets and artifact directory
$previewAssetsPath = Join-Path $assetsDir "style_comparison_mockup.png"
$previewArtifactPath = Join-Path $artifactDir "style_comparison_mockup.png"

$bmp.Save($previewAssetsPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Save($previewArtifactPath, [System.Drawing.Imaging.ImageFormat]::Png)

Write-Host "Generated style comparison mockup in: $previewAssetsPath and $previewArtifactPath"

$userRefImg.Dispose()
$genIconImg.Dispose()
$fgImg.Dispose()
$g.Dispose()
$bmp.Dispose()
