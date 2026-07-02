<?php
declare(strict_types=1);

function app_config(?string $key = null, mixed $default = null): mixed
{
    static $config = null;
    if ($config === null) {
        $config = require dirname(__DIR__, 2) . '/config.php';
        $apiConfigPath = (string) ($config['api_config_path'] ?? '');
        if ($apiConfigPath !== '' && is_file($apiConfigPath)) {
            $apiConfig = require $apiConfigPath;
            if (is_array($apiConfig) && isset($apiConfig['support_phone'])) {
                $config['support_phone'] = (string) $apiConfig['support_phone'];
            }
        }
    }

    if ($key === null) {
        return $config;
    }

    return $config[$key] ?? $default;
}

function e(mixed $value): string
{
    return htmlspecialchars((string) $value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function url(string $path = '', array $query = []): string
{
    $script = str_replace('\\', '/', (string) ($_SERVER['SCRIPT_NAME'] ?? '/index.php'));
    $base = rtrim(dirname($script), '/');
    $target = ($base === '' || $base === '.') ? '' : $base;
    $path = '/' . ltrim($path, '/');
    $href = $target . ($path === '/' ? '/' : $path);
    if ($query !== []) {
        $href .= '?' . http_build_query($query);
    }

    return $href;
}

function asset_url(string $path): string
{
    return url('public/' . ltrim($path, '/'));
}

function redirect_to(string $path, array $query = []): never
{
    header('Location: ' . url($path, $query));
    exit;
}

function current_path(): string
{
    $uri = parse_url((string) ($_SERVER['REQUEST_URI'] ?? '/'), PHP_URL_PATH) ?: '/';
    $scriptDir = rtrim(str_replace('\\', '/', dirname((string) ($_SERVER['SCRIPT_NAME'] ?? ''))), '/');
    if ($scriptDir !== '' && $scriptDir !== '/' && str_starts_with($uri, $scriptDir)) {
        $uri = substr($uri, strlen($scriptDir)) ?: '/';
    }

    return '/' . trim($uri, '/');
}

function is_active_path(string $path): bool
{
    $current = current_path();
    return $current === '/' . trim($path, '/') || ($path !== '/' && str_starts_with($current, '/' . trim($path, '/')));
}

function money_iqd(mixed $amount): string
{
    if ($amount === null || $amount === '') {
        return 'السعر عند الاتصال';
    }

    return number_format((float) $amount, 0) . ' د.ع';
}

function compact_number(mixed $value): string
{
    $n = (int) ($value ?? 0);
    if ($n >= 1000000) {
        return round($n / 1000000, 1) . 'M';
    }
    if ($n >= 1000) {
        return round($n / 1000, 1) . 'K';
    }

    return (string) $n;
}

function pick(array $array, string $key, mixed $default = ''): mixed
{
    return $array[$key] ?? $default;
}

function first_image(array $item): string
{
    $candidates = [
        $item['thumb_url'] ?? '',
        $item['image_url'] ?? '',
        $item['cover_url'] ?? '',
    ];
    if (isset($item['image_urls']) && is_array($item['image_urls']) && !empty($item['image_urls'])) {
        array_unshift($candidates, (string) $item['image_urls'][0]);
    }

    foreach ($candidates as $candidate) {
        $candidate = trim((string) $candidate);
        if ($candidate !== '') {
            return $candidate;
        }
    }

    return asset_url('assets/placeholder-property.svg');
}
