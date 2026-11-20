@echo off
setlocal EnableExtensions
title Lab PC Maintenance
set "SELF=%~f0"
set "RUN_DEFRAG=0"
set "RUN_DEEP=0"

:: ---------- Auto elevate ----------
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%SELF%' -Verb RunAs"
    exit /b
)

call :browsers
call :apps
call :bloat
call :optimise
if "%RUN_DEEP%"=="1" (
    sfc /scannow
    dism /online /Cleanup-Image /RestoreHealth
    dism /online /Cleanup-Image /StartComponentCleanup
)
echo [OK] Selesai.
exit /b

:: =====================================================
:browsers
echo [*] Reset browser...
call :runps BROWSERS
exit /b

:apps
echo [*] Uninstall app (Opera, Roblox, WPS, RAV)...
call :runps APPS
call :onedrive
exit /b

:bloat
echo [*] Hapus bloatware...
call :runps BLOAT
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableSoftLanding /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsSpotlightFeatures /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Chat" /v ChatIcon /t REG_DWORD /d 3 /f >nul
reg add "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /v AllowNewsAndInterests /t REG_DWORD /d 0 /f >nul
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" /v EnableFeeds /t REG_DWORD /d 0 /f >nul
exit /b

:onedrive
echo [*] Hapus OneDrive...
taskkill /f /im OneDrive.exe >nul 2>&1
if exist "%SystemRoot%\SysWOW64\OneDriveSetup.exe" "%SystemRoot%\SysWOW64\OneDriveSetup.exe" /uninstall
if exist "%SystemRoot%\System32\OneDriveSetup.exe" "%SystemRoot%\System32\OneDriveSetup.exe" /uninstall
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" /v DisableFileSyncNGSC /t REG_DWORD /d 1 /f >nul
:: cegah OneDrive ter-install di profil user baru
reg load HKU\DefUser "%SystemDrive%\Users\Default\NTUSER.DAT" >nul 2>&1
reg delete "HKU\DefUser\Software\Microsoft\Windows\CurrentVersion\Run" /v OneDriveSetup /f >nul 2>&1
reg unload HKU\DefUser >nul 2>&1
exit /b

:optimise
echo [*] Optimasi Windows...
:: Temp & cache
call :runps TEMP
net stop wuauserv >nul 2>&1
net stop bits >nul 2>&1
del /f /s /q "%SystemRoot%\SoftwareDistribution\Download\*" >nul 2>&1
net start bits >nul 2>&1
net start wuauserv >nul 2>&1
del /f /s /q "%SystemRoot%\Prefetch\*" >nul 2>&1
rd /s /q "%SystemDrive%\$Recycle.Bin" >nul 2>&1
ipconfig /flushdns >nul

:: Power: high performance, no sleep, hibernate/fast startup off
powercfg /setactive SCHEME_MIN >nul 2>&1
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
powercfg /change monitor-timeout-ac 30
powercfg -h off

:: Policy: telemetry, ads, game dvr
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f >nul
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" /v DisabledByGroupPolicy /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR /t REG_DWORD /d 0 /f >nul

:: Service tidak perlu di lab
for %%S in (DiagTrack dmwappushservice XblAuthManager XblGameSave XboxNetApiSvc XboxGipSvc MapsBroker RetailDemo) do (
    sc query %%S >nul 2>&1 && (
        sc stop %%S >nul 2>&1
        sc config %%S start= disabled >nul 2>&1
    )
)
:: Opsional (HDD lama): uncomment untuk matikan SysMain
:: sc stop SysMain & sc config SysMain start= disabled

:: TRIM (SSD) / defrag (HDD) otomatis
if "%RUN_DEFRAG%"=="1" defrag %SystemDrive% /O
exit /b

:: =====================================================
:: Jalankan blok PowerShell di bawah file ini
:runps
powershell -NoProfile -ExecutionPolicy Bypass -Command "$t=[IO.File]::ReadAllText('%SELF%'); $m=[regex]::Match($t,'(?s)#BEGIN %~1\r?\n(.*?)#END %~1'); iex $m.Groups[1].Value"
exit /b

exit /b

:: ===================== POWERSHELL BLOCKS =====================

#BEGIN BROWSERS
Get-Process chrome,firefox,msedge,opera,MicrosoftEdgeUpdate -ErrorAction SilentlyContinue | Stop-Process -Force
$users = Get-ChildItem C:\Users -Directory | Where-Object { $_.Name -notin 'Public','Default','Default User','All Users' }
foreach ($u in $users) {
    $p = $u.FullName
    $targets = @(
        "$p\AppData\Local\Google\Chrome\User Data",
        "$p\AppData\Local\Microsoft\Edge\User Data",
        "$p\AppData\Roaming\Mozilla\Firefox\Profiles",
        "$p\AppData\Local\Mozilla\Firefox\Profiles",
        "$p\AppData\Roaming\Mozilla\Firefox\profiles.ini"
    )
    foreach ($t in $targets) {
        if (Test-Path $t) {
            Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  reset: $t"
        }
    }
}
#END BROWSERS

#BEGIN APPS
$pat = 'Opera*','RAV *','WPS Office*','Roblox*','Kingsoft*'

# stop proses & service
Get-Process | Where-Object { $_.Name -match '^(opera|wps|wpp|et|wpscloudsvr|wpsupdate|ksolaunch|Roblox.*|RAV.*)$' } | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Service | Where-Object { $_.Name -match '^RAV' -or $_.DisplayName -match '^RAV' } | ForEach-Object { Stop-Service $_ -Force -ErrorAction SilentlyContinue }

# uninstall silent (install system-wide)
$keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
$found = Get-ItemProperty $keys -ErrorAction SilentlyContinue | Where-Object { $n = $_.DisplayName; $n -and ($pat | Where-Object { $n -like $_ }) }
foreach ($a in $found) {
    Write-Host "  uninstall: $($a.DisplayName)"
    $us = $a.UninstallString
    if ($us -match '(?i)msiexec') {
        $g = [regex]::Match($us, '\{[0-9A-Fa-f-]+\}').Value
        $cmd = "msiexec.exe /x $g /qn /norestart"
    } elseif ($a.QuietUninstallString) {
        $cmd = $a.QuietUninstallString
    } else {
        $cmd = "$us /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /S"
    }
    $pr = Start-Process cmd.exe -ArgumentList "/c `"$cmd`"" -PassThru -WindowStyle Hidden
    if (-not $pr.WaitForExit(180000)) { $pr.Kill() }
}

# sisa service RAV
Get-Service | Where-Object { $_.Name -match '^RAV' } | ForEach-Object { sc.exe delete $_.Name | Out-Null }

# hapus sisa file per-user (Opera, Roblox, WPS biasanya install per-user)
$users = Get-ChildItem C:\Users -Directory | Where-Object { $_.Name -notin 'Public','Default','Default User','All Users' }
foreach ($u in $users) {
    $p = $u.FullName
    $dirs = @(
        "$p\AppData\Local\Programs\Opera", "$p\AppData\Local\Programs\Opera GX",
        "$p\AppData\Roaming\Opera Software", "$p\AppData\Local\Opera Software",
        "$p\AppData\Local\Roblox", "$p\AppData\Local\Kingsoft", "$p\AppData\Roaming\kingsoft"
    )
    foreach ($d in $dirs) { if (Test-Path $d) { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue; Write-Host "  hapus: $d" } }
    Get-ChildItem "$p\Desktop","$p\OneDrive\Desktop","$p\AppData\Roaming\Microsoft\Windows\Start Menu\Programs" -Recurse -Include *.lnk -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'Opera|Roblox|WPS' } | Remove-Item -Force -ErrorAction SilentlyContinue
}
$sys = @("$env:ProgramFiles\Opera", "${env:ProgramFiles(x86)}\Opera", "${env:ProgramFiles(x86)}\Kingsoft", "$env:ProgramFiles\Kingsoft")
foreach ($d in $sys) { if (Test-Path $d) { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue } }
Get-ChildItem "C:\Users\Public\Desktop","C:\ProgramData\Microsoft\Windows\Start Menu\Programs" -Recurse -Include *.lnk -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match 'Opera|Roblox|WPS|^RAV' } | Remove-Item -Force -ErrorAction SilentlyContinue

# scheduled task updater
Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match 'Opera|Roblox|WPS|Kingsoft|^RAV' } | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

# startup entries
foreach ($k in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run') {
    $props = (Get-ItemProperty $k -ErrorAction SilentlyContinue).PSObject.Properties | Where-Object { $_.Name -match 'Opera|WPS|Kingsoft|Roblox|^RAV|OneDrive' -and $_.Name -notmatch '^PS' }
    foreach ($x in $props) { Remove-ItemProperty $k -Name $x.Name -ErrorAction SilentlyContinue }
}
#END APPS

#BEGIN BLOAT
$bloat = @(
 'Microsoft.BingNews','Microsoft.BingWeather','Microsoft.GetHelp','Microsoft.Getstarted',
 'Microsoft.MicrosoftOfficeHub','Microsoft.MicrosoftSolitaireCollection','Microsoft.MixedReality.Portal',
 'Microsoft.Microsoft3DViewer','Microsoft.Print3D','Microsoft.People','Microsoft.SkypeApp',
 'Microsoft.WindowsFeedbackHub','Microsoft.YourPhone','Microsoft.ZuneMusic','Microsoft.ZuneVideo',
 'microsoft.windowscommunicationsapps','Microsoft.Xbox*','Microsoft.GamingApp','Microsoft.Todos',
 'Microsoft.PowerAutomateDesktop','Clipchamp.Clipchamp','MicrosoftTeams','MSTeams',
 'Microsoft.549981C3F5F10','Microsoft.WindowsMaps','Microsoft.OneConnect','Microsoft.Wallet',
 'Microsoft.Office.OneNote','Microsoft.OutlookForWindows','Microsoft.Windows.DevHome','Microsoft.Copilot',
 '*CandyCrush*','king.com.*','*TikTok*','*Disney*','*Spotify*','*Netflix*','*Facebook*',
 '*Instagram*','*Twitter*','*LinkedIn*','*Amazon*','*Dropbox*','*Hulu*','*PrimeVideo*'
)
foreach ($b in $bloat) {
    Write-Host "  cek: $b"
    Get-AppxPackage -AllUsers -Name $b -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $b } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
}
#END BLOAT

#BEGIN TEMP
function Clear-Dir($d) {
    if (Test-Path $d) {
        Get-ChildItem $d -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -ne $env:SELF } |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}
$users = Get-ChildItem C:\Users -Directory | Where-Object { $_.Name -notin 'Default','Default User','All Users' }
foreach ($u in $users) {
    $p = $u.FullName
    Write-Host "  bersihkan: $p"
    foreach ($d in "$p\Downloads", "$p\AppData\Local\Temp", "$p\AppData\Local\Microsoft\Windows\INetCache", "$p\AppData\Local\CrashDumps") {
        Clear-Dir $d
    }
}
Clear-Dir "$env:SystemRoot\Temp"
Clear-Dir $env:TEMP
Clear-RecycleBin -Force -ErrorAction SilentlyContinue
#END TEMP
