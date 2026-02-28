@echo off
title SideKick GoCardless Diagnostics
color 0A

set "OUTFILE=%USERPROFILE%\Desktop\gc_diagnostic_results.txt"

echo ============================================================
echo   SideKick GoCardless Diagnostics
echo   %date% %time%
echo ============================================================
echo.
echo Please wait, running tests...
echo.

powershell -ExecutionPolicy Bypass -Command ^
 "$out = @(); " ^
 "$SK = 'C:\Program Files (x86)\SideKick_PS'; " ^
 "$GCA = Join-Path $SK '_gca.exe'; " ^
 "$SPS = Join-Path $SK '_sps.exe'; " ^
 "$INI1 = Join-Path $env:APPDATA 'SideKick_PS\SideKick_PS.ini'; " ^
 "$INI2 = Join-Path $SK 'SideKick_PS.ini'; " ^
 "$LOGDIR = Join-Path $env:APPDATA 'SideKick_PS\Logs'; " ^
 "" ^
 "$out += '============================================================'; " ^
 "$out += '  SideKick GoCardless Diagnostics'; " ^
 "$out += '  Date: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'); " ^
 "$out += '  Computer: ' + $env:COMPUTERNAME; " ^
 "$out += '  User: ' + $env:USERNAME; " ^
 "$out += '============================================================'; " ^
 "$out += ''; " ^
 "" ^
 "$out += '--- 1. SYSTEM INFO ---'; " ^
 "$out += 'OS: ' + (Get-CimInstance Win32_OperatingSystem).Caption; " ^
 "$out += 'Build: ' + [Environment]::OSVersion.Version.ToString(); " ^
 "$out += 'Arch: ' + $env:PROCESSOR_ARCHITECTURE; " ^
 "$out += ''; " ^
 "" ^
 "$out += '--- 2. CHECK SIDEKICK FILES ---'; " ^
 "if (Test-Path $SK) { " ^
 "  $out += '  [OK] SideKick folder exists'; " ^
 "  $exes = Get-ChildItem $SK -Filter '_*.exe' -ErrorAction SilentlyContinue; " ^
 "  foreach ($e in $exes) { $out += '  EXE: ' + $e.Name + ' (' + [math]::Round($e.Length/1KB) + ' KB, ' + $e.LastWriteTime + ')' } " ^
 "  if (Test-Path $GCA) { $out += '  [OK] _gca.exe FOUND' } else { $out += '  [FAIL] _gca.exe NOT FOUND!' } " ^
 "  if (Test-Path $SPS) { $out += '  [OK] _sps.exe FOUND' } else { $out += '  [WARN] _sps.exe not found' } " ^
 "} else { $out += '  [FAIL] SideKick folder NOT FOUND' }; " ^
 "$out += ''; " ^
 "" ^
 "$out += '--- 3. CHECK INI FILE ---'; " ^
 "$iniPath = ''; " ^
 "if (Test-Path $INI1) { $iniPath = $INI1 } elseif (Test-Path $INI2) { $iniPath = $INI2 }; " ^
 "if ($iniPath) { " ^
 "  $out += '  [OK] INI: ' + $iniPath; " ^
 "  $iniContent = Get-Content $iniPath -Raw; " ^
 "  if ($iniContent -match '(?m)^Token=(.{0,10})') { $out += '  Token starts with: ' + $Matches[1] + '...' } else { $out += '  [WARN] No Token= line found' }; " ^
 "  if ($iniContent -match '(?m)^Environment=(.+)') { $out += '  Environment: ' + $Matches[1].Trim() }; " ^
 "  if ($iniContent -match '(?m)^DebugLogging=(.+)') { $out += '  DebugLogging: ' + $Matches[1].Trim() }; " ^
 "} else { $out += '  [FAIL] No INI file found!' }; " ^
 "$out += ''; " ^
 "" ^
 "$out += '--- 4. CHECK ANTIVIRUS ---'; " ^
 "try { " ^
 "  $av = Get-CimInstance -Namespace 'root/SecurityCenter2' -ClassName AntiVirusProduct -ErrorAction Stop; " ^
 "  foreach ($a in $av) { $out += '  AV: ' + $a.displayName } " ^
 "} catch { $out += '  Could not query AV products' }; " ^
 "try { " ^
 "  $excl = (Get-MpPreference).ExclusionPath; " ^
 "  if ($excl) { foreach ($e in $excl) { $out += '  Defender Exclusion: ' + $e } } else { $out += '  No Defender exclusions set' } " ^
 "} catch { $out += '  Could not read Defender exclusions (need admin)' }; " ^
 "try { " ^
 "  $threats = Get-MpThreatDetection -ErrorAction Stop | Select-Object -First 5; " ^
 "  if ($threats) { foreach ($t in $threats) { $out += '  Threat: ' + $t.ProcessName + ' at ' + $t.InitialDetectionTime } } else { $out += '  No recent Defender threats' } " ^
 "} catch { $out += '  Could not read threat history' }; " ^
 "$out += ''; " ^
 "" ^
 "$out += '--- 5. TEST _gca.exe DIRECTLY ---'; " ^
 "if (Test-Path $GCA) { " ^
 "  $out += '  Running: _gca.exe --test-connection --live'; " ^
 "  try { " ^
 "    $proc = Start-Process -FilePath $GCA -ArgumentList '--test-connection','--live' -Wait -NoNewWindow -PassThru -RedirectStandardOutput (Join-Path $env:TEMP 'gc_diag_stdout.txt') -RedirectStandardError (Join-Path $env:TEMP 'gc_diag_stderr.txt') -ErrorAction Stop; " ^
 "    $out += '  Exit code: ' + $proc.ExitCode; " ^
 "    $stdout = Get-Content (Join-Path $env:TEMP 'gc_diag_stdout.txt') -Raw -ErrorAction SilentlyContinue; " ^
 "    $stderr = Get-Content (Join-Path $env:TEMP 'gc_diag_stderr.txt') -Raw -ErrorAction SilentlyContinue; " ^
 "    if ($stdout) { $out += '  STDOUT: ' + $stdout.Trim() } else { $out += '  [FAIL] STDOUT is EMPTY!' }; " ^
 "    if ($stderr) { $out += '  STDERR: ' + $stderr.Trim() }; " ^
 "  } catch { $out += '  [FAIL] Could not run _gca.exe: ' + $_.Exception.Message }; " ^
 "} else { $out += '  [SKIP] _gca.exe not found' }; " ^
 "$out += ''; " ^
 "" ^
 "$out += '--- 6. PyInstaller TEMP CHECK ---'; " ^
 "$mei = Get-ChildItem $env:TEMP -Directory -Filter '_MEI*' -ErrorAction SilentlyContinue; " ^
 "if ($mei) { foreach ($m in $mei) { $out += '  _MEI folder: ' + $m.Name + ' (' + $m.CreationTime + ')' } } else { $out += '  [WARN] No _MEI folders - PyInstaller not extracting!' }; " ^
 "$testFile = Join-Path $env:TEMP 'gc_perm_test.tmp'; " ^
 "try { 'test' | Set-Content $testFile -ErrorAction Stop; Remove-Item $testFile; $out += '  [OK] Can write to TEMP' } catch { $out += '  [FAIL] Cannot write to TEMP!' }; " ^
 "$out += ''; " ^
 "" ^
 "$out += '--- 7. NETWORK / API ---'; " ^
 "try { " ^
 "  $dns = Resolve-DnsName api.gocardless.com -ErrorAction Stop; " ^
 "  $out += '  [OK] DNS resolves: ' + ($dns | Where-Object { $_.QueryType -eq 'A' } | Select-Object -First 1).IPAddress; " ^
 "} catch { $out += '  [FAIL] DNS resolution failed: ' + $_.Exception.Message }; " ^
 "try { " ^
 "  $r = Invoke-WebRequest -Uri 'https://api.gocardless.com/health_check' -UseBasicParsing -TimeoutSec 10; " ^
 "  $out += '  [OK] API health: ' + $r.Content; " ^
 "} catch { $out += '  [FAIL] API connection: ' + $_.Exception.Message }; " ^
 "$out += ''; " ^
 "" ^
 "$out += '--- 8. PROCESS BLOCKS ---'; " ^
 "try { " ^
 "  $alp = Get-AppLockerPolicy -Effective -ErrorAction Stop; " ^
 "  $out += '  AppLocker: ' + ($alp.RuleCollections.Count) + ' rule collections'; " ^
 "} catch { $out += '  No AppLocker policies' }; " ^
 "$srp = Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Safer\CodeIdentifiers' -ErrorAction SilentlyContinue; " ^
 "if ($srp) { $out += '  [WARN] Software Restriction Policies found!' } else { $out += '  No Software Restriction Policies' }; " ^
 "$out += ''; " ^
 "" ^
 "$out += '--- 9. LOG FOLDER ---'; " ^
 "if (Test-Path $LOGDIR) { " ^
 "  $out += '  [OK] Log folder: ' + $LOGDIR; " ^
 "  $gcerr = Get-ChildItem $LOGDIR -Filter 'gc_error_*' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending; " ^
 "  $gcdbg = Get-ChildItem $LOGDIR -Filter 'gc_debug_*' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending; " ^
 "  if ($gcerr) { foreach ($f in $gcerr | Select-Object -First 3) { $out += '  gc_error: ' + $f.Name + ' (' + $f.LastWriteTime + ')' }; $out += '  --- Last 30 lines of newest error log ---'; $out += (Get-Content $gcerr[0].FullName -Tail 30 | Out-String) } else { $out += '  No gc_error logs' }; " ^
 "  if ($gcdbg) { foreach ($f in $gcdbg | Select-Object -First 3) { $out += '  gc_debug: ' + $f.Name + ' (' + $f.LastWriteTime + ')' } } else { $out += '  No gc_debug logs' }; " ^
 "} else { $out += '  [WARN] Log folder missing: ' + $LOGDIR }; " ^
 "$out += ''; " ^
 "" ^
 "$out += '--- 10. RUNTIME CHECK ---'; " ^
 "$pyPath = Get-Command python -ErrorAction SilentlyContinue; " ^
 "if ($pyPath) { $out += '  Python: ' + $pyPath.Source } else { $out += '  Python not in PATH (normal)' }; " ^
 "$vcx64 = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64' -ErrorAction SilentlyContinue; " ^
 "$vcx86 = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x86' -ErrorAction SilentlyContinue; " ^
 "if ($vcx64) { $out += '  [OK] VC++ x64: ' + $vcx64.Version } else { $out += '  [WARN] VC++ x64 not found' }; " ^
 "if ($vcx86) { $out += '  [OK] VC++ x86: ' + $vcx86.Version } else { $out += '  [WARN] VC++ x86 not found' }; " ^
 "$out += ''; " ^
 "" ^
 "$out += '============================================================'; " ^
 "$out += '  DIAGNOSTICS COMPLETE'; " ^
 "$out += '============================================================'; " ^
 "" ^
 "$outFile = Join-Path ([Environment]::GetFolderPath('Desktop')) 'gc_diagnostic_results.txt'; " ^
 "$out | Out-File $outFile -Encoding UTF8; " ^
 "$out | ForEach-Object { Write-Host $_ }; " ^
 "Write-Host ''; " ^
 "Write-Host 'Results saved to:' $outFile; " ^
 "Write-Host 'Please send this file to Guy.'; "

echo.
echo ============================================================
echo   Done! Check your Desktop for gc_diagnostic_results.txt
echo   Please send that file to Guy.
echo ============================================================
echo.
pause
