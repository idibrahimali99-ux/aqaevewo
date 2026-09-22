<?php
declare(strict_types=1);

/**
 * Web Town configuration (legacy entry — يُفضَّل config/app.php).
 */
$scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
$host = (string) ($_SERVER['HTTP_HOST'] ?? 'localhost');
$apiHint = 'http://212.224.86.115/api/index.php';
$envEntry = getenv('WEB_TOWN_API_ENTRY');
$apiEntry = (is_string($envEntry) && trim($envEntry) !== '')
    ? trim($envEntry)
    : 'http://127.0.0.1/api/index.php';

return [
    'app_name' => 'عقار تاون',
    'brand_name' => 'عقار تاون | AQAR TOWN',
    'api_entry' => $apiEntry,
    'api_base_hint' => $apiHint,
    'api_fallback_entry' => $scheme . '://' . $host . '/api/index.php',
    'api_config_path' => dirname(__DIR__) . '/api/config.php',
    'support_phone' => '07887444177',
    'session_name' => 'web_town_session',
    'debug' => (bool) (getenv('WEB_TOWN_DEBUG') ?: false),
];
