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
    /** رقم الدعم لزر «اتصال» في تطبيق العقار (صيغة 07XXXXXXXXX) */
    'support_phone' => '07871456361',

    /**
     * إعدادات Push (Firebase Cloud Messaging).
     * ضع Server Key (Legacy) أو اتركه فارغاً إن لم تفعّل FCM بعد.
     */
    'fcm' => [
        // Legacy server key (Authorization: key=XXXX)
        'server_key' => '',
    ],
];
