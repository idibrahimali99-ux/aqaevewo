<?php
declare(strict_types=1);

require_once __DIR__ . '/Support/helpers.php';

$sessionName = (string) app_config('session_name', 'web_town_session');
session_name($sessionName);
session_set_cookie_params([
    'lifetime' => 0,
    'path' => '/',
    'secure' => !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off',
    'httponly' => true,
    'samesite' => 'Lax',
]);
session_start();

require_once __DIR__ . '/Support/csrf.php';
require_once __DIR__ . '/Services/ApiClient.php';
require_once __DIR__ . '/Support/auth.php';

function render(string $view, array $data = [], string $layout = 'app'): void
{
    extract($data, EXTR_SKIP);
    $viewFile = dirname(__DIR__) . '/views/' . trim($view, '/') . '.php';
    if (!is_file($viewFile)) {
        http_response_code(500);
        echo 'View not found: ' . e($view);
        return;
    }

    ob_start();
    require $viewFile;
    $content = ob_get_clean();

    require dirname(__DIR__) . '/views/layouts/' . $layout . '.php';
}

function page_title(string $title = ''): string
{
    $app = (string) app_config('app_name', 'ويب تاون');
    return $title === '' ? $app : $title . ' | ' . $app;
}

function request_method(): string
{
    return strtoupper((string) ($_SERVER['REQUEST_METHOD'] ?? 'GET'));
}
