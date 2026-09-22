<?php
declare(strict_types=1);

$configPath = dirname(__DIR__) . '/config.php';
if (!is_file($configPath)) {
    fwrite(STDERR, "missing config.php\n");
    exit(1);
}
$config = require $configPath;
$GLOBALS['vewo_config'] = $config;
require_once dirname(__DIR__) . '/lib/backup_telegram.php';

$out = vewo_telegram_send_status();
echo json_encode($out, JSON_UNESCAPED_UNICODE) . PHP_EOL;
exit(!empty($out['ok']) ? 0 : 1);
