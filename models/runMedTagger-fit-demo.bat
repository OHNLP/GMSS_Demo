@echo off
REM runMedTagger-fit-demo.bat — Windows equivalent of runMedTagger-fit-demo.sh
setlocal

REM ── Resolve script location ──────────────────────────────────────────────────
set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

REM ═══════════════════════════════════════════════════════════════════
REM  CONFIG — edit these paths or pass them as positional arguments:
REM    runMedTagger-fit-demo.bat C:\GMSS\input C:\GMSS\output C:\GMSS\models\AITC
REM ═══════════════════════════════════════════════════════════════════
if not "%~1"=="" (set "INPUT_DIR=%~1")  else (set "INPUT_DIR=C:\Users\sfu3\Desktop\GMSS\input")
if not "%~2"=="" (set "OUTPUT_DIR=%~2") else (set "OUTPUT_DIR=C:\Users\sfu3\Desktop\GMSS\output")
if not "%~3"=="" (set "RULES_DIR=%~3")  else (set "RULES_DIR=C:\Users\sfu3\Desktop\GMSS\models\AITC")

REM ── Pre-flight checks ────────────────────────────────────────────────────────
where java >nul 2>&1
if errorlevel 1 (
    echo [ERROR] 'java' not found on PATH. Please install the JDK and try again.
    exit /b 1
)

if not exist "%INPUT_DIR%" (
    echo [ERROR] Input directory not found: %INPUT_DIR%
    exit /b 1
)

if not exist "%SCRIPT_DIR%\MedTagger-fit-context.jar" (
    echo [ERROR] MedTagger-fit-context.jar not found in: %SCRIPT_DIR%
    exit /b 1
)

REM ── Run ──────────────────────────────────────────────────────────────────────
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

echo Running MedTagger...
echo   Input : %INPUT_DIR%
echo   Output: %OUTPUT_DIR%
echo   Rules : %RULES_DIR%

java -Xms512M -Xmx2000M -jar "%SCRIPT_DIR%\MedTagger-fit-context.jar" ^
     "%INPUT_DIR%" "%OUTPUT_DIR%" "%RULES_DIR%"

if errorlevel 1 (
    echo [ERROR] MedTagger failed.
    exit /b 1
)

echo [OK] MedTagger complete. Output: %OUTPUT_DIR%
endlocal
