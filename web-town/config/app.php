<?php
declare(strict_types=1);

$scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
$host = (string) ($_SERVER['HTTP_HOST'] ?? 'localhost');

/**
 * رابط API الموثوق للإنتاج (تجنّب فشل طلبات السيرفر لنفسه عبر الدومين).
 * يمكن تجاوزه بمتغير البيئة WEB_TOWN_API_ENTRY.
 */
$apiHint = 'http://212.224.86.115/api/index.php';
$envEntry = getenv('WEB_TOWN_API_ENTRY');
$apiEntry = (is_string($envEntry) && trim($envEntry) !== '')
    ? trim($envEntry)
    : 'http://127.0.0.1/api/index.php';

return [
    'name' => 'عقار تاون',
    'brand' => 'Aqar Town | عقار تاون',
    'tagline' => 'منصة عقارية عراقية احترافية',
    'locale' => 'ar_IQ',
    'timezone' => 'Asia/Baghdad',
    'primary_color' => '#F5B400',
    'api_entry' => $apiEntry,
    /** احتياطي إن فشل الرابط الأساسي */
    'api_base_hint' => $apiHint,
    'api_fallback_entry' => $scheme . '://' . $host . '/api/index.php',
    'api_config_path' => dirname(__DIR__) . '/../api/config.php',
    'support_phone' => '07887444177',
    'session_name' => 'aqar_town_web',
    'debug' => (bool) (getenv('WEB_TOWN_DEBUG') ?: false),
    'google_maps_key' => getenv('GOOGLE_MAPS_KEY') ?: '',
    'base_path' => '/web-town',
];
