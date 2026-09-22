<?php
declare(strict_types=1);

/**
 * نسخ احتياطي كل ساعة: SQL + أرشيف api/web-town وإرسالهما إلى تيليغرام.
 */

function vewo_telegram_secrets_path(): string
{
    return dirname(__DIR__) . '/secrets/telegram.json';
}

/** @return array{bot_token:string,chat_id:string} */
function vewo_telegram_settings(): array
{
    $cfg = $GLOBALS['vewo_config'] ?? [];
    $token = trim((string) (is_array($cfg['telegram'] ?? null) ? ($cfg['telegram']['bot_token'] ?? '') : ''));
    $chatId = trim((string) (is_array($cfg['telegram'] ?? null) ? ($cfg['telegram']['chat_id'] ?? '') : ''));
    $path = vewo_telegram_secrets_path();
    if (is_file($path)) {
        $raw = json_decode((string) file_get_contents($path), true);
        if (is_array($raw)) {
            if (trim((string) ($raw['bot_token'] ?? '')) !== '') {
                $token = trim((string) $raw['bot_token']);
            }
            if (trim((string) ($raw['chat_id'] ?? '')) !== '') {
                $chatId = trim((string) $raw['chat_id']);
            }
        }
    }

    return ['bot_token' => $token, 'chat_id' => $chatId];
}

function vewo_telegram_save_settings(string $botToken, string $chatId): bool
{
    $dir = dirname(vewo_telegram_secrets_path());
    if (!is_dir($dir) && !mkdir($dir, 0700, true) && !is_dir($dir)) {
        return false;
    }
    $current = vewo_telegram_settings();
    if ($botToken === '') {
        $botToken = $current['bot_token'];
    }
    if ($chatId === '') {
        $chatId = $current['chat_id'];
    }
    $json = json_encode([
        'bot_token' => $botToken,
        'chat_id' => $chatId,
        'updated_at' => date('c'),
    ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);

    return file_put_contents(vewo_telegram_secrets_path(), $json) !== false;
}

function vewo_telegram_control_keyboard(): array
{
    return [
        'inline_keyboard' => [
            [
                ['text' => 'حالة السيرفر', 'callback_data' => 'aqar:status'],
                ['text' => 'إصلاح الويب', 'callback_data' => 'aqar:repair'],
            ],
            [
                ['text' => 'نسخ احتياطي', 'callback_data' => 'aqar:backup'],
            ],
        ],
    ];
}

function vewo_telegram_send_message(string $text, ?array $replyMarkup = null): array
{
    $s = vewo_telegram_settings();
    if ($s['bot_token'] === '' || $s['chat_id'] === '') {
        return ['ok' => false, 'error' => 'تيليغرام غير مضبوط'];
    }
    $url = 'https://api.telegram.org/bot' . $s['bot_token'] . '/sendMessage';
    $payload = [
        'chat_id' => $s['chat_id'],
        'text' => $text,
        'disable_web_page_preview' => true,
    ];
    if ($replyMarkup !== null) {
        $payload['reply_markup'] = json_encode($replyMarkup, JSON_UNESCAPED_UNICODE);
    }
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => $payload,
        CURLOPT_CONNECTTIMEOUT => 8,
        CURLOPT_TIMEOUT => 20,
    ]);
    $raw = curl_exec($ch);
    $err = curl_error($ch);
    curl_close($ch);
    if ($raw === false) {
        return ['ok' => false, 'error' => $err !== '' ? $err : 'فشل إرسال تيليغرام'];
    }
    $decoded = json_decode((string) $raw, true);

    return is_array($decoded) ? $decoded : ['ok' => false, 'error' => 'استجابة تيليغرام غير مفهومة'];
}

function vewo_telegram_send_document(string $filePath, string $caption): array
{
    $s = vewo_telegram_settings();
    if ($s['bot_token'] === '' || $s['chat_id'] === '') {
        return ['ok' => false, 'error' => 'تيليغرام غير مضبوط — احفظ التوكن ومعرّف المحادثة من الإعدادات'];
    }
    if (!is_file($filePath)) {
        return ['ok' => false, 'error' => 'الملف غير موجود'];
    }
    $size = (int) filesize($filePath);
    if ($size < 1) {
        return ['ok' => false, 'error' => 'ملف فارغ'];
    }
    if ($size > 49 * 1024 * 1024) {
        return ['ok' => false, 'error' => 'الملف أكبر من حد تيليغرام (50MB)'];
    }
    $url = 'https://api.telegram.org/bot' . $s['bot_token'] . '/sendDocument';
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => [
            'chat_id' => $s['chat_id'],
            'caption' => mb_substr($caption, 0, 900),
            'document' => new CURLFile($filePath, 'application/octet-stream', basename($filePath)),
        ],
        CURLOPT_CONNECTTIMEOUT => 15,
        CURLOPT_TIMEOUT => 180,
    ]);
    $raw = curl_exec($ch);
    $err = curl_error($ch);
    curl_close($ch);
    if ($raw === false) {
        return ['ok' => false, 'error' => $err !== '' ? $err : 'فشل رفع الملف إلى تيليغرام'];
    }
    $decoded = json_decode((string) $raw, true);

    return is_array($decoded) ? $decoded : ['ok' => false, 'error' => 'استجابة تيليغرام غير مفهومة'];
}

/** @return array<string,mixed> */
function vewo_collect_server_stats(): array
{
    $load = function_exists('sys_getloadavg') ? sys_getloadavg() : [0, 0, 0];
    $cores = 1;
    $cpuModel = php_uname('m');
    if (is_readable('/proc/cpuinfo')) {
        $cpuinfo = (string) file_get_contents('/proc/cpuinfo');
        $cores = max(1, preg_match_all('/^processor\s*:/m', $cpuinfo));
        if (preg_match('/^model name\s*:\s*(.+)$/m', $cpuinfo, $m)) {
            $cpuModel = trim($m[1]);
        }
    }
    $memTotal = 0;
    $memAvail = 0;
    if (is_readable('/proc/meminfo')) {
        $mem = (string) file_get_contents('/proc/meminfo');
        if (preg_match('/MemTotal:\s+(\d+)/', $mem, $m)) {
            $memTotal = (int) $m[1] * 1024;
        }
        if (preg_match('/MemAvailable:\s+(\d+)/', $mem, $m)) {
            $memAvail = (int) $m[1] * 1024;
        }
    }
    $root = DIRECTORY_SEPARATOR === '\\' ? 'C:\\' : '/';
    $diskTotal = @disk_total_space($root) ?: 0;
    $diskFree = @disk_free_space($root) ?: 0;
    $rx = 0;
    $tx = 0;
    if (is_readable('/proc/net/dev')) {
        foreach (preg_split('/\R/', (string) file_get_contents('/proc/net/dev')) as $line) {
            if (!str_contains($line, ':') || str_contains($line, 'lo:')) {
                continue;
            }
            $parts = preg_split('/\s+/', trim($line));
            if (is_array($parts) && count($parts) >= 10) {
                $rx += (int) $parts[1];
                $tx += (int) $parts[9];
            }
        }
    }
    $started = microtime(true);
    $sample = is_file(__FILE__) ? (string) file_get_contents(__FILE__) : 'ok';
    $elapsedMs = max(1, (int) round((microtime(true) - $started) * 1000));
    $bytes = max(1, strlen($sample));
    $localMBps = round(($bytes / 1024 / 1024) / max(0.001, (microtime(true) - $started)), 2);

    return [
        'ok' => true,
        'time' => date('c'),
        'timezone' => date_default_timezone_get(),
        'country' => 'العراق',
        'city' => 'السيرفر',
        'hostname' => php_uname('n'),
        'os' => php_uname('s') . ' ' . php_uname('r'),
        'php' => PHP_VERSION,
        'cpu_model' => $cpuModel,
        'cpu_cores' => $cores,
        'load_1' => is_array($load) ? round((float) ($load[0] ?? 0), 2) : 0,
        'load_5' => is_array($load) ? round((float) ($load[1] ?? 0), 2) : 0,
        'load_15' => is_array($load) ? round((float) ($load[2] ?? 0), 2) : 0,
        'cpu_usage_pct' => $cores > 0 ? round(min(100, ((float) ($load[0] ?? 0) / $cores) * 100), 1) : 0,
        'memory_total' => $memTotal,
        'memory_available' => $memAvail,
        'memory_used' => max(0, $memTotal - $memAvail),
        'disk_total' => $diskTotal,
        'disk_free' => $diskFree,
        'net_rx' => $rx,
        'net_tx' => $tx,
        'local_read_ms' => $elapsedMs,
        'local_mbps' => $localMBps,
        'uptime' => is_readable('/proc/uptime') ? (float) explode(' ', (string) file_get_contents('/proc/uptime'))[0] : 0,
    ];
}

function vewo_format_bytes(int $bytes): string
{
    if ($bytes < 1024) {
        return $bytes . ' B';
    }
    $units = ['KB', 'MB', 'GB', 'TB'];
    $v = (float) $bytes;
    foreach ($units as $u) {
        $v /= 1024;
        if ($v < 1024) {
            return round($v, 1) . ' ' . $u;
        }
    }

    return round($v / 1024, 1) . ' TB';
}

function vewo_backup_dir(): string
{
    $dir = dirname(__DIR__, 2) . '/backups';
    if (!is_dir($dir)) {
        @mkdir($dir, 0700, true);
    }

    return $dir;
}

function vewo_run_mysqldump(string $outFile): array
{
    $cfg = $GLOBALS['vewo_config'] ?? [];
    $db = is_array($cfg['db'] ?? null) ? $cfg['db'] : [];
    $host = (string) ($db['host'] ?? '127.0.0.1');
    $port = (int) ($db['port'] ?? 3306);
    $name = (string) ($db['name'] ?? '');
    $user = (string) ($db['user'] ?? '');
    $pass = (string) ($db['pass'] ?? '');
    if ($name === '' || $user === '') {
        return ['ok' => false, 'error' => 'إعدادات قاعدة البيانات ناقصة'];
    }
    $mysqldump = trim((string) shell_exec('command -v mysqldump 2>/dev/null')) ?: 'mysqldump';
    $tmpCnf = tempnam(sys_get_temp_dir(), 'aqar-my');
    if ($tmpCnf === false) {
        return ['ok' => false, 'error' => 'تعذر إنشاء ملف مؤقت'];
    }
    $cnf = "[client]\nuser=" . $user . "\npassword=" . $pass . "\nhost=" . $host . "\nport=" . $port . "\ndefault-character-set=utf8mb4\n";
    file_put_contents($tmpCnf, $cnf);
    $cmd = escapeshellcmd($mysqldump)
        . ' --defaults-extra-file=' . escapeshellarg($tmpCnf)
        . ' --single-transaction --quick --routines --triggers '
        . escapeshellarg($name)
        . ' | gzip -9 > ' . escapeshellarg($outFile);
    $code = 0;
    system($cmd, $code);
    @unlink($tmpCnf);
    if ($code !== 0 || !is_file($outFile) || filesize($outFile) < 32) {
        return ['ok' => false, 'error' => 'فشل mysqldump'];
    }

    return ['ok' => true, 'path' => $outFile, 'bytes' => (int) filesize($outFile)];
}

function vewo_run_project_archive(string $outFile): array
{
    $root = dirname(__DIR__, 2);
    $api = $root . '/api';
    $web = $root . '/web-town';
    if (!is_dir($api) || !is_dir($web)) {
        return ['ok' => false, 'error' => 'مجلدات المشروع غير موجودة'];
    }
    $cmd = 'tar -czf ' . escapeshellarg($outFile)
        . ' -C ' . escapeshellarg($root)
        . ' --exclude=api/.git --exclude=web-town/.git'
        . ' --exclude=api/node_modules --exclude=web-town/node_modules'
        . ' --exclude=api/_deploy_linux_fcm --exclude=backups'
        . ' --exclude=api/secrets --exclude="*.log"'
        . ' api web-town';
    $code = 0;
    system($cmd, $code);
    if ($code !== 0 || !is_file($outFile) || filesize($outFile) < 32) {
        return ['ok' => false, 'error' => 'فشل أرشيف المشروع'];
    }

    return ['ok' => true, 'path' => $outFile, 'bytes' => (int) filesize($outFile)];
}

/** @return array<string,mixed> */
function vewo_hourly_backup_run(): array
{
    $stamp = date('Ymd-His');
    $dir = vewo_backup_dir();
    $sqlFile = $dir . '/db-' . $stamp . '.sql.gz';
    $projFile = $dir . '/project-' . $stamp . '.tar.gz';
    $sql = vewo_run_mysqldump($sqlFile);
    $proj = vewo_run_project_archive($projFile);
    $sent = [];
    if (!empty($sql['ok'])) {
        $sent['sql'] = vewo_telegram_send_document(
            $sqlFile,
            'نسخة SQL — عقار تاون ' . date('Y-m-d H:i')
        );
    } else {
        $sent['sql'] = $sql;
    }
    if (!empty($proj['ok'])) {
        $sent['project'] = vewo_telegram_send_document(
            $projFile,
            'نسخة المشروع api+ويب — عقار تاون ' . date('Y-m-d H:i')
        );
    } else {
        $sent['project'] = $proj;
    }
    $sqlOk = !empty($sent['sql']['ok']);
    $projOk = !empty($sent['project']['ok']);
    vewo_telegram_send_message(
        "نسخ احتياطي ساعي\n"
        . 'SQL: ' . ($sqlOk ? 'أُرسلت' : (string) ($sent['sql']['error'] ?? 'فشل')) . "\n"
        . 'المشروع: ' . ($projOk ? 'أُرسلت' : (string) ($sent['project']['error'] ?? 'فشل')),
        vewo_telegram_control_keyboard()
    );
    foreach (glob($dir . '/*.{sql.gz,tar.gz}', GLOB_BRACE) ?: [] as $old) {
        if (is_file($old) && filemtime($old) < time() - 3 * 86400) {
            @unlink($old);
        }
    }

    return [
        'ok' => $sqlOk && $projOk,
        'sql' => $sent['sql'],
        'project' => $sent['project'],
        'sql_bytes' => $sql['bytes'] ?? 0,
        'project_bytes' => $proj['bytes'] ?? 0,
    ];
}

function vewo_repair_flag_path(): string
{
    return dirname(__DIR__) . '/secrets/repair_web.flag';
}

function vewo_watchdog_state_path(): string
{
    return dirname(__DIR__) . '/secrets/watchdog_state.json';
}

function vewo_telegram_offset_path(): string
{
    return dirname(__DIR__) . '/secrets/telegram_offset.txt';
}

function vewo_local_api_health(): bool
{
    $ch = curl_init('http://127.0.0.1/api/index.php?r=health');
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CONNECTTIMEOUT => 3,
        CURLOPT_TIMEOUT => 6,
        CURLOPT_HTTPHEADER => ['Accept: application/json'],
    ]);
    $raw = curl_exec($ch);
    $code = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    if ($raw === false || $code !== 200) {
        return false;
    }
    $decoded = json_decode((string) $raw, true);

    return is_array($decoded) && !empty($decoded['ok']);
}

function vewo_service_is_active(string $unit): bool
{
    if (PHP_OS_FAMILY === 'Windows') {
        return false;
    }
    $line = [];
    $code = 1;
    exec('systemctl is-active ' . escapeshellarg($unit) . ' 2>/dev/null', $line, $code);

    return $code === 0 && implode('', $line) === 'active';
}

function vewo_format_server_status_text(): string
{
    $st = vewo_collect_server_stats();
    $apiOk = vewo_local_api_health();
    $nginx = vewo_service_is_active('nginx');
    $php = vewo_service_is_active('php8.3-fpm');
    $mysql = vewo_service_is_active('mysql') || vewo_service_is_active('mariadb');
    $uptimeH = round(((float) ($st['uptime'] ?? 0)) / 3600, 1);
    $memUsed = vewo_format_bytes((int) ($st['memory_used'] ?? 0));
    $memTotal = vewo_format_bytes((int) ($st['memory_total'] ?? 0));
    $diskFree = vewo_format_bytes((int) ($st['disk_free'] ?? 0));
    $diskTotal = vewo_format_bytes((int) ($st['disk_total'] ?? 0));

    return "حالة سيرفر عقار تاون\n"
        . 'الوقت: ' . date('Y-m-d H:i') . "\n"
        . 'API: ' . ($apiOk ? 'يعمل' : 'متوقف') . "\n"
        . 'Nginx: ' . ($nginx ? 'يعمل' : 'متوقف') . "\n"
        . 'PHP-FPM: ' . ($php ? 'يعمل' : 'متوقف') . "\n"
        . 'قاعدة البيانات: ' . ($mysql ? 'تعمل' : 'متوقفة') . "\n"
        . 'المعالج: ' . (string) ($st['cpu_usage_pct'] ?? 0) . "% · حمل " . (string) ($st['load_1'] ?? 0) . "\n"
        . 'الذاكرة: ' . $memUsed . ' / ' . $memTotal . "\n"
        . 'القرص الحر: ' . $diskFree . ' / ' . $diskTotal . "\n"
        . 'التشغيل: ' . $uptimeH . " ساعة\n"
        . 'المضيف: ' . (string) ($st['hostname'] ?? '');
}

function vewo_telegram_send_status(): array
{
    return vewo_telegram_send_message(
        vewo_format_server_status_text(),
        vewo_telegram_control_keyboard()
    );
}

function vewo_repair_web_services(): array
{
    if (PHP_OS_FAMILY === 'Windows') {
        return ['ok' => false, 'error' => 'الإصلاح يعمل على سيرفر لينكس فقط'];
    }
    $cmds = [
        'systemctl restart php8.3-fpm',
        'systemctl restart nginx',
    ];
    $log = [];
    foreach ($cmds as $cmd) {
        $lines = [];
        $code = 0;
        exec($cmd . ' 2>&1', $lines, $code);
        $log[] = $cmd . ' => ' . $code . (count($lines) ? ' ' . implode(' ', $lines) : '');
    }
    usleep(800000);
    $ok = vewo_local_api_health();

    return [
        'ok' => $ok,
        'health' => $ok,
        'log' => implode("\n", $log),
    ];
}

function vewo_request_web_repair(string $source = 'admin'): array
{
    $dir = dirname(vewo_repair_flag_path());
    if (!is_dir($dir) && !mkdir($dir, 0700, true) && !is_dir($dir)) {
        return ['ok' => false, 'error' => 'تعذر تجهيز مجلد الأسرار'];
    }
    $ok = file_put_contents(
        vewo_repair_flag_path(),
        json_encode(['at' => date('c'), 'source' => $source], JSON_UNESCAPED_UNICODE)
    ) !== false;
    if (function_exists('posix_geteuid') && posix_geteuid() === 0) {
        $repair = vewo_repair_web_services();
        @unlink(vewo_repair_flag_path());
        vewo_telegram_send_message(
            ($repair['ok'] ? 'تم إصلاح خدمات الويب' : 'تعذر إصلاح خدمات الويب') . "\n"
            . vewo_format_server_status_text(),
            vewo_telegram_control_keyboard()
        );

        return $repair;
    }

    $queued = [
        'ok' => $ok,
        'queued' => true,
        'message' => $ok ? 'طُلب الإصلاح — يُنفَّذ خلال دقيقة' : 'تعذر تسجيل طلب الإصلاح',
    ];
    vewo_telegram_send_message(
        (string) $queued['message'] . "\n" . vewo_format_server_status_text(),
        vewo_telegram_control_keyboard()
    );

    return $queued;
}

/** @return array<string,mixed> */
function vewo_watchdog_read_state(): array
{
    $path = vewo_watchdog_state_path();
    if (!is_file($path)) {
        return ['down' => false, 'last_alert' => 0];
    }
    $raw = json_decode((string) file_get_contents($path), true);

    return is_array($raw) ? $raw : ['down' => false, 'last_alert' => 0];
}

function vewo_watchdog_write_state(array $state): void
{
    $dir = dirname(vewo_watchdog_state_path());
    if (!is_dir($dir)) {
        @mkdir($dir, 0700, true);
    }
    file_put_contents(
        vewo_watchdog_state_path(),
        json_encode($state, JSON_UNESCAPED_UNICODE)
    );
}

function vewo_watchdog_tick(): array
{
    $healthy = vewo_local_api_health();
    $flag = is_file(vewo_repair_flag_path());
    $state = vewo_watchdog_read_state();
    $didRepair = false;
    $repair = null;
    if (!$healthy || $flag) {
        $repair = vewo_repair_web_services();
        $didRepair = true;
        @unlink(vewo_repair_flag_path());
        $healthy = !empty($repair['ok']);
        $now = time();
        $shouldAlert = empty($state['last_alert']) || ($now - (int) $state['last_alert']) > 300;
        if ($shouldAlert || $flag) {
            $msg = $healthy
                ? 'أُعيد تشغيل Nginx وPHP-FPM — الـ API عاد للعمل'
                : 'فشل إصلاح الويب — الـ API ما زال لا يرد';
            vewo_telegram_send_message(
                $msg . "\n" . vewo_format_server_status_text(),
                vewo_telegram_control_keyboard()
            );
            $state['last_alert'] = $now;
        }
        $state['down'] = !$healthy;
        vewo_watchdog_write_state($state);
    } elseif (!empty($state['down'])) {
        $state['down'] = false;
        $state['last_alert'] = time();
        vewo_watchdog_write_state($state);
        vewo_telegram_send_message(
            "الـ API عاد للعمل تلقائياً\n" . vewo_format_server_status_text(),
            vewo_telegram_control_keyboard()
        );
    }

    return [
        'ok' => $healthy,
        'repaired' => $didRepair,
        'repair' => $repair,
    ];
}

function vewo_telegram_api(string $method, array $payload): array
{
    $s = vewo_telegram_settings();
    if ($s['bot_token'] === '') {
        return ['ok' => false];
    }
    $ch = curl_init('https://api.telegram.org/bot' . $s['bot_token'] . '/' . $method);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => $payload,
        CURLOPT_CONNECTTIMEOUT => 8,
        CURLOPT_TIMEOUT => 20,
    ]);
    $raw = curl_exec($ch);
    curl_close($ch);
    $decoded = json_decode((string) $raw, true);

    return is_array($decoded) ? $decoded : ['ok' => false];
}

function vewo_telegram_handle_update(array $update): void
{
    $s = vewo_telegram_settings();
    $allowed = (string) $s['chat_id'];
    $cb = is_array($update['callback_query'] ?? null) ? $update['callback_query'] : null;
    if (is_array($cb)) {
        $fromChat = (string) ($cb['message']['chat']['id'] ?? $cb['from']['id'] ?? '');
        if ($allowed !== '' && $fromChat !== $allowed) {
            return;
        }
        $data = (string) ($cb['data'] ?? '');
        $cbId = (string) ($cb['id'] ?? '');
        if ($data === 'aqar:status') {
            vewo_telegram_api('answerCallbackQuery', ['callback_query_id' => $cbId, 'text' => 'جاري جلب الحالة']);
            vewo_telegram_send_status();
            return;
        }
        if ($data === 'aqar:repair') {
            vewo_telegram_api('answerCallbackQuery', ['callback_query_id' => $cbId, 'text' => 'جاري إصلاح الويب']);
            vewo_request_web_repair('telegram');
            return;
        }
        if ($data === 'aqar:backup') {
            vewo_telegram_api('answerCallbackQuery', ['callback_query_id' => $cbId, 'text' => 'جاري النسخ الاحتياطي']);
            vewo_hourly_backup_run();
            return;
        }
        vewo_telegram_api('answerCallbackQuery', ['callback_query_id' => $cbId]);
        return;
    }
    $msg = is_array($update['message'] ?? null) ? $update['message'] : null;
    if (!is_array($msg)) {
        return;
    }
    $fromChat = (string) ($msg['chat']['id'] ?? '');
    if ($allowed !== '' && $fromChat !== $allowed) {
        return;
    }
    $text = trim((string) ($msg['text'] ?? ''));
    if ($text === '/start' || $text === '/status' || $text === 'حالة') {
        vewo_telegram_send_status();
        return;
    }
    if ($text === '/repair' || $text === 'إصلاح') {
        vewo_request_web_repair('telegram');
    }
}

function vewo_telegram_poll_once(): void
{
    $s = vewo_telegram_settings();
    if ($s['bot_token'] === '') {
        return;
    }
    $offset = 0;
    $path = vewo_telegram_offset_path();
    if (is_file($path)) {
        $offset = (int) trim((string) file_get_contents($path));
    }
    $res = vewo_telegram_api('getUpdates', [
        'offset' => (string) $offset,
        'timeout' => '0',
        'allowed_updates' => json_encode(['message', 'callback_query']),
    ]);
    $desc = (string) ($res['description'] ?? '');
    if ($desc !== '' && stripos($desc, 'webhook') !== false) {
        vewo_telegram_api('deleteWebhook', ['drop_pending_updates' => 'false']);
        $res = vewo_telegram_api('getUpdates', [
            'offset' => (string) $offset,
            'timeout' => '0',
            'allowed_updates' => json_encode(['message', 'callback_query']),
        ]);
    }
    $updates = is_array($res['result'] ?? null) ? $res['result'] : [];
    $max = $offset;
    foreach ($updates as $update) {
        if (!is_array($update)) {
            continue;
        }
        $id = (int) ($update['update_id'] ?? 0);
        if ($id >= $max) {
            $max = $id + 1;
        }
        vewo_telegram_handle_update($update);
    }
    if ($max > $offset) {
        $dir = dirname($path);
        if (!is_dir($dir)) {
            @mkdir($dir, 0700, true);
        }
        file_put_contents($path, (string) $max);
    }
}

function admin_server_stats_route(PDO $pdo): void
{
    require_admin_from_bearer($pdo);
    echo json_encode(vewo_collect_server_stats(), JSON_UNESCAPED_UNICODE);
}

function vewo_cron_hourly_backup_route(): void
{
    $cfg = $GLOBALS['vewo_config'] ?? [];
    $secret = trim((string) (is_array($cfg) ? ($cfg['cron_secret'] ?? '') : ''));
    $key = trim((string) ($_GET['key'] ?? $_POST['key'] ?? ''));
    $cli = PHP_SAPI === 'cli';
    if (!$cli && ($secret === '' || !hash_equals($secret, $key))) {
        json_error(403, 'غير مصرح');
    }
    echo json_encode(vewo_hourly_backup_run(), JSON_UNESCAPED_UNICODE);
}

function admin_telegram_settings_route(PDO $pdo): void
{
    $admin = require_admin_from_bearer($pdo);
    if (($admin['role'] ?? '') !== 'admin') {
        json_error(403, 'للمسؤول الرئيسي فقط');
    }
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'GET') {
        $s = vewo_telegram_settings();
        echo json_encode([
            'ok' => true,
            'configured' => $s['bot_token'] !== '' && $s['chat_id'] !== '',
            'bot_token_set' => $s['bot_token'] !== '',
            'chat_id' => $s['chat_id'],
        ], JSON_UNESCAPED_UNICODE);

        return;
    }
    if ($method === 'POST') {
        $in = read_json_body();
        $action = trim((string) ($in['action'] ?? 'save'));
        if ($action === 'test') {
            echo json_encode(vewo_telegram_send_status(), JSON_UNESCAPED_UNICODE);

            return;
        }
        if ($action === 'status') {
            echo json_encode(vewo_telegram_send_status(), JSON_UNESCAPED_UNICODE);

            return;
        }
        if ($action === 'repair_web') {
            echo json_encode(vewo_request_web_repair('لوحة الإعدادات'), JSON_UNESCAPED_UNICODE);

            return;
        }
        if ($action === 'backup_now') {
            echo json_encode(vewo_hourly_backup_run(), JSON_UNESCAPED_UNICODE);

            return;
        }
        $ok = vewo_telegram_save_settings(
            trim((string) ($in['bot_token'] ?? '')),
            trim((string) ($in['chat_id'] ?? ''))
        );
        echo json_encode(['ok' => $ok, 'error' => $ok ? null : 'تعذر حفظ الإعدادات'], JSON_UNESCAPED_UNICODE);

        return;
    }
    json_error(405, 'Method not allowed');
}
