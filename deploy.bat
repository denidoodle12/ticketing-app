@echo off

:: Read version from pubspec.yaml
for /f "tokens=2 delims=: " %%a in ('findstr /r "^version:" pubspec.yaml') do set VERSION=%%a

echo ========================================
echo  Deploying Ticketing App v%VERSION%
echo ========================================
echo.

:: Build APK
echo [1/2] Building APK...
call flutter build apk --release
if %errorlevel% neq 0 (
    echo Build failed!
    exit /b 1
)

echo.
echo [2/2] Uploading to Firebase App Distribution...

:: Set release notes
if "%~1"=="" (
    set "NOTES=v%VERSION%"
) else (
    set "NOTES=v%VERSION% - %~1"
)

:: Upload to Firebase
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk --app 1:866621809782:android:34d880d6e90da18c93eb57 --groups "enigma-ticketing-app" --release-notes "%NOTES%"

echo.
echo ========================================
echo  Done! QA akan menerima notifikasi.
echo  Version: v%VERSION%
echo ========================================
