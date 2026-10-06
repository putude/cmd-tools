@echo off
setlocal EnableExtensions
title Lab Maintenance - Windows 10/11

:: ==========================================================
::  KONFIG - ubah 1 (aktif) / 0 (nonaktif)
:: ==========================================================
set BG_COLOR=0 99 177
set DO_WALLPAPER=1
set DO_CLEAN=1
set DO_BROWSER_CACHE=1
set KILL_BROWSERS=1
set DO_POWER=1
set DO_VISUAL=1
set DO_SERVICES=1
set DIS_SYSMAIN=1
set DIS_WSEARCH=0
set DIS_DIAGTRACK=1
set DO_TWEAKS=1
set DO_TIMESYNC=1
:: Task lambat (default mati)
set DO_SLOW_DISM=0
set DO_SLOW_SFC=0
set DO_SLOW_DEFRAG=0
set CLEAR_EVENTLOGS=0
set AUTO_REBOOT=0
:: ==========================================================

:: ---- Cek admin, kalau belum auto-elevate ----
net session >nul 2>&1
if errorlevel 1 (
    echo Meminta hak Administrator...
    powershell -nop -c "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: ---- Log ----
set LOGDIR=%~dp0logs
if not exist "%LOGDIR%" mkdir "%LOGDIR%"
for /f %%i in ('powershell -nop -c "Get-Date -Format yyyyMMdd_HHmm"') do set TS=%%i
set LOG=%LOGDIR%\%COMPUTERNAME%_%TS%.log

:: ---- Deteksi OS ----
for /f %%b in ('powershell -nop -c "[Environment]::OSVersion.Version.Build"') do set BUILD=%%b
set OSNAME=Windows 10
if %BUILD% GEQ 22000 set OSNAME=Windows 11

call :log "=== Maintenance %COMPUTERNAME% - %OSNAME% build %BUILD% ==="
for /f %%f in ('powershell -nop -c "[math]::Round((Get-PSDrive C).Free/1MB)"') do set FREE_BEFORE=%%f

if "%DO_WALLPAPER%"=="1" call :reg_users
if "%DO_VISUAL%"=="1"    call :reg_users
if "%DO_POWER%"=="1"     call :power
if "%DO_CLEAN%"=="1"     call :clean
if "%DO_SERVICES%"=="1"  call :services
if "%DO_TWEAKS%"=="1"    call :tweaks
if "%DO_TIMESYNC%"=="1"  call :timesync
if "%CLEAR_EVENTLOGS%"=="1" call :eventlogs
if "%DO_SLOW_DISM%"=="1"   call :dism
if "%DO_SLOW_SFC%"=="1"    call :sfc
if "%DO_SLOW_DEFRAG%"=="1" call :defrag

for /f %%f in ('powershell -nop -c "[math]::Round((Get-PSDrive C).Free/1MB)"') do set FREE_AFTER=%%f
set /a FREED=FREE_AFTER-FREE_BEFORE
call :log "Ruang C: kosong sekarang %FREE_AFTER% MB, bertambah sekitar %FREED% MB"
call :log "Selesai. Log: %LOG%"

if "%AUTO_REBOOT%"=="1" (
    shutdown /r /t 30 /c "Maintenance selesai, restart..."
) else (
    choice /c YN /m "Restart sekarang (disarankan)"
    if not errorlevel 2 shutdown /r /t 5
)
exit /b

:: ==========================================================
::  PER-USER REGISTRY (semua user yang sedang login + profil Default)
:: ==========================================================
:reg_users
if defined REG_USERS_DONE exit /b
set REG_USERS_DONE=1
call :log "Terapkan setting per-user (desktop, visual effects, screensaver)"
for /f %%s in ('reg query HKU ^| findstr /r /c:"S-1-5-21-[0-9-]*$"') do call :applyuser "%%s"
reg load HKU\DefTmp "%SystemDrive%\Users\Default\NTUSER.DAT" >nul 2>&1
if not errorlevel 1 (
    call :applyuser "HKU\DefTmp"
    reg unload HKU\DefTmp >nul 2>&1
)
:: refresh sesi admin saat ini (user lain perlu logoff/login)
RUNDLL32.EXE user32.dll,UpdatePerUserSystemParameters 1, True
exit /b

:applyuser
if "%DO_WALLPAPER%"=="1" (
    reg add "%~1\Control Panel\Desktop" /v Wallpaper /t REG_SZ /d "" /f >nul
    reg add "%~1\Control Panel\Colors" /v Background /t REG_SZ /d "%BG_COLOR%" /f >nul
    reg add "%~1\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers" /v BackgroundType /t REG_DWORD /d 1 /f >nul
    reg add "%~1\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v EnableSnapAssistFlyout /t REG_DWORD /d 0 /f >nul
)
if "%DO_VISUAL%"=="1" (
    reg add "%~1\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f >nul
    reg add "%~1\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 0 /f >nul
    reg add "%~1\Control Panel\Desktop" /v UserPreferencesMask /t REG_BINARY /d 9012038010000000 /f >nul
    reg add "%~1\Control Panel\Desktop" /v FontSmoothing /t REG_SZ /d 2 /f >nul
    reg add "%~1\Control Panel\Desktop\WindowMetrics" /v MinAnimate /t REG_SZ /d 0 /f >nul
    reg add "%~1\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAnimations /t REG_DWORD /d 0 /f >nul
    reg add "%~1\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ListviewAlphaSelect /t REG_DWORD /d 0 /f >nul
    reg add "%~1\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ListviewShadow /t REG_DWORD /d 0 /f >nul
)
if "%DO_POWER%"=="1" (
    reg add "%~1\Control Panel\Desktop" /v ScreenSaveActive /t REG_SZ /d 0 /f >nul
)
if "%DO_TWEAKS%"=="1" (
    reg add "%~1\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 0 /f >nul
    reg add "%~1\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SilentInstalledAppsEnabled /t REG_DWORD /d 0 /f >nul
    reg add "%~1\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SoftLandingEnabled /t REG_DWORD /d 0 /f >nul
    reg add "%~1\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /t REG_DWORD /d 1 /f >nul
    reg add "%~1\System\GameConfigStore" /v GameDVR_Enabled /t REG_DWORD /d 0 /f >nul
)
exit /b

:: ==========================================================
::  POWER
:: ==========================================================
:power
call :log "Power plan: High Performance, sleep/monitor/disk = never"
powercfg /list | find /i "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" >nul
if errorlevel 1 powercfg -duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c >nul 2>&1
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

powercfg /change monitor-timeout-ac 0
powercfg /change monitor-timeout-dc 0
powercfg /change standby-timeout-ac 0
powercfg /change standby-timeout-dc 0
powercfg /change disk-timeout-ac 0
powercfg /change disk-timeout-dc 0
powercfg /change hibernate-timeout-ac 0
powercfg /change hibernate-timeout-dc 0

:: CPU min/max 100%
powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100
powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100
powercfg /setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100
powercfg /setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100
:: USB selective suspend off
powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setactive SCHEME_CURRENT

:: Hibernate + Fast Startup off (shutdown jadi bersih, hiberfil.sys hilang)
powercfg -h off
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f >nul
exit /b

:: ==========================================================
::  CLEAN CACHE
:: ==========================================================
:clean
call :log "Bersihkan cache dan file temp"
if "%KILL_BROWSERS%"=="1" (
    taskkill /f /im chrome.exe >nul 2>&1
    taskkill /f /im msedge.exe >nul 2>&1
    taskkill /f /im firefox.exe >nul 2>&1
)

:: Windows Update download cache
net stop wuauserv >nul 2>&1
net stop bits >nul 2>&1
net stop dosvc >nul 2>&1
call :cleandir "%SystemRoot%\SoftwareDistribution\Download"
call :cleandir "%SystemRoot%\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache"
net start bits >nul 2>&1
net start wuauserv >nul 2>&1

:: System
call :cleandir "%SystemRoot%\Temp"
call :cleandir "%SystemRoot%\Minidump"
call :cleandir "%ProgramData%\Microsoft\Windows\WER\ReportQueue"
call :cleandir "%ProgramData%\Microsoft\Windows\WER\ReportArchive"
del /f /q "%SystemRoot%\MEMORY.DMP" >nul 2>&1

:: Semua profil user
for /d %%u in ("%SystemDrive%\Users\*") do call :cleanuser "%%~fu"

:: Recycle Bin semua drive (Windows buat ulang otomatis)
for %%d in (C D E F) do if exist "%%d:\$Recycle.Bin" rd /s /q "%%d:\$Recycle.Bin" >nul 2>&1

ipconfig /flushdns >nul
exit /b

:cleanuser
call :cleandir "%~1\AppData\Local\Temp"
call :cleandir "%~1\AppData\Local\Microsoft\Windows\INetCache"
call :cleandir "%~1\AppData\Local\CrashDumps"
call :cleandir "%~1\AppData\Local\D3DSCache"
del /f /q "%~1\AppData\Local\Microsoft\Windows\Explorer\thumbcache_*.db" >nul 2>&1
del /f /q "%~1\AppData\Local\Microsoft\Windows\Explorer\iconcache_*.db" >nul 2>&1
if not "%DO_BROWSER_CACHE%"=="1" exit /b
for /d %%p in ("%~1\AppData\Local\Google\Chrome\User Data\*") do (
    call :cleandir "%%~fp\Cache"
    call :cleandir "%%~fp\Code Cache"
    call :cleandir "%%~fp\GPUCache"
)
for /d %%p in ("%~1\AppData\Local\Microsoft\Edge\User Data\*") do (
    call :cleandir "%%~fp\Cache"
    call :cleandir "%%~fp\Code Cache"
    call :cleandir "%%~fp\GPUCache"
)
for /d %%p in ("%~1\AppData\Local\Mozilla\Firefox\Profiles\*") do (
    call :cleandir "%%~fp\cache2"
)
exit /b

:cleandir
if not exist "%~1" exit /b
del /f /s /q "%~1\*" >nul 2>&1
for /d %%d in ("%~1\*") do rd /s /q "%%d" >nul 2>&1
exit /b

:: ==========================================================
::  SERVICES
:: ==========================================================
:services
call :log "Atur services"
if "%DIS_SYSMAIN%"=="1" (
    sc stop SysMain >nul 2>&1
    sc config SysMain start= disabled >nul 2>&1
)
if "%DIS_WSEARCH%"=="1" (
    sc stop WSearch >nul 2>&1
    sc config WSearch start= disabled >nul 2>&1
)
if "%DIS_DIAGTRACK%"=="1" (
    sc stop DiagTrack >nul 2>&1
    sc config DiagTrack start= disabled >nul 2>&1
    sc stop dmwappushservice >nul 2>&1
    sc config dmwappushservice start= disabled >nul 2>&1
)
exit /b

:: ==========================================================
::  TWEAKS (HKLM / policy)
:: ==========================================================
:tweaks
call :log "Tweak policy (consumer features, widgets/news, game DVR, telemetry)"
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR /t REG_DWORD /d 0 /f >nul
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f >nul
if %BUILD% GEQ 22000 (
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /v AllowNewsAndInterests /t REG_DWORD /d 0 /f >nul
) else (
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" /v EnableFeeds /t REG_DWORD /d 0 /f >nul
)
exit /b

:timesync
call :log "Sinkronisasi waktu"
net start w32time >nul 2>&1
w32tm /resync /force >nul 2>&1
exit /b

:eventlogs
call :log "Hapus Event Logs"
for /f "tokens=*" %%g in ('wevtutil el') do wevtutil cl "%%g" >nul 2>&1
exit /b

:: ==========================================================
::  TASK LAMBAT
:: ==========================================================
:dism
call :log "DISM component cleanup (lama)"
dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase
exit /b

:sfc
call :log "SFC scan (lama)"
sfc /scannow
exit /b

:defrag
call :log "Optimize drive C (TRIM untuk SSD, defrag untuk HDD)"
defrag C: /O
exit /b

:log
echo [%time:~0,8%] %~1
>>"%LOG%" echo [%time:~0,8%] %~1
exit /b
