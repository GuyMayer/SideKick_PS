@echo off
setlocal enabledelayedexpansion
title SideKick_PS Settings Recovery
color 0B
echo.
echo ==============================
echo  SideKick_PS Settings Recovery
echo ==============================
echo.
echo Checking for existing INI files...
echo.

set "APPDATA_INI=%APPDATA%\SideKick_PS\SideKick_PS.ini"
set "PROGX86_INI=%ProgramFiles(x86)%\SideKick_PS\SideKick_PS.ini"
set "PROG64_INI=%ProgramFiles%\SideKick_PS\SideKick_PS.ini"
set "FOUND=0"
set "SOURCE_INI="

if exist "%APPDATA_INI%" (
    echo [OK] AppData INI exists: %APPDATA_INI%
    set FOUND=1
    goto CHECK_CONTENT
)

if exist "%PROGX86_INI%" (
    echo [FOUND] Program Files ^(x86^) INI: %PROGX86_INI%
    set FOUND=1
    set "SOURCE_INI=%PROGX86_INI%"
    goto COPY_FILE
)

if exist "%PROG64_INI%" (
    echo [FOUND] Program Files INI: %PROG64_INI%
    set FOUND=1
    set "SOURCE_INI=%PROG64_INI%"
    goto COPY_FILE
)

if !FOUND!==0 (
    echo.
    echo [NOT FOUND] No INI files found in any location
    echo.
    color 0C
    echo Unfortunately, no settings backup was found.
    echo You will need to re-enter your GHL credentials in Settings ^> GHL Integration.
    echo.
    pause
    exit /b
)

:CHECK_CONTENT
echo.
echo Checking INI file contents...
findstr /C:"LocationID=" "%APPDATA_INI%" >nul 2>&1
if !errorlevel!==0 (
    echo   [OK] GHL Location ID: Found
    set HAS_GHL=1
) else (
    echo   [MISSING] GHL Location ID: Not configured
    set HAS_GHL=0
)

findstr /C:"Token=" "%APPDATA_INI%" >nul 2>&1
if !errorlevel!==0 (
    echo   [OK] License Token: Found
) else (
    echo   [MISSING] License Token: Not configured
)

for %%A in ("%APPDATA_INI%") do set SIZE=%%~zA
if !SIZE! LSS 50 (
    echo.
    color 0E
    echo WARNING: INI file appears to be empty or nearly empty!
    echo File size: !SIZE! bytes
    
    if exist "%PROGX86_INI%" (
        echo.
        echo Found backup in Program Files. Restoring...
        copy /Y "%PROGX86_INI%" "%APPDATA_INI%" >nul
        color 0A
        echo Restored from: %PROGX86_INI%
        echo.
        echo SUCCESS! Please restart SideKick_PS.
    ) else if exist "%PROG64_INI%" (
        echo.
        echo Found backup in Program Files. Restoring...
        copy /Y "%PROG64_INI%" "%APPDATA_INI%" >nul
        color 0A
        echo Restored from: %PROG64_INI%
        echo.
        echo SUCCESS! Please restart SideKick_PS.
    ) else (
        color 0C
        echo.
        echo No backup found in Program Files.
        echo You will need to re-enter your settings in the app.
    )
) else if !HAS_GHL!==0 (
    color 0E
    echo.
    echo Your INI file exists but GHL is not configured.
    echo Please set up GHL in Settings ^> GHL Integration.
) else (
    color 0A
    echo.
    echo Your settings appear to be complete!
    echo If the app still shows missing settings, please restart SideKick_PS.
)
echo.
pause
exit /b

:COPY_FILE
echo.
echo Found settings in old location. Copying to new location...

if not exist "%APPDATA%\SideKick_PS\" (
    mkdir "%APPDATA%\SideKick_PS"
    echo   Created folder: %APPDATA%\SideKick_PS
)

copy /Y "%SOURCE_INI%" "%APPDATA_INI%" >nul
if !errorlevel!==0 (
    color 0A
    echo.
    echo SUCCESS! Settings recovered.
    echo   From: %SOURCE_INI%
    echo   To:   %APPDATA_INI%
    echo.
    echo Please restart SideKick_PS to load your settings.
) else (
    color 0C
    echo.
    echo ERROR: Failed to copy settings file.
)

echo.
pause
