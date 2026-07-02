# بناء APK (Release) — تجنب عطل AOT على ويندوز (android-arm)
# شغّل من PowerShell داخل مجلد المشروع:
#   .\build_release_apk.ps1

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

flutter clean
flutter pub get
flutter build apk --release --target-platform android-arm64

Write-Host ""
Write-Host "تم — الملف غالبًا هنا:"
Write-Host "  build\app\outputs\flutter-apk\app-release.apk"
