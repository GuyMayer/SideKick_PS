@echo off
title SideKick - GoCardless Connection Fix
color 0B
echo ============================================================
echo   SideKick GoCardless Connection Fix
echo   %date% %time%
echo ============================================================
echo.
echo   Checking and repairing GoCardless connection...
echo.

:: Self-contained: extract embedded PowerShell from this file into TEMP and run it
set "PSFILE=%TEMP%\gc_fix_connection.ps1"
set "SELF=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$f=Get-Content $env:SELF;$m=$f|Select-String '^#BEGINPS$'|Select-Object -First 1;if($m){$f[($m.LineNumber)..($f.Count-1)]|Set-Content $env:PSFILE -Encoding UTF8}"

if not exist "%PSFILE%" (
    echo   ERROR: Failed to extract PowerShell script.
    echo   Please contact Guy.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PSFILE%"
del "%PSFILE%" 2>nul

echo.
echo ============================================================
echo   Done! If issues remain, screenshot this and send to Guy.
echo ============================================================
echo.
pause
exit /b

#BEGINPS
$ErrorActionPreference = 'SilentlyContinue'
$SK = 'C:\Program Files (x86)\SideKick_PS'
$AppData = Join-Path $env:APPDATA 'SideKick_PS'
$INI = Join-Path $AppData 'SideKick_PS.ini'
$CRED = Join-Path $AppData 'credentials.json'
$GCA = Join-Path $SK '_gca.exe'
$LOGDIR = Join-Path $AppData 'Logs'
$fixed = 0
$issues = 0

function Write-Status($icon, $msg, $color = 'White') {
    Write-Host "  $icon $msg" -ForegroundColor $color
}

# ============================================================
# STEP 1: Check SideKick Installation
# ============================================================
Write-Host '--- STEP 1: Check SideKick Installation ---' -ForegroundColor Cyan
Write-Host ''

if (-not (Test-Path $SK)) {
    Write-Status '[FAIL]' 'SideKick_PS not installed at expected location' 'Red'
    Write-Status '      ' $SK 'Yellow'
    Write-Host ''
    Write-Host '  Cannot continue. Please reinstall SideKick_PS.' -ForegroundColor Red
    Read-Host '  Press Enter to exit'
    exit 1
}
Write-Status '[OK]' "Install folder: $SK" 'Green'

if (-not (Test-Path $GCA)) {
    Write-Status '[FAIL]' '_gca.exe missing - GoCardless module not installed' 'Red'
    $issues++
} else {
    $gcaInfo = Get-Item $GCA
    $sizeKB = [math]::Round($gcaInfo.Length / 1KB)
    $modified = $gcaInfo.LastWriteTime.ToString('dd/MM/yyyy HH:mm')
    Write-Status '[OK]' "_gca.exe found ($sizeKB KB, $modified)" 'Green'
}
Write-Host ''

# ============================================================
# STEP 2: Check AppData Folder
# ============================================================
Write-Host '--- STEP 2: Check AppData Folder ---' -ForegroundColor Cyan
Write-Host ''

if (-not (Test-Path $AppData)) {
    Write-Status '[FIX]' 'AppData folder missing - creating it...' 'Yellow'
    New-Item -ItemType Directory -Path $AppData -Force | Out-Null
    $fixed++
}
Write-Status '[OK]' "AppData: $AppData" 'Green'

if (-not (Test-Path $LOGDIR)) {
    Write-Status '[FIX]' 'Logs folder missing - creating it...' 'Yellow'
    New-Item -ItemType Directory -Path $LOGDIR -Force | Out-Null
    $fixed++
}
Write-Status '[OK]' "Logs: $LOGDIR" 'Green'
Write-Host ''

# ============================================================
# STEP 3: Check INI File
# ============================================================
Write-Host '--- STEP 3: Check INI File ---' -ForegroundColor Cyan
Write-Host ''

$iniExists = Test-Path $INI
$iniFallback = Join-Path $SK 'SideKick_PS.ini'
if ((-not $iniExists) -and (Test-Path $iniFallback)) {
    Write-Status '[FIX]' 'INI missing from AppData but found in install folder - copying...' 'Yellow'
    Copy-Item $iniFallback $INI -Force
    $fixed++
    $iniExists = $true
}

if (-not $iniExists) {
    Write-Status '[FAIL]' 'No INI file found!' 'Red'
    $issues++
} else {
    Write-Status '[OK]' "INI: $INI" 'Green'
    $iniContent = Get-Content $INI -Raw

    if ($iniContent -match '(?m)^\[GoCardless\]') {
        Write-Status '[OK]' '[GoCardless] section exists' 'Green'
        if ($iniContent -match '(?m)^Environment=(.+)') {
            $envVal = $Matches[1].Trim()
            if ($envVal -eq 'live') {
                Write-Status '[OK]' "Environment=$envVal" 'Green'
            } elseif ($envVal -eq 'sandbox') {
                Write-Status '[WARN]' 'Environment=sandbox - should be live for production!' 'Yellow'
                $issues++
            } else {
                Write-Status '[WARN]' "Environment=$envVal (unexpected)" 'Yellow'
                $issues++
            }
        } else {
            Write-Status '[WARN]' 'No Environment= line in [GoCardless] section' 'Yellow'
            $issues++
        }
        if ($iniContent -match '(?m)^Enabled=(.+)') {
            $gcEnabled = $Matches[1].Trim()
            if ($gcEnabled -eq '1') {
                Write-Status '[OK]' 'GoCardless Enabled=1' 'Green'
            } else {
                Write-Status '[WARN]' "GoCardless Enabled=$gcEnabled - should be 1!" 'Yellow'
                $issues++
            }
        }
    } else {
        Write-Status '[FIX]' '[GoCardless] section MISSING from INI - adding it...' 'Yellow'
        Add-Content -Path $INI -Value "`r`n[GoCardless]`r`nEnvironment=live`r`nEnabled=1`r`n" -Encoding UTF8
        $fixed++
        Write-Status '[OK]' 'Added [GoCardless] section with Environment=live, Enabled=1' 'Green'
    }
}
Write-Host ''

# ============================================================
# STEP 4: Check credentials.json
# ============================================================
Write-Host '--- STEP 4: Check credentials.json ---' -ForegroundColor Cyan
Write-Host ''

$credExists = Test-Path $CRED
$credFallback = Join-Path $SK 'credentials.json'
if ((-not $credExists) -and (Test-Path $credFallback)) {
    Write-Status '[FIX]' 'credentials.json missing from AppData - copying from install folder...' 'Yellow'
    Copy-Item $credFallback $CRED -Force
    $fixed++
    $credExists = $true
}

if (-not $credExists) {
    Write-Status '[FAIL]' 'credentials.json NOT FOUND!' 'Red'
    Write-Status '      ' "Expected at: $CRED" 'Yellow'
    Write-Status '      ' "Or at: $credFallback" 'Yellow'
    $issues++
} else {
    Write-Status '[OK]' "credentials.json: $CRED" 'Green'
    try {
        $credJson = Get-Content $CRED -Raw -Encoding UTF8
        $creds = $credJson | ConvertFrom-Json

        $gcTokenB64 = $creds.gc_token_b64
        if ($gcTokenB64 -and $gcTokenB64.Length -gt 10 -and $gcTokenB64 -ne 'BASE64_ENCODED_GOCARDLESS_TOKEN_HERE') {
            try {
                $decoded = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($gcTokenB64))
                $preview = $decoded.Substring(0, [Math]::Min(15, $decoded.Length))
                Write-Status '[OK]' "gc_token_b64: present ($preview...)" 'Green'
                if ($decoded.StartsWith('live_')) {
                    Write-Status '[OK]' 'Token prefix: live_' 'Green'
                } elseif ($decoded.StartsWith('sandbox_')) {
                    Write-Status '[WARN]' 'Token prefix: sandbox_ - is this intentional?' 'Yellow'
                    $issues++
                } else {
                    $pfx = $decoded.Substring(0, [Math]::Min(8, $decoded.Length))
                    Write-Status '[WARN]' "Token prefix: $pfx (unexpected)" 'Yellow'
                    $issues++
                }
            } catch {
                Write-Status '[FAIL]' 'gc_token_b64 is not valid Base64!' 'Red'
                $issues++
            }
        } elseif ($gcTokenB64 -eq 'BASE64_ENCODED_GOCARDLESS_TOKEN_HERE') {
            Write-Status '[FAIL]' 'gc_token_b64 still has placeholder value - needs real token!' 'Red'
            $issues++
        } else {
            Write-Status '[FAIL]' 'gc_token_b64 is EMPTY or too short!' 'Red'
            $issues++
        }

        $apiKeyB64 = $creds.api_key_b64
        if ($apiKeyB64 -and $apiKeyB64.Length -gt 10) {
            Write-Status '[OK]' 'api_key_b64: present' 'Green'
        } else {
            Write-Status '[INFO]' 'api_key_b64: empty (GHL integration disabled)' 'Cyan'
        }

        $locId = $creds.location_id
        if ($locId -and $locId.Length -gt 5) {
            Write-Status '[OK]' "location_id: $locId" 'Green'
        } else {
            Write-Status '[INFO]' 'location_id: empty (GHL integration disabled)' 'Cyan'
        }
    } catch {
        Write-Status '[FAIL]' 'credentials.json is CORRUPT or invalid JSON!' 'Red'
        Write-Status '      ' $_.Exception.Message 'Yellow'
        $issues++
    }
}
Write-Host ''

# ============================================================
# STEP 5: Test _gca.exe Connection
# ============================================================
Write-Host '--- STEP 5: Test _gca.exe Connection ---' -ForegroundColor Cyan
Write-Host ''

if (Test-Path $GCA) {
    $stdOut = Join-Path $env:TEMP 'gc_fix_stdout.txt'
    $stdErr = Join-Path $env:TEMP 'gc_fix_stderr.txt'

    # Test WITH --live flag (as diagnostic does)
    Write-Status '[..]' 'Testing: _gca.exe --test-connection --live' 'Cyan'
    try {
        $proc = Start-Process -FilePath $GCA -ArgumentList '--test-connection','--live' -Wait -NoNewWindow -PassThru -RedirectStandardOutput $stdOut -RedirectStandardError $stdErr
        $output = Get-Content $stdOut -Raw -ErrorAction SilentlyContinue
        $errors = Get-Content $stdErr -Raw -ErrorAction SilentlyContinue
        if ($proc.ExitCode -eq 0 -and $output -match 'SUCCESS') {
            Write-Status '[OK]' "With --live: $($output.Trim())" 'Green'
        } else {
            Write-Status '[FAIL]' "With --live: Exit=$($proc.ExitCode)" 'Red'
            if ($output) { Write-Status '      ' "Out: $($output.Trim())" 'Yellow' }
            if ($errors) { Write-Status '      ' "Err: $($errors.Trim())" 'Yellow' }
            $issues++
        }
    } catch {
        Write-Status '[FAIL]' "Could not run _gca.exe: $($_.Exception.Message)" 'Red'
        $issues++
    }

    # Test WITHOUT --live flag (how SideKick actually calls it)
    Write-Status '[..]' 'Testing: _gca.exe --test-connection (no --live flag)' 'Cyan'
    try {
        $proc2 = Start-Process -FilePath $GCA -ArgumentList '--test-connection' -Wait -NoNewWindow -PassThru -RedirectStandardOutput $stdOut -RedirectStandardError $stdErr
        $output2 = Get-Content $stdOut -Raw -ErrorAction SilentlyContinue
        $errors2 = Get-Content $stdErr -Raw -ErrorAction SilentlyContinue
        if ($proc2.ExitCode -eq 0 -and $output2 -match 'SUCCESS') {
            Write-Status '[OK]' "Without --live: $($output2.Trim())" 'Green'
        } else {
            Write-Status '[FAIL]' 'FAILED without --live flag - this is how SideKick calls it!' 'Red'
            Write-Status '[!!!!]' 'INI [GoCardless] Environment setting is wrong or missing' 'Red'
            if ($output2) { Write-Status '      ' "Out: $($output2.Trim())" 'Yellow' }
            if ($errors2) { Write-Status '      ' "Err: $($errors2.Trim())" 'Yellow' }
            $issues++

            # Try to auto-fix sandbox to live
            if ($iniExists) {
                $iniContent2 = Get-Content $INI -Raw
                if ($iniContent2 -match 'Environment=sandbox') {
                    Write-Status '[FIX]' 'Changing Environment from sandbox to live...' 'Yellow'
                    $iniContent2 = $iniContent2 -replace 'Environment=sandbox', 'Environment=live'
                    Set-Content -Path $INI -Value $iniContent2 -Encoding UTF8 -NoNewline
                    $fixed++

                    Write-Status '[..]' 'Re-testing after fix...' 'Cyan'
                    $proc3 = Start-Process -FilePath $GCA -ArgumentList '--test-connection' -Wait -NoNewWindow -PassThru -RedirectStandardOutput $stdOut -RedirectStandardError $stdErr
                    $output3 = Get-Content $stdOut -Raw -ErrorAction SilentlyContinue
                    if ($proc3.ExitCode -eq 0 -and $output3 -match 'SUCCESS') {
                        Write-Status '[OK]' "Fixed! $($output3.Trim())" 'Green'
                        $issues--
                    } else {
                        Write-Status '[FAIL]' 'Still failing after environment fix' 'Red'
                    }
                }
            }
        }
    } catch {
        Write-Status '[FAIL]' "Could not run _gca.exe: $($_.Exception.Message)" 'Red'
        $issues++
    }
} else {
    Write-Status '[SKIP]' '_gca.exe not found - cannot test' 'Yellow'
}
Write-Host ''

# ============================================================
# STEP 6: Check Stale _MEI Folders
# ============================================================
Write-Host '--- STEP 6: Check Stale _MEI Folders ---' -ForegroundColor Cyan
Write-Host ''

$mei = Get-ChildItem $env:TEMP -Directory -Filter '_MEI*' -ErrorAction SilentlyContinue
$meiCount = 0
if ($mei) { $meiCount = @($mei).Count }
if ($meiCount -gt 50) {
    Write-Status '[WARN]' "$meiCount stale _MEI folders in TEMP (excessive)" 'Yellow'
    $cutoff = (Get-Date).AddDays(-7)
    $old = @($mei | Where-Object { $_.CreationTime -lt $cutoff })
    if ($old.Count -gt 0) {
        $oldCount = $old.Count
        $cleanedCount = 0
        foreach ($m in $old) {
            try {
                Remove-Item $m.FullName -Recurse -Force -ErrorAction Stop
                $cleanedCount++
            } catch { }
        }
        Write-Status '[FIX]' "Cleaned $cleanedCount of $oldCount old _MEI folders" 'Green'
        $fixed++
    }
} elseif ($meiCount -gt 0) {
    Write-Status '[OK]' "$meiCount _MEI folders (normal)" 'Green'
} else {
    Write-Status '[OK]' 'No _MEI folders' 'Green'
}
Write-Host ''

# ============================================================
# STEP 7: Check Error Logs
# ============================================================
Write-Host '--- STEP 7: Check Error Logs ---' -ForegroundColor Cyan
Write-Host ''

if (Test-Path $LOGDIR) {
    $gcerr = Get-ChildItem $LOGDIR -Filter 'gc_error_*' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 3
    if ($gcerr) {
        foreach ($f in $gcerr) {
            $ts = $f.LastWriteTime.ToString('dd/MM/yyyy HH:mm')
            Write-Status '[LOG]' "$($f.Name) ($ts)" 'Yellow'
        }
        Write-Host ''
        Write-Host '  --- Last 15 lines of newest error log ---' -ForegroundColor Yellow
        Get-Content $gcerr[0].FullName -Tail 15 | ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }
    } else {
        Write-Status '[OK]' 'No gc_error logs' 'Green'
    }
    $gcdbg = Get-ChildItem $LOGDIR -Filter 'gc_debug_*' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($gcdbg) {
        Write-Status '[LOG]' "Latest debug: $($gcdbg[0].Name)" 'Cyan'
    }
} else {
    Write-Status '[WARN]' 'Log folder does not exist' 'Yellow'
}
Write-Host ''

# ============================================================
# STEP 8: Check TLS / Network
# ============================================================
Write-Host '--- STEP 8: Check TLS / Network ---' -ForegroundColor Cyan
Write-Host ''

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $null = Invoke-WebRequest -Uri 'https://api.gocardless.com/creditors' -Method GET -Headers @{
        'Authorization' = 'Bearer test'
        'GoCardless-Version' = '2015-07-06'
    } -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
} catch {
    $httpEx = $_.Exception
    if ($httpEx.Response) {
        $statusCode = [int]$httpEx.Response.StatusCode
        if ($statusCode -eq 401) {
            Write-Status '[OK]' 'API reachable (got 401 as expected with dummy token)' 'Green'
        } else {
            Write-Status '[WARN]' "API returned status $statusCode" 'Yellow'
            $issues++
        }
    } elseif ($httpEx.Message -match 'SSL|TLS|certificate|trust') {
        Write-Status '[FAIL]' 'TLS/SSL connection error - check system certificates' 'Red'
        Write-Status '      ' $httpEx.Message 'Yellow'
        $issues++
    } elseif ($httpEx.Message -match 'timeout|timed out') {
        Write-Status '[FAIL]' 'Connection timed out - check firewall/proxy' 'Red'
        $issues++
    } else {
        Write-Status '[FAIL]' "Network error: $($httpEx.Message)" 'Red'
        $issues++
    }
}
Write-Host ''

# ============================================================
# STEP 9: Defender / Software Restrictions
# ============================================================
Write-Host '--- STEP 9: Defender / Software Restrictions ---' -ForegroundColor Cyan
Write-Host ''

try {
    $excl = (Get-MpPreference).ExclusionPath
    $skExcluded = $false
    if ($excl) {
        foreach ($e in $excl) {
            if ($e -match 'SideKick') { $skExcluded = $true; break }
        }
    }
    if ($skExcluded) {
        Write-Status '[OK]' 'SideKick folder in Defender exclusions' 'Green'
    } else {
        Write-Status '[WARN]' 'SideKick folder NOT in Defender exclusions' 'Yellow'
        Write-Status '      ' 'Consider adding: C:\Program Files (x86)\SideKick_PS' 'Yellow'
        $issues++
    }
} catch {
    Write-Status '[INFO]' 'Cannot read Defender settings (need admin)' 'Cyan'
}

$srp = Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Safer\CodeIdentifiers' -ErrorAction SilentlyContinue
if ($srp) {
    Write-Status '[WARN]' 'Software Restriction Policies detected - may block EXEs' 'Yellow'
    $issues++
} else {
    Write-Status '[OK]' 'No Software Restriction Policies' 'Green'
}
Write-Host ''

# ============================================================
# SUMMARY
# ============================================================
Write-Host '============================================================' -ForegroundColor Cyan
if ($issues -eq 0) {
    Write-Host '  ALL CHECKS PASSED' -ForegroundColor Green
    if ($fixed -gt 0) { Write-Host "  $fixed issue(s) were auto-fixed." -ForegroundColor Green }
    Write-Host '  If GoCardless is still not working, restart SideKick.' -ForegroundColor Green
} else {
    Write-Host "  $issues issue(s) found" -ForegroundColor Red
    if ($fixed -gt 0) { Write-Host "  $fixed issue(s) were auto-fixed" -ForegroundColor Green }
    Write-Host '  Please send a screenshot of this window to Guy.' -ForegroundColor Yellow
}
Write-Host '============================================================'
