@echo off
rem Via Studios Kit - install or update this PC (new PC, or the Update button did not finish). Double-click; say Yes to Windows.
title Via Studios Kit - install / update
net session >nul 2>&1 || (powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs" & exit /b)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol='Tls12'; $s = Invoke-RestMethod -UseBasicParsing ('https://raw.githubusercontent.com/waelsamiry/via-kit-releases/main/install.ps1?t=' + [DateTime]::Now.Ticks); Invoke-Expression $s"
pause
