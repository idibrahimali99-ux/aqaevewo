<?php
declare(strict_types=1);

namespace App\Core;

final class View
{
    /** @param array<string,mixed> $data */
    public static function render(string $template, array $data = [], string $layout = 'main'): void
    {
        extract($data, EXTR_SKIP);
        $viewsRoot = dirname(__DIR__, 2) . '/views';
        $viewFile = $viewsRoot . '/' . trim($template, '/') . '.php';
        if (!is_file($viewFile)) {
            http_response_code(500);
            echo 'View not found: ' . htmlspecialchars($template, ENT_QUOTES, 'UTF-8');
            return;
        }

        ob_start();
        require $viewFile;
        $content = ob_get_clean() ?: '';

        $layoutFile = $viewsRoot . '/layouts/' . $layout . '.php';
        if (!is_file($layoutFile)) {
            echo $content;
            return;
        }
        require $layoutFile;
    }

    public static function partial(string $partial, array $data = []): void
    {
        extract($data, EXTR_SKIP);
        require dirname(__DIR__, 2) . '/views/partials/' . trim($partial, '/') . '.php';
    }
}
