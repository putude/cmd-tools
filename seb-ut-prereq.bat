@echo off
setlocal
title Prasyarat SEB UT - Cleanup Remote Tools

:: ---- Auto elevate ke Administrator ----
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo ============================================
echo  Prasyarat SEB UT (Windows 10/11)
echo ============================================

echo.
echo [1/5] Menutup proses...
for %%P in (Zoom.exe CptHost.exe zoom_launcher.exe AnyDesk.exe UltraViewer_Desktop.exe UltraViewer_Service.exe remoting_host.exe remoting_start_host.exe remoting_desktop.exe) do (
    taskkill /f /im %%P >nul 2>&1
)

echo.
echo [2/5] Uninstall Zoom, AnyDesk, UltraViewer, Chrome Remote Desktop...
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((Get-Content -LiteralPath '%~f0' -Raw) -split ('#'+'PS#'))[1]"

echo.
echo [3/5] Hapus service sisa...
for %%S in (AnyDesk UltraViewer_Service chromoting) do (
    sc stop %%S >nul 2>&1
    sc delete %%S >nul 2>&1
)

echo.
echo [4/5] Disable Remote Desktop + Remote Assistance...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Remote Assistance" /v fAllowToGetHelp /t REG_DWORD /d 0 /f >nul
netsh advfirewall firewall set rule group="remote desktop" new enable=No >nul 2>&1
netsh advfirewall firewall set rule group="@FirewallAPI.dll,-28752" new enable=No >nul 2>&1
netsh advfirewall firewall set rule group="remote assistance" new enable=No >nul 2>&1
sc config TermService start= disabled >nul 2>&1
sc config UmRdpService start= disabled >nul 2>&1
net stop UmRdpService /y >nul 2>&1
net stop TermService /y >nul 2>&1

echo.
echo [5/5] Verifikasi...
powershell -NoProfile -Command "$r=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -EA SilentlyContinue | ? { $_.DisplayName -match '^Zoom|AnyDesk|UltraViewer|Chrome Remote Desktop' }; if($r){Write-Host 'MASIH TERINSTALL:' -ForegroundColor Red; $r.DisplayName}else{Write-Host 'OK: semua aplikasi sudah terhapus' -ForegroundColor Green}; $d=(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server').fDenyTSConnections; if($d -eq 1){Write-Host 'OK: Remote Desktop disabled' -ForegroundColor Green}else{Write-Host 'Remote Desktop MASIH AKTIF' -ForegroundColor Red}"

echo.
echo Selesai. Disarankan RESTART PC sebelum install SEB.
echo Catatan: extension Chrome Remote Desktop di browser hapus manual (chrome://extensions).
exit /b

#PS#
$ErrorActionPreference = 'SilentlyContinue'

$keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'Registry::HKEY_USERS\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'

# --- AnyDesk (pakai --remove) ---
$ad = @("${env:ProgramFiles(x86)}\AnyDesk\AnyDesk.exe", "$env:ProgramFiles\AnyDesk\AnyDesk.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($ad) {
    Write-Host "Uninstall: AnyDesk"
    Start-Process $ad -ArgumentList '--silent --remove' -Wait
}

# --- Zoom, UltraViewer, Chrome Remote Desktop (dari registry) ---
$apps = Get-ItemProperty $keys | Where-Object { $_.DisplayName -match '^Zoom|UltraViewer|Chrome Remote Desktop' }
foreach ($a in $apps) {
    Write-Host "Uninstall: $($a.DisplayName)"
    $u = $a.UninstallString
    if (-not $u) { continue }

    if ($u -match 'msiexec' -and $u -match '\{[0-9A-Fa-f-]+\}') {
        Start-Process msiexec -ArgumentList "/x $($matches[0]) /qn /norestart" -Wait
    }
    else {
        if ($u -match '^"([^"]+)"') { $exe = $matches[1] } else { $exe = ($u -split ' /')[0].Trim() }

        if ($exe -match 'unins\d*\.exe$') {
            Start-Process $exe -ArgumentList '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART' -Wait
        }
        elseif ($exe -match 'Zoom') {
            Start-Process $exe -ArgumentList '/uninstall' -Wait
        }
        elseif ($a.QuietUninstallString) {
            Start-Process cmd -ArgumentList "/c $($a.QuietUninstallString)" -Wait -WindowStyle Hidden
        }
        else {
            Start-Process cmd -ArgumentList "/c $u" -Wait
        }
    }
}

# --- Bersihkan folder sisa ---
$dirs = @(
    'C:\ProgramData\AnyDesk',
    "$env:ProgramFiles\AnyDesk", "${env:ProgramFiles(x86)}\AnyDesk",
    "$env:ProgramFiles\UltraViewer", "${env:ProgramFiles(x86)}\UltraViewer",
    "$env:ProgramFiles\Zoom", "${env:ProgramFiles(x86)}\Zoom",
    "$env:ProgramFiles\Google\Chrome Remote Desktop", "${env:ProgramFiles(x86)}\Google\Chrome Remote Desktop",
    'C:\ProgramData\Google\Chrome Remote Desktop'
)
Get-ChildItem 'C:\Users' -Directory | ForEach-Object {
    $dirs += "$($_.FullName)\AppData\Roaming\AnyDesk"
    $dirs += "$($_.FullName)\AppData\Roaming\Zoom"
    $dirs += "$($_.FullName)\AppData\Local\Zoom"
    $dirs += "$($_.FullName)\AppData\Roaming\UltraViewer"
    $dirs += "$($_.FullName)\AppData\Local\UltraViewer"
}
foreach ($d in $dirs) {
    if (Test-Path $d) { Remove-Item $d -Recurse -Force; Write-Host "Hapus folder: $d" }
}
#PS#
