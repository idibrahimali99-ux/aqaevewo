<?php
declare(strict_types=1);

$scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
$host = (string) ($_SERVER['HTTP_HOST'] ?? 'localhost');

return [
    'name' => 'عقار تاون',
    'brand' => 'Aqar Town | عقار تاون',
    'tagline' => 'منصة عقارية عراقية احترافية',
    'locale' => 'ar_IQ',
    'timezone' => 'Asia/Baghdad',
    'primary_color' => '#F5B400',
    'api_entry' => getenv('WEB_TOWN_API_ENTRY') ?: $scheme . '://' . $host . '/api/index.php',
    /** يجب أن يطابق عنوان API في vewo_admin (VEWO_API_BASE) + /index.php */
    'api_base_hint' => 'http://31.57.156.84/api/index.php',
    'api_config_path' => dirname(__DIR__) . '/../api/config.php',
    'support_phone' => '07871456361',
    'session_name' => 'aqar_town_web',
    'debug' => (bool) (getenv('WEB_TOWN_DEBUG') ?: false),
    'google_maps_key' => getenv('GOOGLE_MAPS_KEY') ?: '',
    'base_path' => '/web-town',
];
