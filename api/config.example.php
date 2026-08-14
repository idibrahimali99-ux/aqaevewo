<?php
/**
 * انسخ هذا الملف إلى config.php وعدّل القيم.
 * لا ترفع config.php إلى Git إذا كان يحتوي أسرارًا.
 */
return [
    'db' => [
        'host' => '127.0.0.1',
        'port' => 3306,
        'name' => 'vewo',
        'user' => 'root',
        'pass' => '',
        'charset' => 'utf8mb4',
    ],
    'cors' => [
        'allow_origin' => '*', // للتطوير فقط؛ في الإنتاج حدد نطاق تطبيقك
    ],
    /** اختياري: عنوان الـAPI العلني إن كان يختلف عن الاستنتاج من الطلب (بروكسي، CDN، إلخ) */
    'public_base_url' => '',
    /**
     * Cloudflare R2 — تخزين الصور/الفيديو/وسائط الشات.
     * فعّل enabled بعد تعبئة access_key / secret_key / bucket / public_base_url.
     * مهم للإنتاج: استخدم Custom Domain بدل pub-*.r2.dev (الأخير محدود السرعة وقد يمنع عرض الصور).
     * وفي Settings → CORS Policy أضف GET/HEAD مع AllowedOrigins "*".
     */
    'r2' => [
        'enabled' => false, // فعّل في config.php بعد وضع المفاتيح
        'account_id' => 'b77883ec5147e23734a32b173e11a1cc',
        'endpoint' => 'https://b77883ec5147e23734a32b173e11a1cc.r2.cloudflarestorage.com',
        'region' => 'auto',
        'bucket' => 'aqartown',
        'access_key' => '', // من Create Account API token → Access Key ID
        'secret_key' => '', // من Create Account API token → Secret Access Key
        'public_base_url' => 'https://pub-54323270cbf4445f8180abd7e7138cc5.r2.dev',
    ],
    /** رقم الدعم لزر «اتصال» في تطبيق العقار (صيغة 07XXXXXXXXX) */
    'support_phone' => '07887444177',

    /**
     * إعدادات Push (Firebase Cloud Messaging).
     * الأفضل استخدام HTTP v1 عبر service account (لا تحتاج بايثون).
     *
     * خطوات التشغيل:
     * 1) Firebase Console → Project settings → Service accounts → Generate new private key
     * 2) ضع الملف في api/secrets/firebase-sa.json (خارج Git) أو الصق JSON في service_account_json
     * 3) تأكد أن تطبيقَي Flutter يستخدمان نفس Firebase project
     * 4) iOS: ارفع APNs Auth Key (.p8) في Firebase Cloud Messaging
     *    Bundle IDs:
     *      com.idibrahimali99.aqaevewo
     *      com.idibrahimali99.aqaevewo.admin
     *    وضع GoogleService-Info.plist داخل ios/Runner لكل تطبيق
     *
     * تذكيرات دورية (اختياري):
     * cron يومياً: GET /api/?r=cron/push-reminders&key=YOUR_CRON_SECRET
     */
    'fcm' => [
        // Firebase project id، أو يُقرأ من service account إذا تركته فارغاً.
        'project_id' => '',
        // ضع JSON كامل كـ string، أو استخدم service_account_file أدناه.
        'service_account_json' => '',
        // مسار ملف service account JSON نسبةً لمجلد api أو مسار كامل.
        'service_account_file' => 'secrets/firebase-sa.json',
        // Legacy server key (Authorization: key=XXXX) كـ fallback فقط.
        'server_key' => '',
    ],

    /** مفتاح سري لمسار cron/push-reminders — غيّره في config.php */
    'cron_secret' => '',
];
