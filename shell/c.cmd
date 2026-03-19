@echo off
setlocal enabledelayedexpansion

if /i "%~1"=="--help" goto help
if /i "%~1"=="-h" goto help
if /i "%~1"=="/?" goto help

set "test_mode=0"
if /i "%~1"=="--test" set "test_mode=1" & shift

set "flags=%~1"
set "resume_id=%~2"
set "args=claude --dangerously-skip-permissions"
set "has_model=0"
set "has_effort=0"
set "has_resume=0"

if "!flags!"=="" goto defaults
set "i=0"
:loop
if "!flags:~%i%,1!"=="" goto defaults
set "ch=!flags:~%i%,1!"
if /i "!ch!"=="o" set "args=!args! --model opus" & set "has_model=1" & goto next
if /i "!ch!"=="s" set "args=!args! --model sonnet" & set "has_model=1" & goto next
if /i "!ch!"=="h" set "args=!args! --model haiku" & set "has_model=1" & goto next
if /i "!ch!"=="p" set "args=!args! --model opus --permission-mode plan" & set "has_model=1" & goto next
if /i "!ch!"=="i" set "args=!args! --ide" & goto next
if "!ch!"=="1" set "args=!args! --effort low" & set "has_effort=1" & goto next
if "!ch!"=="2" set "args=!args! --effort medium" & set "has_effort=1" & goto next
if "!ch!"=="3" set "args=!args! --effort high" & set "has_effort=1" & goto next
if /i "!ch!"=="c" set "args=!args! --continue" & goto next
if /i "!ch!"=="f" set "args=!args! --fork" & goto next
if /i "!ch!"=="r" set "has_resume=1" & goto next
:next
set /a i+=1
goto loop

:defaults
if "!has_model!"=="0" set "args=!args! --model opus"
if "!has_effort!"=="0" set "args=!args! --effort medium"
if "!has_resume!"=="1" (
    if not "!resume_id!"=="" (
        set "args=!args! --resume !resume_id!"
    ) else (
        set "args=!args! --resume"
    )
)

if "!test_mode!"=="1" goto testecho
!args!
goto :eof

:testecho
echo !args!
goto :eof

:help
echo Usage: c [flags] [session-id]
echo.
echo Flags (combine in any order, no spaces):
echo   o  model opus (default)
echo   s  model sonnet
echo   h  model haiku
echo   p  model opus + plan mode
echo   i  ide
echo   1  effort low
echo   2  effort medium (default)
echo   3  effort high
echo   c  continue
echo   f  fork
echo   r  resume (session-id as next arg, or picker if omitted)
echo.
echo Examples:
echo   c           opus, medium
echo   c si3c      sonnet, ide, high, continue
echo   c r abc123  opus, medium, resume abc123
goto :eof
