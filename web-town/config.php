<?php
declare(strict_types=1);

/**
 * Web Town configuration.
 *
 * Keep this project outside the API directory, but point it to the existing API
 * entry point. On XAMPP the default becomes: http://localhost/api/index.php
 */
$scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
$host = (string) ($_SERVER['HTTP_HOST'] ?? 'localhost');

return [
    'app_name' => 'ويب تاون',
    'brand_name' => 'عقار تاون | Web Town',
    'api_entry' => getenv('WEB_TOWN_API_ENTRY') ?: $scheme . '://' . $host . '/api/index.php',
    'api_config_path' => dirname(__DIR__) . '/api/config.php',
    'support_phone' => '07871456361',
    'session_name' => 'web_town_session',
    'debug' => (bool) (getenv('WEB_TOWN_DEBUG') ?: false),
];
