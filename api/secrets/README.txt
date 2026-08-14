ضع هنا ملف Service Account من Firebase:
  firebase-sa.json

من Firebase Console:
  Project settings → Service accounts → Generate new private key

ثم في config.php يجب أن يكون:
  'service_account_file' => 'secrets/firebase-sa.json',

═══════════════════════════════════════
Android
═══════════════════════════════════════
  real_estate_iraq/android/app/google-services.json
    package: com.aqaevewo.real_estate_iraq

  vewo_admin/android/app/google-services.json
    package: com.vewo.vewo_admin

═══════════════════════════════════════
iPhone / iOS  (مهم)
═══════════════════════════════════════
1) أضف تطبيقَي iOS في نفس مشروع Firebase:

  عقار تاون:
    Bundle ID: com.idibrahimali99.aqaevewo
    ضع الملف: real_estate_iraq/ios/Runner/GoogleService-Info.plist

  الأدمن:
    Bundle ID: com.idibrahimali99.aqaevewo.admin
    ضع الملف: vewo_admin/ios/Runner/GoogleService-Info.plist

2) APNs في Firebase (بدون هذا لن تصل إشعارات الآيفون):
   Apple Developer → Keys → إنشاء مفتاح مع Apple Push Notifications (APNs)
   ثم Firebase → Project settings → Cloud Messaging → Apple app configuration
   → Upload APNs Authentication Key (.p8) + Key ID + Team ID

3) في Xcode (مرة واحدة لكل تطبيق):
   Runner → Signing & Capabilities
   → تأكد من تفعيل Push Notifications
   → Background Modes → Remote notifications (موجود في Info.plist)

4) للرفع على App Store:
   غيّر في Runner.entitlements قيمة aps-environment إلى production
   (development كافية للتجربة على الجهاز)

اختبار السيرفر بعد الضبط:
  GET  /api/?r=health          → "fcm":{"ready":true,"mode":"http_v1"}
  POST /api/?r=admin/fcm/test  → إشعار تجريبي لجهاز الأدمن
