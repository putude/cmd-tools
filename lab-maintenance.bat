@echo off
setlocal EnableExtensions
title Lab PC Maintenance
set "SELF=%~f0"
set "RUN_DEFRAG=0"
set "RUN_DEEP=0"
set "LITE_SERVICES=1"

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
call :performance
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
echo [*] Uninstall app (Opera, Roblox, WPS, RAV, Valorant/Riot, TLauncher, Avast, Brave)...
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

:: Hibernate + fast startup off (power plan diatur di :performance)
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

:performance
echo [*] Performa maksimum + tampilan ringan...

:: ---- Power plan: High performance (fallback Ultimate) ----
powercfg /setactive SCHEME_MIN >nul 2>&1 || (
    for /f "tokens=4" %%G in ('powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2^>nul') do powercfg /setactive %%G
)
for %%X in (setacvalueindex setdcvalueindex) do (
    rem CPU: 100% min/max, turbo agresif, core parking off, pendingin aktif
    powercfg /%%X SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100 >nul 2>&1
    powercfg /%%X SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100 >nul 2>&1
    powercfg /%%X SCHEME_CURRENT SUB_PROCESSOR PERFBOOSTMODE 2 >nul 2>&1
    powercfg /%%X SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100 >nul 2>&1
    powercfg /%%X SCHEME_CURRENT SUB_PROCESSOR SYSCOOLPOL 1 >nul 2>&1
    rem Sleep / hibernate / monitor / disk / lock = NEVER
    powercfg /%%X SCHEME_CURRENT SUB_SLEEP STANDBYIDLE 0 >nul 2>&1
    powercfg /%%X SCHEME_CURRENT SUB_SLEEP HIBERNATEIDLE 0 >nul 2>&1
    powercfg /%%X SCHEME_CURRENT SUB_SLEEP HYBRIDSLEEP 0 >nul 2>&1
    powercfg /%%X SCHEME_CURRENT SUB_VIDEO VIDEOIDLE 0 >nul 2>&1
    powercfg /%%X SCHEME_CURRENT SUB_VIDEO VIDEOCONLOCK 0 >nul 2>&1
    powercfg /%%X SCHEME_CURRENT SUB_DISK DISKIDLE 0 >nul 2>&1
    powercfg /%%X SCHEME_CURRENT SUB_NONE CONSOLELOCK 0 >nul 2>&1
    rem PCIe link power & USB selective suspend off
    powercfg /%%X SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0 >nul 2>&1
    powercfg /%%X SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 >nul 2>&1
)
powercfg /change standby-timeout-ac 0
powercfg /change standby-timeout-dc 0
powercfg /change monitor-timeout-ac 0
powercfg /change monitor-timeout-dc 0
powercfg /change disk-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
powercfg /setactive SCHEME_CURRENT >nul 2>&1

:: ---- CPU scheduler / throttling ----
reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v Win32PrioritySeparation /t REG_DWORD /d 38 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" /v PowerThrottlingOff /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f >nul
fsutil behavior set disablelastaccess 1 >nul 2>&1

:: ---- Background apps & P2P update off ----
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsRunInBackground /t REG_DWORD /d 2 /f >nul
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" /v DODownloadMode /t REG_DWORD /d 0 /f >nul

:: ---- Browser: jangan jalan di background / startup boost ----
for %%P in ("Google\Chrome" "Microsoft\Edge") do (
    reg add "HKLM\SOFTWARE\Policies\%%~P" /v StartupBoostEnabled /t REG_DWORD /d 0 /f >nul
    reg add "HKLM\SOFTWARE\Policies\%%~P" /v BackgroundModeEnabled /t REG_DWORD /d 0 /f >nul
)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v HideFirstRunExperience /t REG_DWORD /d 1 /f >nul

:: ---- Service ringan (HDD/SSD lab): Search index, SysMain, error reporting, fax ----
if "%LITE_SERVICES%"=="1" (
    for %%S in (SysMain WSearch WerSvc Fax) do (
        sc stop %%S >nul 2>&1
        sc config %%S start= disabled >nul 2>&1
    )
)

:: ---- Defender: scan hanya saat idle, CPU rendah ----
powershell -NoProfile -Command "try{Set-MpPreference -ScanOnlyIfIdleEnabled $true -ScanAvgCPULoadFactor 20 -EnableLowCpuPriority $true -ErrorAction Stop}catch{}"

:: ---- Log & dump ----
for /f "tokens=*" %%L in ('wevtutil el') do wevtutil cl "%%L" >nul 2>&1
del /f /q "%SystemRoot%\MEMORY.DMP" >nul 2>&1
del /f /s /q "%SystemRoot%\Minidump\*" >nul 2>&1
del /f /s /q "%ProgramData%\Microsoft\Windows\WER\*" >nul 2>&1

:: ---- Per-user: wallpaper solid biru, efek visual off, startup browser off ----
call :runps HKCU
call :runps STARTUP
call :runps DESKTOP
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
$DelMinecraft = $true   # hapus juga folder .minecraft (world/mod/profil TLauncher); set $false untuk menyimpan
$pat = 'Opera*','RAV *','WPS Office*','Roblox*','Kingsoft*','TLauncher*','Brave*'

# stop proses & service
Get-Process | Where-Object { $_.Name -match '^(opera|wps|wpp|et|wpscloudsvr|wpsupdate|ksolaunch|Roblox.*|RAV.*|Riot.*|VALORANT.*|vgtray|TLauncher.*|brave|BraveUpdate|BraveCrashHandler.*|Avast.*|asw.*|afwServ|wsc_proxy)$' } | Stop-Process -Force -ErrorAction SilentlyContinue
# Minecraft (java/javaw) yang dijalankan TLauncher
Get-CimInstance Win32_Process -Filter "Name='java.exe' OR Name='javaw.exe'" | Where-Object { $_.CommandLine -match 'tlauncher|\.minecraft' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
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
    } elseif ($us -match '(?i)BraveSoftware') {
        $cmd = "$us --force-uninstall"
    } else {
        $cmd = "$us /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /S"
    }
    $pr = Start-Process cmd.exe -ArgumentList "/c `"$cmd`"" -PassThru -WindowStyle Hidden
    if (-not $pr.WaitForExit(180000)) { $pr.Kill() }
}

# Avast: uninstall silent via instup.exe, lalu bersihkan service/driver/entry sisa
$ai = @("$env:ProgramFiles\Avast Software\Avast\Setup\Instup.exe", "$env:ProgramFiles\Avast Software\Avast\instup.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($ai) {
    Write-Host "  uninstall: Avast"
    $pr = Start-Process $ai -ArgumentList '/instop:uninstall','/silent' -PassThru -WindowStyle Hidden
    if (-not $pr.WaitForExit(300000)) { $pr.Kill() }
}
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services' -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^(asw|avast|AvastWscReporter)' } |
    ForEach-Object { sc.exe stop $_.PSChildName 2>&1 | Out-Null; sc.exe delete $_.PSChildName 2>&1 | Out-Null }
Get-ItemProperty $keys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match '^Avast' } |
    ForEach-Object { Write-Host "  hapus entry: $($_.DisplayName)"; Remove-Item -LiteralPath $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue }

# Brave: service sisa
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services' -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^(brave|bravem|BraveElevationService)' } |
    ForEach-Object { sc.exe stop $_.PSChildName 2>&1 | Out-Null; sc.exe delete $_.PSChildName 2>&1 | Out-Null }

# sisa service RAV
Get-Service | Where-Object { $_.Name -match '^RAV' } | ForEach-Object { sc.exe delete $_.Name | Out-Null }

# Riot Vanguard (anti-cheat Valorant): service + driver, uninstall entry Valorant/Riot
foreach ($s in 'vgc','vgk') { sc.exe stop $s 2>&1 | Out-Null; sc.exe delete $s 2>&1 | Out-Null }
Remove-Item "$env:SystemRoot\System32\drivers\vgk.sys" -Force -ErrorAction SilentlyContinue
Get-ItemProperty $keys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match '^(VALORANT|Riot)' } |
    ForEach-Object { Write-Host "  hapus entry: $($_.DisplayName)"; Remove-Item -LiteralPath $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue }

# hapus sisa file per-user (Opera, Roblox, WPS biasanya install per-user)
$users = Get-ChildItem C:\Users -Directory | Where-Object { $_.Name -notin 'Public','Default','Default User','All Users' }
foreach ($u in $users) {
    $p = $u.FullName
    $dirs = @(
        "$p\AppData\Local\Programs\Opera", "$p\AppData\Local\Programs\Opera GX",
        "$p\AppData\Roaming\Opera Software", "$p\AppData\Local\Opera Software",
        "$p\AppData\Local\Roblox", "$p\AppData\Local\Kingsoft", "$p\AppData\Roaming\kingsoft",
        "$p\AppData\Local\Riot Games", "$p\AppData\Local\VALORANT",
        "$p\AppData\Roaming\.tlauncher", "$p\AppData\Roaming\TLauncher", "$p\AppData\Local\TLauncher",
        "$p\AppData\Local\BraveSoftware", "$p\AppData\Roaming\BraveSoftware",
        "$p\AppData\Local\AVAST Software", "$p\AppData\Roaming\AVAST Software"
    )
    if ($DelMinecraft) { $dirs += "$p\AppData\Roaming\.minecraft" }
    foreach ($d in $dirs) { if (Test-Path $d) { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue; Write-Host "  hapus: $d" } }
    Get-ChildItem "$p\Desktop","$p\OneDrive\Desktop","$p\AppData\Roaming\Microsoft\Windows\Start Menu\Programs" -Recurse -Include *.lnk -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'Opera|Roblox|WPS|Riot|VALORANT|TLauncher|Brave|Avast' } | Remove-Item -Force -ErrorAction SilentlyContinue
}
$sys = @("$env:ProgramFiles\Opera", "${env:ProgramFiles(x86)}\Opera", "${env:ProgramFiles(x86)}\Kingsoft", "$env:ProgramFiles\Kingsoft", "$env:ProgramFiles\Riot Vanguard", "$env:ProgramData\Riot Games", "$env:ProgramFiles\TLauncher", "${env:ProgramFiles(x86)}\TLauncher", "$env:ProgramFiles\BraveSoftware", "${env:ProgramFiles(x86)}\BraveSoftware", "$env:ProgramFiles\Avast Software", "${env:ProgramFiles(x86)}\Avast Software", "$env:ProgramData\AVAST Software")
foreach ($d in $sys) { if (Test-Path $d) { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue } }
# C:\Riot Games / D:\Riot Games dst (Valorant + Riot Client)
Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    $rg = Join-Path $_.Root 'Riot Games'
    if (Test-Path $rg) { Remove-Item $rg -Recurse -Force -ErrorAction SilentlyContinue; Write-Host "  hapus: $rg" }
}
Get-ChildItem "C:\Users\Public\Desktop","C:\ProgramData\Microsoft\Windows\Start Menu\Programs" -Recurse -Include *.lnk -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match 'Opera|Roblox|WPS|^RAV|Riot|VALORANT|TLauncher|Brave|Avast' } | Remove-Item -Force -ErrorAction SilentlyContinue

# scheduled task updater
Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match 'Opera|Roblox|WPS|Kingsoft|^RAV|Riot|VALORANT|Vanguard|TLauncher|Brave|Avast' } | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

# startup entries
foreach ($k in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run') {
    $props = (Get-ItemProperty $k -ErrorAction SilentlyContinue).PSObject.Properties | Where-Object { $_.Name -match 'Opera|WPS|Kingsoft|Roblox|^RAV|OneDrive|Riot|VALORANT|vgtray|TLauncher|Brave|Avast' -and $_.Name -notmatch '^PS' }
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
$ErrorActionPreference = 'SilentlyContinue'
foreach ($b in $bloat) {
    # skip app inti Windows (NonRemovable) & framework supaya tidak muncul error "Removal failed"
    Get-AppxPackage -AllUsers -Name $b | Where-Object { -not $_.NonRemovable -and -not $_.IsFramework } | ForEach-Object {
        try {
            Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction Stop
            Write-Host "  hapus: $($_.Name)"
        } catch {
            # fallback: registrasi sisa/rusak (mis. 0x80070002) kadang bisa dihapus tanpa -AllUsers
            try {
                Remove-AppxPackage -Package $_.PackageFullName -ErrorAction Stop
                Write-Host "  hapus (fallback): $($_.Name)"
            } catch {
                Write-Host "  skip (dipakai sistem): $($_.Name)"
            }
        }
    }
    Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $b } | ForEach-Object {
        try { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction Stop | Out-Null } catch {}
    }
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
Get-PSDrive -PSProvider FileSystem | ForEach-Object { Remove-Item (Join-Path $_.Root '$Recycle.Bin') -Recurse -Force -ErrorAction SilentlyContinue }
#END TEMP

#BEGIN HKCU
$runPat = 'MicrosoftEdgeAutoLaunch|GoogleChromeAutoLaunch|chrome|firefox|msedge|opera|OneDrive|Teams|Spotify|Discord|Skype|Steam|Kingsoft|WPS|Roblox|Riot|vgtray|TLauncher|Brave|Avast'

function Set-V($root, $path, $name, $val, $type = 'DWord') {
    $k = "Registry::$root\$path"
    if (-not (Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
    New-ItemProperty -Path $k -Name $name -Value $val -PropertyType $type -Force | Out-Null
}

function Apply-User($r) {
    # --- Wallpaper: kosong + solid color biru Windows (0,120,215) ---
    Set-V $r 'Control Panel\Desktop' 'Wallpaper' '' 'String'
    Set-V $r 'Control Panel\Colors' 'Background' '0 120 215' 'String'
    Set-V $r 'Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers' 'BackgroundType' 1
    Set-V $r 'Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop' 'NoChangingWallPaper' 1

    # --- Efek visual: best performance ---
    Set-V $r 'Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 2
    Set-V $r 'Control Panel\Desktop' 'UserPreferencesMask' ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) 'Binary'
    Set-V $r 'Control Panel\Desktop' 'DragFullWindows' '0' 'String'
    Set-V $r 'Control Panel\Desktop' 'MenuShowDelay' '0' 'String'
    Set-V $r 'Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0' 'String'
    Set-V $r 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAnimations' 0
    Set-V $r 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ListviewAlphaSelect' 0
    Set-V $r 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ListviewShadow' 0
    Set-V $r 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'IconsOnly' 1
    Set-V $r 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarDa' 0
    Set-V $r 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarMn' 0
    Set-V $r 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowTaskViewButton' 0
    Set-V $r 'Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'StartupDelayInMSec' 0
    Set-V $r 'Software\Microsoft\Windows\DWM' 'EnableAeroPeek' 0
    Set-V $r 'Software\Microsoft\Windows\DWM' 'AlwaysHibernateThumbnails' 0
    Set-V $r 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0
    Set-V $r 'Software\Microsoft\Windows\CurrentVersion\SearchSettings' 'IsDynamicSearchBoxEnabled' 0

    # --- Screensaver off ---
    Set-V $r 'Control Panel\Desktop' 'ScreenSaveActive' '0' 'String'
    Set-V $r 'Control Panel\Desktop' 'ScreenSaverIsSecure' '0' 'String'

    # --- Game bar / DVR off ---
    Set-V $r 'System\GameConfigStore' 'GameDVR_Enabled' 0
    Set-V $r 'Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0

    # --- Background apps, tips, suggestion, auto-install app off ---
    Set-V $r 'Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' 1
    $cdm = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    foreach ($n in 'ContentDeliveryAllowed','OemPreInstalledAppsEnabled','PreInstalledAppsEnabled','PreInstalledAppsEverEnabled','SilentInstalledAppsEnabled','SoftLandingEnabled','SystemPaneSuggestionsEnabled','RotatingLockScreenEnabled','SubscribedContent-310093Enabled','SubscribedContent-338387Enabled','SubscribedContent-338388Enabled','SubscribedContent-338389Enabled','SubscribedContent-353694Enabled','SubscribedContent-353696Enabled') {
        Set-V $r $cdm $n 0
    }

    # --- Hapus auto-start browser & app liar dari Run milik user ---
    $rk = "Registry::$r\Software\Microsoft\Windows\CurrentVersion\Run"
    if (Test-Path $rk) {
        (Get-Item $rk).GetValueNames() | Where-Object { $_ -match $runPat } | ForEach-Object { Remove-ItemProperty $rk -Name $_ -ErrorAction SilentlyContinue }
    }
}

$profiles = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*' -ErrorAction SilentlyContinue |
    Where-Object { $_.PSChildName -like 'S-1-5-21-*' -and $_.ProfileImagePath -like '*\Users\*' }

foreach ($pf in $profiles) {
    $sid = $pf.PSChildName
    $dat = Join-Path $pf.ProfileImagePath 'NTUSER.DAT'
    Write-Host "  user: $($pf.ProfileImagePath)"
    if (Test-Path "Registry::HKEY_USERS\$sid") {
        Apply-User "HKEY_USERS\$sid"
    } elseif ([IO.File]::Exists($dat)) {
        reg load HKU\LabTmp "$dat" | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Apply-User 'HKEY_USERS\LabTmp'
            [gc]::Collect(); Start-Sleep -Milliseconds 500
            reg unload HKU\LabTmp | Out-Null
        }
    }
    Remove-Item "$($pf.ProfileImagePath)\AppData\Roaming\Microsoft\Windows\Themes\TranscodedWallpaper" -Force -ErrorAction SilentlyContinue
    Remove-Item "$($pf.ProfileImagePath)\AppData\Roaming\Microsoft\Windows\Themes\CachedFiles" -Recurse -Force -ErrorAction SilentlyContinue
}

# Profil Default (untuk user baru)
$def = 'C:\Users\Default\NTUSER.DAT'
if ([IO.File]::Exists($def)) {
    reg load HKU\LabDef "$def" | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Apply-User 'HKEY_USERS\LabDef'
        [gc]::Collect(); Start-Sleep -Milliseconds 500
        reg unload HKU\LabDef | Out-Null
    }
}

# Terapkan wallpaper kosong ke sesi yang sedang aktif
try {
    Add-Type -Namespace LabW -Name N -MemberDefinition '[DllImport("user32.dll",CharSet=CharSet.Auto)] public static extern int SystemParametersInfo(int a,int b,string c,int d);'
    [LabW.N]::SystemParametersInfo(20, 0, '', 3) | Out-Null
} catch {}
#END HKCU

#BEGIN STARTUP
$bpat = 'chrome|firefox|msedge|edge|opera|brave|MicrosoftEdgeAutoLaunch|GoogleChromeAutoLaunch'

# Run key sistem
foreach ($k in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run') {
    if (Test-Path $k) {
        (Get-Item $k).GetValueNames() | Where-Object { $_ -match $bpat } | ForEach-Object { Remove-ItemProperty $k -Name $_ -ErrorAction SilentlyContinue; Write-Host "  hapus startup: $_" }
    }
}

# Folder Startup (semua user + per user)
$dirs = @('C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp')
$dirs += Get-ChildItem C:\Users -Directory -ErrorAction SilentlyContinue | ForEach-Object { "$($_.FullName)\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup" }
foreach ($d in $dirs) {
    if (Test-Path $d) {
        Get-ChildItem $d -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $bpat } | Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

# Scheduled task yang membuka browser saat logon
Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match 'AutoLaunch' } | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
#END STARTUP

#BEGIN DESKTOP
$sh = New-Object -ComObject WScript.Shell
$desks = @('C:\Users\Public\Desktop')
Get-ChildItem C:\Users -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin 'Default','Default User','All Users' } | ForEach-Object {
    $desks += "$($_.FullName)\Desktop"
    $desks += (Get-ChildItem $_.FullName -Directory -Filter 'OneDrive*' -ErrorAction SilentlyContinue | ForEach-Object { "$($_.FullName)\Desktop" })
}
foreach ($d in $desks) {
    if (-not (Test-Path $d)) { continue }
    Get-ChildItem $d -Filter *.lnk -Force -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $tp = [Environment]::ExpandEnvironmentVariables($sh.CreateShortcut($_.FullName).TargetPath)
            if ($tp -and -not (Test-Path -LiteralPath $tp)) {
                Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
                Write-Host "  deadlink: $($_.FullName)"
            }
        } catch {}
    }
}
#END DESKTOP
