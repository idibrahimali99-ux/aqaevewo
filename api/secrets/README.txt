ضع هنا ملف Service Account من Firebase:
  firebase-sa.json

من Firebase Console:
  Project settings → Service accounts → Generate new private key

ثم في config.php يجب أن يكون:
  'service_account_file' => 'secrets/firebase-sa.json',

═══════════════════════════════════════
تحديث سيرفر لينكس (مهم)
═══════════════════════════════════════
ارفع من جهازك إلى المسار على السيرفر (مثال /var/www/html/api):

  api/index.php
  api/lib/extend.php
  api/config.php          (إن لم يكن موجوداً مسبقاً)
  api/secrets/firebase-sa.json

ثم تحقق:
  curl "http://212.224.86.115/api/?r=health"
  يجب أن ترى: "fcm":{"ready":true,"mode":"http_v1"}

═══════════════════════════════════════
Android
═══════════════════════════════════════
  real_estate_iraq/android/app/google-services.json
    package: com.aqaevewo.real_estate_iraq

  vewo_admin/android/app/google-services.json
    package: com.vewo.vewo_admin

═══════════════════════════════════════
iPhone / iOS  (سبب الشائع: يعمل داخل التطبيق فقط)
═══════════════════════════════════════
إشعارات داخل التطبيق قد تأتي من العرض المحلي (foreground) حتى لو APNs غير مضبوط.
بدون مفتاح APNs لن يصل إشعار والآيفون مغلق/في الخلفية.

1) أضف تطبيقَي iOS في نفس مشروع Firebase:

  عقار تاون:
    Bundle ID: com.idibrahimali99.aqaevewo
    ضع الملف: real_estate_iraq/ios/Runner/GoogleService-Info.plist

  الأدمن:
    Bundle ID: com.idibrahimali99.aqaevewo.admin
    ضع الملف: vewo_admin/ios/Runner/GoogleService-Info.plist

2) APNs في Firebase (إلزامي لـ iOS خارج التطبيق):
   Apple Developer → Keys → إنشاء مفتاح مع Apple Push Notifications (APNs)
   نزّل ملف .p8 واحفظ Key ID + Team ID
   ثم Firebase → Project settings → Cloud Messaging → Apple app configuration
   → Upload APNs Authentication Key (.p8) + Key ID + Team ID
   ارفع المفتاح لكلا تطبيقَي iOS إن ظهر كل تطبيق منفصل

3) في Xcode (مرة واحدة لكل تطبيق):
   Runner → Signing & Capabilities
   → Push Notifications مفعّل
   → Background Modes → Remote notifications
   Debug يستخدم RunnerDebug.entitlements (development)
   Release/Profile يستخدم Runner.entitlements (production)

4) اختبر على جهاز حقيقي (المحاكي لا يستقبل push حقيقي):
   - افتح الأدمن → إعدادات → اختبار Firebase (FCM)
   - أغلق التطبيق تماماً من المهام
   - إن ظهر خطأ InvalidApnsCredential → الخطوة 2 غير مكتملة

اختبار السيرفر بعد الضبط:
  GET  /api/?r=health          → "fcm":{"ready":true,"mode":"http_v1"}
  POST /api/?r=admin/fcm/test  → يعيد sent/failed/errors/hint
