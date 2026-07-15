<?php
declare(strict_types=1);

require dirname(__DIR__) . '/app/bootstrap.php';

use App\Core\Router;

$router = new Router();
(require dirname(__DIR__) . '/routes/web.php')($router);
(require dirname(__DIR__) . '/routes/admin.php')($router);

$uri = parse_url((string) ($_SERVER['REQUEST_URI'] ?? '/'), PHP_URL_PATH) ?: '/';
$base = base_path();
if ($base !== '' && str_starts_with($uri, $base)) {
    $uri = substr($uri, strlen($base)) ?: '/';
}

$router->dispatch(request_method(), $uri);
