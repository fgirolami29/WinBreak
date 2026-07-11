@echo off
setlocal

powershell.exe ^
  -NoLogo ^
  -NoProfile ^
  -ExecutionPolicy Bypass ^
  -File "%~dp0WinBreak.ps1" %*

set "WINBREAK_EXIT_CODE=%ERRORLEVEL%"

echo.
echo WinBreak terminato con exit code %WINBREAK_EXIT_CODE%.
pause

exit /b %WINBREAK_EXIT_CODE%
