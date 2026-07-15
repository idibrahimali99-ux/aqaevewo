<?php
declare(strict_types=1);

namespace App\Core;

final class App
{
    private static ?self $instance = null;

    /** @var array<string,mixed> */
    private array $config;

    private function __construct()
    {
        $this->config = require dirname(__DIR__, 2) . '/config/app.php';
        $apiPath = (string) ($this->config['api_config_path'] ?? '');
        if ($apiPath !== '' && is_file($apiPath)) {
            $apiCfg = require $apiPath;
            if (is_array($apiCfg) && isset($apiCfg['support_phone'])) {
                $this->config['support_phone'] = (string) $apiCfg['support_phone'];
            }
        }
    }

    public static function getInstance(): self
    {
        return self::$instance ??= new self();
    }

    public static function config(?string $key = null, mixed $default = null): mixed
    {
        $cfg = self::getInstance()->config;
        if ($key === null) {
            return $cfg;
        }

        return $cfg[$key] ?? $default;
    }
}
