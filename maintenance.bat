@echo off
:: ==========================================================
::  Simpan file ini sebagai ANSI / Windows-1252 (BUKAN UTF-8 BOM)
::  agar batch tidak error di baris pertama.
:: ==========================================================
setlocal EnableExtensions
title Lab Maintenance - Windows 10/11

:: ==========================================================
::  KONFIG - ubah 1 (aktif) / 0 (nonaktif)
:: ==========================================================
set "BG_COLOR=0 99 177"
set "DO_WALLPAPER=1"
set "DO_CLEAN=1"
set "DO_BROWSER_CACHE=1"
set "KILL_BROWSERS=1"
set "DO_POWER=1"
set "DO_VISUAL=1"
set "DO_SERVICES=1"
set "DIS_SYSMAIN=1"
set "DIS_WSEARCH=0"
set "DIS_DIAGTRACK=1"
set "DO_TWEAKS=1"
set "DO_TIMESYNC=1"

:: Task lambat (default mati)
set "DO_SLOW_DISM=0"
set "DO_SLOW_SFC=0"
set "DO_SLOW_DEFRAG=0"
set "CLEAR_EVENTLOGS=0"

:: Restart otomatis? 1 = restart, 0 = tidak (unattended friendly)
set "AUTO_REBOOT=0"
set "REBOOT_DELAY=30"

:: Mode uji coba - 1 = hanya log, tidak mengubah apa pun
set "DRY_RUN=0"

:: Backup registry sebelum tweak HKLM? 1 = ya (disarankan)
set "BACKUP_REG=1"

:: Auto-disable SysMain HANYA kalau disk sistem SSD
:: 1 = deteksi otomatis, 0 = selalu pakai DIS_SYSMAIN di atas
set "AUTO_SSD_DETECT=1"

:: Peringatan kalau free space C: < N MB (0 = matikan)
set "MIN_FREE_WARN=2048"
:: ==========================================================

:: ---- Cek admin, kalau belum auto-elevate ----
net session >nul 2>&1
if errorlevel 1 (
    echo Meminta hak Administrator...
    powershell -nop -c "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b 5
)

:: ---- Log (dengan fallback kalau folder read-only) ----
set "LOGDIR=%~dp0logs"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1
set "LOG="
for /f %%i in ('powershell -nop -c "Get-Date -Format yyyyMMdd_HHmm"') do set "TS=%%i"
if not defined TS set "TS=unknown"
if exist "%LOGDIR%\" (
    >"%LOGDIR%\.wtest" echo test 2>nul && (
        set "LOG=%LOGDIR%\%COMPUTERNAME%_%TS%.log"
        del "%LOGDIR%\.wtest" >nul 2>&1
    )
)
if not defined LOG (
    set "LOG=%TEMP%\%COMPUTERNAME%_%TS%.log"
    echo [!] Folder log tidak writable, fallback ke %TEMP%
)

:: ---- Deteksi OS ----
set "BUILD=0"
for /f "tokens=3" %%b in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber 2^>nul ^| findstr /i "CurrentBuildNumber"') do set "BUILD=%%b"
if not defined BUILD set "BUILD=0"
set "OSNAME=Windows 10"
if %BUILD% GEQ 22000 set "OSNAME=Windows 11"

:: ---- Deteksi media disk sistem (SSD / HDD) ----
set "MEDIA=UNKNOWN"
if "%AUTO_SSD_DETECT%"=="1" (
    for /f "tokens=*" %%m in ('powershell -nop -c "(Get-PhysicalDisk | Where-Object {$_.DeviceID -eq 0} | Select-Object -First 1).MediaType" 2^>nul') do set "MEDIA=%%m"
    if /i "%MEDIA%"=="SSD" (
        call :log "Disk sistem terdeteksi SSD - SysMain akan di-disable (aman)"
    ) else if /i "%MEDIA%"=="HDD" (
        call :log "Disk sistem terdeteksi HDD - SysMain DIPERTAHANKAN (perlu prefetch)"
        set "DIS_SYSMAIN=0"
    ) else (
        call :log "Tipe media tidak dapat dideteksi, pakai konfigurasi DIS_SYSMAIN=%DIS_SYSMAIN%"
    )
)

call :log "=== Maintenance %COMPUTERNAME% - %OSNAME% build %BUILD% ==="
if "%DRY_RUN%"=="1" call :log "*** DRY RUN MODE - tidak ada perubahan yang diterapkan ***"

for /f %%f in ('powershell -nop -c "[math]::Round((Get-PSDrive C).Free/1MB)"') do set "FREE_BEFORE=%%f"
if not defined FREE_BEFORE set "FREE_BEFORE=0"
call :log "Ruang C: awal = %FREE_BEFORE% MB"

:: ---- Peringatan free space rendah ----
if %MIN_FREE_WARN% GTR 0 (
    if %FREE_BEFORE% LSS %MIN_FREE_WARN% call :log "PERINGATAN: ruang C: < %MIN_FREE_WARN% MB, cleanup sangat disarankan"
)

:: ---- Backup registry (opsional) ----
if "%BACKUP_REG%"=="1" if "%DRY_RUN%"=="0" call :backup_reg

:: ---- Eksekusi task ----
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

:: ---- TRIM check untuk SSD ----
if /i "%MEDIA%"=="SSD" call :trim_check

:: ---- Restart explorer untuk apply tampilan ----
if "%DO_WALLPAPER%"=="1" call :restart_explorer
if "%DO_VISUAL%"=="1"    call :restart_explorer

:: ---- Verifikasi power plan ----
if "%DO_POWER%"=="1" (
    call :log "Power plan aktif saat ini:"
    if defined LOG >>"%LOG%" 2>&1 (powercfg /getactivescheme)
)

:: ---- Ringkasan ----
for /f %%f in ('powershell -nop -c "[math]::Round((Get-PSDrive C).Free/1MB)"') do set "FREE_AFTER=%%f"
if not defined FREE_AFTER set "FREE_AFTER=%FREE_BEFORE%"
set /a FREED=FREE_AFTER-FREE_BEFORE
call :log "Ruang C: kosong sekarang %FREE_AFTER% MB (bertambah %FREED% MB)"
call :log "Selesai. Log: %LOG%"

:: ---- Restart ----
if "%AUTO_REBOOT%"=="1" (
    if "%DRY_RUN%"=="1" (
        call :log "[DRY RUN] Akan restart dalam %REBOOT_DELAY% detik"
    ) else (
        call :log "Restart otomatis dalam %REBOOT_DELAY% detik..."
        shutdown /r /t %REBOOT_DELAY% /c "Maintenance selesai, restart..."
    )
) else (
    call :log "Restart disarankan tapi tidak dijalankan (AUTO_REBOOT=0)"
)

endlocal & exit /b 0

:: ==========================================================
::  BACKUP REGISTRY
:: ==========================================================
:backup_reg
call :log "Backup registry ke folder logs..."
set "BK=%LOGDIR%\backup_%COMPUTERNAME%_%TS%"
if not exist "%BK%" mkdir "%BK%" >nul 2>&1
reg export "HKLM\SOFTWARE\Policies\Microsoft\Windows" "%BK%\policies_windows.reg" /y >nul 2>&1
reg export "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "%BK%\power.reg" /y >nul 2>&1
reg export "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies" "%BK%\policies_currentversion.reg" /y >nul 2>&1
call :log "Backup registry selesai: %BK%"
exit /b

:: ==========================================================
::  PER-USER REGISTRY
:: ==========================================================
:reg_users
if defined REG_USERS_DONE exit /b
set "REG_USERS_DONE=1"
call :log "Terapkan setting per-user (desktop, visual effects, screensaver)"
if "%DRY_RUN%"=="1" (
    call :log "[DRY RUN] Skip apply per-user registry"
    exit /b
)
for /f %%s in ('reg query HKU ^| findstr /r /c:"S-1-5-21-[0-9-]*$"') do call :applyuser "%%s"
reg load HKU\DefTmp "%SystemDrive%\Users\Default\NTUSER.DAT" >nul 2>&1
if not errorlevel 1 (
    call :applyuser "HKU\DefTmp"
    reg unload HKU\DefTmp >nul 2>&1
)
exit /b

:applyuser
if "%DO_WALLPAPER%"=="1" (
    reg add "%~1\Control Panel\Desktop" /v Wallpaper /t REG_SZ /d "" /f >nul 2>&1
    reg add "%~1\Control Panel\Colors" /v Background /t REG_SZ /d "%BG_COLOR%" /f >nul 2>&1
    reg add "%~1\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers" /v BackgroundType /t REG_DWORD /d 1 /f >nul 2>&1
    reg add "%~1\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v EnableSnapAssistFlyout /t REG_DWORD /d 0 /f >nul 2>&1
)
if "%DO_VISUAL%"=="1" (
    reg add "%~1\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f >nul 2>&1
    reg add "%~1\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "%~1\Control Panel\Desktop" /v UserPreferencesMask /t REG_BINARY /d 9012038010000000 /f >nul 2>&1
    reg add "%~1\Control Panel\Desktop" /v FontSmoothing /t REG_SZ /d 2 /f >nul 2>&1
    reg add "%~1\Control Panel\Desktop\WindowMetrics" /v MinAnimate /t REG_SZ /d 0 /f >nul 2>&1
    reg add "%~1\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAnimations /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "%~1\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ListviewAlphaSelect /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "%~1\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ListviewShadow /t REG_DWORD /d 0 /f >nul 2>&1
)
if "%DO_POWER%"=="1" (
    reg add "%~1\Control Panel\Desktop" /v ScreenSaveActive /t REG_SZ /d 0 /f >nul 2>&1
)
if "%DO_TWEAKS%"=="1" (
    reg add "%~1\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "%~1\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SilentInstalledAppsEnabled /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "%~1\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SoftLandingEnabled /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "%~1\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /t REG_DWORD /d 1 /f >nul 2>&1
    reg add "%~1\System\GameConfigStore" /v GameDVR_Enabled /t REG_DWORD /d 0 /f >nul 2>&1
)
exit /b

:: ==========================================================
::  POWER
:: ==========================================================
:power
call :log "Power plan: High Performance, sleep/monitor/disk = never"
if "%DRY_RUN%"=="1" (
    call :log "[DRY RUN] Skip power configuration"
    exit /b
)

set "HP_GUID=8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
set "ACTIVE_GUID="
for /f "tokens=4" %%g in ('powercfg /list ^| findstr /i "%HP_GUID%"') do set "ACTIVE_GUID=%%g"

if not defined ACTIVE_GUID (
    for /f "tokens=4" %%g in ('powercfg -duplicatescheme %HP_GUID% 2^>nul ^| findstr /i "GUID"') do set "ACTIVE_GUID=%%g"
)

if defined ACTIVE_GUID (
    powercfg /setactive %ACTIVE_GUID%
) else (
    call :log "High Performance tidak tersedia, pakai scheme aktif"
)

powercfg /change monitor-timeout-ac 0
powercfg /change monitor-timeout-dc 0
powercfg /change standby-timeout-ac 0
powercfg /change standby-timeout-dc 0
powercfg /change disk-timeout-ac 0
powercfg /change disk-timeout-dc 0
powercfg /change hibernate-timeout-ac 0
powercfg /change hibernate-timeout-dc 0

powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100
powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100
powercfg /setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100
powercfg /setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100
powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setactive SCHEME_CURRENT

powercfg -h off >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f >nul 2>&1
exit /b

:: ==========================================================
::  CLEAN CACHE
:: ==========================================================
:clean
call :log "Bersihkan cache dan file temp"
if "%DRY_RUN%"=="1" (
    call :log "[DRY RUN] Skip cleanup"
    exit /b
)
if "%KILL_BROWSERS%"=="1" (
    call :log "Menutup browser..."
    taskkill /f /im chrome.exe >nul 2>&1
    taskkill /f /im msedge.exe >nul 2>&1
    taskkill /f /im firefox.exe >nul 2>&1
    ping -n 3 127.0.0.1 >nul
)

net stop wuauserv >nul 2>&1
net stop bits >nul 2>&1
net stop dosvc >nul 2>&1
call :cleandir "%SystemRoot%\SoftwareDistribution\Download"
call :cleandir "%SystemRoot%\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache"
net start bits >nul 2>&1
net start wuauserv >nul 2>&1
net start dosvc >nul 2>&1

call :cleandir "%SystemRoot%\Temp"
call :cleandir "%SystemRoot%\Minidump"
call :cleandir "%ProgramData%\Microsoft\Windows\WER\ReportQueue"
call :cleandir "%ProgramData%\Microsoft\Windows\WER\ReportArchive"
del /f /q "%SystemRoot%\MEMORY.DMP" >nul 2>&1

for /d %%u in ("%SystemDrive%\Users\*") do call :cleanuser "%%~fu"

powershell -nop -c "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" >nul 2>&1

ipconfig /flushdns >nul 2>&1
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
if "%DRY_RUN%"=="1" (
    call :log "[DRY RUN] Skip services"
    exit /b
)
if "%DIS_SYSMAIN%"=="1" (
    sc stop SysMain >nul 2>&1
    sc config SysMain start= disabled >nul 2>&1
) else (
    sc config SysMain start= auto >nul 2>&1
    sc start SysMain >nul 2>&1
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
::  TWEAKS
:: ==========================================================
:tweaks
call :log "Tweak policy (consumer features, widgets/news, game DVR, telemetry)"
if "%DRY_RUN%"=="1" (
    call :log "[DRY RUN] Skip HKLM tweaks"
    exit /b
)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f >nul 2>&1
if %BUILD% GEQ 22000 (
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /v AllowNewsAndInterests /t REG_DWORD /d 0 /f >nul 2>&1
) else (
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" /v EnableFeeds /t REG_DWORD /d 0 /f >nul 2>&1
)
exit /b

:timesync
call :log "Sinkronisasi waktu"
if "%DRY_RUN%"=="1" exit /b
net start w32time >nul 2>&1
w32tm /resync /force >nul 2>&1
if errorlevel 1 call :log "Resync waktu gagal (cek GPO w32time / NTP source)"
exit /b

:eventlogs
call :log "Hapus Event Logs"
if "%DRY_RUN%"=="1" exit /b
for /f "tokens=*" %%g in ('wevtutil el') do (
    echo %%g | findstr /i /c:"analytic" /c:"debug" >nul || wevtutil cl "%%g" >nul 2>&1
)
exit /b

:: ==========================================================
::  TASK LAMBAT
:: ==========================================================
:dism
call :log "DISM component cleanup (lama)"
if "%DRY_RUN%"=="1" exit /b
dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase >>"%LOG%" 2>&1
exit /b

:sfc
call :log "SFC scan (lama)"
if "%DRY_RUN%"=="1" exit /b
sfc /scannow >>"%LOG%" 2>&1
exit /b

:defrag
call :log "Optimize drive C (TRIM untuk SSD, defrag untuk HDD)"
if "%DRY_RUN%"=="1" exit /b
defrag C: /O /U >>"%LOG%" 2>&1
exit /b

:: ==========================================================
::  TRIM CHECK (SSD)
:: ==========================================================
:trim_check
call :log "Cek status TRIM"
if "%DRY_RUN%"=="1" exit /b
:: Pastikan TRIM aktif (DisableDeleteNotify = 0 artinya TRIM aktif)
fsutil behavior set DisableDeleteNotify 0 >nul 2>&1
call :log "TRIM diaktifkan (DisableDeleteNotify=0)"
exit /b

:: ==========================================================
::  REFRESH SHELL
:: ==========================================================
:restart_explorer
if defined EXPLORER_RESTARTED exit /b
set "EXPLORER_RESTARTED=1"
if "%DRY_RUN%"=="1" (
    call :log "[DRY RUN] Skip restart explorer"
    exit /b
)
call :log "Restart explorer.exe untuk apply setting tampilan"
taskkill /f /im explorer.exe >nul 2>&1
ping -n 3 127.0.0.1 >nul
start "" explorer.exe
exit /b

:: ==========================================================
::  LOGGING
:: ==========================================================
:log
echo [%time:~0,8%] %~1
if defined LOG (
    >>"%LOG%" echo [%time:~0,8%] %~1
)
exit /b
