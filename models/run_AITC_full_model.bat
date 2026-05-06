@echo off
REM run_model.bat — AIDE4HF pipeline launcher for Windows
REM Usage: run_model.bat [IN_DIR] [OUT_DIR] [RULES_DIR]
REM   All three arguments are optional; they override the defaults below.
setlocal EnableDelayedExpansion

REM ── Resolve script location ──────────────────────────────────────────────────
set "SCRIPT_DIR=%~dp0"
REM Remove trailing backslash
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

REM ═══════════════════════════════════════════════════════════════════
REM  CONFIG — edit these defaults or pass them as positional arguments:
REM    run_model.bat C:\GMSS\input C:\GMSS\output C:\GMSS\models\AITC
REM ═══════════════════════════════════════════════════════════════════
if not "%~1"=="" (set "IN_DIR=%~1") else (set "IN_DIR=C:\Users\sfu3\Desktop\GMSS\input")
if not "%~2"=="" (set "OUT_DIR=%~2") else (set "OUT_DIR=C:\Users\sfu3\Desktop\GMSS\output")
if not "%~3"=="" (set "RULES_DIR=%~3") else (set "RULES_DIR=C:\Users\sfu3\Desktop\GMSS\models\AITC")

REM Windows classpath uses semicolons, not colons
set "CLASSPATH=%SCRIPT_DIR%\resources;%SCRIPT_DIR%\MedXN-2\MedXN.jar"
set "COMBINED=%OUT_DIR%\_combined.out"
set "LOG=%OUT_DIR%\pipeline.log"
set "CONVERTER=%SCRIPT_DIR%\convert_xml.py"

REM ── Pre-flight checks ────────────────────────────────────────────────────────
where java >nul 2>&1
if errorlevel 1 (
    echo [ERROR] 'java' not found on PATH. Please install the JDK and try again.
    exit /b 1
)

where python >nul 2>&1
if errorlevel 1 (
    echo [ERROR] 'python' not found on PATH. Please install Python 3 and try again.
    exit /b 1
)

if not exist "%CONVERTER%" (
    echo [ERROR] convert_xml.py not found at: %CONVERTER%
    exit /b 1
)

if not exist "%IN_DIR%" (
    echo [ERROR] Input directory not found: %IN_DIR%
    exit /b 1
)

REM ── Setup ────────────────────────────────────────────────────────────────────
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

REM Rotate previous log
if exist "%LOG%" move /y "%LOG%" "%OUT_DIR%\pipeline_prev.log" >nul

REM Remove previous outputs (del /f is silent on no-match, unlike bash rm -f)
del /f /q "%OUT_DIR%\*.xml" >nul 2>&1
if exist "%COMBINED%" del /f /q "%COMBINED%"

echo ================================================
echo   AIDE4HF Pipeline
echo   IN   : %IN_DIR%
echo   OUT  : %OUT_DIR%
echo   Rules: %RULES_DIR%
echo ================================================

REM ── Step 1: MedTagger ────────────────────────────────────────────────────────
echo [1/3] Running MedTagger...
java -Xms512M -Xmx2000M -jar "%SCRIPT_DIR%\MedTagger-fit-context.jar" ^
     "%IN_DIR%" "%OUT_DIR%" "%RULES_DIR%" >>"%LOG%" 2>&1
if errorlevel 1 (
    echo [ERROR] MedTagger failed -- check %LOG%
    exit /b 1
)
echo       MedTagger done.

REM ── Step 2: MedXN ────────────────────────────────────────────────────────────
echo [2/3] Running MedXN...
java -cp "%CLASSPATH%" org.ohnlp.medxn.Main ^
     "%IN_DIR%" "%COMBINED%" >>"%LOG%" 2>&1
if errorlevel 1 (
    echo [ERROR] MedXN failed -- check %LOG%
    exit /b 1
)

if not exist "%COMBINED%" (
    echo [ERROR] MedXN produced no output file -- check %LOG%
    exit /b 1
)

REM Check file is non-empty (Windows has no -s test)
for %%A in ("%COMBINED%") do if %%~zA==0 (
    echo [ERROR] MedXN output is empty -- check %LOG%
    exit /b 1
)
echo       MedXN done.

REM ── Step 3: Convert to XML ───────────────────────────────────────────────────
echo [3/3] Converting to XML...
python "%CONVERTER%" ^
    --in-dir   "%IN_DIR%"   ^
    --out-dir  "%OUT_DIR%"  ^
    --combined "%COMBINED%" 2>&1 | tee "%LOG%"
if errorlevel 1 (
    echo [ERROR] XML conversion failed -- check %LOG%
    exit /b 1
)

echo ================================================
echo [OK] Pipeline complete. Output: %OUT_DIR%
echo ================================================
endlocal
