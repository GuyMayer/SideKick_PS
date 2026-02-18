@echo off
cd /d "C:\Stash\SideKick_PS"
call C:\Stash\.venv\Scripts\activate.bat
powershell -ExecutionPolicy Bypass -File "build_and_archive.ps1" -Version "2.5.26" -ForceRebuild -SkipPublish
pause
