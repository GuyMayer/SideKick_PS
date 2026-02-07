using namespace Windows.Storage
using namespace Windows.Graphics.Imaging

# Windows 10/11 OCR - Find text position in screen region
# Returns JSON with word positions for calibration
# Usage: .\OCR_FindText.ps1 -x 100 -y 100 -width 400 -height 50 -searchText "Rooms"

param(
    [int]$x,
    [int]$y,
    [int]$width,
    [int]$height,
    [string]$searchText = ""
)

Add-Type -AssemblyName System.Drawing

# Load WinRT assemblies
Add-Type -AssemblyName System.Runtime.WindowsRuntime

$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
$null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Foundation, ContentType = WindowsRuntime]
$null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime]

# Create OCR engine
$ocrEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()

# Async helper
$getAwaiterMethod = [System.Reflection.Assembly]::LoadWithPartialName('System.Runtime.WindowsRuntime').GetType('System.WindowsRuntimeSystemExtensions').GetMethods() | 
    Where-Object { $_.Name -eq 'GetAwaiter' -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | 
    Select-Object -First 1

Function Await {
    param($AsyncTask, $ResultType)
    $getAwaiterMethod.
        MakeGenericMethod($ResultType).
        Invoke($null, @($AsyncTask)).
        GetResult()
}

try {
    # Capture screen region
    $bitmap = New-Object System.Drawing.Bitmap($width, $height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($x, $y, 0, 0, [System.Drawing.Size]::new($width, $height))
    $graphics.Dispose()

    # Save to temp file
    $tempFile = Join-Path $env:TEMP ("ocr_calibrate_" + [guid]::NewGuid().ToString() + ".png")
    $bitmap.Save($tempFile, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()

    # Load for OCR
    $storageFile = Await ([StorageFile]::GetFileFromPathAsync($tempFile)) ([StorageFile])
    $fileStream = Await ($storageFile.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
    $bitmapDecoder = Await ([BitmapDecoder]::CreateAsync($fileStream)) ([BitmapDecoder])
    $softwareBitmap = Await ($bitmapDecoder.GetSoftwareBitmapAsync()) ([SoftwareBitmap])

    # Run OCR
    $ocrResult = Await ($ocrEngine.RecognizeAsync($softwareBitmap)) ([Windows.Media.Ocr.OcrResult])
    
    # Build result with word positions
    $words = @()
    foreach ($line in $ocrResult.Lines) {
        foreach ($word in $line.Words) {
            $rect = $word.BoundingRect
            $wordInfo = @{
                text = $word.Text
                x = [int]($x + $rect.X)
                y = [int]($y + $rect.Y)
                width = [int]$rect.Width
                height = [int]$rect.Height
                centerX = [int]($x + $rect.X + $rect.Width / 2)
                centerY = [int]($y + $rect.Y + $rect.Height / 2)
            }
            $words += $wordInfo
        }
    }
    
    # If searchText specified, find matching word
    $found = $null
    if ($searchText -ne "") {
        foreach ($w in $words) {
            if ($w.text -like "*$searchText*") {
                $found = $w
                break
            }
        }
    }
    
    # Output JSON result
    $result = @{
        success = $true
        fullText = $ocrResult.Text
        wordCount = $words.Count
        words = $words
        found = $found
    }
    
    Write-Output ($result | ConvertTo-Json -Depth 3 -Compress)
    
    $fileStream.Dispose()
    
} catch {
    $errorResult = @{
        success = $false
        error = $_.Exception.Message
    }
    Write-Output ($errorResult | ConvertTo-Json -Compress)
} finally {
    if ($tempFile -and (Test-Path $tempFile)) {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }
}
