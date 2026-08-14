<?php
declare(strict_types=1);

/**
 * يضبط CORS على بكت R2 حتى تُعرض الصور/الفيديو من التطبيق والويب بدون حظر.
 * التشغيل من سطر الأوامر: php api/scripts/setup_r2_cors.php
 */
$configPath = dirname(__DIR__) . '/config.php';
if (!is_file($configPath)) {
    fwrite(STDERR, "Missing config.php\n");
    exit(1);
}

/** @var array $config */
$config = require $configPath;
require dirname(__DIR__) . '/lib/r2_storage.php';

function json_error(int $code, string $msg): void
{
    fwrite(STDERR, "ERR $code: $msg\n");
    exit(1);
}

if (!vewo_r2_enabled($config)) {
    fwrite(STDERR, "R2 is not enabled / incomplete in config.php\n");
    exit(1);
}

vewo_r2_put_cors(vewo_r2_config($config));
echo "CORS OK for bucket " . (vewo_r2_config($config)['bucket'] ?? '') . "\n";
