@echo off
setlocal EnableExtensions
title Setup Lab PC - SEB UT

:: ---- Konfigurasi ----
set "SHARE=\\10.10.0.138\shared"
set "DRV=Z:"
:: Isi kalau share butuh login (kosongkan kalau tidak)
set "SHARE_USER="
set "SHARE_PASS="

:: ---- Auto elevate ke Administrator ----
:: (map drive dibuat SETELAH elevate, karena drive non-admin tidak terlihat di sesi admin)
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: ---- Map share ----
echo [*] Map %SHARE% ke %DRV%
net use %DRV% /delete /y >nul 2>&1
if defined SHARE_USER (
    net use %DRV% "%SHARE%" /user:%SHARE_USER% %SHARE_PASS% /persistent:no
) else (
    net use %DRV% "%SHARE%" /persistent:no
)
if errorlevel 1 (
    echo [!] Gagal map share %SHARE%. Cek koneksi / kredensial.
    timeout /t 10 >nul
    exit /b 1
)

pushd %DRV%\

:: ---- Jalankan semua script (urutan tetap) ----
:: "< nul" supaya pause di dalam script tidak menahan proses
:: "cmd /c" supaya exit di dalam script tidak menutup runner ini
for %%F in (disable-setup-nag lab-maintenance maintenance reset-sharing seb-ut-prereq) do (
    if exist "%DRV%\%%F.bat" (
        echo [*] Jalankan %%F.bat
        cmd /c "%DRV%\%%F.bat" < nul
    ) else (
        echo [!] Tidak ditemukan: %%F.bat
    )
)

:: ---- Terakhir: SUO Exam Browser ----
set "SUO="
for %%F in ("%DRV%\SUO-Exam-Browser*Setup.exe") do set "SUO=%%~fF"
if defined SUO (
    echo [*] Jalankan %SUO%
    start "" /wait "%SUO%"
) else (
    echo [!] Installer SUO Exam Browser tidak ditemukan.
)

:: ---- Hapus map ----
popd
net use %DRV% /delete /y >nul 2>&1
echo [*] Selesai. Map %DRV% dihapus.
exit /b 0
