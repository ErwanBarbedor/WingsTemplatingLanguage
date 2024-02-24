@echo off
setlocal enabledelayedexpansion

rem Vérification des droits Administrateur
net session >nul 2>&1
if NOT %errorlevel% == 0 (
    echo This script must be run as admin.
    exit /b 1
)

set DESTINATION=%APPDATA%\WingsTemplatingLanguage
set INTERPRETER=lua
set WINGS_FILE=wings.lua
set WINGS_SCRIPT_PATH=%DESTINATION%\wings.cmd

set SCRIPT_DIR=%~dp0

:parse_args
if "%~1"==""          goto verify
if /i "%~1"=="-h"     goto help
if /i "%~1"=="--help" goto help
if /i "%~1"=="-p" (
  set "DESTINATION=%~2"
  shift
) else if /i "%~1"=="-i" (
  set "INTERPRETER=%~2"
  shift
)
shift
goto parse_args

:help
echo Help:
echo    -h, --help       : Show this help message and exit.
echo    -p DESTINATION   : Set the install location (default, %%).
echo    -i INTERPRETER   : Set the lua interpreter name/path (default:  %DEFAULT_INTERPRETER%).
goto end

:verify
where %INTERPRETER% >nul 2>&1
if not "%ERRORLEVEL%"=="0" (
  echo Cannont found %INTERPRETER% interpreter. Be sure that lua is in your path and/or the path provided is correct.
  goto end
)

REM create dir and copy files
if not exist "%DESTINATION%" mkdir "%DESTINATION%"
copy "%SCRIPT_DIR%\%WINGS_FILE%" "%DESTINATION%\%WINGS_FILE%"

IF EXIST "%WINGS_SCRIPT_PATH%" DEL /F "%WINGS_SCRIPT_PATH%"
echo @echo off >> "%WINGS_SCRIPT_PATH%"
echo %INTERPRETER% "%DESTINATION%\%WINGS_FILE%" %%* >> "%WINGS_SCRIPT_PATH%"

REM update path
SET Key="HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
FOR /F "usebackq tokens=2*" %%A IN (`REG QUERY %Key% /v PATH`) DO Set CurrPath=%%B
ECHO %CurrPath% > system_path_bak.txt
SETX PATH "%CurrPath%;%DESTINATION%" /M
DEL /F system_path_bak.txt
:end
endlocal