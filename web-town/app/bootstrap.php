<?php
declare(strict_types=1);

use App\Core\App;

spl_autoload_register(static function (string $class): void {
    $prefix = 'App\\';
    if (!str_starts_with($class, $prefix)) {
        return;
    }
    $relative = str_replace('\\', '/', substr($class, strlen($prefix)));
    $file = __DIR__ . '/' . $relative . '.php';
    if (is_file($file)) {
        require $file;
    }
});

require __DIR__ . '/Helpers/functions.php';
require __DIR__ . '/Helpers/csrf.php';
require __DIR__ . '/Helpers/auth.php';
require __DIR__ . '/Helpers/admin.php';
require __DIR__ . '/Helpers/favorites.php';
require __DIR__ . '/Helpers/chat.php';

$sessionName = (string) App::config('session_name', 'aqar_town_web');
session_name($sessionName);
session_set_cookie_params([
    'lifetime' => 0,
    'path' => '/',
    'secure' => !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off',
    'httponly' => true,
    'samesite' => 'Lax',
]);
session_start();

function request_method(): string
{
    return strtoupper((string) ($_SERVER['REQUEST_METHOD'] ?? 'GET'));
}

function page_title(string $title = ''): string
{
    $app = (string) App::config('name', '\u0639\u0642\u0627\u0631 \u062a\u0627\u0648\u0646');
    return $title === '' ? $app : $title . ' | ' . $app;
}
