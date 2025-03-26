@echo off
title Image at PDF verifier ni Kyle
setlocal EnableDelayedExpansion

echo ===================================
echo Media Integrity Check Launcher
echo Current Time (UTC): 2025-03-26 22:29:53
echo User: NeoMatrix14241
echo ===================================
echo.

:: Check if PowerShell 7 is available
where pwsh >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo Error: PowerShell 7 is not installed or not available in PATH.
    echo Please install PowerShell 7 to run this script.
    echo Download from: https://github.com/PowerShell/PowerShell/releases
    echo.
    pause
    exit /b 1
)

:: Check if the PS1 script exists
if not exist "Check-MediaIntegrity.ps1" (
    echo Error: Check-MediaIntegrity.ps1 not found in the current directory.
    echo Please ensure the script is in the same folder as this batch file.
    echo.
    pause
    exit /b 1
)

:: Check if pdftk is available
where pdftk >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo Error: pdftk is not installed or not available in PATH.
    echo Please install pdftk to run this script.
    echo.
    pause
    exit /b 1
)

:: Ask for the folder to scan
set /p "SCAN_PATH=Enter the folder path to scan (press Enter for current folder): "

:: If no path is entered, use current directory
if "!SCAN_PATH!"=="" set "SCAN_PATH=%CD%"

:: Remove quotes if present
set SCAN_PATH=!SCAN_PATH:"=!

:: Check if the folder exists
if not exist "!SCAN_PATH!\" (
    echo Error: The specified folder does not exist.
    echo Path: !SCAN_PATH!
    echo.
    pause
    exit /b 1
)

:: Ask for maximum parallel jobs
set /p "MAX_JOBS=Enter maximum number of parallel jobs (press Enter for default 3): "

:: If no number is entered, use default
if "!MAX_JOBS!"=="" set "MAX_JOBS=3"

:: Validate input is a number
echo !MAX_JOBS!| findstr /r "^[1-9][0-9]*$" >nul
if %ERRORLEVEL% neq 0 (
    echo Error: Invalid number of parallel jobs. Using default: 3
    set "MAX_JOBS=3"
)

:: Run the PowerShell script with execution policy bypass and the specified path
echo.
echo Starting integrity check in: !SCAN_PATH!
echo Using !MAX_JOBS! parallel jobs
echo.
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File ".\Check-MediaIntegrity.ps1" -ScanPath "!SCAN_PATH!" -MaxParallelJobs !MAX_JOBS!

if %ERRORLEVEL% equ 0 (
    echo.
    echo Script completed successfully.
) else (
    echo.
    echo Script encountered some errors. Please check the log file for details.
)

echo.
echo Press any key to exit...
pause >nul