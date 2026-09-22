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

$watch = vewo_watchdog_tick();
echo json_encode($watch, JSON_UNESCAPED_UNICODE) . PHP_EOL;
exit(!empty($watch['ok']) ? 0 : 2);
