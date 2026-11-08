$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Set-Location $PSScriptRoot

# NOTE: keep this file pure ASCII. Windows PowerShell 5.1 decodes BOM-less
# scripts as GBK, which corrupts non-ASCII literals and breaks parsing.
$glyph = [string][char]0x543E   # U+543E

function New-RoundedPath([single]$w, [single]$h, [single]$r) {
    $p = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $d = [single]($r * 2)
    $p.AddArc([single]0, [single]0, $d, $d, [single]180, [single]90)
    $p.AddArc([single]($w - $d), [single]0, $d, $d, [single]270, [single]90)
    $p.AddArc([single]($w - $d), [single]($h - $d), $d, $d, [single]0, [single]90)
    $p.AddArc([single]0, [single]($h - $d), $d, $d, [single]90, [single]90)
    $p.CloseFigure()
    return $p
}

$targets = [ordered]@{
    'mipmap-mdpi'    = 48
    'mipmap-hdpi'    = 72
    'mipmap-xhdpi'   = 96
    'mipmap-xxhdpi'  = 144
    'mipmap-xxxhdpi' = 192
}

$SS = 4   # supersample factor, keeps edges and glyph crisp after downscale

foreach ($dir in $targets.Keys) {
    $size = [int]$targets[$dir]
    $px   = [single]($size * $SS)

    $big = [System.Drawing.Bitmap]::new([int]$px, [int]$px)
    $g = [System.Drawing.Graphics]::FromImage($big)
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.Clear([System.Drawing.Color]::Transparent)

    # rounded-square background with a diagonal gradient matching the app theme
    $path = New-RoundedPath $px $px ([single]($px * 0.23))
    $pt1 = [System.Drawing.PointF]::new([single]0, [single]0)
    $pt2 = [System.Drawing.PointF]::new($px, $px)
    $c1  = [System.Drawing.Color]::FromArgb(255, 11, 18, 32)
    $c2  = [System.Drawing.Color]::FromArgb(255, 26, 49, 72)
    $bg  = [System.Drawing.Drawing2D.LinearGradientBrush]::new($pt1, $pt2, $c1, $c2)
    $g.FillPath($bg, $path)

    $font = [System.Drawing.Font]::new(
        'Microsoft YaHei', [single]($px * 0.52),
        [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $accent = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 121, 215, 197))
    $fmt = [System.Drawing.StringFormat]::new()
    $fmt.Alignment     = [System.Drawing.StringAlignment]::Center
    $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
    $rect = [System.Drawing.RectangleF]::new([single]0, [single](-$px * 0.02), $px, $px)
    $g.DrawString($glyph, $font, $accent, $rect, $fmt)
    $g.Dispose()
    $bg.Dispose(); $accent.Dispose(); $font.Dispose(); $path.Dispose(); $fmt.Dispose()

    $final = [System.Drawing.Bitmap]::new($size, $size)
    $g2 = [System.Drawing.Graphics]::FromImage($final)
    $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g2.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g2.DrawImage($big, 0, 0, $size, $size)
    $g2.Dispose()
    $big.Dispose()

    $outDir = Join-Path 'app\res' $dir
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    $outFile = Join-Path $outDir 'ic_launcher.png'
    $final.Save((Join-Path (Get-Location).Path $outFile), [System.Drawing.Imaging.ImageFormat]::Png)
    $final.Dispose()

    Write-Host ("{0,-16} {1,4}px -> {2}" -f $dir, $size, $outFile)
}
