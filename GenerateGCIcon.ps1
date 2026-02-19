param(
    [string]$ColorHex = "FF1493"
)

$srcPath = Join-Path $PSScriptRoot "Icon_GC_32_White.png"
$dstPath = Join-Path $PSScriptRoot "Icon_GC_Current.png"

if (-not (Test-Path $srcPath)) {
    exit 1
}

Add-Type -AssemblyName System.Drawing

$src = [System.Drawing.Image]::FromFile($srcPath)
$bmp = New-Object System.Drawing.Bitmap($src)

# Parse hex color
$ColorHex = $ColorHex -replace '^0x|^#', ''
$r = [Convert]::ToInt32($ColorHex.Substring(0, 2), 16)
$g = [Convert]::ToInt32($ColorHex.Substring(2, 2), 16)
$b = [Convert]::ToInt32($ColorHex.Substring(4, 2), 16)

for ($y = 0; $y -lt $bmp.Height; $y++) {
    for ($x = 0; $x -lt $bmp.Width; $x++) {
        $pixel = $bmp.GetPixel($x, $y)
        if ($pixel.A -gt 0) {
            $brightness = $pixel.R / 255.0
            $newR = [Math]::Min(255, [int]($r * $brightness))
            $newG = [Math]::Min(255, [int]($g * $brightness))
            $newB = [Math]::Min(255, [int]($b * $brightness))
            $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($pixel.A, $newR, $newG, $newB))
        }
    }
}

$bmp.Save($dstPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
$src.Dispose()
