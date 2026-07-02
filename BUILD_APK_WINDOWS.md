# بناء APK على ويندوز (حل خطأ `android_aot_release_android-arm`)

إذا ظهر عندك:

`Target android_aot_release_android-arm failed` + `AOT snapshotter exited with code -1073741701`

فهذا غالبًا بسبب محاولة Flutter بناء **ARMv7 (32-bit)** على ويندوز.

## الحل (استخدمه دائمًا على هذا الجهاز)

### تطبيق العقار الرئيسي (`real_estate_iraq`)

```powershell
cd "C:\Users\2025\Desktop\aqaevewo\real_estate_iraq"
flutter clean
flutter pub get
flutter build apk --release --target-platform android-arm64
```

أو شغّل السكربت:

```powershell
cd "C:\Users\2025\Desktop\aqaevewo\real_estate_iraq"
.\build_release_apk.ps1
```

### تطبيق الأدمن (`vewo_admin`)

```powershell
cd "C:\Users\2025\Desktop\aqaevewo\vewo_admin"
flutter clean
flutter pub get
flutter build apk --release --target-platform android-arm64
```

أو:

```powershell
cd "C:\Users\2025\Desktop\aqaevewo\vewo_admin"
.\build_release_apk.ps1
```

## مخرجات APK

`build\app\outputs\flutter-apk\app-release.apk`

## ملاحظة

APK بـ **arm64 فقط** يغطي أغلب الهواتف الحديثة. إذا احتجت دعم أجهزة 32-bit قديمة جدًا، غالبًا تحتاج بناء على Linux/CI.

## إذا استمر الفشل حتى مع arm64

ثبّت **Microsoft Visual C++ Redistributable 2015–2022 (x64)** من موقع Microsoft، ثم أعد تشغيل الجهاز.
