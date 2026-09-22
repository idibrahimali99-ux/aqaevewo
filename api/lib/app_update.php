<?php
declare(strict_types=1);

/**
 * سياسة تحديث تطبيق عقار تاون — أندرويد و App Store مستقلان.
 * تُحفظ في api/data/app_update.json وتُدار من لوحة الأدمن (ويب).
 * تفعيل أندرويد لا يفرض تحديثاً على iOS والعكس.
 */

function vewo_app_update_file(): string
{
    return dirname(__DIR__) . '/data/app_update.json';
}

function vewo_app_update_flag(mixed $value): int
{
    if (is_bool($value)) {
        return $value ? 1 : 0;
    }
    $raw = strtolower(trim((string) $value));

    return in_array($raw, ['1', 'true', 'yes', 'on'], true) ? 1 : 0;
}

/** @return array<string,mixed> */
function vewo_app_update_defaults(): array
{
    $cfg = [];
    if (isset($GLOBALS['vewo_config']) && is_array($GLOBALS['vewo_config']['app_update'] ?? null)) {
        $cfg = $GLOBALS['vewo_config']['app_update'];
    } elseif (isset($GLOBALS['config']) && is_array($GLOBALS['config']['app_update'] ?? null)) {
        $cfg = $GLOBALS['config']['app_update'];
    }

    $androidUrl = trim((string) ($cfg['android_store_url'] ?? $cfg['android_url'] ?? ''));
    $iosUrl = trim((string) ($cfg['ios_store_url'] ?? $cfg['ios_url'] ?? ''));

    return [
        'title' => trim((string) ($cfg['title'] ?? 'يتوفر إصدار جديد')),
        'message' => trim((string) ($cfg['message'] ?? 'حدّث تطبيق عقار تاون للاستمرار في استخدام التطبيق.')),
        'android_enabled' => vewo_app_update_flag($cfg['android_enabled'] ?? 0),
        'android_min_version' => trim((string) ($cfg['android_min_version'] ?? '')),
        'android_min_build' => (int) ($cfg['android_min_build'] ?? 0),
        'android_latest_version' => trim((string) ($cfg['android_latest_version'] ?? '')),
        'android_latest_build' => (int) ($cfg['android_latest_build'] ?? 0),
        'android_store_url' => $androidUrl,
        'ios_enabled' => vewo_app_update_flag($cfg['ios_enabled'] ?? 0),
        'ios_min_version' => trim((string) ($cfg['ios_min_version'] ?? '')),
        'ios_min_build' => (int) ($cfg['ios_min_build'] ?? 0),
        'ios_latest_version' => trim((string) ($cfg['ios_latest_version'] ?? '')),
        'ios_latest_build' => (int) ($cfg['ios_latest_build'] ?? 0),
        'ios_store_url' => $iosUrl,
        'enabled' => 0,
        'min_version' => '',
        'min_build' => 0,
        'latest_version' => '',
        'latest_build' => 0,
    ];
}

function vewo_app_update_pick_str(array $in, array $current, string $key): string
{
    if (array_key_exists($key, $in)) {
        return trim((string) $in[$key]);
    }

    return trim((string) ($current[$key] ?? ''));
}

function vewo_app_update_pick_int(array $in, array $current, string $key): int
{
    if (array_key_exists($key, $in)) {
        return max(0, (int) $in[$key]);
    }

    return max(0, (int) ($current[$key] ?? 0));
}

function vewo_app_update_pick_flag(array $in, array $current, string $key): int
{
    if (array_key_exists($key, $in)) {
        return vewo_app_update_flag($in[$key]);
    }

    return vewo_app_update_flag($current[$key] ?? 0);
}

/** @return array<string,mixed> */
function vewo_app_update_sync_aliases(array $s): array
{
    $s['android_store_url'] = trim((string) ($s['android_store_url'] ?? $s['android_url'] ?? ''));
    $s['ios_store_url'] = trim((string) ($s['ios_store_url'] ?? $s['ios_url'] ?? ''));
    $s['enabled'] = (int) ($s['android_enabled'] ?? 0);
    $s['min_version'] = (string) ($s['android_min_version'] ?? '');
    $s['min_build'] = (int) ($s['android_min_build'] ?? 0);
    $s['latest_version'] = (string) ($s['android_latest_version'] ?? '');
    $s['latest_build'] = (int) ($s['android_latest_build'] ?? 0);

    return $s;
}

/** @return array<string,mixed> */
function vewo_app_update_migrate_legacy(array $raw, array $out): array
{
    $hasPlatform = array_key_exists('android_enabled', $raw) || array_key_exists('ios_enabled', $raw);
    if ($hasPlatform) {
        return $out;
    }
    $legacyOn = vewo_app_update_flag($raw['enabled'] ?? 0);
    $out['android_enabled'] = $legacyOn;
    $out['android_min_version'] = trim((string) ($raw['min_version'] ?? $out['android_min_version']));
    $out['android_min_build'] = (int) ($raw['min_build'] ?? $out['android_min_build']);
    $out['android_latest_version'] = trim((string) ($raw['latest_version'] ?? $out['android_latest_version']));
    $out['android_latest_build'] = (int) ($raw['latest_build'] ?? $out['android_latest_build']);
    $out['android_store_url'] = trim((string) ($raw['android_store_url'] ?? $out['android_store_url']));
    $out['ios_enabled'] = 0;
    $out['ios_store_url'] = trim((string) ($raw['ios_store_url'] ?? $out['ios_store_url']));
    $out['ios_min_version'] = trim((string) ($raw['ios_min_version'] ?? ''));
    $out['ios_latest_version'] = trim((string) ($raw['ios_latest_version'] ?? ''));

    return $out;
}

/** @return array<string,mixed> */
function vewo_app_update_load(): array
{
    $out = vewo_app_update_defaults();
    $path = vewo_app_update_file();
    if (!is_file($path)) {
        return vewo_app_update_sync_aliases($out);
    }
    try {
        $raw = json_decode((string) file_get_contents($path), true);
        if (!is_array($raw)) {
            return vewo_app_update_sync_aliases($out);
        }
        $flagKeys = ['android_enabled', 'ios_enabled', 'enabled'];
        $intKeys = [
            'android_min_build', 'android_latest_build',
            'ios_min_build', 'ios_latest_build',
            'min_build', 'latest_build',
        ];
        foreach ($out as $key => $fallback) {
            if (!array_key_exists($key, $raw)) {
                continue;
            }
            if (in_array($key, $flagKeys, true)) {
                $out[$key] = vewo_app_update_flag($raw[$key]);
            } elseif (in_array($key, $intKeys, true) || is_int($fallback)) {
                $out[$key] = (int) $raw[$key];
            } else {
                $out[$key] = trim((string) $raw[$key]);
            }
        }
        if (array_key_exists('android_url', $raw) && trim((string) $raw['android_url']) !== '') {
            $out['android_store_url'] = trim((string) $raw['android_url']);
        }
        if (array_key_exists('ios_url', $raw) && trim((string) $raw['ios_url']) !== '') {
            $out['ios_store_url'] = trim((string) $raw['ios_url']);
        }
        $out = vewo_app_update_migrate_legacy($raw, $out);
    } catch (Throwable $e) {
    }

    return vewo_app_update_sync_aliases($out);
}

function vewo_app_update_write(array $next): bool
{
    if (trim((string) ($next['title'] ?? '')) === '') {
        $next['title'] = 'يتوفر إصدار جديد';
    }
    if (trim((string) ($next['message'] ?? '')) === '') {
        $next['message'] = 'حدّث تطبيق عقار تاون للاستمرار في استخدام التطبيق.';
    }
    $next = vewo_app_update_sync_aliases($next);
    $dir = dirname(vewo_app_update_file());
    if (!is_dir($dir)) {
        @mkdir($dir, 0775, true);
    }
    $json = json_encode($next, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
    if ($json === false) {
        return false;
    }

    return @file_put_contents(vewo_app_update_file(), $json) !== false;
}

function vewo_app_update_touches_platform(array $in, string $platform): bool
{
    $explicit = strtolower(trim((string) ($in['platform'] ?? '')));
    if ($explicit === 'both' || $explicit === '') {
        if ($explicit === 'both') {
            return true;
        }
        foreach ($in as $key => $_) {
            $k = (string) $key;
            if ($k === 'platform' || $k === 'action' || $k === 'title' || $k === 'message') {
                continue;
            }
            if (str_starts_with($k, $platform . '_') || ($platform === 'android' && in_array($k, ['enabled', 'min_version', 'min_build', 'latest_version', 'latest_build'], true))) {
                return true;
            }
        }

        return $explicit === '';
    }

    return $explicit === $platform;
}

/** @param array<string,mixed> $in */
function vewo_app_update_save(array $in): bool
{
    $current = vewo_app_update_load();
    $next = $current;
    $next['title'] = vewo_app_update_pick_str($in, $current, 'title');
    $next['message'] = vewo_app_update_pick_str($in, $current, 'message');

    $saveAndroid = vewo_app_update_touches_platform($in, 'android');
    $saveIos = vewo_app_update_touches_platform($in, 'ios');
    if (!$saveAndroid && !$saveIos) {
        $saveAndroid = true;
        $saveIos = true;
    }

    if ($saveAndroid) {
        $legacyEnabled = array_key_exists('android_enabled', $in) ? $in['android_enabled'] : ($in['enabled'] ?? null);
        if ($legacyEnabled !== null) {
            $next['android_enabled'] = vewo_app_update_flag($legacyEnabled);
        }
        if (array_key_exists('android_min_version', $in) || array_key_exists('min_version', $in)) {
            $next['android_min_version'] = array_key_exists('android_min_version', $in)
                ? trim((string) $in['android_min_version'])
                : trim((string) $in['min_version']);
        }
        if (array_key_exists('android_min_build', $in) || array_key_exists('min_build', $in)) {
            $next['android_min_build'] = array_key_exists('android_min_build', $in)
                ? max(0, (int) $in['android_min_build'])
                : max(0, (int) $in['min_build']);
        }
        if (array_key_exists('android_latest_version', $in) || array_key_exists('latest_version', $in)) {
            $next['android_latest_version'] = array_key_exists('android_latest_version', $in)
                ? trim((string) $in['android_latest_version'])
                : trim((string) $in['latest_version']);
        }
        if (array_key_exists('android_latest_build', $in) || array_key_exists('latest_build', $in)) {
            $next['android_latest_build'] = array_key_exists('android_latest_build', $in)
                ? max(0, (int) $in['android_latest_build'])
                : max(0, (int) $in['latest_build']);
        }
        if (array_key_exists('android_store_url', $in) || array_key_exists('android_url', $in)) {
            $next['android_store_url'] = array_key_exists('android_store_url', $in)
                ? trim((string) $in['android_store_url'])
                : trim((string) $in['android_url']);
        }
    }

    if ($saveIos) {
        if (array_key_exists('ios_enabled', $in)) {
            $next['ios_enabled'] = vewo_app_update_flag($in['ios_enabled']);
        }
        $next['ios_min_version'] = vewo_app_update_pick_str($in, $current, 'ios_min_version');
        $next['ios_min_build'] = vewo_app_update_pick_int($in, $current, 'ios_min_build');
        $next['ios_latest_version'] = vewo_app_update_pick_str($in, $current, 'ios_latest_version');
        $next['ios_latest_build'] = vewo_app_update_pick_int($in, $current, 'ios_latest_build');
        if (array_key_exists('ios_store_url', $in) || array_key_exists('ios_url', $in)) {
            $next['ios_store_url'] = array_key_exists('ios_store_url', $in)
                ? trim((string) $in['ios_store_url'])
                : trim((string) $in['ios_url']);
        }
    }

    return vewo_app_update_write($next);
}

function vewo_app_update_clear(?string $platform = null): bool
{
    $current = vewo_app_update_load();
    $platform = strtolower(trim((string) $platform));
    $next = $current;
    if ($platform === '' || $platform === 'both' || $platform === 'all') {
        $next['android_enabled'] = 0;
        $next['android_min_version'] = '';
        $next['android_min_build'] = 0;
        $next['android_latest_version'] = '';
        $next['android_latest_build'] = 0;
        $next['ios_enabled'] = 0;
        $next['ios_min_version'] = '';
        $next['ios_min_build'] = 0;
        $next['ios_latest_version'] = '';
        $next['ios_latest_build'] = 0;
    } elseif ($platform === 'android') {
        $next['android_enabled'] = 0;
        $next['android_min_version'] = '';
        $next['android_min_build'] = 0;
        $next['android_latest_version'] = '';
        $next['android_latest_build'] = 0;
    } elseif ($platform === 'ios') {
        $next['ios_enabled'] = 0;
        $next['ios_min_version'] = '';
        $next['ios_min_build'] = 0;
        $next['ios_latest_version'] = '';
        $next['ios_latest_build'] = 0;
    }

    return vewo_app_update_write($next);
}

/** @return array<string,mixed> */
function vewo_app_update_platform_public(array $s, string $platform): array
{
    $enabled = (int) ($s[$platform . '_enabled'] ?? 0) === 1;
    $minVersion = $enabled ? (string) ($s[$platform . '_min_version'] ?? '') : '';
    $latestVersion = $enabled ? (string) ($s[$platform . '_latest_version'] ?? '') : '';
    $minBuild = $enabled ? (int) ($s[$platform . '_min_build'] ?? 0) : 0;
    $latestBuild = $enabled ? (int) ($s[$platform . '_latest_build'] ?? 0) : 0;
    if ($enabled) {
        if ($minVersion === '' && $latestVersion !== '') {
            $minVersion = $latestVersion;
        }
        if ($latestVersion === '' && $minVersion !== '') {
            $latestVersion = $minVersion;
        }
        if ($minBuild <= 0 && $latestBuild > 0) {
            $minBuild = $latestBuild;
        }
        if ($latestBuild <= 0 && $minBuild > 0) {
            $latestBuild = $minBuild;
        }
    }
    $url = (string) ($s[$platform . '_store_url'] ?? '');

    return [
        'enabled' => $enabled,
        'min_version' => $minVersion,
        'min_build' => $minBuild,
        'latest_version' => $latestVersion,
        'latest_build' => $latestBuild,
        'url' => $url,
        'store_url' => $url,
        'force' => $enabled && ($minVersion !== '' || $minBuild > 0),
    ];
}

/** @return array<string,mixed> */
function vewo_app_update_public(): array
{
    $s = vewo_app_update_load();
    $android = vewo_app_update_platform_public($s, 'android');
    $ios = vewo_app_update_platform_public($s, 'ios');

    return [
        'title' => (string) $s['title'],
        'message' => (string) $s['message'],
        'android' => $android,
        'ios' => $ios,
        'enabled' => $android['enabled'],
        'min_version' => $android['min_version'],
        'min_build' => $android['min_build'],
        'latest_version' => $android['latest_version'],
        'latest_build' => $android['latest_build'],
        'android_store_url' => (string) $s['android_store_url'],
        'ios_store_url' => (string) $s['ios_store_url'],
        'force' => $android['force'],
    ];
}

function admin_app_update_route(PDO $pdo): void
{
    require_admin_from_bearer($pdo);
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'GET') {
        echo json_encode(array_merge(['ok' => true], vewo_app_update_load()), JSON_UNESCAPED_UNICODE);

        return;
    }
    if ($method === 'POST' || $method === 'DELETE') {
        $in = $method === 'DELETE' ? [] : read_json_body();
        $action = strtolower(trim((string) ($in['action'] ?? '')));
        $platform = strtolower(trim((string) ($in['platform'] ?? '')));
        if ($method === 'DELETE' || $action === 'clear' || $action === 'delete' || $action === 'disable') {
            $ok = vewo_app_update_clear($platform !== '' ? $platform : 'both');
        } elseif ($action === 'clear_android') {
            $ok = vewo_app_update_clear('android');
        } elseif ($action === 'clear_ios') {
            $ok = vewo_app_update_clear('ios');
        } else {
            $ok = vewo_app_update_save($in);
        }
        echo json_encode(
            array_merge(
                ['ok' => $ok, 'error' => $ok ? null : 'تعذر حفظ سياسة التحديث'],
                vewo_app_update_load()
            ),
            JSON_UNESCAPED_UNICODE
        );

        return;
    }
    json_error(405, 'Method not allowed');
}
