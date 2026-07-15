<?php
declare(strict_types=1);

namespace App\Middleware;

final class AuthMiddleware
{
    public static function handle(): void
    {
        require_login();
    }
}
