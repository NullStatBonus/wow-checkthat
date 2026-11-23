@echo off
rem Double-click this on the Windows PC that runs WoW. It copies the CheckThat and addon saved variables
rem (and screenshots) into evidence-src\ in the repository folder. Then run the collect and report step on the Mac:
rem   .venv/bin/python tools/ct.py collect --src evidence-src
rem   .venv/bin/python tools/ct.py report
rem Log out of WoW or type /reload first: the game writes saved variables only then.
setlocal
rem pushd maps a UNC (network) path to a temporary drive letter, so cmd.exe can run from it.
pushd "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Copy-CheckThatEvidence.ps1"
set "result=%errorlevel%"
popd
pause
exit /b %result%
