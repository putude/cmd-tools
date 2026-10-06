@echo off
setlocal EnableDelayedExpansion
title Reset File and Printer Sharing (Win10/11)

:: ===== OPSI (0 = tidak, 1 = ya) =====
set SET_PRIVATE=1        & rem ubah profil jaringan aktif jadi Private
set CLEAR_MAPPED=1       & rem hapus mapped drive/koneksi SMB lama (net use)
set CLEAR_SPOOL=1        & rem bersihkan antrian print yang nyangkut
set RESET_PRINT_RPC=1    & rem hapus override RpcAuthnLevelPrivacyEnabled (balik default)
set RESET_TOKEN_FILTER=1 & rem hapus LocalAccountTokenFilterPolicy (balik default)
set RESET_TCPIP=0        & rem netsh winsock/ip reset (butuh restart)
:: =====================================

:: --- Cek admin ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Jalankan sebagai Administrator.
    pause & exit /b 1
)

echo.
echo [1/7] Service ke setelan default...
sc config LanmanServer      start= auto          >nul
sc config LanmanWorkstation start= auto          >nul
sc config lmhosts           start= auto          >nul
sc config Spooler           start= auto          >nul
sc config FDResPub          start= delayed-auto  >nul
sc config fdPHost           start= demand        >nul
sc config SSDPSRV           start= demand        >nul
sc config upnphost          start= demand        >nul
sc config BFE               start= auto          >nul
sc config mpssvc            start= auto          >nul
sc config NlaSvc            start= auto          >nul
sc config netprofm          start= demand        >nul

echo [2/7] Registry ke default...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LimitBlankPasswordUse /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v AutoShareWks /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v AutoShareServer /t REG_DWORD /d 1 /f >nul 2>&1
if "%RESET_TOKEN_FILTER%"=="1" reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v LocalAccountTokenFilterPolicy /f >nul 2>&1
if "%RESET_PRINT_RPC%"=="1"    reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Print" /v RpcAuthnLevelPrivacyEnabled /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint" /f >nul 2>&1

echo [3/7] Firewall: aktifkan rule File/Printer Sharing + Network Discovery...
:: Pakai resource string supaya jalan di semua bahasa Windows
netsh advfirewall firewall set rule group="@FirewallAPI.dll,-28502" new enable=Yes >nul
netsh advfirewall firewall set rule group="@FirewallAPI.dll,-32752" new enable=Yes >nul
powershell -NoProfile -Command "Get-NetFirewallRule -DisplayGroup 'File and Printer Sharing','Network Discovery','Berbagi File dan Printer','Penemuan Jaringan' -ErrorAction SilentlyContinue | Set-NetFirewallRule -Enabled True -Profile Private,Domain" >nul 2>&1

echo [4/7] SMB: pastikan SMB2/3 aktif...
powershell -NoProfile -Command "Set-SmbServerConfiguration -EnableSMB2Protocol $true -Force" >nul 2>&1

if "%SET_PRIVATE%"=="1" (
    echo [5/7] Profil jaringan aktif -^> Private...
    powershell -NoProfile -Command "Get-NetConnectionProfile | Where-Object {$_.IPv4Connectivity -ne 'Disconnected'} | Set-NetConnectionProfile -NetworkCategory Private" >nul 2>&1
) else echo [5/7] Skip profil jaringan

if "%CLEAR_MAPPED%"=="1" (
    echo [6/7] Hapus koneksi SMB lama + cache NetBIOS/DNS...
    net use * /delete /y >nul 2>&1
    nbtstat -R  >nul 2>&1
    nbtstat -RR >nul 2>&1
    ipconfig /flushdns >nul
) else echo [6/7] Skip clear koneksi

echo [7/7] Restart service sharing + printer...
net stop Spooler /y >nul 2>&1
if "%CLEAR_SPOOL%"=="1" del /q /f "%SystemRoot%\System32\spool\PRINTERS\*" >nul 2>&1
net start Spooler >nul 2>&1
net stop LanmanServer /y >nul 2>&1
net start LanmanServer >nul 2>&1
net start LanmanWorkstation >nul 2>&1
net start lmhosts >nul 2>&1
net start FDResPub >nul 2>&1
net start fdPHost >nul 2>&1
net start SSDPSRV >nul 2>&1
net start upnphost >nul 2>&1

if "%RESET_TCPIP%"=="1" (
    echo [+] Reset Winsock dan TCP/IP...
    netsh winsock reset >nul
    netsh int ip reset >nul
    set NEED_REBOOT=1
)

echo.
echo ===== Selesai =====
if defined NEED_REBOOT (echo Restart PC diperlukan.) else echo Kalau masih bermasalah, restart PC sekali.
pause
endlocal
