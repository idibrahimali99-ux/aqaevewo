<?php
declare(strict_types=1);

namespace App\Middleware;

final class AdminMiddleware
{
    public static function handle(): void
    {
        require_admin_api_token();
    }
}
