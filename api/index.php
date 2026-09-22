<?php
declare(strict_types=1);

$__vewoEarlyRoute = trim((string) (is_array($_GET['r'] ?? null) ? '' : ($_GET['r'] ?? '')));
if ($__vewoEarlyRoute === 'chat/stream') {
    $origin = '*';
    $cfgPath = __DIR__ . '/config.php';
    if (is_file($cfgPath)) {
        /** @var array $cfg */
        $cfg = require $cfgPath;
        $origin = (string) ($cfg['cors']['allow_origin'] ?? '*');
    }
    header('Access-Control-Allow-Origin: ' . $origin);
    header('Access-Control-Allow-Methods: GET, OPTIONS');
    header('Access-Control-Allow-Headers: Range, Content-Type, Authorization');
    header('Access-Control-Expose-Headers: Content-Range, Accept-Ranges, Content-Length');
    if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
        http_response_code(204);
        exit;
    }
    require_once __DIR__ . '/lib/chat_stream.php';
    chat_stream_serve();
    exit;
}

@ini_set('max_execution_time', '0');
@ini_set('max_input_time', '0');
@ini_set('memory_limit', '2048M');
@ini_set('default_socket_timeout', '600');
@set_time_limit(0);
if (in_array($__vewoEarlyRoute, ['properties/upload', 'admin/upload', 'chat/upload', 'register/office_photo', 'farms/upload', 'farms/booking/proof'], true)) {
    @ignore_user_abort(true);
}

header('Content-Type: application/json; charset=utf-8');
@ini_set('display_errors', '0');
if (ob_get_level() === 0) {
    ob_start();
}

$configPath = __DIR__ . '/config.php';
if (!is_file($configPath)) {
    http_response_code(503);
    $accept = (string) ($_SERVER['HTTP_ACCEPT'] ?? '');
    $forceJson = (($_GET['format'] ?? '') === 'json');
    $wantsJson = $forceJson || (preg_match('/application\/json/i', $accept) === 1);
    $wantsHtml = preg_match('/text\/html/i', $accept) === 1;
    if ($wantsHtml && !$wantsJson) {
        header('Content-Type: text/html; charset=utf-8');
        $dir = htmlspecialchars(__DIR__, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
        echo '<!DOCTYPE html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>vewo API</title>'
            . '<style>body{font-family:system-ui,sans-serif;padding:24px;max-width:560px;margin:auto;line-height:1.6;background:#f4f6fb}'
            . 'code{background:#e8ecf4;padding:2px 8px;border-radius:6px}</style></head><body>';
        echo '<h1>السيرفر يحتاج إعدادًا</h1>';
        echo '<p>انسخ الملف <code>config.example.php</code> إلى الملف <strong>config.php</strong> في نفس مجلد الـAPI، ثم اضبط اتصال MySQL.</p>';
        echo '<p>المسار على الخادم: <code>' . $dir . '</code></p>';
        echo '<p>للتطبيقات (JSON) أضف في الرابط: <code>?format=json</code> أو أرسل الهيدر <code>Accept: application/json</code>.</p>';
        echo '</body></html>';
        exit;
    }
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'ok' => false,
        'error' => 'Missing config.php — copy config.example.php to config.php',
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

/** @var array $config */
$config = require $configPath;
$GLOBALS['vewo_config'] = $config;

$origin = $config['cors']['allow_origin'] ?? '*';
header('Access-Control-Allow-Origin: ' . $origin);
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

try {
    $db = $config['db'];
    $dsn = sprintf(
        'mysql:host=%s;port=%d;dbname=%s;charset=%s',
        $db['host'],
        (int) $db['port'],
        $db['name'],
        $db['charset']
    );
    $pdo = new PDO($dsn, $db['user'], $db['pass'], [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    $GLOBALS['vewo_pdo'] = $pdo;
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        'ok' => false,
        'error' => 'Database connection failed',
        'detail' => $e->getMessage(),
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

/**
 * مسار التوجيه:
 * - مع mod_rewrite: GET /api/health
 * - بدون rewrite:   GET /api/index.php?r=health
 */
$rParam = $_GET['r'] ?? '';
$route = is_array($rParam) ? '' : trim((string) $rParam);
if ($route === '' && !empty($_SERVER['REQUEST_URI'])) {
    $uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH) ?: '';
    $base = rtrim(str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'] ?? '')), '/');
    if ($base !== '' && strpos($uri, $base) === 0) {
        $uri = substr($uri, strlen($base)) ?: '/';
    }
    $route = trim($uri, '/');
}
// مسارات بديلة إذا حذفت الاستضافة الشرطة المائلة في الاستعلام أو استُخدم اسم underscore.
if ($route === 'admin_parcels') {
    $route = 'admin/parcels';
}

require_once __DIR__ . '/lib/r2_storage.php';
require_once __DIR__ . '/lib/extend.php';
require_once __DIR__ . '/lib/backup_telegram.php';
require_once __DIR__ . '/lib/social.php';
require_once __DIR__ . '/lib/app_update.php';
require_once __DIR__ . '/lib/farms.php';

switch ($route) {
    case '':
    case 'health':
        $fcmReady = false;
        $fcmMode = 'none';
        if (function_exists('vewo_fcm_service_account') && function_exists('vewo_fcm_config_value')) {
            $sa = vewo_fcm_service_account();
            $projectId = vewo_fcm_config_value('project_id');
            if ($projectId === '' && is_array($sa)) {
                $projectId = trim((string) ($sa['project_id'] ?? ''));
            }
            if ($sa !== null && $projectId !== '') {
                $fcmReady = true;
                $fcmMode = 'http_v1';
            } elseif (function_exists('vewo_fcm_server_key') && vewo_fcm_server_key() !== '') {
                $fcmReady = true;
                $fcmMode = 'legacy';
            }
        }
        echo json_encode([
            'ok' => true,
            'service' => 'vewo-api',
            'time' => date('c'),
            'db' => $db['name'],
            'fcm' => [
                'ready' => $fcmReady,
                'mode' => $fcmMode,
            ],
        ], JSON_UNESCAPED_UNICODE);
        break;

    case 'version':
        echo json_encode([
            'ok' => true,
            'php' => PHP_VERSION,
        ], JSON_UNESCAPED_UNICODE);
        break;

    case 'users/me':
        if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
            json_error(405, 'Method not allowed');
        }
        users_me_route($pdo);
        break;

    case 'users/update-profile':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            json_error(405, 'Method not allowed');
        }
        users_update_profile_route($pdo);
        break;

    case 'users/delete-account':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            json_error(405, 'Method not allowed');
        }
        users_delete_account_route($pdo);
        break;

    case 'auth/register':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            json_error(405, 'Method not allowed');
        }
        auth_register($pdo);
        break;

    case 'auth/login':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            json_error(405, 'Method not allowed');
        }
        auth_login($pdo, false);
        break;

    case 'auth/admin/login':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            json_error(405, 'Method not allowed');
        }
        auth_login($pdo, true);
        break;

    case 'app/bootstrap':
        if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
            json_error(405, 'Method not allowed');
        }
        app_bootstrap($pdo, $config);
        break;

    case 'admin/promotions':
        vewo_require_admin_permission($pdo, 'promotions');
        admin_promotions_route($pdo);
        break;

    case 'admin/home-sections':
    case 'admin_home_sections':
        vewo_require_admin_permission($pdo, 'settings');
        admin_home_sections_route($pdo);
        break;

    case 'admin/app-update':
    case 'admin_app_update':
        vewo_require_admin_permission($pdo, 'settings');
        admin_app_update_route($pdo);
        break;

    case 'admin/property-news':
    case 'admin_property_news':
        vewo_require_admin_permission($pdo, 'news');
        admin_property_news_route($pdo);
        break;

    case 'app/property-news/get':
    case 'app_property_news_get':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
            json_error(405, 'Method not allowed');
        }
        app_property_news_get_route($pdo);
        break;

    case 'admin/upload':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
            json_error(405, 'Method not allowed');
        }
        admin_upload_route($pdo, $config);
        break;

    case 'admin/properties':
        vewo_require_admin_permission($pdo, 'properties');
        admin_properties_route($pdo);
        break;

    case 'admin/reels':
        vewo_require_admin_permission_any($pdo, ['reels', 'properties']);
        admin_reels_route($pdo);
        break;

    case 'admin/engagement':
        admin_engagement_route($pdo);
        break;

    case 'admin_parcels':
    case 'admin/parcels':
        vewo_require_admin_permission($pdo, 'parcels');
        admin_parcels_route($pdo);
        break;

    case 'admin_compounds':
    case 'admin/compounds':
        vewo_require_admin_permission($pdo, 'parcels');
        admin_compounds_route($pdo);
        break;

    case 'chat/thread/open':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            json_error(405, 'Method not allowed');
        }
        chat_thread_open($pdo);
        break;

    case 'chat/threads':
        if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
            json_error(405, 'Method not allowed');
        }
        chat_threads_list($pdo);
        break;

    case 'app/notifications/poll':
    case 'app_notifications_poll':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
            json_error(405, 'Method not allowed');
        }
        app_notifications_poll_route($pdo);
        break;

    case 'app/governorates':
    case 'app/governorates/list':
    case 'app_governorates_list':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
            json_error(405, 'Method not allowed');
        }
        app_governorates_list_route($pdo);
        break;

    case 'app/governorates/full':
    case 'app_governorates_full':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
            json_error(405, 'Method not allowed');
        }
        app_governorates_full_route($pdo);
        break;

    case 'property-requests':
    case 'property_requests':
        $prm = $_SERVER['REQUEST_METHOD'] ?? 'GET';
        if ($prm === 'GET') {
            property_requests_my_route($pdo);
        } elseif ($prm === 'POST') {
            property_requests_create_route($pdo);
        } else {
            json_error(405, 'Method not allowed');
        }
        break;

    case 'admin/property-requests':
    case 'admin_property_requests':
        vewo_require_admin_permission($pdo, 'properties');
        admin_property_requests_route($pdo);
        break;

    case 'app/districts/list':
    case 'app/districts':
    case 'app_districts_list':
        app_districts_public_route($pdo);
        break;

    case 'admin/governorates':
    case 'admin_governorates':
        vewo_require_admin_permission($pdo, 'settings');
        admin_governorates_route($pdo);
        break;

    case 'admin/districts':
    case 'admin_districts':
        vewo_require_admin_permission($pdo, 'settings');
        admin_districts_route($pdo);
        break;

    case 'admin/reports':
    case 'admin_reports':
        admin_reports_route($pdo);
        break;

    case 'admin/user':
    case 'admin_user':
        vewo_require_admin_permission($pdo, 'users');
        admin_user_detail_route($pdo);
        break;

    case 'app/broadcast/poll':
    case 'app_broadcast_poll':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
            json_error(405, 'Method not allowed');
        }
        app_broadcast_poll_route($pdo);
        break;

    case 'admin/broadcast':
    case 'admin_broadcast':
        vewo_require_admin_permission($pdo, 'settings');
        admin_broadcast_route($pdo);
        break;

    case 'cron/push-reminders':
    case 'cron_push_reminders':
        cron_push_reminders_route($pdo);
        break;

    case 'cron/hourly-backup':
    case 'cron_hourly_backup':
        vewo_cron_hourly_backup_route();
        break;

    case 'admin/server-stats':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
            json_error(405, 'Method not allowed');
        }
        vewo_require_admin_permission($pdo, 'settings');
        admin_server_stats_route($pdo);
        break;

    case 'admin/telegram':
        vewo_require_admin_permission($pdo, 'settings');
        admin_telegram_settings_route($pdo);
        break;

    case 'chat/messages':
        $cm = $_SERVER['REQUEST_METHOD'] ?? 'GET';
        if ($cm === 'GET') {
            chat_messages_list($pdo);
        } elseif ($cm === 'POST') {
            chat_messages_post($pdo);
        } else {
            json_error(405, 'Method not allowed');
        }
        break;

    case 'chat/thread/read':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            json_error(405, 'Method not allowed');
        }
        chat_thread_mark_read($pdo);
        break;

    case 'chat/upload':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
            json_error(405, 'Method not allowed');
        }
        chat_upload_route($pdo, $config);
        break;

    case 'admin/stats':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
            json_error(405, 'Method not allowed');
        }
        admin_stats_route($pdo);
        break;

    case 'admin/notify-pulse':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
            json_error(405, 'Method not allowed');
        }
        admin_notify_pulse_route($pdo);
        break;

    case 'admin/offices':
        vewo_require_admin_permission($pdo, 'offices');
        admin_offices_route($pdo);
        break;

    case 'admin/users':
        vewo_require_admin_permission($pdo, 'users');
        admin_users_route($pdo);
        break;

    case 'admin/system':
        vewo_require_admin_permission($pdo, 'settings');
        admin_system_route($pdo);
        break;

    case 'app/device/register':
    case 'app_device_register':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
            json_error(405, 'Method not allowed');
        }
        app_device_register_route($pdo);
        break;

    case 'admin/device/register':
    case 'admin_device_register':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
            json_error(405, 'Method not allowed');
        }
        admin_device_register_route($pdo);
        break;

    case 'admin/fcm/test':
    case 'admin_fcm_test':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
            json_error(405, 'Method not allowed');
        }
        admin_fcm_test_route($pdo);
        break;

    case 'properties/list':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
            json_error(405, 'Method not allowed');
        }
        public_properties_list_route($pdo);
        break;

    case 'properties/get':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
            json_error(405, 'Method not allowed');
        }
        public_properties_get_route($pdo);
        break;

    case 'properties/create':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
            json_error(405, 'Method not allowed');
        }
        properties_create_route($pdo);
        break;

    case 'properties/update':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
            json_error(405, 'Method not allowed');
        }
        user_property_update_route($pdo);
        break;

    case 'properties/delete':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
            json_error(405, 'Method not allowed');
        }
        user_properties_delete_route($pdo);
        break;

    case 'properties/upload':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
            json_error(405, 'Method not allowed');
        }
        user_properties_upload_route($pdo, $config);
        break;

    case 'reels/list':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
            json_error(405, 'Method not allowed');
        }
        public_reels_list_route($pdo);
        break;

    case 'reels/detail':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
            json_error(405, 'Method not allowed');
        }
        public_reel_detail_route($pdo);
        break;

    case 'reels/create':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
            json_error(405, 'Method not allowed');
        }
        reels_create_route($pdo);
        break;

    case 'reels/update':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
            json_error(405, 'Method not allowed');
        }
        reels_update_route($pdo);
        break;

    case 'reels/delete':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
            json_error(405, 'Method not allowed');
        }
        user_reels_delete_route($pdo);
        break;

    case 'reels/mark-sold':
    case 'reels_mark_sold':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
            json_error(405, 'Method not allowed');
        }
        reels_mark_sold_route($pdo);
        break;

    case 'reels/view':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
            json_error(405, 'Method not allowed');
        }
        reels_record_view_route($pdo);
        break;

    case 'reels/react':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
            json_error(405, 'Method not allowed');
        }
        reels_react_route($pdo);
        break;

    case 'reels/comments':
        $rm = $_SERVER['REQUEST_METHOD'] ?? 'GET';
        if ($rm === 'GET') {
            echo json_encode(['ok' => true, 'items' => []], JSON_UNESCAPED_UNICODE);
        } elseif ($rm === 'POST') {
            json_error(403, 'تعليقات الريلز متوقفة');
        } else {
            json_error(405, 'Method not allowed');
        }
        break;

    case 'reels/comment-like':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
            json_error(405, 'Method not allowed');
        }
        json_error(403, 'تعليقات الريلز متوقفة');
        break;

    case 'properties/mark-sold':
    case 'properties_mark_sold':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
            json_error(405, 'Method not allowed');
        }
        properties_mark_sold_route($pdo);
        break;

    case 'offices/list':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
            json_error(405, 'Method not allowed');
        }
        public_offices_list_route($pdo);
        break;

    case 'offices/detail':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
            json_error(405, 'Method not allowed');
        }
        public_office_detail_route($pdo);
        break;

    case 'marketers/list':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
            json_error(405, 'Method not allowed');
        }
        public_marketers_list_route($pdo);
        break;

    case 'marketers/detail':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
            json_error(405, 'Method not allowed');
        }
        public_marketer_detail_route($pdo);
        break;

    case 'parcels/list':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
            json_error(405, 'Method not allowed');
        }
        public_parcels_list_route($pdo);
        break;

    case 'compounds/list':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
            json_error(405, 'Method not allowed');
        }
        public_compounds_list_route($pdo);
        break;

    case 'follow/list':
        follow_list_route($pdo);
        break;

    case 'follow/toggle':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
            json_error(405, 'Method not allowed');
        }
        follow_toggle_route($pdo);
        break;

    case 'follow/status':
        follow_status_route($pdo);
        break;

    case 'admin/posting-packages':
        admin_posting_packages_route($pdo);
        break;

    case 'admin/marketers':
        admin_marketers_list_route($pdo);
        break;

    case 'admin/assign-package':
        admin_assign_posting_package_route($pdo);
        break;

    case 'admin/follow/boost':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
            json_error(405, 'Method not allowed');
        }
        admin_follow_boost_route($pdo);
        break;

    case 'register/office_photo':
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
            json_error(405, 'Method not allowed');
        }
        register_office_photo_upload_route($pdo, $config);
        break;

    default:
        json_error(404, 'Route not found: ' . $route);
}

/**
 * @return array<string,mixed>
 */
function read_json_body(): array
{
    $raw = file_get_contents('php://input') ?: '';
    $data = json_decode($raw, true);
    return is_array($data) ? $data : [];
}

function uuid_v4(): string
{
    $b = random_bytes(16);
    $b[6] = chr(ord($b[6]) & 0x0f | 0x40);
    $b[8] = chr(ord($b[8]) & 0x3f | 0x80);

    return sprintf(
        '%s-%s-%s-%s-%s',
        bin2hex(substr($b, 0, 4)),
        bin2hex(substr($b, 4, 2)),
        bin2hex(substr($b, 6, 2)),
        bin2hex(substr($b, 8, 2)),
        bin2hex(substr($b, 10, 6))
    );
}

function password_verify_stored(string $plain, string $stored): bool
{
    if (str_starts_with($stored, 'PLAIN:')) {
        return hash_equals(substr($stored, 6), $plain);
    }
    return password_verify($plain, $stored);
}

/**
 * @param array<string,mixed>|false $row
 * @return array<string,mixed>
 */
function user_public_json($row): array
{
    if (!is_array($row)) {
        return [];
    }
    $out = [
        'id' => (string) $row['id'],
        'full_name' => (string) $row['full_name'],
        'phone' => (string) $row['phone'],
        'email' => (string) ($row['email'] ?? ''),
        'role' => (string) $row['role'],
        'office_approved' => (int) $row['office_approved'] === 1,
    ];
    if (isset($row['office_address'])) {
        $out['office_address'] = (string) $row['office_address'];
    }
    if (isset($row['office_license_no'])) {
        $out['office_license_no'] = (string) $row['office_license_no'];
    }
    if (isset($row['office_photo_url'])) {
        $out['office_photo_url'] = (string) $row['office_photo_url'];
    }
    if (isset($row['office_name'])) {
        $out['office_name'] = (string) $row['office_name'];
    }
    if (isset($row['profile_photo_url']) && (string) $row['profile_photo_url'] !== '') {
        $out['profile_photo_url'] = (string) $row['profile_photo_url'];
    }
    if (isset($row['is_marketer']) && (int) $row['is_marketer'] === 1) {
        $out['is_marketer'] = true;
    }
    if (isset($row['office_verified'])) {
        $out['office_verified'] = (int) $row['office_verified'] === 1;
    }
    if (isset($row['office_lat']) && $row['office_lat'] !== null && $row['office_lat'] !== '') {
        $out['office_lat'] = (float) $row['office_lat'];
    }
    if (isset($row['office_lng']) && $row['office_lng'] !== null && $row['office_lng'] !== '') {
        $out['office_lng'] = (float) $row['office_lng'];
    }
    if (isset($row['staff_permissions_json'])) {
        $decoded = json_decode((string) $row['staff_permissions_json'], true);
        $out['staff_permissions'] = is_array($decoded) ? array_values($decoded) : [];
    }
    if (isset($row['posting_trial_unlimited'])) {
        $out['posting_trial_unlimited'] = (int) $row['posting_trial_unlimited'] === 1;
    }
    if (array_key_exists('posting_listings_remaining', $row)) {
        $pr = $row['posting_listings_remaining'];
        $out['posting_listings_remaining'] = ($pr === null || $pr === '') ? null : (int) $pr;
    }

    return $out;
}

function auth_register(PDO $pdo): void
{
    $in = read_json_body();
    $fullName = trim((string) ($in['full_name'] ?? ''));
    $phone = trim((string) ($in['phone'] ?? ''));
    $email = trim(strtolower((string) ($in['email'] ?? '')));
    $password = (string) ($in['password'] ?? '');
    $role = (string) ($in['role'] ?? 'customer');
    if (!in_array($role, ['customer', 'office'], true)) {
        json_error(400, 'نوع الحساب غير صالح');
    }
    if ($fullName === '' || mb_strlen($fullName) < 3) {
        json_error(400, 'الاسم غير صالح');
    }
    if (!preg_match('/^07[0-9]{9}$/', $phone)) {
        json_error(400, 'رقم الهاتف يجب أن يكون 11 رقماً ويبدأ بـ 07');
    }
    if ($email !== '' && !filter_var($email, FILTER_VALIDATE_EMAIL)) {
        json_error(400, 'البريد الإلكتروني غير صالح');
    }
    if (strlen($password) < 8) {
        json_error(400, 'كلمة المرور يجب ألا تقل عن 8 أحرف');
    }
    if (!preg_match('/[0-9]/', $password) || !preg_match('/\p{L}/u', $password)) {
        json_error(400, 'كلمة مرور أقوى مطلوبة: أحرف وأرقام معاً');
    }

    $officeName = trim((string) ($in['office_name'] ?? ''));
    $officeAddr = trim((string) ($in['office_address'] ?? ''));
    $officeLic = trim((string) ($in['office_license_no'] ?? ''));
    $officePhoto = trim((string) ($in['office_photo_url'] ?? ''));
    $profilePhoto = trim((string) ($in['profile_photo_url'] ?? ''));
    $isMarketerReq = !empty($in['is_marketer'])
        || ($in['account_kind'] ?? '') === 'marketer'
        || ($in['register_as'] ?? '') === 'marketer';
    $isFarmReq = !empty($in['is_farm'])
        || ($in['account_kind'] ?? '') === 'farm'
        || ($in['register_as'] ?? '') === 'farm';
    if ($isFarmReq) {
        json_error(400, 'تسجيل حساب المزرعة غير متاح');
    }
    if ($role === 'office') {
        if ($isFarmReq && mb_strlen($officeName) < 2) {
            $officeName = trim((string) ($in['farm_name'] ?? $in['name'] ?? $fullName));
        }
        if (mb_strlen($officeName) < 2) {
            json_error(400, $isFarmReq ? 'اسم المزرعة مطلوب' : 'اسم المكتب مطلوب');
        }
        if (!$isMarketerReq && !$isFarmReq) {
            if (mb_strlen($officeAddr) < 5) {
                json_error(400, 'عنوان المكتب مطلوب (5 أحرف على الأقل)');
            }
            if ($officeLic === '') {
                json_error(400, 'رقم الإجازة مطلوب');
            }
            if (strlen($officePhoto) < 12) {
                json_error(400, 'صورة المكتب مطلوبة — ارفع الشعار من التطبيق');
            }
        } else {
            if ($officeLic === '') {
                $officeLic = '—';
            }
            if ($officePhoto === '' && $profilePhoto !== '') {
                $officePhoto = $profilePhoto;
            }
            if ($isFarmReq && $officeAddr === '') {
                $officeAddr = trim((string) ($in['address_line'] ?? '—'));
            }
        }
    } else {
        $officeName = '';
        $officeAddr = '';
        $officeLic = '';
        $officePhoto = '';
    }

    $id = uuid_v4();
    $hash = password_hash($password, PASSWORD_DEFAULT);
    $officeApproved = $role === 'office' ? 0 : 1;
    $hasEmail = function_exists('vewo_users_has_email_column') && vewo_users_has_email_column($pdo);

    try {
        $params = [
            ':id' => $id,
            ':fn' => $fullName,
            ':oname' => $officeName,
            ':ph' => $phone,
            ':oad' => $officeAddr,
            ':olc' => $officeLic,
            ':oph' => $officePhoto,
            ':pw' => $hash,
            ':rl' => $role,
            ':oappr' => $officeApproved,
        ];
        if ($hasEmail) {
            $stmt = $pdo->prepare(
                'INSERT INTO users (id, full_name, office_name, phone, email, office_address, office_license_no, office_photo_url, password_hash, role, office_approved, is_active, created_by, created_at)
                 VALUES (:id, :fn, :oname, :ph, :email, :oad, :olc, :oph, :pw, :rl, :oappr, 1, NULL, NOW(3))'
            );
            $params[':email'] = $email !== '' ? $email : null;
        } else {
            $stmt = $pdo->prepare(
                'INSERT INTO users (id, full_name, office_name, phone, office_address, office_license_no, office_photo_url, password_hash, role, office_approved, is_active, created_by, created_at)
                 VALUES (:id, :fn, :oname, :ph, :oad, :olc, :oph, :pw, :rl, :oappr, 1, NULL, NOW(3))'
            );
        }
        $stmt->execute($params);
    } catch (PDOException $e) {
        $dup = (int) ($e->errorInfo[1] ?? 0) === 1062;
        if ($dup || str_contains($e->getMessage(), 'Duplicate')) {
            json_error(409, 'رقم الهاتف أو البريد الإلكتروني مسجّل مسبقاً');
        }
        throw $e;
    }

    if ($role === 'office' && $isMarketerReq && function_exists('vewo_users_has_is_marketer_column') && vewo_users_has_is_marketer_column($pdo)) {
        try {
            $pdo->prepare('UPDATE users SET is_marketer = 1 WHERE id = :id LIMIT 1')->execute([':id' => $id]);
        } catch (Throwable $e) {
        }
    }
    if ($role === 'office' && $isFarmReq && function_exists('vewo_farms_ensure')) {
        vewo_farms_ensure($pdo);
        if (function_exists('vewo_users_has_is_farm_column') && vewo_users_has_is_farm_column($pdo)) {
            try {
                $pdo->prepare('UPDATE users SET is_farm = 1 WHERE id = :id LIMIT 1')->execute([':id' => $id]);
            } catch (Throwable $e) {
            }
        }
        try {
            if (function_exists('vewo_farm_create_for_owner')) {
                vewo_farm_create_for_owner($pdo, $id, $in, $phone, $fullName);
            }
        } catch (Throwable $e) {
        }
    }
    if ($profilePhoto !== '' && function_exists('vewo_users_has_profile_photo_column') && vewo_users_has_profile_photo_column($pdo)) {
        try {
            $pdo->prepare('UPDATE users SET profile_photo_url = :p WHERE id = :id LIMIT 1')->execute([':p' => $profilePhoto, ':id' => $id]);
        } catch (Throwable $e) {
        }
    }

    $officeLat = $in['office_lat'] ?? null;
    $officeLng = $in['office_lng'] ?? null;
    if (
        $role === 'office'
        && function_exists('vewo_users_has_office_location_columns')
        && vewo_users_has_office_location_columns($pdo)
        && is_numeric($officeLat)
        && is_numeric($officeLng)
    ) {
        $la = (float) $officeLat;
        $ln = (float) $officeLng;
        if ($la >= -90 && $la <= 90 && $ln >= -180 && $ln <= 180) {
            try {
                $pdo->prepare('UPDATE users SET office_lat = :la, office_lng = :ln WHERE id = :id LIMIT 1')->execute([
                    ':la' => $la,
                    ':ln' => $ln,
                    ':id' => $id,
                ]);
            } catch (Throwable $e) {
            }
        }
    }

    $sel = $pdo->prepare('SELECT * FROM users WHERE id = :id LIMIT 1');
    $sel->execute([':id' => $id]);
    $row = $sel->fetch(PDO::FETCH_ASSOC);
    if (is_array($row)) {
        unset($row['password_hash']);
    }

    if ($role === 'office') {
        try {
            if (function_exists('vewo_fcm_notify_admins')) {
                vewo_fcm_notify_admins(
                    $pdo,
                    'طلب حساب جديد',
                    ($isFarmReq ? 'صاحب مزرعة' : ($isMarketerReq ? 'مسوّق عقاري' : 'مكتب عقاري')) . ' بانتظار المراجعة',
                    ['type' => $isFarmReq ? 'farm_pending' : 'office_pending', 'section' => $isFarmReq ? 'farms' : 'offices', 'user_id' => $id]
                );
            }
        } catch (Throwable $e) {
        }
    }

    $tok = issue_user_session_token($pdo, $id);
    echo json_encode([
        'ok' => true,
        'user' => user_public_json($row),
        'token' => $tok['token'],
        'expires_at' => $tok['expires_at'],
    ], JSON_UNESCAPED_UNICODE);
}

/**
 * @return array{token: string, expires_at: string}
 */
function issue_user_session_token(PDO $pdo, string $userId): array
{
    $token = bin2hex(random_bytes(32));
    $expires = (new DateTimeImmutable('+30 days'))->format('Y-m-d H:i:s.v');
    $pdo->prepare('DELETE FROM user_session_tokens WHERE user_id = :u')->execute([':u' => $userId]);
    $pdo->prepare(
        'INSERT INTO user_session_tokens (token, user_id, expires_at) VALUES (:t, :u, :e)'
    )->execute([':t' => $token, ':u' => $userId, ':e' => $expires]);

    return ['token' => $token, 'expires_at' => $expires];
}

/**
 * @param bool $adminPanel إن true يُقبل حساب role = admin فقط (لوحة vewo_admin).
 */
function auth_login(PDO $pdo, bool $adminPanel = false): void
{
    $in = read_json_body();
    $login = trim((string) ($in['login'] ?? $in['phone'] ?? $in['email'] ?? ''));
    $password = (string) ($in['password'] ?? '');
    if ($login === '') {
        json_error(400, 'أدخل رقم الهاتف أو البريد الإلكتروني');
    }
    $isEmail = str_contains($login, '@');
    $loginEmail = strtolower($login);
    $hasEmail = function_exists('vewo_users_has_email_column') && vewo_users_has_email_column($pdo);
    if ($isEmail && !$hasEmail) {
        json_error(400, 'تسجيل الدخول بالبريد يحتاج تشغيل باتش البريد في قاعدة البيانات');
    }
    if (!$isEmail && !preg_match('/^07[0-9]{9}$/', $login)) {
        json_error(400, 'رقم الهاتف أو البريد الإلكتروني غير صالح');
    }
    $emailSelect = $hasEmail ? 'email' : "'' AS email";
    $whereLogin = $isEmail ? 'LOWER(email) = :login' : 'phone = :login';
    $profileSelect = function_exists('vewo_users_has_profile_photo_column') && vewo_users_has_profile_photo_column($pdo)
        ? 'profile_photo_url'
        : "'' AS profile_photo_url";
    $marketerSelect = function_exists('vewo_users_has_is_marketer_column') && vewo_users_has_is_marketer_column($pdo)
        ? 'is_marketer'
        : '0 AS is_marketer';

    $postingSel = function_exists('vewo_users_has_posting_quota_columns') && vewo_users_has_posting_quota_columns($pdo)
        ? 'posting_trial_unlimited, posting_listings_remaining,'
        : '';
    $stmt = $pdo->prepare(
        'SELECT id, full_name, phone, ' . $emailSelect . ', ' . $profileSelect . ', ' . $marketerSelect . ', role, office_approved, office_name, office_photo_url,
                ' . (function_exists('vewo_users_has_staff_permissions_column') && vewo_users_has_staff_permissions_column($pdo)
                    ? 'staff_permissions_json,'
                    : 'NULL AS staff_permissions_json,') . '
                ' . $postingSel . '
                password_hash, is_active FROM users WHERE ' . $whereLogin . ' LIMIT 1'
    );
    $stmt->execute([':login' => $isEmail ? $loginEmail : $login]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row || !(int) $row['is_active']) {
        json_error(401, 'بيانات الدخول غير صحيحة');
    }
    if (!password_verify_stored($password, (string) $row['password_hash'])) {
        json_error(401, 'بيانات الدخول غير صحيحة');
    }

    if ($adminPanel && !in_array((string) ($row['role'] ?? ''), ['admin', 'staff'], true)) {
        json_error(403, 'هذه اللوحة للمسؤول أو الموظف فقط');
    }

    if (!$adminPanel && ($row['role'] ?? '') === 'staff') {
        json_error(403, 'حساب موظف — سجّل الدخول من تطبيق الإدارة');
    }

    unset($row['password_hash']);
    $payload = [
        'ok' => true,
        'user' => user_public_json($row),
    ];

    if ($adminPanel) {
        $userId = (string) $row['id'];
        $token = bin2hex(random_bytes(32));
        $expires = (new DateTimeImmutable('+14 days'))->format('Y-m-d H:i:s.v');
        $pdo->prepare('DELETE FROM admin_api_tokens WHERE user_id = :u')->execute([':u' => $userId]);
        $pdo->prepare(
            'INSERT INTO admin_api_tokens (token, user_id, expires_at) VALUES (:t, :u, :e)'
        )->execute([':t' => $token, ':u' => $userId, ':e' => $expires]);
        $payload['token'] = $token;
        $payload['expires_at'] = $expires;
    } else {
        $tok = issue_user_session_token($pdo, (string) $row['id']);
        $payload['token'] = $tok['token'];
        $payload['expires_at'] = $tok['expires_at'];
    }

    echo json_encode($payload, JSON_UNESCAPED_UNICODE);
}

/**
 * @param array<string,mixed> $config
 */
function app_bootstrap(PDO $pdo, array $config): void
{
    $phone = (string) ($config['support_phone'] ?? '07887444177');
    $items = [];
    try {
        $stmt = $pdo->query(
            "SELECT id, title, subtitle, image_url, link_type, link_target, sort_order,
                    display_mode, popup_duration_sec, campaign_ends_at, slot
             FROM home_promotions
             WHERE is_active = 1
               AND (campaign_ends_at IS NULL OR campaign_ends_at > NOW(3))
             ORDER BY sort_order ASC, created_at DESC
             LIMIT 20"
        );
        if ($stmt !== false) {
            $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
        }
    } catch (Throwable $e) {
        $items = [];
    }

    $newsItems = [];
    try {
        $nstmt = $pdo->query(
            "SELECT id, title, image_url, created_at AS published_at
             FROM property_news
             WHERE is_active = 1
             ORDER BY sort_order ASC, created_at DESC
             LIMIT 20"
        );
        if ($nstmt !== false) {
            $newsItems = $nstmt->fetchAll(PDO::FETCH_ASSOC);
        }
    } catch (Throwable $e) {
        $newsItems = [];
    }

    $homeSections = vewo_home_sections_list($pdo);

    $maintenance = false;
    try {
        $maintenance = is_file(__DIR__ . '/data/maintenance.flag');
    } catch (Throwable $e) {
        $maintenance = false;
    }

    echo json_encode([
        'ok' => true,
        'support_phone' => $phone,
        'promotions' => $items,
        'property_news' => $newsItems,
        'home_sections' => $homeSections,
        'maintenance_mode' => $maintenance,
        'app_update' => function_exists('vewo_app_update_public') ? vewo_app_update_public() : null,
    ], JSON_UNESCAPED_UNICODE);
}

/** @return array<int,array<string,mixed>> */
function vewo_home_section_defaults(): array
{
    return [
        ['section_key' => 'offices', 'label' => 'المكاتب', 'icon_name' => 'apartment', 'route_target' => '/app/offices', 'sort_order' => 10],
        ['section_key' => 'parcels', 'label' => 'المقاطعات', 'icon_name' => 'grid', 'route_target' => '/app/parcels', 'sort_order' => 20],
        ['section_key' => 'compounds', 'label' => 'مجمعات سكنية', 'icon_name' => 'city', 'route_target' => '/app/compounds', 'sort_order' => 30],
        ['section_key' => 'house', 'label' => 'بيوت', 'icon_name' => 'home', 'route_target' => '/app/search?cat=house', 'sort_order' => 40],
        ['section_key' => 'land', 'label' => 'أراضي', 'icon_name' => 'land', 'route_target' => '/app/search?cat=land', 'sort_order' => 50],
        ['section_key' => 'apartment', 'label' => 'شقق', 'icon_name' => 'building', 'route_target' => '/app/search?cat=apartment', 'sort_order' => 60],
        ['section_key' => 'shop', 'label' => 'محلات', 'icon_name' => 'shop', 'route_target' => '/app/search?cat=shop', 'sort_order' => 70],
        ['section_key' => 'villa', 'label' => 'فلل', 'icon_name' => 'villa', 'route_target' => '/app/search?cat=villa', 'sort_order' => 80],
    ];
}

function vewo_home_sections_ensure(PDO $pdo): bool
{
    static $ok = null;
    if ($ok !== null) return $ok;
    try {
        $pdo->exec(
            "CREATE TABLE IF NOT EXISTS home_sections (
                section_key VARCHAR(40) NOT NULL PRIMARY KEY,
                label VARCHAR(100) NOT NULL,
                icon_name VARCHAR(80) NOT NULL,
                route_target VARCHAR(160) NOT NULL,
                sort_order INT NOT NULL DEFAULT 0,
                is_active TINYINT(1) NOT NULL DEFAULT 1,
                updated_at DATETIME(3) NULL
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
        );
        foreach (vewo_home_section_defaults() as $d) {
            $stmt = $pdo->prepare(
                'INSERT IGNORE INTO home_sections (section_key, label, icon_name, route_target, sort_order, is_active, updated_at)
                 VALUES (:k, :l, :i, :r, :s, 1, NOW(3))'
            );
            $stmt->execute([
                ':k' => $d['section_key'],
                ':l' => $d['label'],
                ':i' => $d['icon_name'],
                ':r' => $d['route_target'],
                ':s' => $d['sort_order'],
            ]);
        }
        try {
            $pdo->exec("DELETE FROM home_sections WHERE section_key = 'farms'");
        } catch (Throwable $e) {
        }
        $ok = true;
    } catch (Throwable $e) {
        $ok = false;
    }
    return $ok;
}

/** @return array<int,array<string,mixed>> */
function vewo_home_sections_list(PDO $pdo): array
{
    if (!vewo_home_sections_ensure($pdo)) {
        return vewo_home_section_defaults();
    }
    try {
        $stmt = $pdo->query(
            'SELECT section_key, label, icon_name, route_target, sort_order, is_active
             FROM home_sections
             WHERE is_active = 1
             ORDER BY sort_order ASC, label ASC'
        );
        $rows = $stmt !== false ? $stmt->fetchAll(PDO::FETCH_ASSOC) : [];
        if (!is_array($rows) || $rows === []) {
            return vewo_home_section_defaults();
        }
        $out = [];
        foreach ($rows as $row) {
            if ((string) ($row['section_key'] ?? '') === 'farms') {
                continue;
            }
            $out[] = $row;
        }
        return $out !== [] ? $out : vewo_home_section_defaults();
    } catch (Throwable $e) {
        return vewo_home_section_defaults();
    }
}

function admin_home_sections_route(PDO $pdo): void
{
    require_admin_from_bearer($pdo);
    if (!vewo_home_sections_ensure($pdo)) {
        json_error(500, 'تعذر تجهيز جدول أقسام الرئيسية');
    }
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'GET') {
        $stmt = $pdo->query(
            'SELECT section_key, label, icon_name, route_target, sort_order, is_active
             FROM home_sections
             ORDER BY sort_order ASC, label ASC'
        );
        $rows = $stmt !== false ? $stmt->fetchAll(PDO::FETCH_ASSOC) : [];
        echo json_encode(['ok' => true, 'items' => $rows], JSON_UNESCAPED_UNICODE);
        return;
    }
    if ($method === 'POST') {
        $in = read_json_body();
        $key = trim((string) ($in['section_key'] ?? ''));
        $label = trim((string) ($in['label'] ?? ''));
        $icon = trim((string) ($in['icon_name'] ?? 'home'));
        $route = trim((string) ($in['route_target'] ?? ''));
        $sort = (int) ($in['sort_order'] ?? 0);
        $active = (int) ($in['is_active'] ?? 1) === 1 ? 1 : 0;
        if ($key === '' || !preg_match('/^[a-z0-9_-]{2,40}$/i', $key)) {
            json_error(400, 'مفتاح القسم غير صالح');
        }
        if ($label === '') {
            json_error(400, 'اسم القسم مطلوب');
        }
        if ($route === '' || mb_strlen($route) > 160) {
            json_error(400, 'مسار القسم مطلوب');
        }
        if ($icon === '' || mb_strlen($icon) > 80) {
            $icon = 'home';
        }
        $stmt = $pdo->prepare(
            'INSERT INTO home_sections (section_key, label, icon_name, route_target, sort_order, is_active, updated_at)
             VALUES (:k, :l, :i, :r, :s, :a, NOW(3))
             ON DUPLICATE KEY UPDATE label = VALUES(label), icon_name = VALUES(icon_name),
                route_target = VALUES(route_target), sort_order = VALUES(sort_order),
                is_active = VALUES(is_active), updated_at = NOW(3)'
        );
        $stmt->execute([
            ':k' => $key,
            ':l' => $label,
            ':i' => $icon,
            ':r' => $route,
            ':s' => $sort,
            ':a' => $active,
        ]);
        echo json_encode(['ok' => true], JSON_UNESCAPED_UNICODE);
        return;
    }
    json_error(405, 'Method not allowed');
}

function get_bearer_token(): ?string
{
    $h = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    if (is_string($h) && preg_match('/Bearer\s+(\S+)/i', $h, $m)) {
        return $m[1];
    }
    $x = $_SERVER['HTTP_X_AUTH_TOKEN'] ?? '';
    return is_string($x) && $x !== '' ? $x : null;
}

/**
 * @return array{id:string,full_name:string,role:string}
 */
function require_admin_from_bearer(PDO $pdo): array
{
    $token = get_bearer_token();
    if ($token === null || strlen($token) !== 64) {
        json_error(401, 'رمز الدخول مطلوب (Authorization: Bearer …)');
    }
    $stmt = $pdo->prepare(
        'SELECT u.id, u.full_name, u.role,
                ' . (function_exists('vewo_users_has_staff_permissions_column') && vewo_users_has_staff_permissions_column($pdo)
                    ? 'u.staff_permissions_json'
                    : 'NULL AS staff_permissions_json') . '
         FROM admin_api_tokens k
         INNER JOIN users u ON u.id = k.user_id
         WHERE k.token = :t AND k.expires_at > NOW(3) AND u.role IN (\'admin\',\'staff\') AND u.is_active = 1
         LIMIT 1'
    );
    $stmt->execute([':t' => $token]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row) {
        json_error(401, 'رمز غير صالح أو منتهي — أعد تسجيل الدخول');
    }

    /** @var array{id:string,full_name:string,role:string} */
    return $row;
}

/**
 * رفع صورة أو فيديو (multipart، الحقل: file) — يتطلب Bearer مسؤول.
 *
 * @param array<string,mixed> $config
 */
function admin_upload_route(PDO $pdo, array $config): void
{
    require_admin_from_bearer($pdo);
    if (!isset($_FILES['file']) || !is_array($_FILES['file'])) {
        json_error(400, 'لم يُرفع ملف (استخدم الحقل file)');
    }
    $f = $_FILES['file'];
    $tmp = vewo_require_uploaded_file($f);
    $finfo = new finfo(FILEINFO_MIME_TYPE);
    $mime = $finfo->file($tmp);
    if (!is_string($mime)) {
        json_error(400, 'تعذر تحديد نوع الملف');
    }
    $map = [
        'image/jpeg' => 'jpg',
        'image/png' => 'png',
        'image/webp' => 'webp',
        'image/gif' => 'gif',
        'video/mp4' => 'mp4',
        'video/webm' => 'webm',
    ];
    if (!isset($map[$mime])) {
        json_error(400, 'نوع الملف غير مدعوم (صورة أو فيديو شائع فقط)');
    }
    $ext = $map[$mime];
    $stored = vewo_store_uploaded_file($config, $tmp, $mime, $ext, '');

    echo json_encode([
        'ok' => true,
        'public_url' => $stored['public_url'],
        'storage_key' => $stored['storage_key'],
        'mime' => $mime,
    ], JSON_UNESCAPED_UNICODE);
}

/**
 * رفع وسائط محادثة (صورة/صوت) — يتطلب Bearer مستخدم/مكتب/موظف/أدمن.
 *
 * الحقل multipart: file
 * يعيد: public_url + mime
 *
 * @param array<string,mixed> $config
 */
function chat_upload_route(PDO $pdo, array $config): void
{
    require_auth_user($pdo);
    if (!isset($_FILES['file']) || !is_array($_FILES['file'])) {
        json_error(400, 'لم يُرفع ملف (استخدم الحقل file)');
    }
    $f = $_FILES['file'];
    $tmp = vewo_require_uploaded_file($f);
    $finfo = new finfo(FILEINFO_MIME_TYPE);
    $mime = $finfo->file($tmp);
    if (!is_string($mime)) {
        json_error(400, 'تعذر تحديد نوع الملف');
    }
    $map = [
        // images
        'image/jpeg' => 'jpg',
        'image/png' => 'png',
        'image/webp' => 'webp',
        'image/gif' => 'gif',
        // audio
        'audio/aac' => 'aac',
        'audio/m4a' => 'm4a',
        'audio/mp4' => 'm4a',
        'audio/mpeg' => 'mp3',
        'audio/ogg' => 'ogg',
        'audio/webm' => 'webm',
        'audio/wav' => 'wav',
    ];
    $origName = (string) ($f['name'] ?? '');
    $nameExt = strtolower(pathinfo($origName, PATHINFO_EXTENSION));
    if (!isset($map[$mime])) {
        if ($nameExt === 'wav' && str_starts_with($mime, 'audio/')) {
            $mime = 'audio/wav';
        } elseif (($nameExt === 'm4a' || $nameExt === 'aac') && str_starts_with($mime, 'audio/')) {
            $mime = 'audio/mp4';
        } elseif ($mime === 'application/octet-stream') {
            if ($nameExt === 'wav') {
                $mime = 'audio/wav';
            } elseif ($nameExt === 'm4a' || $nameExt === 'aac') {
                $mime = 'audio/mp4';
            } elseif ($nameExt === 'mp3') {
                $mime = 'audio/mpeg';
            }
        }
    }
    if (!isset($map[$mime])) {
        json_error(400, 'نوع الملف غير مدعوم (صورة/صوت شائع فقط)');
    }
    $ext = $map[$mime];
    if ($ext === 'm4a' && $nameExt === 'wav') {
        $ext = 'wav';
    }
    $stored = vewo_store_uploaded_file($config, $tmp, $mime, $ext, 'chat');
    $publicUrl = $stored['public_url'];
    // على R2/CDN يكفي الرابط العام (يدعم Range). محلياً نُبقي مسار البث التدريجي.
    $streamUrl = vewo_r2_enabled($config)
        ? $publicUrl
        : (vewo_media_public_base($config) . '/index.php?r=chat/stream&file=' . rawurlencode($stored['name']));

    echo json_encode([
        'ok' => true,
        'public_url' => $publicUrl,
        'stream_url' => $streamUrl,
        'storage_key' => $stored['storage_key'],
        'mime' => $mime,
    ], JSON_UNESCAPED_UNICODE);
}

function admin_promotions_route(PDO $pdo): void
{
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'GET') {
        require_admin_from_bearer($pdo);
        $stmt = $pdo->query(
            'SELECT id, title, subtitle, image_url, link_type, link_target, sort_order, is_active, created_at,
                    display_mode, popup_duration_sec, campaign_ends_at, slot
             FROM home_promotions ORDER BY sort_order ASC, created_at DESC'
        );
        $rows = $stmt !== false ? $stmt->fetchAll(PDO::FETCH_ASSOC) : [];
        echo json_encode(['ok' => true, 'items' => $rows], JSON_UNESCAPED_UNICODE);
        return;
    }
    if ($method === 'POST') {
        require_admin_from_bearer($pdo);
        $in = read_json_body();
        $action = trim((string) ($in['action'] ?? 'create'));
        $editId = trim((string) ($in['id'] ?? ''));
        $title = trim((string) ($in['title'] ?? ''));
        $subtitle = trim((string) ($in['subtitle'] ?? ''));
        $imageUrl = trim((string) ($in['image_url'] ?? ''));
        $sortOrder = (int) ($in['sort_order'] ?? 0);
        $displayMode = trim((string) ($in['display_mode'] ?? 'both'));
        $popupDurationSec = (int) ($in['popup_duration_sec'] ?? 20);
        $popupDurationSec = max(5, min(120, $popupDurationSec));
        $campaignDays = (int) ($in['campaign_days'] ?? 0);
        $campaignDays = max(0, min(3650, $campaignDays));
        $slot = trim((string) ($in['slot'] ?? 'home'));
        if ($slot === '' || mb_strlen($slot) > 40) {
            $slot = 'home';
        }
        $linkType = trim((string) ($in['link_type'] ?? 'url'));
        $linkTarget = trim((string) ($in['link_target'] ?? ($in['link_url'] ?? '')));
        if ($linkTarget === '') {
            $linkType = 'none';
        } elseif (!in_array($linkType, ['url', 'route', 'property', 'property_no'], true)) {
            $linkType = 'url';
        }
        if ($title === '' || $imageUrl === '') {
            json_error(400, 'العنوان ورابط الصورة مطلوبان');
        }
        if (!in_array($displayMode, ['both', 'slider', 'popup'], true)) {
            json_error(400, 'display_mode غير صالح');
        }
        if ($action === 'update') {
            if ($editId === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $editId)) {
                json_error(400, 'معرّف الإعلان غير صالح');
            }
            $endsAt = null;
            if ($campaignDays > 0) {
                $endsAt = (new DateTimeImmutable('now'))->modify('+' . $campaignDays . ' days')->format('Y-m-d H:i:s.v');
            }
            $stmt = $pdo->prepare(
                'UPDATE home_promotions
                 SET title = :ti, subtitle = :su, image_url = :im, link_type = :lt, link_target = :lk,
                     display_mode = :dm, popup_duration_sec = :pop, campaign_ends_at = :ends_at,
                     slot = :sl, sort_order = :so
                 WHERE id = :id LIMIT 1'
            );
            $stmt->execute([
                ':id' => $editId,
                ':ti' => $title,
                ':su' => $subtitle,
                ':im' => $imageUrl,
                ':lt' => $linkType,
                ':lk' => $linkTarget,
                ':dm' => $displayMode,
                ':pop' => $popupDurationSec,
                ':ends_at' => $endsAt,
                ':sl' => $slot,
                ':so' => $sortOrder,
            ]);
            echo json_encode(['ok' => true, 'updated' => $stmt->rowCount()], JSON_UNESCAPED_UNICODE);
            return;
        }
        $endsSql = 'NULL';
        $endsParams = [];
        $endsAt = null;
        if ($campaignDays > 0) {
            $endsAt = (new DateTimeImmutable('now'))->modify('+' . $campaignDays . ' days')->format('Y-m-d H:i:s.v');
            $endsSql = ':ends_at';
            $endsParams[':ends_at'] = $endsAt;
        }
        $id = uuid_v4();
        $sql = 'INSERT INTO home_promotions (id, title, subtitle, image_url, link_type, link_target,
                display_mode, popup_duration_sec, campaign_ends_at, slot, sort_order, is_active, created_at)
             VALUES (:id, :ti, :su, :im, :lt, :lk, :dm, :pop, ' . $endsSql . ', :sl, :so, 1, NOW(3))';
        $stmt = $pdo->prepare($sql);
        $params = [
            ':id' => $id,
            ':ti' => $title,
            ':su' => $subtitle,
            ':im' => $imageUrl,
            ':lt' => $linkType,
            ':lk' => $linkTarget,
            ':dm' => $displayMode,
            ':pop' => $popupDurationSec,
            ':sl' => $slot,
            ':so' => $sortOrder,
        ];
        foreach ($endsParams as $k => $v) {
            $params[$k] = $v;
        }
        $stmt->execute($params);
        $pushCount = 0;
        $pushBody = $subtitle !== '' ? $subtitle : 'إعلان جديد على الرئيسية — افتح التطبيق للاطلاع';
        $pushCount = vewo_fcm_notify_all_users(
            $pdo,
            'إعلان جديد',
            $title . ($subtitle !== '' ? ' — ' . $subtitle : ''),
            [
                'type' => 'home_promotion',
                'promotion_id' => $id,
                'title' => $title,
                'body' => $pushBody,
            ]
        );
        echo json_encode([
            'ok' => true,
            'id' => $id,
            'push_tokens' => $pushCount,
        ], JSON_UNESCAPED_UNICODE);
        return;
    }
    if ($method === 'DELETE') {
        require_admin_from_bearer($pdo);
        $id = trim((string) ($_GET['id'] ?? ''));
        if ($id === '') {
            json_error(400, 'معرّف id مطلوب');
        }
        $stmt = $pdo->prepare('DELETE FROM home_promotions WHERE id = :id LIMIT 1');
        $stmt->execute([':id' => $id]);
        echo json_encode(['ok' => true, 'deleted' => $stmt->rowCount()], JSON_UNESCAPED_UNICODE);
        return;
    }
    json_error(405, 'Method not allowed');
}

function app_property_news_get_route(PDO $pdo): void
{
    $id = trim((string) ($_GET['id'] ?? ''));
    if ($id === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $id)) {
        json_error(400, 'معرّف غير صالح');
    }
    $stmt = $pdo->prepare(
        'SELECT id, title, image_url, body, created_at AS published_at
         FROM property_news WHERE id = :id AND is_active = 1 LIMIT 1'
    );
    $stmt->execute([':id' => $id]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row) {
        json_error(404, 'الخبر غير موجود');
    }
    echo json_encode(['ok' => true, 'item' => $row], JSON_UNESCAPED_UNICODE);
}

function admin_property_news_route(PDO $pdo): void
{
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'GET') {
        require_admin_from_bearer($pdo);
        $stmt = $pdo->query(
            'SELECT id, title, image_url, body, sort_order, is_active, created_at
             FROM property_news ORDER BY sort_order ASC, created_at DESC'
        );
        $rows = $stmt !== false ? $stmt->fetchAll(PDO::FETCH_ASSOC) : [];
        echo json_encode(['ok' => true, 'items' => $rows], JSON_UNESCAPED_UNICODE);

        return;
    }
    if ($method === 'POST') {
        require_admin_from_bearer($pdo);
        $in = read_json_body();
        $action = trim((string) ($in['action'] ?? 'create'));
        $editId = trim((string) ($in['id'] ?? ''));
        $title = trim((string) ($in['title'] ?? ''));
        $imageUrl = trim((string) ($in['image_url'] ?? ''));
        $body = trim((string) ($in['body'] ?? ''));
        $sortOrder = (int) ($in['sort_order'] ?? 0);
        if ($title === '' || $imageUrl === '') {
            json_error(400, 'العنوان ورابط الصورة مطلوبان');
        }
        if (mb_strlen($body) < 20) {
            json_error(400, 'الوصف التفصيلي مطلوب (20 حرفاً على الأقل)');
        }
        if ($action === 'update') {
            if ($editId === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $editId)) {
                json_error(400, 'معرّف الخبر غير صالح');
            }
            $stmt = $pdo->prepare(
                'UPDATE property_news
                 SET title = :ti, image_url = :im, body = :bo, sort_order = :so, is_active = 1
                 WHERE id = :id LIMIT 1'
            );
            $stmt->execute([
                ':id' => $editId,
                ':ti' => $title,
                ':im' => $imageUrl,
                ':bo' => $body,
                ':so' => $sortOrder,
            ]);
            echo json_encode(['ok' => true, 'updated' => $stmt->rowCount()], JSON_UNESCAPED_UNICODE);
            return;
        }
        $id = uuid_v4();
        $stmt = $pdo->prepare(
            'INSERT INTO property_news (id, title, image_url, body, sort_order, is_active, created_at)
             VALUES (:id, :ti, :im, :bo, :so, 1, NOW(3))'
        );
        $stmt->execute([
            ':id' => $id,
            ':ti' => $title,
            ':im' => $imageUrl,
            ':bo' => $body,
            ':so' => $sortOrder,
        ]);
        $pushCount = 0;
        $snippet = mb_substr(preg_replace('/\s+/u', ' ', $body) ?? $body, 0, 120);
        $pushCount = vewo_fcm_notify_all_users(
            $pdo,
            'خبر عقاري جديد',
            $title . ($snippet !== '' ? ' — ' . $snippet : ''),
            [
                'type' => 'property_news',
                'news_id' => $id,
                'title' => $title,
                'body' => $snippet,
            ]
        );
        echo json_encode([
            'ok' => true,
            'id' => $id,
            'push_tokens' => $pushCount,
        ], JSON_UNESCAPED_UNICODE);

        return;
    }
    if ($method === 'DELETE') {
        require_admin_from_bearer($pdo);
        $id = trim((string) ($_GET['id'] ?? ''));
        if ($id === '') {
            json_error(400, 'معرّف id مطلوب');
        }
        $stmt = $pdo->prepare('DELETE FROM property_news WHERE id = :id LIMIT 1');
        $stmt->execute([':id' => $id]);
        echo json_encode(['ok' => true, 'deleted' => $stmt->rowCount()], JSON_UNESCAPED_UNICODE);

        return;
    }
    json_error(405, 'Method not allowed');
}

/**
 * جلسة مستخدم: رمز جلسة الزبون/المكتب أو رمز لوحة المسؤول.
 *
 * @return array{id: string, full_name: string, phone: string, role: string}
 */
function require_auth_user(PDO $pdo): array
{
    $token = get_bearer_token();
    if ($token === null || strlen($token) !== 64) {
        json_error(401, 'يجب تسجيل الدخول (Authorization: Bearer …)');
    }
    $emailSelect = function_exists('vewo_users_has_email_column') && vewo_users_has_email_column($pdo)
        ? 'u.email'
        : "'' AS email";
    $profileSelect = function_exists('vewo_users_has_profile_photo_column') && vewo_users_has_profile_photo_column($pdo)
        ? 'u.profile_photo_url'
        : "'' AS profile_photo_url";
    $marketerSelect = function_exists('vewo_users_has_is_marketer_column') && vewo_users_has_is_marketer_column($pdo)
        ? 'u.is_marketer'
        : '0 AS is_marketer';
    $stmt = $pdo->prepare(
        'SELECT u.id, u.full_name, u.phone, ' . $emailSelect . ', ' . $profileSelect . ', ' . $marketerSelect . ', u.role, u.office_approved, u.office_name, u.office_photo_url
         FROM user_session_tokens k
         INNER JOIN users u ON u.id = k.user_id
         WHERE k.token = :t AND k.expires_at > NOW(3) AND u.is_active = 1
         LIMIT 1'
    );
    $stmt->execute([':t' => $token]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (is_array($row)) {
        /** @var array{id: string, full_name: string, phone: string, role: string} */
        return $row;
    }
    $stmt = $pdo->prepare(
        'SELECT u.id, u.full_name, u.phone, ' . $emailSelect . ', ' . $profileSelect . ', ' . $marketerSelect . ', u.role, u.office_approved, u.office_name, u.office_photo_url
         FROM admin_api_tokens k
         INNER JOIN users u ON u.id = k.user_id
         WHERE k.token = :t AND k.expires_at > NOW(3) AND u.is_active = 1 AND u.role IN (\'admin\', \'staff\')
         LIMIT 1'
    );
    $stmt->execute([':t' => $token]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!is_array($row)) {
        json_error(401, 'رمز غير صالح أو منتهٍ');
    }
    /** @var array{id: string, full_name: string, phone: string, role: string} */
    return $row;
}

function first_admin_user_id(PDO $pdo): string
{
    $stmt = $pdo->query(
        "SELECT id FROM users WHERE role = 'admin' AND is_active = 1 ORDER BY created_at ASC LIMIT 1"
    );
    $id = $stmt !== false ? $stmt->fetchColumn() : false;
    if ($id === false || $id === null) {
        json_error(503, 'لا يوجد حساب مسؤول — أنشئ حساب admin في قاعدة البيانات');
    }

    return (string) $id;
}

/** رقم عرض ثابت للمحادثة (يبدأ من 10000001) — يُستخدم مع GET_LOCK لتفادي التزاحم */
function allocate_thread_public_no(PDO $pdo): int
{
    $pdo->query("SELECT GET_LOCK('vewo_chat_thread_public_no', 20)");
    try {
        $n = (int) $pdo->query(
            'SELECT COALESCE(MAX(thread_public_no), 10000000) + 1 FROM chat_threads'
        )->fetchColumn();

        return $n;
    } finally {
        $pdo->query('SELECT RELEASE_LOCK(\'vewo_chat_thread_public_no\')');
    }
}

/**
 * هل وُجدت رسالة فعلية في المحادثة؟
 */
function vewo_chat_thread_has_any_message(PDO $pdo, string $threadId): bool
{
    if ($threadId === '') {
        return false;
    }
    try {
        $st = $pdo->prepare('SELECT 1 FROM chat_messages WHERE thread_id = :t LIMIT 1');
        $st->execute([':t' => $threadId]);
        return (bool) $st->fetchColumn();
    } catch (Throwable $e) {
        return false;
    }
}

/**
 * في المحادثة الموسّطة: هل ردّ الأدمن/الموظف على خانة المعلن؟
 * عندها فقط تظهر المحادثة للمعلن.
 */
function vewo_chat_mediated_advertiser_unlocked(PDO $pdo, string $threadId): bool
{
    if ($threadId === '') {
        return false;
    }
    try {
        $st = $pdo->prepare(
            "SELECT 1
             FROM chat_messages m
             INNER JOIN users u ON u.id = m.sender_user_id
             WHERE m.thread_id = :t
               AND m.visibility = 'office_only'
               AND u.role IN ('admin','staff')
             LIMIT 1"
        );
        $st->execute([':t' => $threadId]);
        return (bool) $st->fetchColumn();
    } catch (Throwable $e) {
        return false;
    }
}

/**
 * في المحادثة الموسّطة: هل ردّ الأدمن/الموظف على خانة المستفسر؟
 */
function vewo_chat_mediated_inquirer_has_admin_reply(PDO $pdo, string $threadId): bool
{
    if ($threadId === '') {
        return false;
    }
    try {
        $st = $pdo->prepare(
            "SELECT 1
             FROM chat_messages m
             INNER JOIN users u ON u.id = m.sender_user_id
             WHERE m.thread_id = :t
               AND m.visibility = 'customer_only'
               AND u.role IN ('admin','staff')
             LIMIT 1"
        );
        $st->execute([':t' => $threadId]);
        return (bool) $st->fetchColumn();
    } catch (Throwable $e) {
        return false;
    }
}

/**
 * @return array<string,mixed>
 */
function assert_thread_access(PDO $pdo, string $threadId, array $me): array
{
    $stmt = $pdo->prepare('SELECT * FROM chat_threads WHERE id = :id LIMIT 1');
    $stmt->execute([':id' => $threadId]);
    $t = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!is_array($t)) {
        json_error(404, 'المحادثة غير موجودة');
    }
    $uid = (string) $me['id'];
    $role = (string) $me['role'];
    if ($role === 'admin' || $role === 'staff') {
        // الأدمن/الموظف يمكنه الدخول لكل المحادثات (direct و mediated).
        return $t;
    }

    $isInquirer = (string) ($t['customer_user_id'] ?? '') === $uid;
    $isAdvertiser = (string) ($t['office_user_id'] ?? '') === $uid;
    if (!$isInquirer && !$isAdvertiser) {
        json_error(403, 'ليس لديك صلاحية على هذه المحادثة');
    }

    $threadType = (string) ($t['thread_type'] ?? '');
    // المباشر: الطرف الثاني لا يدخل إلا بعد وجود رسالة فعلية.
    if ($threadType === 'direct' && $isAdvertiser && !vewo_chat_thread_has_any_message($pdo, $threadId)) {
        json_error(403, 'المحادثة لم تُفتح بعد — بانتظار رسالة من الطرف الآخر');
    }
    // الموسّطة: المعلن لا يدخل إلا بعد رد الأدمن/الموظف على خانته.
    if (
        $threadType === 'mediated' &&
        $isAdvertiser &&
        !vewo_chat_mediated_advertiser_unlocked($pdo, $threadId)
    ) {
        json_error(403, 'المحادثة لم تُفتح بعد — بانتظار رد الإدارة');
    }

    return $t;
}

function chat_thread_open_response(array $payload, ?array $reelContext = null): void
{
    if ($reelContext !== null) {
        $payload['reel'] = $reelContext;
    }
    echo json_encode($payload, JSON_UNESCAPED_UNICODE);
}

function vewo_chat_threads_has_reel_id_column(PDO $pdo): bool
{
    static $has = null;
    if ($has !== null) {
        return $has;
    }
    try {
        $chk = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'chat_threads' AND column_name = 'reel_id'"
        );
        $has = $chk !== false && (int) $chk->fetchColumn() > 0;
    } catch (Throwable $e) {
        $has = false;
    }
    return $has;
}

/**
 * طرف محادثة "محترف" = مكتب أو مسوّق.
 * المسوّق عادة role=office مع is_marketer=1 (وقد يكون role=marketer).
 */
function vewo_chat_is_pro_party(string $role, $isMarketerFlag = 0): bool
{
    if ($role === 'marketer' || $role === 'office') {
        return true;
    }
    return $isMarketerFlag === true
        || (int) $isMarketerFlag === 1
        || (string) $isMarketerFlag === '1';
}

/** زبون شخصي حقيقي (ليس مسوّقاً). */
function vewo_chat_is_customer_party(string $role, $isMarketerFlag = 0): bool
{
    if ($role !== 'customer') {
        return false;
    }
    return !vewo_chat_is_pro_party($role, $isMarketerFlag);
}

/**
 * قواعد الطرف الثالث (أدمن/موظف):
 * - زبون ↔ زبون → mediated
 * - مكتب/مسوق → زبون → mediated
 * - زبون → مكتب/مسوق → direct
 * - مكتب ↔ مسوق (وبالعكس، وأي محترف↔محترف) → direct
 */
function vewo_chat_should_open_direct(
    string $requesterRole,
    $requesterIsMarketer,
    string $peerRole,
    $peerIsMarketer
): bool {
    $reqPro = vewo_chat_is_pro_party($requesterRole, $requesterIsMarketer);
    $peerPro = vewo_chat_is_pro_party($peerRole, $peerIsMarketer);
    $reqCust = vewo_chat_is_customer_party($requesterRole, $requesterIsMarketer);
    $peerCust = vewo_chat_is_customer_party($peerRole, $peerIsMarketer);

    if ($reqCust && $peerCust) {
        return false;
    }
    if ($reqPro && $peerCust) {
        return false;
    }
    if ($reqCust && $peerPro) {
        return true;
    }
    if ($reqPro && $peerPro) {
        return true;
    }
    return false;
}

function vewo_chat_open_direct_response(
    PDO $pdo,
    string $customerId,
    string $officeId,
    ?string $propertyId,
    string $rawReelId,
    bool $hasReelThreadColumn,
    string $adminId,
    ?array $reelContext = null
): void {
    if ($customerId === '' || $officeId === '' || $customerId === $officeId) {
        json_error(400, 'لا يمكن فتح محادثة مباشرة غير صالحة');
    }

    $find = $pdo->prepare(
        "SELECT id, thread_public_no
         FROM chat_threads
         WHERE thread_type = 'direct'
           AND (
             (customer_user_id = :c1 AND office_user_id = :o1)
             OR (customer_user_id = :o2 AND office_user_id = :c2)
           )
         ORDER BY COALESCE(last_message_at, created_at) DESC
         LIMIT 1"
    );
    $params = [
        ':c1' => $customerId,
        ':o1' => $officeId,
        ':o2' => $officeId,
        ':c2' => $customerId,
    ];
    $find->execute($params);
    $exRow = $find->fetch(PDO::FETCH_ASSOC);
    if (is_array($exRow) && ($exRow['id'] ?? '') !== '') {
        $tid = (string) $exRow['id'];
        $tpn = $exRow['thread_public_no'] ?? null;
        $peer = $pdo->prepare('SELECT full_name, phone FROM users WHERE id = :id LIMIT 1');
        $peer->execute([':id' => $officeId]);
        $pr = $peer->fetch(PDO::FETCH_ASSOC) ?: [];
        chat_thread_open_response([
            'ok' => true,
            'thread_id' => $tid,
            'thread_public_no' => $tpn !== null && $tpn !== '' ? (int) $tpn : null,
            'thread_mode' => 'direct',
            'peer' => [
                'full_name' => (string) ($pr['full_name'] ?? ''),
                'phone' => (string) ($pr['phone'] ?? ''),
            ],
        ], $reelContext);
        return;
    }

    $tid = uuid_v4();
    $tpnNew = allocate_thread_public_no($pdo);
    $insertParams = [
        ':id' => $tid,
        ':c' => $customerId,
        ':o' => $officeId,
        ':a' => $adminId,
        ':p' => $propertyId,
        ':tpn' => $tpnNew,
    ];
    if ($hasReelThreadColumn) {
        $ins = $pdo->prepare(
            "INSERT INTO chat_threads (id, thread_type, customer_user_id, office_user_id, admin_user_id, property_id, reel_id, thread_public_no, created_at)
             VALUES (:id, 'direct', :c, :o, :a, :p, :r, :tpn, NOW(3))"
        );
        $insertParams[':r'] = $rawReelId !== '' ? $rawReelId : null;
    } else {
        $ins = $pdo->prepare(
            "INSERT INTO chat_threads (id, thread_type, customer_user_id, office_user_id, admin_user_id, property_id, thread_public_no, created_at)
             VALUES (:id, 'direct', :c, :o, :a, :p, :tpn, NOW(3))"
        );
    }
    $ins->execute($insertParams);

    $peer = $pdo->prepare('SELECT full_name, phone FROM users WHERE id = :id LIMIT 1');
    $peer->execute([':id' => $officeId]);
    $pr = $peer->fetch(PDO::FETCH_ASSOC) ?: [];
    chat_thread_open_response([
        'ok' => true,
        'thread_id' => $tid,
        'thread_public_no' => $tpnNew,
        'thread_mode' => 'direct',
        'peer' => [
            'full_name' => (string) ($pr['full_name'] ?? ''),
            'phone' => (string) ($pr['phone'] ?? ''),
        ],
    ], $reelContext);
}

function vewo_chat_normalize_mediated_parties(PDO $pdo, ?string $onlyThreadId = null): void
{
    $hasReel = vewo_chat_threads_has_reel_id_column($pdo);
    $reelSelect = $hasReel ? 't.reel_id, r.owner_user_id AS reel_owner_id,' : 'NULL AS reel_id, NULL AS reel_owner_id,';
    $reelJoin = $hasReel ? 'LEFT JOIN reels r ON r.id = t.reel_id' : '';
    $sql = 'SELECT t.id, t.customer_user_id, t.office_user_id,
                   COALESCE(t.customer_unread_count, 0) AS customer_unread_count,
                   COALESCE(t.office_unread_count, 0) AS office_unread_count,
                   t.property_id, ' . $reelSelect . '
                   p.owner_user_id AS property_owner_id
            FROM chat_threads t
            LEFT JOIN properties p ON p.id = t.property_id
            ' . $reelJoin . "
            WHERE t.thread_type = 'mediated'
              AND t.office_user_id IS NOT NULL";
    $params = [];
    if ($onlyThreadId !== null && $onlyThreadId !== '') {
        $sql .= ' AND t.id = :tid';
        $params[':tid'] = $onlyThreadId;
    }
    try {
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Throwable $e) {
        return;
    }
    foreach ($rows as $r) {
        $tid = (string) ($r['id'] ?? '');
        $customerId = (string) ($r['customer_user_id'] ?? '');
        $officeId = (string) ($r['office_user_id'] ?? '');
        $ownerId = trim((string) ($r['property_owner_id'] ?? ''));
        if ($ownerId === '') {
            $ownerId = trim((string) ($r['reel_owner_id'] ?? ''));
        }
        if (
            $tid === '' ||
            $ownerId === '' ||
            $customerId === '' ||
            $officeId === '' ||
            $officeId === $ownerId ||
            $customerId !== $ownerId
        ) {
            continue;
        }
        try {
            $pdo->beginTransaction();
            $up = $pdo->prepare(
                'UPDATE chat_threads
                 SET customer_user_id = :new_customer,
                     office_user_id = :new_office,
                     customer_unread_count = :new_customer_unread,
                     office_unread_count = :new_office_unread
                 WHERE id = :id LIMIT 1'
            );
            $up->execute([
                ':new_customer' => $officeId,
                ':new_office' => $customerId,
                ':new_customer_unread' => (int) ($r['office_unread_count'] ?? 0),
                ':new_office_unread' => (int) ($r['customer_unread_count'] ?? 0),
                ':id' => $tid,
            ]);
            $pdo->prepare(
                "UPDATE chat_messages
                 SET visibility = CASE
                    WHEN visibility = 'customer_only' THEN 'office_only'
                    WHEN visibility = 'office_only' THEN 'customer_only'
                    ELSE visibility
                 END
                 WHERE thread_id = :id"
            )->execute([':id' => $tid]);
            $pdo->commit();
        } catch (Throwable $e) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
        }
    }
}

function chat_thread_open(PDO $pdo): void
{
    $me = require_auth_user($pdo);
    if (($me['role'] ?? '') === 'admin') {
        json_error(400, 'افتح المحادثات من تطبيق المسؤول — قائمة المحادثات');
    }
    $in = read_json_body();
    $rawReelId = trim((string) ($in['reel_id'] ?? $in['reelId'] ?? ''));
    if ($rawReelId !== '' && !preg_match('/^[0-9a-fA-F-]{36}$/', $rawReelId)) {
        json_error(400, 'معرّف الريل غير صالح');
    }
    $hasReelThreadColumn = vewo_chat_threads_has_reel_id_column($pdo);
    $rawPid = trim((string) ($in['property_id'] ?? ''));
    $propertyId = $rawPid === '' ? null : $rawPid;
    $reelContext = null;
    $reelOwnerId = null;
    $reelOwnerRole = null;
    $isMarketerReelOwner = false;
    if ($rawReelId !== '') {
        $rstmt = $pdo->prepare(
            "SELECT r.id, r.property_id, r.owner_user_id, r.caption, r.video_public_url, r.created_at,
                    u.full_name, u.office_name, u.role, u.is_marketer
             FROM reels r INNER JOIN users u ON u.id = r.owner_user_id
             WHERE r.id = :id AND r.approval_status = 'approved' LIMIT 1"
        );
        $rstmt->execute([':id' => $rawReelId]);
        $rrow = $rstmt->fetch(PDO::FETCH_ASSOC);
        if (!is_array($rrow)) {
            json_error(404, 'الريل غير موجود');
        }
        if ($propertyId === null && !empty($rrow['property_id'])) {
            $propertyId = (string) $rrow['property_id'];
        }
        $reelOwnerId = trim((string) ($rrow['owner_user_id'] ?? ''));
        $reelOwnerRole = (string) ($rrow['role'] ?? '');
        $isMarketerReelOwner = (int) ($rrow['is_marketer'] ?? 0) === 1;
        $pub = $isMarketerReelOwner
            ? trim((string) ($rrow['full_name'] ?? ''))
            : trim((string) ($rrow['office_name'] ?? ''));
        $isOfficeReelOwner = $reelOwnerRole === 'office';
        if ($pub === '') {
            $pub = trim((string) ($rrow['full_name'] ?? ''));
        }
        $reelContext = [
            'id' => (string) $rrow['id'],
            'owner_user_id' => (string) ($rrow['owner_user_id'] ?? ''),
            'property_id' => $rrow['property_id'] !== null ? (string) $rrow['property_id'] : null,
            'caption' => (string) ($rrow['caption'] ?? ''),
            'video_public_url' => (string) ($rrow['video_public_url'] ?? ''),
            'publisher_display' => $isOfficeReelOwner && $pub !== '' ? $pub : 'عقار تاون',
            'publisher_account_type' => $isMarketerReelOwner ? 'marketer' : ($isOfficeReelOwner ? 'office' : 'customer'),
            'created_at' => (string) ($rrow['created_at'] ?? ''),
        ];
    }
    if ($propertyId !== null && !preg_match('/^[0-9a-fA-F-]{36}$/', $propertyId)) {
        json_error(400, 'معرّف المنشور غير صالح');
    }

    $adminId = first_admin_user_id($pdo);
    vewo_chat_normalize_mediated_parties($pdo);
    $cid = (string) $me['id'];
    $requesterRole = (string) ($me['role'] ?? '');
    $requesterIsMarketer = $me['is_marketer'] ?? 0;
    $threadCustomerId = $cid;
    $advertiserId = null;

    if ($propertyId !== null) {
        $marketerSelect = function_exists('vewo_users_has_is_marketer_column') && vewo_users_has_is_marketer_column($pdo)
            ? 'COALESCE(u.is_marketer, 0) AS owner_is_marketer'
            : '0 AS owner_is_marketer';
        $owStmt = $pdo->prepare(
            "SELECT u.id AS owner_id, u.role AS owner_role, {$marketerSelect}
             FROM properties p INNER JOIN users u ON u.id = p.owner_user_id
             WHERE p.id = :pid LIMIT 1"
        );
        $owStmt->execute([':pid' => $propertyId]);
        $own = $owStmt->fetch(PDO::FETCH_ASSOC);
        if (is_array($own)) {
            $ownerId = (string) ($own['owner_id'] ?? '');
            $ownerRole = (string) ($own['owner_role'] ?? '');
            $ownerIsMarketer = $own['owner_is_marketer'] ?? 0;
            if ($ownerId !== '' && $ownerId === $cid) {
                json_error(400, 'لا يمكن فتح محادثة مع نفسك من هذا المنشور');
            }
            if ($ownerId !== '') {
                $advertiserId = $ownerId;
            }
            // بادئ المحادثة = المستفسر، صاحب المنشور = المعلن.
            $threadCustomerId = $cid;
            if (
                $advertiserId !== null &&
                $ownerRole !== '' &&
                vewo_chat_should_open_direct(
                    $requesterRole,
                    $requesterIsMarketer,
                    $ownerRole,
                    $ownerIsMarketer
                )
            ) {
                // زبون → مكتب/مسوق، أو مكتب ↔ مسوق: مباشرة بدون وسيط.
                vewo_chat_open_direct_response(
                    $pdo,
                    $cid,
                    $advertiserId,
                    $propertyId,
                    $rawReelId,
                    $hasReelThreadColumn,
                    $adminId,
                    $reelContext
                );
                return;
            }
            // زبون ↔ زبون، أو مكتب/مسوق → زبون: عبر الإدارة/الموظف.
        }
    }

    if (
        $propertyId === null &&
        $reelOwnerId !== null &&
        $reelOwnerId !== '' &&
        $reelOwnerId !== $cid &&
        $reelOwnerRole !== '' &&
        in_array($requesterRole, ['customer', 'office', 'marketer'], true)
    ) {
        $reelOwnerIsMarketer = !empty($isMarketerReelOwner) ? 1 : 0;
        if (
            vewo_chat_should_open_direct(
                $requesterRole,
                $requesterIsMarketer,
                $reelOwnerRole,
                $reelOwnerIsMarketer
            )
        ) {
            vewo_chat_open_direct_response(
                $pdo,
                $cid,
                $reelOwnerId,
                null,
                $rawReelId,
                $hasReelThreadColumn,
                $adminId,
                $reelContext
            );
            return;
        }
        $threadCustomerId = $cid;
        $advertiserId = $reelOwnerId;
    }

    if ($propertyId === null && $reelOwnerId !== null && $reelOwnerId !== '' && $reelOwnerId !== $cid) {
        $threadCustomerId = $cid;
        $advertiserId = $reelOwnerId;
    } elseif ($propertyId === null && $rawReelId !== '' && $reelOwnerId === $cid) {
        json_error(400, 'لا يمكن فتح محادثة مع ريلك');
    }

    if ($propertyId !== null) {
        if ($hasReelThreadColumn && $rawReelId !== '') {
            $find = $pdo->prepare(
                'SELECT id FROM chat_threads WHERE thread_type = \'mediated\'
                 AND customer_user_id = :c AND admin_user_id = :a AND property_id = :p AND reel_id = :r
                 AND ((:o IS NULL AND office_user_id IS NULL) OR office_user_id = :o) LIMIT 1'
            );
            $find->execute([
                ':c' => $threadCustomerId,
                ':a' => $adminId,
                ':p' => $propertyId,
                ':r' => $rawReelId,
                ':o' => $advertiserId,
            ]);
        } else {
            $find = $pdo->prepare(
                'SELECT id FROM chat_threads WHERE thread_type = \'mediated\'
                 AND customer_user_id = :c AND admin_user_id = :a AND property_id = :p
                 AND ((:o IS NULL AND office_user_id IS NULL) OR office_user_id = :o) LIMIT 1'
            );
            $find->execute([
                ':c' => $threadCustomerId,
                ':a' => $adminId,
                ':p' => $propertyId,
                ':o' => $advertiserId,
            ]);
        }
    } elseif ($advertiserId !== null) {
        if ($hasReelThreadColumn && $rawReelId !== '') {
            $find = $pdo->prepare(
                'SELECT id FROM chat_threads WHERE thread_type = \'mediated\'
                 AND customer_user_id = :c AND admin_user_id = :a AND office_user_id = :o AND property_id IS NULL AND reel_id = :r LIMIT 1'
            );
            $find->execute([':c' => $threadCustomerId, ':a' => $adminId, ':o' => $advertiserId, ':r' => $rawReelId]);
        } else {
            $find = $pdo->prepare(
                'SELECT id FROM chat_threads WHERE thread_type = \'mediated\'
                 AND customer_user_id = :c AND admin_user_id = :a AND office_user_id = :o AND property_id IS NULL LIMIT 1'
            );
            $find->execute([':c' => $threadCustomerId, ':a' => $adminId, ':o' => $advertiserId]);
        }
    } else {
        $find = $pdo->prepare(
            'SELECT id FROM chat_threads WHERE thread_type = \'mediated\'
             AND customer_user_id = :c AND admin_user_id = :a AND office_user_id IS NULL AND property_id IS NULL LIMIT 1'
        );
        $find->execute([':c' => $cid, ':a' => $adminId]);
    }
    $existing = $find->fetchColumn();
    if ($existing !== false && $existing !== null) {
        $tpRow = $pdo->prepare('SELECT thread_public_no FROM chat_threads WHERE id = :id LIMIT 1');
        $tpRow->execute([':id' => (string) $existing]);
        $tpnEx = $tpRow->fetchColumn();
        $adm = $pdo->prepare('SELECT full_name, phone FROM users WHERE id = :id LIMIT 1');
        $adm->execute([':id' => $adminId]);
        $an = $adm->fetch(PDO::FETCH_ASSOC) ?: [];

        chat_thread_open_response([
            'ok' => true,
            'thread_id' => (string) $existing,
            'thread_public_no' => $tpnEx !== false && $tpnEx !== null && $tpnEx !== ''
                ? (int) $tpnEx
                : null,
            'thread_mode' => 'mediated',
            'admin' => [
                'full_name' => 'عقار تاون',
                'phone' => (string) ($an['phone'] ?? ''),
            ],
        ], $reelContext);

        return;
    }

    $tid = uuid_v4();
    $tpnMed = allocate_thread_public_no($pdo);
    $params = [
        ':id' => $tid,
        ':c' => $threadCustomerId,
        ':o' => $advertiserId,
        ':a' => $adminId,
        ':p' => $propertyId,
        ':tpn' => $tpnMed,
    ];
    if ($hasReelThreadColumn) {
        $ins = $pdo->prepare(
            'INSERT INTO chat_threads (id, thread_type, customer_user_id, office_user_id, admin_user_id, property_id, reel_id, thread_public_no, created_at)
             VALUES (:id, \'mediated\', :c, :o, :a, :p, :r, :tpn, NOW(3))'
        );
        $params[':r'] = $rawReelId !== '' ? $rawReelId : null;
    } else {
        $ins = $pdo->prepare(
            'INSERT INTO chat_threads (id, thread_type, customer_user_id, office_user_id, admin_user_id, property_id, thread_public_no, created_at)
             VALUES (:id, \'mediated\', :c, :o, :a, :p, :tpn, NOW(3))'
        );
    }
    $ins->execute($params);

    $adm = $pdo->prepare('SELECT full_name, phone FROM users WHERE id = :id LIMIT 1');
    $adm->execute([':id' => $adminId]);
    $an = $adm->fetch(PDO::FETCH_ASSOC) ?: [];

    chat_thread_open_response([
        'ok' => true,
        'thread_id' => $tid,
        'thread_public_no' => $tpnMed,
        'thread_mode' => 'mediated',
        'admin' => [
            'full_name' => 'عقار تاون',
            'phone' => (string) ($an['phone'] ?? ''),
        ],
    ], $reelContext);
}

function chat_threads_list(PDO $pdo): void
{
    $me = require_auth_user($pdo);
    vewo_chat_normalize_mediated_parties($pdo);
    $uid = (string) $me['id'];
    $role = (string) $me['role'];

    $qRaw = trim((string) ($_GET['q'] ?? ''));
    $qRaw = ltrim($qRaw, '#');
    $filterNo = null;
    if ($qRaw !== '' && ctype_digit($qRaw)) {
        $filterNo = (int) $qRaw;
    }

    $propPubExpr = vewo_properties_has_public_no_column($pdo)
        ? 'p.property_public_no'
        : 'NULL';
    $thumbSql = '(SELECT m.public_url FROM property_media m WHERE m.property_id = t.property_id AND m.media_type = \'image\' ORDER BY m.created_at ASC LIMIT 1) AS property_thumb_url';
    $hasReelThreadColumn = vewo_chat_threads_has_reel_id_column($pdo);
    $reelIdSelect = $hasReelThreadColumn ? 't.reel_id' : 'NULL AS reel_id';
    $reelJoin = $hasReelThreadColumn ? 'LEFT JOIN reels r ON r.id = t.reel_id' : '';
    $reelSelect = $hasReelThreadColumn
        ? ', r.caption AS reel_caption, r.video_public_url AS reel_video_public_url'
        : ', NULL AS reel_caption, NULL AS reel_video_public_url';
    // اسم من أرسل أول رسالة: للمكتب يُفضَّل اسم المكتب المسجَّل ثم الاسم الشخصي.
    $firstSenderSql = '(SELECT COALESCE(
                NULLIF(TRIM(u_fs.office_name), \'\'),
                NULLIF(TRIM(u_fs.full_name), \'\'),
                NULLIF(TRIM(u_fs.phone), \'\'),
                \'\'
             )
             FROM chat_messages cm_fs
             INNER JOIN users u_fs ON u_fs.id = cm_fs.sender_user_id
             WHERE cm_fs.thread_id = t.id
             ORDER BY cm_fs.created_at ASC
             LIMIT 1) AS first_sender_name';

    if ($role === 'admin' || $role === 'staff') {
        $sql = 'SELECT t.id, t.thread_public_no, t.property_id, ' . $reelIdSelect . ', ' . $propPubExpr . ' AS property_public_no,
                    p.title AS property_title,
                    t.customer_user_id, t.office_user_id, t.created_at, t.thread_type,
                    c.full_name AS customer_name, c.office_name AS customer_office_name, c.phone AS customer_phone,
                    ofc.full_name AS office_full_name, ofc.office_name AS office_name, ofc.phone AS office_phone,
                    t.admin_unread_count, t.last_message_at, t.last_message_preview,
                    ' . $firstSenderSql . ',
                    ' . $thumbSql . '
                    ' . $reelSelect . '
             FROM chat_threads t
             INNER JOIN users c ON c.id = t.customer_user_id
             LEFT JOIN users ofc ON ofc.id = t.office_user_id
             LEFT JOIN properties p ON p.id = t.property_id
             ' . $reelJoin . '
             WHERE t.last_message_at IS NOT NULL';
        if ($filterNo !== null) {
            $sql .= ' AND t.thread_public_no = :tpn';
        }
        $sql .= ' ORDER BY COALESCE(t.last_message_at, t.created_at) DESC LIMIT 80';
        $stmt = $pdo->prepare($sql);
        if ($filterNo !== null) {
            $stmt->bindValue(':tpn', $filterNo, PDO::PARAM_INT);
        }
        $stmt->execute();
    } else {
        $sql = 'SELECT t.id, t.thread_public_no, t.property_id, ' . $reelIdSelect . ', ' . $propPubExpr . ' AS property_public_no,
                    p.title AS property_title,
                    t.customer_user_id, t.office_user_id, t.created_at, t.thread_type,
                    CASE
                        WHEN t.thread_type = \'mediated\' AND t.office_user_id = :c1 THEN cu.full_name
                        WHEN t.thread_type = \'mediated\' THEN COALESCE(NULLIF(TRIM(ofc.office_name), \'\'), ofc.full_name, \'عقار تاون\')
                        WHEN t.office_user_id = :c1 THEN cu.full_name
                        ELSE COALESCE(NULLIF(TRIM(ofc.office_name), \'\'), ofc.full_name)
                    END AS admin_name,
                    CASE
                        WHEN t.thread_type = \'mediated\' AND t.office_user_id = :c2 THEN cu.phone
                        WHEN t.thread_type = \'mediated\' THEN a.phone
                        WHEN t.office_user_id = :c2 THEN cu.phone
                        ELSE ofc.phone
                    END AS admin_phone
                    ,t.customer_unread_count, t.office_unread_count, t.last_message_at, t.last_message_preview,
                    ' . $firstSenderSql . ',
                    ' . $thumbSql . '
                    ' . $reelSelect . '
             FROM chat_threads t
             LEFT JOIN users a ON t.thread_type = \'mediated\' AND a.id = t.admin_user_id
             LEFT JOIN users cu ON cu.id = t.customer_user_id
             LEFT JOIN users ofc ON ofc.id = t.office_user_id
             LEFT JOIN properties p ON p.id = t.property_id
             ' . $reelJoin . '
             WHERE (
                -- مباشر: البادئ يرى محادثته، والطرف الثاني فقط بعد رسالة فعلية
                (t.thread_type = \'direct\' AND t.customer_user_id = :c3)
                OR (t.thread_type = \'direct\' AND t.office_user_id = :c6 AND t.last_message_at IS NOT NULL)
                -- موسّطة: المستفسر يرى محادثته، والمعلن فقط بعد رد الإدارة على خانته
                OR (t.thread_type = \'mediated\' AND t.customer_user_id = :c4)
                OR (
                    t.thread_type = \'mediated\'
                    AND t.office_user_id = :c7
                    AND EXISTS (
                        SELECT 1
                        FROM chat_messages m_unlock
                        INNER JOIN users u_unlock ON u_unlock.id = m_unlock.sender_user_id
                        WHERE m_unlock.thread_id = t.id
                          AND m_unlock.visibility = \'office_only\'
                          AND u_unlock.role IN (\'admin\',\'staff\')
                    )
                )
             )';
        if ($filterNo !== null) {
            $sql .= ' AND t.thread_public_no = :tpn';
        }
        $sql .= ' ORDER BY COALESCE(t.last_message_at, t.created_at) DESC LIMIT 80';
        $stmt = $pdo->prepare($sql);
        $stmt->bindValue(':c1', $uid, PDO::PARAM_STR);
        $stmt->bindValue(':c2', $uid, PDO::PARAM_STR);
        $stmt->bindValue(':c3', $uid, PDO::PARAM_STR);
        $stmt->bindValue(':c4', $uid, PDO::PARAM_STR);
        $stmt->bindValue(':c6', $uid, PDO::PARAM_STR);
        $stmt->bindValue(':c7', $uid, PDO::PARAM_STR);
        if ($filterNo !== null) {
            $stmt->bindValue(':tpn', $filterNo, PDO::PARAM_INT);
        }
        $stmt->execute();
    }
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Add role-specific unread_count and display names.
    foreach ($rows as &$r) {
        $tt = (string) ($r['thread_type'] ?? '');
        $isInquirerSide = (string) ($r['customer_user_id'] ?? '') === $uid;
        $isAdvertiserSide = (string) ($r['office_user_id'] ?? '') === $uid;
        if ($isAdvertiserSide) {
            $r['unread_count'] = (int) ($r['office_unread_count'] ?? 0);
        } elseif ($isInquirerSide) {
            $r['unread_count'] = (int) ($r['customer_unread_count'] ?? 0);
        } else {
            $r['unread_count'] = (int) ($r['admin_unread_count'] ?? 0);
        }
        if ($role !== 'admin' && $role !== 'staff' && $tt === 'mediated') {
            $laneVis = $isAdvertiserSide ? 'office_only' : 'customer_only';
            try {
                $pv = $pdo->prepare(
                    "SELECT body, media_public_url
                     FROM chat_messages
                     WHERE thread_id = :tid
                       AND (
                         visibility = :lane
                         OR (visibility = 'all' AND sender_user_id = :uid)
                       )
                     ORDER BY created_at DESC
                     LIMIT 1"
                );
                $pv->execute([
                    ':tid' => (string) ($r['id'] ?? ''),
                    ':lane' => $laneVis,
                    ':uid' => $uid,
                ]);
                $pr = $pv->fetch(PDO::FETCH_ASSOC);
                if (is_array($pr)) {
                    $preview = trim((string) ($pr['body'] ?? ''));
                    if ($preview === '' && trim((string) ($pr['media_public_url'] ?? '')) !== '') {
                        $preview = 'وسائط';
                    }
                    $r['last_message_preview'] = $preview;
                } else {
                    $r['last_message_preview'] = '';
                }
            } catch (Throwable $e) {
                $r['last_message_preview'] = '';
            }
        }
        if ($role === 'admin' || $role === 'staff') {
            $customerOffice = trim((string) ($r['customer_office_name'] ?? ''));
            $customerFull = trim((string) ($r['customer_name'] ?? ''));
            $officeName = trim((string) ($r['office_name'] ?? ''));
            $officeFull = trim((string) ($r['office_full_name'] ?? ''));
            $r['office_display_name'] = $officeName !== '' ? $officeName : $officeFull;
            $r['customer_display_name'] = $customerOffice !== '' ? $customerOffice : ($customerFull !== '' ? $customerFull : 'زبون');
            // For mediated threads without office, keep office_display_name empty.
        }
        $r['thread_type'] = $tt;
    }
    unset($r);

    echo json_encode(['ok' => true, 'items' => $rows], JSON_UNESCAPED_UNICODE);
}

function chat_messages_list(PDO $pdo): void
{
    $me = require_auth_user($pdo);
    $tid = trim((string) ($_GET['thread_id'] ?? ''));
    if ($tid === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $tid)) {
        json_error(400, 'thread_id مطلوب');
    }
    vewo_chat_normalize_mediated_parties($pdo, $tid);
    $t = assert_thread_access($pdo, $tid, $me);

    $role = (string) ($me['role'] ?? '');
    $uid = (string) ($me['id'] ?? '');
    $where = 'thread_id = :t';
    $params = [':t' => $tid];
    if ((string) ($t['thread_type'] ?? '') === 'direct') {
        if ((string) ($t['office_user_id'] ?? '') === $uid) {
            $where .= " AND visibility IN ('all','office_only')";
        } elseif ((string) ($t['customer_user_id'] ?? '') === $uid) {
            $where .= " AND visibility IN ('all','customer_only')";
        } else {
            // admin/staff see everything
        }
    } elseif ($role !== 'admin' && $role !== 'staff') {
        // موسّطة: كل طرف يرى خانته فقط مع ردود الإدارة الموجّهة له.
        // لا نعرض visibility=all حتى لا تتسرب رسائل الطرف الآخر القديمة.
        if ((string) ($t['office_user_id'] ?? '') === $uid) {
            $where .= " AND (
                visibility = 'office_only'
                OR (visibility = 'all' AND sender_user_id = :uid_self_o)
            )";
            $params[':uid_self_o'] = $uid;
        } elseif ((string) ($t['customer_user_id'] ?? '') === $uid) {
            $where .= " AND (
                visibility = 'customer_only'
                OR (visibility = 'all' AND sender_user_id = :uid_self_c)
            )";
            $params[':uid_self_c'] = $uid;
        } else {
            json_error(403, 'ليس لديك صلاحية على هذه المحادثة');
        }
    } else {
        // admin/staff see everything
    }

    $avatarSql = 'COALESCE(NULLIF(TRIM(u.profile_photo_url), \'\'), NULLIF(TRIM(u.office_photo_url), \'\'), \'\') AS sender_avatar_url';
    if (!function_exists('vewo_users_has_profile_photo_column') || !vewo_users_has_profile_photo_column($pdo)) {
        $avatarSql = 'NULLIF(TRIM(u.office_photo_url), \'\') AS sender_avatar_url';
    }
    $stmt = $pdo->prepare(
        'SELECT m.id, m.sender_user_id, m.visibility, m.body,
                m.media_type, m.media_public_url, m.duration_ms,
                m.created_at,
                u.full_name AS sender_full_name, u.role AS sender_role, u.office_name AS sender_office_name,
                ' . $avatarSql . '
         FROM chat_messages m
         INNER JOIN users u ON u.id = m.sender_user_id
         WHERE ' . $where . '
         ORDER BY m.created_at ASC
         LIMIT 500'
    );
    $stmt->execute($params);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $threadCustomerId = (string) ($t['customer_user_id'] ?? '');
    $threadOfficeId = (string) ($t['office_user_id'] ?? '');
    $threadTypeForLabels = (string) ($t['thread_type'] ?? '');
    foreach ($rows as &$r) {
        $sr = (string) ($r['sender_role'] ?? '');
        $senderId = (string) ($r['sender_user_id'] ?? '');
        if ($sr === 'admin' || $sr === 'staff') {
            $r['sender_display_name'] = 'عقار تاون';
            $r['sender_conversation_label'] = '';
        } elseif ($threadOfficeId !== '' && $senderId === $threadOfficeId) {
            $on = trim((string) ($r['sender_office_name'] ?? ''));
            $fn = trim((string) ($r['sender_full_name'] ?? ''));
            $r['sender_display_name'] = $on !== '' ? $on : $fn;
            $r['sender_conversation_label'] = $threadTypeForLabels === 'direct' ? '' : 'معلن';
        } elseif ($threadCustomerId !== '' && $senderId === $threadCustomerId) {
            $r['sender_display_name'] = (string) ($r['sender_full_name'] ?? '');
            $r['sender_conversation_label'] = $threadTypeForLabels === 'direct' ? '' : 'مستفسر';
        } elseif ($sr === 'office' || $sr === 'marketer') {
            $on = trim((string) ($r['sender_office_name'] ?? ''));
            $fn = trim((string) ($r['sender_full_name'] ?? ''));
            $r['sender_display_name'] = $on !== '' ? $on : $fn;
            $r['sender_conversation_label'] = 'معلن';
        } else {
            $r['sender_display_name'] = (string) ($r['sender_full_name'] ?? '');
            $r['sender_conversation_label'] = 'مستفسر';
        }
    }
    unset($r);

    $tpnMsg = $t['thread_public_no'] ?? null;
    $property = null;
    $pid = trim((string) ($t['property_id'] ?? ''));
    if ($pid !== '') {
        $property = function_exists('vewo_property_summary_array')
            ? vewo_property_summary_array($pdo, $pid)
            : null;
    }

    $reel = null;
    if (vewo_chat_threads_has_reel_id_column($pdo)) {
        $rid = trim((string) ($t['reel_id'] ?? ''));
        if ($rid !== '' && preg_match('/^[0-9a-fA-F-]{36}$/', $rid)) {
            try {
                $rs = $pdo->prepare(
                    "SELECT r.id, r.owner_user_id, r.property_id, r.caption, r.video_public_url, r.created_at,
                            u.full_name, u.office_name, u.role
                     FROM reels r INNER JOIN users u ON u.id = r.owner_user_id
                     WHERE r.id = :id LIMIT 1"
                );
                $rs->execute([':id' => $rid]);
                $rr = $rs->fetch(PDO::FETCH_ASSOC);
                if (is_array($rr)) {
                    $pub = trim((string) ($rr['office_name'] ?? ''));
                    $isOfficeReelOwner = (string) ($rr['role'] ?? '') === 'office';
                    if ($pub === '') {
                        $pub = trim((string) ($rr['full_name'] ?? ''));
                    }
                    $reel = [
                        'id' => (string) $rr['id'],
                        'owner_user_id' => (string) ($rr['owner_user_id'] ?? ''),
                        'property_id' => $rr['property_id'] !== null ? (string) $rr['property_id'] : null,
                        'caption' => (string) ($rr['caption'] ?? ''),
                        'video_public_url' => (string) ($rr['video_public_url'] ?? ''),
                        'publisher_display' => $isOfficeReelOwner && $pub !== '' ? $pub : 'عقار تاون',
                        'created_at' => (string) ($rr['created_at'] ?? ''),
                    ];
                }
            } catch (Throwable $e) {
                $reel = null;
            }
        }
    }

    $customerPhone = null;
    $customerDisplayName = null;
    $officePhone = null;
    $officeDisplayName = null;
    $cid = trim((string) ($t['customer_user_id'] ?? ''));
    $oid = trim((string) ($t['office_user_id'] ?? ''));
    if ($cid !== '' && preg_match('/^[0-9a-fA-F-]{36}$/', $cid)) {
        try {
            $ps = $pdo->prepare('SELECT full_name, office_name, phone, role, is_marketer FROM users WHERE id = :id LIMIT 1');
            $ps->execute([':id' => $cid]);
            $cr = $ps->fetch(PDO::FETCH_ASSOC);
            if (is_array($cr)) {
                $customerPhone = (string) ($cr['phone'] ?? '');
                $customerOffice = trim((string) ($cr['office_name'] ?? ''));
                $customerFull = trim((string) ($cr['full_name'] ?? ''));
                $customerIsOffice = (string) ($cr['role'] ?? '') === 'office' && (int) ($cr['is_marketer'] ?? 0) !== 1;
                $customerDisplayName = $customerIsOffice && $customerOffice !== '' ? $customerOffice : $customerFull;
            }
        } catch (Throwable $e) {
            $customerPhone = null;
            $customerDisplayName = null;
        }
    }
    if ($oid !== '' && preg_match('/^[0-9a-fA-F-]{36}$/', $oid)) {
        try {
            $ps = $pdo->prepare('SELECT full_name, office_name, phone, role, is_marketer FROM users WHERE id = :id LIMIT 1');
            $ps->execute([':id' => $oid]);
            $or = $ps->fetch(PDO::FETCH_ASSOC);
            if (is_array($or)) {
                $officePhone = (string) ($or['phone'] ?? '');
                $officeName = trim((string) ($or['office_name'] ?? ''));
                $officeFull = trim((string) ($or['full_name'] ?? ''));
                $officeIsOffice = (string) ($or['role'] ?? '') === 'office' && (int) ($or['is_marketer'] ?? 0) !== 1;
                $officeDisplayName = $officeIsOffice && $officeName !== '' ? $officeName : $officeFull;
            }
        } catch (Throwable $e) {
            $officePhone = null;
            $officeDisplayName = null;
        }
    }

    $customerReadAt = $t['customer_last_read_at'] ?? null;
    $adminReadAt = $t['admin_last_read_at'] ?? null;

    $out = [
        'ok' => true,
        'thread_public_no' => $tpnMsg !== null && $tpnMsg !== '' ? (int) $tpnMsg : null,
        'thread_type' => (string) ($t['thread_type'] ?? ''),
        'customer_user_id' => (string) ($t['customer_user_id'] ?? ''),
        'office_user_id' => (string) ($t['office_user_id'] ?? ''),
        'customer_display_name' => $customerDisplayName,
        'customer_phone' => $customerPhone,
        'office_display_name' => $officeDisplayName,
        'office_phone' => $officePhone,
        'customer_last_read_at' => $customerReadAt,
        'admin_last_read_at' => $adminReadAt,
        'property' => $property,
        'reel' => $reel,
        'items' => $rows,
    ];
    if ((string) ($t['thread_type'] ?? '') === 'mediated') {
        $out['awaiting_admin_reply'] = !vewo_chat_mediated_inquirer_has_admin_reply($pdo, $tid);
    } else {
        $out['awaiting_admin_reply'] = false;
    }
    if ($role === 'admin' || $role === 'staff') {
        try {
            $ts = $pdo->prepare(
                'SELECT customer_unread_count, office_unread_count, last_message_at FROM chat_threads WHERE id = :id LIMIT 1'
            );
            $ts->execute([':id' => $tid]);
            $tr = $ts->fetch(PDO::FETCH_ASSOC);
            if (is_array($tr)) {
                $out['thread_customer_unread'] = (int) ($tr['customer_unread_count'] ?? 0);
                $out['thread_office_unread'] = (int) ($tr['office_unread_count'] ?? 0);
                $out['thread_last_message_at'] = $tr['last_message_at'] ?? null;
                $out['mediated_customer_caught_up'] = ((string) ($t['thread_type'] ?? '') === 'mediated')
                    && (int) ($tr['customer_unread_count'] ?? 0) === 0;
            }
        } catch (Throwable $e) {
        }
    }

    echo json_encode($out, JSON_UNESCAPED_UNICODE);
}

function chat_messages_post(PDO $pdo): void
{
    $me = require_auth_user($pdo);
    $in = read_json_body();
    $tid = trim((string) ($in['thread_id'] ?? ''));
    $body = trim((string) ($in['body'] ?? ''));
    if ($tid === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $tid)) {
        json_error(400, 'thread_id مطلوب');
    }
    $mediaType = trim((string) ($in['media_type'] ?? ''));
    $mediaUrl = trim((string) ($in['media_public_url'] ?? ''));
    $durationMs = (int) ($in['duration_ms'] ?? 0);
    $visibility = trim((string) ($in['visibility'] ?? 'all'));

    if ($body === '' && $mediaUrl === '') {
        json_error(400, 'أرسل نصاً أو وسائط');
    }
    if ($body !== '' && mb_strlen($body) > 8000) {
        json_error(400, 'الرسالة طويلة جداً');
    }
    if (!in_array($visibility, ['all', 'customer_only', 'office_only'], true)) {
        json_error(400, 'visibility غير صالح');
    }

    vewo_chat_normalize_mediated_parties($pdo, $tid);
    $t = assert_thread_access($pdo, $tid, $me);
    $threadType = (string) ($t['thread_type'] ?? '');
    $role = (string) ($me['role'] ?? '');
    $senderId = (string) $me['id'];

    // Enforce visibility rules.
    // direct: الطرفان يريان بعضاً (all). الأدمن قد يستهدف طرفاً واحداً.
    // mediated: المستفسر والمعلن لا يريان بعضاً أبداً — فقط الأدمن/الموظف يرى الطرفين.
    if ($threadType === 'direct') {
        if ($role === 'admin' || $role === 'staff') {
            if (!in_array($visibility, ['customer_only', 'office_only', 'all'], true)) {
                $visibility = 'all';
            }
        } else {
            $visibility = 'all';
        }
    } else {
        $custIdForVis = (string) ($t['customer_user_id'] ?? '');
        $officeIdForVis = (string) ($t['office_user_id'] ?? '');
        if ($role === 'admin' || $role === 'staff') {
            // الأدمن يرد على خانة واحدة فقط (مستفسر أو معلن).
            if (!in_array($visibility, ['customer_only', 'office_only'], true)) {
                $visibility = 'customer_only';
            }
        } elseif ($senderId === $custIdForVis) {
            $visibility = 'customer_only';
        } elseif ($officeIdForVis !== '' && $senderId === $officeIdForVis) {
            $visibility = 'office_only';
        } else {
            json_error(403, 'ليس لديك صلاحية لإرسال رسالة في هذه المحادثة');
        }
    }

    $mid = uuid_v4();
    $stmt = $pdo->prepare(
        'INSERT INTO chat_messages (id, thread_id, sender_user_id, visibility, body, media_type, media_public_url, duration_ms, created_at)
         VALUES (:id, :tid, :sid, :vis, :body, :mt, :mu, :dur, NOW(3))'
    );
    $stmt->execute([
        ':id' => $mid,
        ':tid' => $tid,
        ':sid' => $senderId,
        ':vis' => $visibility,
        ':body' => $body,
        ':mt' => $mediaUrl !== '' ? ($mediaType !== '' ? $mediaType : 'file') : 'none',
        ':mu' => $mediaUrl !== '' ? $mediaUrl : null,
        ':dur' => $durationMs > 0 ? $durationMs : null,
    ]);

    // Update thread last message + unread counters.
    $preview = $body !== '' ? $body : ($mediaUrl !== '' ? 'وسائط' : '');
    if (mb_strlen($preview) > 380) $preview = mb_substr($preview, 0, 380) . '…';

    $pdo->prepare(
        'UPDATE chat_threads SET last_message_at = NOW(3), last_message_preview = :p WHERE id = :id LIMIT 1'
    )->execute([':p' => $preview, ':id' => $tid]);

    $custId = (string) ($t['customer_user_id'] ?? '');
    $officeId = (string) ($t['office_user_id'] ?? '');
    $adminId = (string) ($t['admin_user_id'] ?? '');
    if ($threadType === 'direct' && $adminId === '') {
        try {
            $adminId = first_admin_user_id($pdo);
        } catch (Throwable $e) {
            $adminId = '';
        }
    }

    if ($threadType === 'direct') {
        if ($senderId === $custId) {
            $pdo->prepare('UPDATE chat_threads SET office_unread_count = office_unread_count + 1, admin_unread_count = admin_unread_count + 1 WHERE id = :id LIMIT 1')
                ->execute([':id' => $tid]);
            // Push to office
            $tokens = vewo_device_tokens_for_user($pdo, $officeId, false);
            vewo_fcm_send(
                $tokens,
                'رسالة جديدة',
                'لديك رسالة جديدة في المحادثات',
                ['type' => 'chat', 'thread_id' => $tid]
            );
            if ($adminId !== '') {
                $adminTokens = function_exists('vewo_admin_app_device_tokens')
                    ? vewo_admin_app_device_tokens($pdo)
                    : vewo_device_tokens_for_user($pdo, $adminId, true);
                vewo_fcm_send(
                    $adminTokens,
                    'محادثة مباشرة',
                    'وصلت رسالة مباشرة بين مستفسر ومعلن',
                    ['type' => 'admin_chat', 'thread_id' => $tid, 'section' => 'chats']
                );
            }
        } elseif ($senderId === $officeId) {
            $pdo->prepare('UPDATE chat_threads SET customer_unread_count = customer_unread_count + 1, admin_unread_count = admin_unread_count + 1 WHERE id = :id LIMIT 1')
                ->execute([':id' => $tid]);
            // Push to customer
            $tokens = vewo_device_tokens_for_user($pdo, $custId, false);
            vewo_fcm_send(
                $tokens,
                'رسالة جديدة',
                'لديك رسالة جديدة في المحادثات',
                ['type' => 'chat', 'thread_id' => $tid]
            );
            if ($adminId !== '') {
                $adminTokens = function_exists('vewo_admin_app_device_tokens')
                    ? vewo_admin_app_device_tokens($pdo)
                    : vewo_device_tokens_for_user($pdo, $adminId, true);
                vewo_fcm_send(
                    $adminTokens,
                    'محادثة مباشرة',
                    'وصلت رسالة مباشرة بين مستفسر ومعلن',
                    ['type' => 'admin_chat', 'thread_id' => $tid, 'section' => 'chats']
                );
            }
        } else {
            // admin/staff message in direct can be targeted to one side.
            if ($visibility === 'customer_only') {
                $pdo->prepare('UPDATE chat_threads SET customer_unread_count = customer_unread_count + 1 WHERE id = :id LIMIT 1')
                    ->execute([':id' => $tid]);
                $tokens = vewo_device_tokens_for_user($pdo, $custId, false);
                vewo_fcm_send(
                    $tokens,
                    'رسالة من الإدارة',
                    'وصلتك رسالة داخل المحادثة',
                    ['type' => 'chat', 'thread_id' => $tid]
                );
            } elseif ($visibility === 'office_only') {
                $pdo->prepare('UPDATE chat_threads SET office_unread_count = office_unread_count + 1 WHERE id = :id LIMIT 1')
                    ->execute([':id' => $tid]);
                $tokens = vewo_device_tokens_for_user($pdo, $officeId, false);
                vewo_fcm_send(
                    $tokens,
                    'رسالة من الإدارة',
                    'وصلتك رسالة داخل المحادثة',
                    ['type' => 'chat', 'thread_id' => $tid]
                );
            } else {
                $pdo->prepare('UPDATE chat_threads SET customer_unread_count = customer_unread_count + 1, office_unread_count = office_unread_count + 1 WHERE id = :id LIMIT 1')
                    ->execute([':id' => $tid]);
                $t1 = vewo_device_tokens_for_user($pdo, $custId, false);
                $t2 = vewo_device_tokens_for_user($pdo, $officeId, false);
                vewo_fcm_send(
                    array_values(array_unique(array_merge($t1, $t2))),
                    'رسالة من الإدارة',
                    'وصلتك رسالة داخل المحادثة',
                    ['type' => 'chat', 'thread_id' => $tid]
                );
            }
        }
    } else {
        // mediated: admin is the mediator; customer and office never see each other.
        if ($visibility === 'customer_only') {
            if ($senderId !== $custId) {
                $pdo->prepare('UPDATE chat_threads SET customer_unread_count = customer_unread_count + 1 WHERE id = :id LIMIT 1')
                    ->execute([':id' => $tid]);
                $tokens = vewo_device_tokens_for_user($pdo, $custId, false);
                vewo_fcm_send(
                    $tokens,
                    'رسالة جديدة',
                    'لديك رسالة جديدة في المحادثات',
                    ['type' => 'chat', 'thread_id' => $tid]
                );
            }
            if ($senderId !== $adminId) {
                $pdo->prepare('UPDATE chat_threads SET admin_unread_count = admin_unread_count + 1 WHERE id = :id LIMIT 1')
                    ->execute([':id' => $tid]);
                $tokens = function_exists('vewo_admin_app_device_tokens')
                    ? vewo_admin_app_device_tokens($pdo)
                    : vewo_device_tokens_for_user($pdo, $adminId, true);
                vewo_fcm_send(
                    $tokens,
                    'محادثة جديدة',
                    'وصلت رسالة جديدة تحتاج متابعة',
                    ['type' => 'admin_chat', 'thread_id' => $tid, 'section' => 'chats']
                );
            }
        } elseif ($visibility === 'office_only') {
            if ($senderId !== $officeId) {
                $pdo->prepare('UPDATE chat_threads SET office_unread_count = office_unread_count + 1 WHERE id = :id LIMIT 1')
                    ->execute([':id' => $tid]);
                $tokens = vewo_device_tokens_for_user($pdo, $officeId, false);
                vewo_fcm_send(
                    $tokens,
                    'رسالة جديدة',
                    'لديك رسالة جديدة في المحادثات',
                    ['type' => 'chat', 'thread_id' => $tid]
                );
            }
            if ($senderId !== $adminId) {
                $pdo->prepare('UPDATE chat_threads SET admin_unread_count = admin_unread_count + 1 WHERE id = :id LIMIT 1')
                    ->execute([':id' => $tid]);
                $tokens = function_exists('vewo_admin_app_device_tokens')
                    ? vewo_admin_app_device_tokens($pdo)
                    : vewo_device_tokens_for_user($pdo, $adminId, true);
                vewo_fcm_send(
                    $tokens,
                    'محادثة جديدة',
                    'وصلت رسالة جديدة تحتاج متابعة',
                    ['type' => 'admin_chat', 'thread_id' => $tid, 'section' => 'chats']
                );
            }
        } else {
            // all: natural message; increment every other participant.
            if ($custId !== '' && $senderId !== $custId) {
                $pdo->prepare('UPDATE chat_threads SET customer_unread_count = customer_unread_count + 1 WHERE id = :id LIMIT 1')
                    ->execute([':id' => $tid]);
            }
            if ($officeId !== '' && $senderId !== $officeId) {
                $pdo->prepare('UPDATE chat_threads SET office_unread_count = office_unread_count + 1 WHERE id = :id LIMIT 1')
                    ->execute([':id' => $tid]);
            }
            if ($adminId !== '' && $senderId !== $adminId) {
                $pdo->prepare('UPDATE chat_threads SET admin_unread_count = admin_unread_count + 1 WHERE id = :id LIMIT 1')
                    ->execute([':id' => $tid]);
            }
            // Push to user sides + admin separately (admin needs admin_chat for deep link).
            $t1 = ($custId !== '' && $senderId !== $custId)
                ? vewo_device_tokens_for_user($pdo, $custId, false)
                : [];
            $t2 = ($officeId !== '' && $senderId !== $officeId)
                ? vewo_device_tokens_for_user($pdo, $officeId, false)
                : [];
            $userTokens = array_values(array_unique(array_merge($t1, $t2)));
            if (!empty($userTokens)) {
                vewo_fcm_send(
                    $userTokens,
                    'رسالة جديدة',
                    'لديك رسالة جديدة في المحادثات',
                    ['type' => 'chat', 'thread_id' => $tid]
                );
            }
            if ($adminId !== '' && $senderId !== $adminId) {
                $t3 = function_exists('vewo_admin_app_device_tokens')
                    ? vewo_admin_app_device_tokens($pdo)
                    : vewo_device_tokens_for_user($pdo, $adminId, true);
                vewo_fcm_send(
                    $t3,
                    'محادثة جديدة',
                    'وصلت رسالة جديدة تحتاج متابعة',
                    ['type' => 'admin_chat', 'thread_id' => $tid, 'section' => 'chats']
                );
            }
        }
    }

    echo json_encode(['ok' => true, 'id' => $mid], JSON_UNESCAPED_UNICODE);
}

function chat_thread_mark_read(PDO $pdo): void
{
    $me = require_auth_user($pdo);
    $in = read_json_body();
    $tid = trim((string) ($in['thread_id'] ?? ''));
    if ($tid === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $tid)) {
        json_error(400, 'thread_id مطلوب');
    }
    vewo_chat_normalize_mediated_parties($pdo, $tid);
    $t = assert_thread_access($pdo, $tid, $me);
    $role = (string) ($me['role'] ?? '');
    $uid = (string) ($me['id'] ?? '');

    $hasReadCols = false;
    try {
        $chk = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'chat_threads' AND column_name = 'customer_last_read_at'"
        );
        $hasReadCols = $chk !== false && (int) $chk->fetchColumn() > 0;
    } catch (Throwable $e) {
        $hasReadCols = false;
    }

    if ($role !== 'admin' && $role !== 'staff') {
        if ((string) ($t['customer_user_id'] ?? '') === $uid) {
            $sql = 'UPDATE chat_threads SET customer_unread_count = 0';
            if ($hasReadCols) {
                $sql .= ', customer_last_read_at = NOW(3)';
            }
            $sql .= ' WHERE id = :id LIMIT 1';
            $pdo->prepare($sql)->execute([':id' => $tid]);
        } elseif ((string) ($t['office_user_id'] ?? '') === $uid) {
            $pdo->prepare('UPDATE chat_threads SET office_unread_count = 0 WHERE id = :id LIMIT 1')
                ->execute([':id' => $tid]);
        } else {
            json_error(403, 'ليس لديك صلاحية');
        }
    } else {
        $sql = 'UPDATE chat_threads SET admin_unread_count = 0';
        if ($hasReadCols) {
            $sql .= ', admin_last_read_at = NOW(3)';
        }
        $sql .= ' WHERE id = :id LIMIT 1';
        $pdo->prepare($sql)->execute([':id' => $tid]);
    }

    echo json_encode(['ok' => true], JSON_UNESCAPED_UNICODE);
}

function vewo_fcm_server_key(): string
{
    $cfg = $GLOBALS['vewo_config'] ?? [];
    $fcm = is_array($cfg) ? ($cfg['fcm'] ?? []) : [];
    $key = is_array($fcm) ? (string) ($fcm['server_key'] ?? '') : '';
    return trim($key);
}

function vewo_fcm_config_value(string $key): string
{
    $cfg = $GLOBALS['vewo_config'] ?? [];
    $fcm = is_array($cfg) ? ($cfg['fcm'] ?? []) : [];
    return trim((string) (is_array($fcm) ? ($fcm[$key] ?? '') : ''));
}

function vewo_base64url(string $raw): string
{
    return rtrim(strtr(base64_encode($raw), '+/', '-_'), '=');
}

/** @return array<string,mixed>|null */
function vewo_fcm_service_account(): ?array
{
    $json = vewo_fcm_config_value('service_account_json');
    $file = vewo_fcm_config_value('service_account_file');
    if ($json === '' && $file !== '') {
        $path = $file;
        if (!preg_match('/^[A-Za-z]:[\\\\\\/]|^\//', $path)) {
            $path = __DIR__ . '/' . ltrim($path, '/\\');
        }
        if (is_file($path)) {
            $json = (string) @file_get_contents($path);
        }
    }
    if ($json === '') {
        return null;
    }
    $decoded = json_decode($json, true);
    return is_array($decoded) ? $decoded : null;
}

function vewo_fcm_access_token(): string
{
    static $cached = '';
    static $expiresAt = 0;

    if ($cached !== '' && $expiresAt > time() + 60) {
        return $cached;
    }

    $sa = vewo_fcm_service_account();
    if ($sa === null) {
        return '';
    }
    $clientEmail = trim((string) ($sa['client_email'] ?? ''));
    $privateKey = (string) ($sa['private_key'] ?? '');
    if ($clientEmail === '' || $privateKey === '') {
        return '';
    }

    $now = time();
    $header = ['alg' => 'RS256', 'typ' => 'JWT'];
    $claims = [
        'iss' => $clientEmail,
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
        'aud' => 'https://oauth2.googleapis.com/token',
        'iat' => $now,
        'exp' => $now + 3600,
    ];
    $unsigned = vewo_base64url(json_encode($header, JSON_UNESCAPED_SLASHES))
        . '.'
        . vewo_base64url(json_encode($claims, JSON_UNESCAPED_SLASHES));
    $signature = '';
    if (!function_exists('openssl_sign') || !openssl_sign($unsigned, $signature, $privateKey, OPENSSL_ALGO_SHA256)) {
        return '';
    }
    $jwt = $unsigned . '.' . vewo_base64url($signature);

    $ch = curl_init('https://oauth2.googleapis.com/token');
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/x-www-form-urlencoded']);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 8);
    curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query([
        'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion' => $jwt,
    ]));
    $raw = (string) @curl_exec($ch);
    @curl_close($ch);
    $token = json_decode($raw, true);
    if (!is_array($token) || empty($token['access_token'])) {
        return '';
    }
    $cached = (string) $token['access_token'];
    $expiresAt = $now + (int) ($token['expires_in'] ?? 3600);
    return $cached;
}

/** @param array<string,mixed> $data */
function vewo_fcm_clean_data(array $data, string $title, string $body): array
{
    $cleanData = [];
    foreach ($data as $k => $v) {
        if ($v === null) continue;
        if (is_bool($v)) {
            $cleanData[(string) $k] = $v ? '1' : '0';
        } elseif (is_scalar($v)) {
            $cleanData[(string) $k] = (string) $v;
        } else {
            $cleanData[(string) $k] = json_encode($v, JSON_UNESCAPED_UNICODE);
        }
    }
    return $cleanData + ['title' => $title, 'body' => $body];
}

function vewo_fcm_error_is_dead_token(string $err): bool
{
    $el = strtolower($err);
    if (str_contains($el, 'invalidapnscredential') || str_contains($el, 'third-party-auth-error')) {
        return false;
    }
    return str_contains($el, 'unregistered')
        || str_contains($el, 'notregistered')
        || str_contains($el, 'registration-token-not-registered')
        || str_contains($el, 'requested entity was not found')
        || str_contains($el, 'not_found')
        || str_contains($el, 'notfound')
        || str_contains($el, 'senderidmismatch')
        || str_contains($el, 'sender id mismatch');
}

function vewo_fcm_forget_token(string $token): void
{
    $token = trim($token);
    if ($token === '') {
        return;
    }
    $pdo = $GLOBALS['vewo_pdo'] ?? $GLOBALS['pdo'] ?? null;
    if (!$pdo instanceof PDO) {
        return;
    }
    try {
        $stmt = $pdo->prepare('DELETE FROM device_tokens WHERE token = :t');
        $stmt->execute([':t' => $token]);
    } catch (Throwable $e) {
    }
}

function vewo_device_tokens_prune_user(PDO $pdo, string $userId, int $adminApp): void
{
    if ($userId === '') {
        return;
    }
    try {
        if ((int) $adminApp === 1) {
            foreach (['android', 'ios'] as $platform) {
                $keep = $pdo->prepare(
                    'SELECT id FROM device_tokens
                     WHERE user_id = :u AND is_admin_app = 1 AND platform = :p
                     ORDER BY last_seen_at DESC
                     LIMIT 1'
                );
                $keep->execute([':u' => $userId, ':p' => $platform]);
                $id = trim((string) ($keep->fetchColumn() ?: ''));
                if ($id === '') {
                    continue;
                }
                $del = $pdo->prepare(
                    'DELETE FROM device_tokens
                     WHERE user_id = :u AND is_admin_app = 1 AND platform = :p AND id <> :id'
                );
                $del->execute([':u' => $userId, ':p' => $platform, ':id' => $id]);
            }
            $pdo->prepare(
                "DELETE FROM device_tokens
                 WHERE user_id = :u AND is_admin_app = 1
                   AND platform NOT IN ('android','ios')"
            )->execute([':u' => $userId]);
            return;
        }
        $keep = $pdo->prepare(
            'SELECT id FROM device_tokens
             WHERE user_id = :u AND is_admin_app = :a
             ORDER BY last_seen_at DESC
             LIMIT 2'
        );
        $keep->execute([':u' => $userId, ':a' => $adminApp]);
        $ids = [];
        foreach ($keep->fetchAll(PDO::FETCH_ASSOC) as $row) {
            $id = trim((string) ($row['id'] ?? ''));
            if ($id !== '') {
                $ids[] = $id;
            }
        }
        if ($ids === []) {
            return;
        }
        $in = implode(',', array_fill(0, count($ids), '?'));
        $del = $pdo->prepare(
            "DELETE FROM device_tokens
             WHERE user_id = ? AND is_admin_app = ? AND id NOT IN ($in)"
        );
        $del->execute(array_merge([$userId, $adminApp], $ids));
    } catch (Throwable $e) {
    }
}

function vewo_fcm_token_is_admin_android(string $token): bool
{
    static $cache = [];
    if (array_key_exists($token, $cache)) {
        return $cache[$token];
    }
    $pdo = $GLOBALS['vewo_pdo'] ?? $GLOBALS['pdo'] ?? null;
    $is = false;
    if ($pdo instanceof PDO) {
        try {
            $stmt = $pdo->prepare(
                'SELECT is_admin_app, platform FROM device_tokens WHERE token = :t LIMIT 1'
            );
            $stmt->execute([':t' => $token]);
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            if (is_array($row)) {
                $is = ((int) ($row['is_admin_app'] ?? 0) === 1)
                    && strtolower(trim((string) ($row['platform'] ?? ''))) === 'android';
            }
        } catch (Throwable $e) {
        }
    }
    $cache[$token] = $is;
    return $is;
}

function vewo_fcm_android_channel_id(array $data = []): string
{
    return 'vewo_heads_up';
}

/** @param string[] $tokens */
function vewo_fcm_send_legacy(array $tokens, string $title, string $body, array $data = []): void
{
    $key = vewo_fcm_server_key();
    if ($key === '' || empty($tokens)) return;
    $cleanData = vewo_fcm_clean_data($data, $title, $body);
    $channel = vewo_fcm_android_channel_id($data);
    foreach (array_chunk(array_values(array_unique($tokens)), 500) as $chunk) {
        $payload = [
            'registration_ids' => array_values($chunk),
            'priority' => 'high',
            'time_to_live' => 86400,
            'notification' => [
                'title' => $title,
                'body' => $body,
                'sound' => 'default',
                'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
                'android_channel_id' => $channel,
                'icon' => 'ic_launcher',
            ],
            'data' => $cleanData,
        ];

        $ch = curl_init('https://fcm.googleapis.com/fcm/send');
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Content-Type: application/json',
            'Authorization: key=' . $key,
        ]);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, 8);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload, JSON_UNESCAPED_UNICODE));
        @curl_exec($ch);
        @curl_close($ch);
    }
}

/** @param string[] $tokens
 *  @return array{sent:int,failed:int,errors:string[]}
 */
function vewo_fcm_send_v1(array $tokens, string $title, string $body, array $data = []): array
{
    $accessToken = vewo_fcm_access_token();
    $projectId = vewo_fcm_config_value('project_id');
    $sa = vewo_fcm_service_account();
    if ($projectId === '' && is_array($sa)) {
        $projectId = trim((string) ($sa['project_id'] ?? ''));
    }
    $report = ['sent' => 0, 'failed' => 0, 'errors' => []];
    if ($accessToken === '' || $projectId === '' || empty($tokens)) {
        $report['failed'] = count($tokens);
        $report['errors'][] = 'missing_access_token_or_project';
        return $report;
    }

    $cleanData = vewo_fcm_clean_data($data, $title, $body);
    $channel = vewo_fcm_android_channel_id($data);
    $url = 'https://fcm.googleapis.com/v1/projects/' . rawurlencode($projectId) . '/messages:send';
    $headers = [
        'Content-Type: application/json',
        'Authorization: Bearer ' . $accessToken,
    ];

    $unique = [];
    foreach (array_values(array_unique($tokens)) as $token) {
        $token = trim((string) $token);
        if ($token !== '') {
            $unique[] = $token;
        }
    }
    foreach (array_chunk($unique, 25) as $chunk) {
        $mh = curl_multi_init();
        $handles = [];
        foreach ($chunk as $token) {
            $notifTag = 'v' . bin2hex(random_bytes(8));
            $isAdminAndroid = vewo_fcm_token_is_admin_android($token);
            $icon = $isAdminAndroid ? 'ic_stat_notify' : 'ic_launcher';
            $androidChannel = $isAdminAndroid ? 'aqar_admin_alert' : $channel;
            $payload = [
                'message' => [
                    'token' => $token,
                    'notification' => ['title' => $title, 'body' => $body],
                    'data' => $cleanData,
                    'android' => [
                        'priority' => 'HIGH',
                        'ttl' => '86400s',
                        'notification' => [
                            'channel_id' => $androidChannel,
                            'icon' => $icon,
                            'tag' => $notifTag,
                            'sound' => 'default',
                            'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
                            'default_vibrate_timings' => true,
                            'default_sound' => true,
                            'default_light_settings' => true,
                            'notification_priority' => 'PRIORITY_MAX',
                            'visibility' => 'PUBLIC',
                            'ticker' => $title,
                        ],
                    ],
                    'apns' => [
                        'headers' => [
                            'apns-priority' => '10',
                            'apns-push-type' => 'alert',
                        ],
                        'payload' => [
                            'aps' => [
                                'alert' => [
                                    'title' => $title,
                                    'body' => $body,
                                ],
                                'sound' => 'default',
                                'badge' => 1,
                                'content-available' => 1,
                                'interruption-level' => 'active',
                            ],
                        ],
                    ],
                ],
            ];
            $ch = curl_init($url);
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_TIMEOUT, 12);
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload, JSON_UNESCAPED_UNICODE));
            curl_multi_add_handle($mh, $ch);
            $handles[] = ['ch' => $ch, 'token' => $token];
        }
        $running = null;
        do {
            $status = curl_multi_exec($mh, $running);
            if ($running > 0) {
                curl_multi_select($mh, 0.5);
            }
        } while ($running > 0 && $status === CURLM_OK);
        foreach ($handles as $item) {
            $ch = $item['ch'];
            $token = (string) ($item['token'] ?? '');
            $raw = (string) curl_multi_getcontent($ch);
            $code = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
            $decoded = json_decode($raw, true);
            if ($code >= 200 && $code < 300) {
                $report['sent']++;
            } else {
                $report['failed']++;
                $err = '';
                if (is_array($decoded)) {
                    $err = (string) ($decoded['error']['status'] ?? '');
                    $msg = (string) ($decoded['error']['message'] ?? '');
                    if ($err === '' && $msg !== '') {
                        $err = $msg;
                    } elseif ($msg !== '' && $err !== '') {
                        $err .= ': ' . $msg;
                    }
                    $details = $decoded['error']['details'] ?? null;
                    if (is_array($details)) {
                        foreach ($details as $d) {
                            if (!is_array($d)) continue;
                            $ec = (string) ($d['errorCode'] ?? '');
                            if ($ec !== '') {
                                $err .= ' [' . $ec . ']';
                            }
                        }
                    }
                }
                if ($err === '') {
                    $err = 'http_' . $code;
                }
                if (vewo_fcm_error_is_dead_token($err) && $token !== '') {
                    vewo_fcm_forget_token($token);
                }
                if (count($report['errors']) < 8) {
                    $report['errors'][] = $err;
                }
            }
            curl_multi_remove_handle($mh, $ch);
            curl_close($ch);
        }
        curl_multi_close($mh);
    }
    return $report;
}

/** @param string[] $tokens */
function vewo_fcm_send(array $tokens, string $title, string $body, array $data = []): void
{
    $tokens = array_values(array_unique(array_filter(array_map('trim', $tokens))));
    if (empty($tokens)) return;
    $sa = vewo_fcm_service_account();
    $projectId = vewo_fcm_config_value('project_id');
    if ($projectId === '' && is_array($sa)) {
        $projectId = trim((string) ($sa['project_id'] ?? ''));
    }
    if ($sa !== null && $projectId !== '' && vewo_fcm_access_token() !== '') {
        vewo_fcm_send_v1($tokens, $title, $body, $data);
        return;
    }
    vewo_fcm_send_legacy($tokens, $title, $body, $data);
}

function vewo_device_tokens_ensure(PDO $pdo): bool
{
    static $ok = null;
    if ($ok !== null) return $ok;
    try {
        $pdo->exec(
            "CREATE TABLE IF NOT EXISTS device_tokens (
              id CHAR(36) NOT NULL,
              token VARCHAR(512) NOT NULL,
              user_id CHAR(36) NULL,
              is_admin_app TINYINT(1) NOT NULL DEFAULT 0,
              platform VARCHAR(20) NOT NULL DEFAULT '',
              last_seen_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
              created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
              PRIMARY KEY (id),
              UNIQUE KEY uniq_device_token (token),
              KEY idx_device_user (user_id, is_admin_app),
              KEY idx_device_seen (last_seen_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"
        );
        try {
            $len = $pdo->query(
                "SELECT CHARACTER_MAXIMUM_LENGTH FROM information_schema.columns
                 WHERE table_schema = DATABASE() AND table_name = 'device_tokens' AND column_name = 'token'"
            );
            $max = $len !== false ? (int) $len->fetchColumn() : 0;
            if ($max > 0 && $max < 512) {
                $pdo->exec('ALTER TABLE device_tokens MODIFY token VARCHAR(512) NOT NULL');
            }
        } catch (Throwable $e) {
        }
        $ok = true;
    } catch (Throwable $e) {
        $ok = false;
    }
    return $ok;
}

/** @return string[] */
function vewo_device_tokens_for_user(PDO $pdo, string $userId, bool $adminApp): array
{
    if ($userId === '') return [];
    if (!vewo_device_tokens_ensure($pdo)) return [];
    try {
        $stmt = $pdo->prepare(
            'SELECT token FROM device_tokens WHERE user_id = :u AND is_admin_app = :a AND last_seen_at >= DATE_SUB(NOW(), INTERVAL 45 DAY) ORDER BY last_seen_at DESC LIMIT 12'
        );
        $stmt->execute([':u' => $userId, ':a' => $adminApp ? 1 : 0]);
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $out = [];
        foreach ($rows as $r) {
            $t = trim((string) ($r['token'] ?? ''));
            if ($t !== '') $out[] = $t;
        }
        return $out;
    } catch (Throwable $e) {
        return [];
    }
}

/** @return string[] */
function vewo_device_tokens_all(PDO $pdo, ?bool $adminApp = false): array
{
    if (!vewo_device_tokens_ensure($pdo)) return [];
    try {
        $sql = 'SELECT token FROM device_tokens WHERE last_seen_at >= DATE_SUB(NOW(), INTERVAL 45 DAY)';
        $params = [];
        if ($adminApp !== null) {
            $sql .= ' AND is_admin_app = :a';
            $params[':a'] = $adminApp ? 1 : 0;
        }
        $sql .= ' ORDER BY last_seen_at DESC LIMIT 50000';
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $out = [];
        foreach ($rows as $r) {
            $t = trim((string) ($r['token'] ?? ''));
            if ($t !== '') $out[] = $t;
        }
        return array_values(array_unique($out));
    } catch (Throwable $e) {
        return [];
    }
}

/** @return string[] توكنات تطبيق الأدمن لكل مسؤول وموظف نشط */
function vewo_admin_app_device_tokens(PDO $pdo): array
{
    if (!vewo_device_tokens_ensure($pdo)) {
        return [];
    }
    try {
        $stmt = $pdo->query(
            "SELECT d.token FROM device_tokens d
             INNER JOIN users u ON u.id = d.user_id
             WHERE d.is_admin_app = 1
               AND u.is_active = 1
               AND u.role IN ('admin','staff')
               AND d.last_seen_at >= DATE_SUB(NOW(), INTERVAL 45 DAY)
             ORDER BY d.last_seen_at DESC
             LIMIT 2000"
        );
        $rows = $stmt !== false ? $stmt->fetchAll(PDO::FETCH_ASSOC) : [];
        $out = [];
        foreach ($rows as $r) {
            $t = trim((string) ($r['token'] ?? ''));
            if ($t !== '') {
                $out[] = $t;
            }
        }

        return array_values(array_unique($out));
    } catch (Throwable $e) {
        return [];
    }
}

/**
 * إشعار فوري لكل أجهزة تطبيق الأدمن (مسؤولون وموظفون).
 */
function vewo_fcm_notify_admins(PDO $pdo, string $title, string $body, array $data = []): int
{
    if (!function_exists('vewo_fcm_send')) {
        return 0;
    }
    $title = trim($title);
    $body = trim($body);
    if ($title === '' && $body === '') {
        return 0;
    }
    $tokens = vewo_admin_app_device_tokens($pdo);
    if ($tokens === []) {
        return 0;
    }
    vewo_fcm_send($tokens, $title, $body, $data);

    return count($tokens);
}

/**
 * إشعار فوري مرتّب لجميع أجهزة تطبيق المستخدمين (ليس الأدمن).
 * @return int عدد التوكنات المستهدفة
 */
function vewo_fcm_notify_all_users(PDO $pdo, string $title, string $body, array $data = []): int
{
    if (!function_exists('vewo_fcm_send')) {
        return 0;
    }
    $title = trim($title);
    $body = trim($body);
    if ($title === '' && $body === '') {
        return 0;
    }
    if ($title === '') {
        $title = 'عقار تاون';
    }
    $tokens = vewo_device_tokens_all($pdo, false);
    if (empty($tokens)) {
        return 0;
    }
    vewo_fcm_send($tokens, $title, $body, $data);
    return count($tokens);
}

function vewo_truthy_flag(mixed $v): bool
{
    if (is_bool($v)) {
        return $v;
    }
    if (is_int($v) || is_float($v)) {
        return ((int) $v) === 1;
    }
    $s = strtolower(trim((string) $v));
    return in_array($s, ['1', 'true', 'yes', 'on'], true);
}

/** تنسيق سعر عراقي للإشعارات */
function vewo_format_iqd_price(int $price): string
{
    if ($price <= 0) {
        return '';
    }
    return number_format($price, 0, '.', ',') . ' د.ع';
}

/**
 * نص إشعار بيع عاجل مرتّب: العنوان · السعر · المنطقة · المساحة
 * @param array<string,mixed> $info
 */
function vewo_urgent_sale_public_body(array $info, int $days = 0): string
{
    $title = trim((string) ($info['title'] ?? ''));
    if ($title === '') {
        $title = trim((string) ($info['address_line'] ?? ''));
    }
    if ($title === '') {
        $title = 'عقار للبيع';
    }
    $parts = [$title];
    $price = vewo_format_iqd_price((int) ($info['price_iqd'] ?? 0));
    if ($price !== '') {
        $parts[] = 'السعر ' . $price;
    }
    $place = trim((string) ($info['governorate'] ?? ''));
    $addr = trim((string) ($info['address_line'] ?? ''));
    if ($addr !== '' && $addr !== $title) {
        $place = $place !== '' ? ($place . '، ' . $addr) : $addr;
    }
    if ($place !== '') {
        $parts[] = 'منطقة ' . $place;
    }
    $area = (int) ($info['area_sqm'] ?? 0);
    if ($area > 0) {
        $parts[] = $area . ' م²';
    }
    // المدة بالأيام للإدارة فقط — لا تُدرج في إشعار المستخدمين.
    return implode(' · ', $parts);
}

function app_device_register_route(PDO $pdo): void
{
    if (!vewo_device_tokens_ensure($pdo)) {
        json_error(500, 'تعذر تجهيز جدول الأجهزة');
    }
    $me = vewo_try_session_user($pdo);
    $uid = $me ? (string) ($me['id'] ?? '') : '';

    $in = read_json_body();
    $token = trim((string) ($in['token'] ?? ''));
    $platform = trim((string) ($in['platform'] ?? ''));
    if ($token === '' || strlen($token) < 20) {
        json_error(400, 'token غير صالح');
    }
    if ($platform === '') $platform = 'unknown';
    try {
        $id = uuid_v4();
        $stmt = $pdo->prepare(
            'INSERT INTO device_tokens (id, token, user_id, is_admin_app, platform, last_seen_at, created_at)
             VALUES (:id, :t, :u, 0, :p, NOW(), NOW())
             ON DUPLICATE KEY UPDATE user_id = VALUES(user_id), is_admin_app = 0, platform = VALUES(platform), last_seen_at = NOW()'
        );
        $stmt->execute([':id' => $id, ':t' => $token, ':u' => ($uid !== '' ? $uid : null), ':p' => $platform]);
        if ($uid !== '') {
            vewo_device_tokens_prune_user($pdo, $uid, 0);
        }
        echo json_encode(['ok' => true], JSON_UNESCAPED_UNICODE);
    } catch (Throwable $e) {
        json_error(500, 'تعذر حفظ التوكن');
    }
}

function admin_device_register_route(PDO $pdo): void
{
    if (!vewo_device_tokens_ensure($pdo)) {
        json_error(500, 'تعذر تجهيز جدول الأجهزة');
    }
    $me = vewo_try_admin_staff_user($pdo);
    $uid = $me ? (string) ($me['id'] ?? '') : '';

    $in = read_json_body();
    $token = trim((string) ($in['token'] ?? ''));
    $platform = trim((string) ($in['platform'] ?? ''));
    if ($token === '' || strlen($token) < 20) {
        json_error(400, 'token غير صالح');
    }
    if ($platform === '') $platform = 'unknown';
    try {
        $id = uuid_v4();
        $stmt = $pdo->prepare(
            'INSERT INTO device_tokens (id, token, user_id, is_admin_app, platform, last_seen_at, created_at)
             VALUES (:id, :t, :u, 1, :p, NOW(), NOW())
             ON DUPLICATE KEY UPDATE user_id = VALUES(user_id), is_admin_app = 1, platform = VALUES(platform), last_seen_at = NOW()'
        );
        $stmt->execute([':id' => $id, ':t' => $token, ':u' => ($uid !== '' ? $uid : null), ':p' => $platform]);
        if ($uid !== '') {
            $pdo->prepare(
                'DELETE FROM device_tokens
                 WHERE user_id = :u AND is_admin_app = 1 AND platform = :p AND token <> :t'
            )->execute([':u' => $uid, ':p' => $platform, ':t' => $token]);
            try {
                $pdo->prepare(
                    "DELETE FROM device_tokens
                     WHERE user_id = :u AND is_admin_app = 1
                       AND platform IN ('other','unknown','','windows','linux','macos')"
                )->execute([':u' => $uid]);
            } catch (Throwable $e) {
            }
            vewo_device_tokens_prune_user($pdo, $uid, 1);
        }
        echo json_encode(['ok' => true], JSON_UNESCAPED_UNICODE);
    } catch (Throwable $e) {
        json_error(500, 'تعذر حفظ التوكن');
    }
}

/**
 * اختبار FCM: يرسل إشعاراً فورياً لأجهزة المسؤول الحالي.
 * POST admin/fcm/test
 */
function admin_fcm_test_route(PDO $pdo): void
{
    $admin = require_admin_from_bearer($pdo);
    $uid = (string) ($admin['id'] ?? '');
    $sa = vewo_fcm_service_account();
    $saFile = vewo_fcm_config_value('service_account_file');
    $saPath = '';
    if ($saFile !== '') {
        $saPath = preg_match('/^[A-Za-z]:[\\\\\\/]|^\//', $saFile)
            ? $saFile
            : (__DIR__ . '/' . ltrim($saFile, '/\\'));
    }
    $projectId = vewo_fcm_config_value('project_id');
    if ($projectId === '' && is_array($sa)) {
        $projectId = trim((string) ($sa['project_id'] ?? ''));
    }
    $legacy = vewo_fcm_server_key();
    $mode = 'none';
    if ($sa !== null && $projectId !== '') {
        $mode = 'http_v1';
        if (vewo_fcm_access_token() === '') {
            json_error(500, 'فشل access token من Google — تحقق من Service Account على سيرفر لينكس (openssl + firebase-sa.json)');
        }
    } elseif ($legacy !== '') {
        $mode = 'legacy';
    } else {
        $hint = $saPath !== '' ? (' الملف المتوقع: ' . $saPath) : '';
        json_error(503, 'FCM غير مضبوط على السيرفر.' . $hint . ' ارفع api/secrets/firebase-sa.json وحدّث config.php');
    }

    if (!vewo_device_tokens_ensure($pdo)) {
        json_error(500, 'جدول الأجهزة غير جاهز');
    }

    $in = [];
    try {
        $in = read_json_body();
    } catch (Throwable $e) {
        $in = [];
    }
    $delay = (int) ($in['delay_sec'] ?? 40);
    if ($delay < 0) {
        $delay = 0;
    }
    if ($delay > 45) {
        $delay = 45;
    }

    vewo_device_tokens_prune_user($pdo, $uid, 1);

    $tokenRows = [];
    try {
        $stmt = $pdo->prepare(
            'SELECT token, platform, last_seen_at FROM device_tokens
             WHERE user_id = :u AND is_admin_app = 1
               AND last_seen_at >= DATE_SUB(NOW(), INTERVAL 45 DAY)
             ORDER BY last_seen_at DESC LIMIT 12'
        );
        $stmt->execute([':u' => $uid]);
        $tokenRows = $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
    } catch (Throwable $e) {
        $tokenRows = [];
    }

    $latestByPlatform = ['android' => '', 'ios' => ''];
    $platforms = ['ios' => 0, 'android' => 0, 'other' => 0];
    foreach ($tokenRows as $row) {
        $t = trim((string) ($row['token'] ?? ''));
        if ($t === '') {
            continue;
        }
        $p = strtolower(trim((string) ($row['platform'] ?? 'other')));
        if ($p === 'ios') {
            $platforms['ios']++;
            if ($latestByPlatform['ios'] === '') {
                $latestByPlatform['ios'] = $t;
            }
        } elseif ($p === 'android') {
            $platforms['android']++;
            if ($latestByPlatform['android'] === '') {
                $latestByPlatform['android'] = $t;
            }
        } else {
            $platforms['other']++;
        }
    }
    $tokens = array_values(array_filter([
        $latestByPlatform['android'],
        $latestByPlatform['ios'],
    ]));
    if (empty($tokens)) {
        json_error(400, 'لا يوجد توكن جهاز مسجّل لهذا الحساب — افتح تطبيق الأدمن على جهاز حقيقي وهو متصل بالإنترنت');
    }

    $payloadTitle = 'اختبار FCM';
    $payloadBody = 'إذا وصلك هذا الإشعار والتطبيق مغلق فـ iOS/Android يعملان';
    $payloadData = ['type' => 'broadcast', 'kind' => 'fcm_test', 'section' => 'settings'];

    if ($delay > 0) {
        ignore_user_abort(true);
        @set_time_limit($delay + 30);
        echo json_encode([
            'ok' => true,
            'queued' => true,
            'mode' => $mode,
            'project_id' => $projectId,
            'tokens' => count($tokens),
            'platforms' => [
                'ios' => $latestByPlatform['ios'] !== '' ? 1 : 0,
                'android' => $latestByPlatform['android'] !== '' ? 1 : 0,
                'other' => 0,
            ],
            'sent' => 0,
            'failed' => 0,
            'errors' => [],
            'hint' => 'أغلق التطبيق من قائمة التطبيقات الآن وانتظر ' . $delay . ' ثانية دون فتحه. إغلاق خلال 8 ثوانٍ لا يكفي — أندرويد يقتل العملية بعد نحو 30 ثانية.',
            'delay_sec' => $delay,
            'sa_file_exists' => ($saPath !== '' && is_file($saPath)),
        ], JSON_UNESCAPED_UNICODE);
        if (function_exists('fastcgi_finish_request')) {
            @fastcgi_finish_request();
        } else {
            if (ob_get_level() > 0) {
                @ob_end_flush();
            }
            @flush();
        }
        sleep($delay);
        if ($mode === 'http_v1') {
            vewo_fcm_send_v1($tokens, $payloadTitle, $payloadBody, $payloadData);
        } else {
            vewo_fcm_send_legacy($tokens, $payloadTitle, $payloadBody, $payloadData);
        }
        return;
    }

    $report = ['sent' => 0, 'failed' => 0, 'errors' => []];
    if ($mode === 'http_v1') {
        $report = vewo_fcm_send_v1($tokens, $payloadTitle, $payloadBody, $payloadData);
    } else {
        vewo_fcm_send_legacy($tokens, $payloadTitle, $payloadBody, $payloadData);
        $report['sent'] = count($tokens);
    }

    $hint = null;
    foreach ($report['errors'] as $e) {
        $el = strtolower($e);
        if (str_contains($el, 'invalidapnscredential') || str_contains($el, 'apns')) {
            $hint = 'ارفع مفتاح APNs (.p8) في Firebase → Project settings → Cloud Messaging — بدون هذا الآيفون لن يستقبل إشعارات خارج التطبيق';
            break;
        }
        if (str_contains($el, 'unregistered') || str_contains($el, 'notfound')) {
            $hint = 'توكن قديم — أغلق التطبيق وافتحه من جديد لتسجيل توكن جديد';
        }
    }
    if ($hint === null && ($platforms['ios'] ?? 0) > 0 && ($report['failed'] ?? 0) > 0) {
        $hint = 'فشل إرسال لـ iOS غالباً بسبب APNs غير مربوط في Firebase';
    }

    $ok = ((int) ($report['sent'] ?? 0)) > 0;
    echo json_encode([
        'ok' => $ok,
        'mode' => $mode,
        'project_id' => $projectId,
        'tokens' => count($tokens),
        'platforms' => [
            'ios' => $latestByPlatform['ios'] !== '' ? 1 : 0,
            'android' => $latestByPlatform['android'] !== '' ? 1 : 0,
            'other' => 0,
        ],
        'sent' => (int) ($report['sent'] ?? 0),
        'failed' => (int) ($report['failed'] ?? 0),
        'errors' => array_values(array_unique($report['errors'] ?? [])),
        'hint' => $hint,
        'delay_sec' => $delay,
        'sa_file_exists' => ($saPath !== '' && is_file($saPath)),
    ], JSON_UNESCAPED_UNICODE);
}

function admin_properties_route(PDO $pdo): void
{
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'GET') {
        require_admin_from_bearer($pdo);
        if (function_exists('vewo_engagement_process_due_rules')) {
            vewo_engagement_process_due_rules($pdo);
        }
        $st = trim((string) ($_GET['status'] ?? 'pending'));
        $qRaw = trim((string) ($_GET['q'] ?? ''));
        $qRaw = ltrim($qRaw, '#');
        $filterPub = ($qRaw !== '' && ctype_digit($qRaw)) ? (int) $qRaw : null;
        $hasPropPub = vewo_properties_has_public_no_column($pdo);
        $pubExpr = $hasPropPub ? 'p.property_public_no' : 'NULL AS property_public_no';

        $ownerAvatarSql = (function_exists('vewo_users_has_profile_photo_column') && vewo_users_has_profile_photo_column($pdo))
            ? ', COALESCE(NULLIF(TRIM(u.profile_photo_url), \'\'), \'\') AS owner_avatar_url'
            : ', \'\' AS owner_avatar_url';
        $reviewSql = (function_exists('vewo_properties_has_review_meta_columns') && vewo_properties_has_review_meta_columns($pdo))
            ? ', p.reject_note, p.resubmission_allowed'
            : ', NULL AS reject_note, 0 AS resubmission_allowed';

        $sql = 'SELECT p.id, ' . $pubExpr . ', p.title, p.governorate, p.address_line, p.category, p.segment, p.purpose,
                p.price_iqd, p.area_sqm, p.description, p.details_json, p.approval_status, p.is_sold, p.sold_at,
                p.created_at, p.owner_user_id, p.views,
                COALESCE(u.phone, \'\') AS owner_phone, COALESCE(u.full_name, \'\') AS owner_name,
                NULLIF(TRIM(u.office_name), \'\') AS office_name'
                . $ownerAvatarSql . $reviewSql . ',
                (SELECT m.public_url FROM property_media m WHERE m.property_id = p.id AND m.media_type = \'image\'
                 ORDER BY m.created_at ASC LIMIT 1) AS thumb_url,
                (SELECT GROUP_CONCAT(m2.public_url ORDER BY m2.created_at ASC SEPARATOR \'|||\')
                 FROM property_media m2
                 WHERE m2.property_id = p.id AND m2.media_type = \'image\') AS image_urls_raw,
                (SELECT GROUP_CONCAT(mv.public_url ORDER BY mv.created_at ASC SEPARATOR \'|||\')
                 FROM property_media mv
                 WHERE mv.property_id = p.id AND mv.media_type = \'video\') AS video_urls_raw
                FROM properties p
                LEFT JOIN users u ON u.id = p.owner_user_id
                WHERE 1=1';
        if ($st === 'pending') {
            $sql .= " AND p.approval_status = 'pending'";
        } elseif ($st === 'approved') {
            $sql .= " AND p.approval_status = 'approved'";
        } elseif ($st === 'urgent') {
            $sql .= " AND p.approval_status = 'approved' AND p.details_json LIKE '%urgent_sale%'";
        } elseif ($st === 'unsold') {
            $sql .= " AND p.approval_status = 'approved' AND COALESCE(p.is_sold, 0) = 0";
        } elseif ($st === 'sold') {
            $sql .= " AND p.approval_status = 'approved' AND p.is_sold = 1";
        }
        if ($filterPub !== null && $hasPropPub) {
            $sql .= ' AND p.property_public_no = :pubq';
        }
        $sql .= ' ORDER BY p.created_at DESC LIMIT 200';
        $stmt = $pdo->prepare($sql);
        if ($filterPub !== null && $hasPropPub) {
            $stmt->bindValue(':pubq', $filterPub, PDO::PARAM_INT);
        }
        try {
            $stmt->execute();
            $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
        } catch (Throwable $e) {
            json_error(500, 'استعلام المنشورات فشل — تحقق من تحديث قاعدة البيانات والجداول.');
        }
        if (is_array($rows) && function_exists('vewo_moderation_attach')) {
            vewo_moderation_attach($pdo, $rows, 'property');
        }

        echo json_encode(['ok' => true, 'items' => $rows], JSON_UNESCAPED_UNICODE);

        return;
    }
    if ($method === 'DELETE') {
        require_admin_from_bearer($pdo);
        $id = trim((string) ($_GET['id'] ?? ''));
        if ($id === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $id)) {
            json_error(400, 'معرّف العقار غير صالح');
        }
        try {
            $pdo->beginTransaction();
            // Best-effort cleanup of related rows.
            try {
                $pdo->prepare('DELETE FROM property_media WHERE property_id = :id')->execute([':id' => $id]);
            } catch (Throwable $e) {
            }
            try {
                $pdo->prepare('DELETE FROM favorites WHERE property_id = :id')->execute([':id' => $id]);
            } catch (Throwable $e) {
            }
            try {
                // If reels reference this property, detach them.
                $pdo->prepare('UPDATE reels SET property_id = NULL WHERE property_id = :id')->execute([':id' => $id]);
            } catch (Throwable $e) {
            }
            $stmt = $pdo->prepare('DELETE FROM properties WHERE id = :id LIMIT 1');
            $stmt->execute([':id' => $id]);
            $pdo->commit();
            echo json_encode(['ok' => true, 'deleted' => $stmt->rowCount()], JSON_UNESCAPED_UNICODE);
        } catch (Throwable $e) {
            if ($pdo->inTransaction()) $pdo->rollBack();
            json_error(500, 'تعذر حذف المنشور');
        }
        return;
    }
    if ($method === 'POST') {
        require_admin_from_bearer($pdo);
        $in = read_json_body();
        $id = trim((string) ($in['id'] ?? ''));
        $action = trim((string) ($in['action'] ?? 'approve'));
        if ($id === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $id)) {
            json_error(400, 'معرّف العقار غير صالح');
        }
        if ($action === 'approve') {
            $pubSelect = vewo_properties_has_public_no_column($pdo)
                ? 'property_public_no'
                : 'NULL AS property_public_no';
            $infoStmt = $pdo->prepare(
                'SELECT owner_user_id, ' . $pubSelect . ' FROM properties WHERE id = :id LIMIT 1'
            );
            $infoStmt->execute([':id' => $id]);
            $info = $infoStmt->fetch(PDO::FETCH_ASSOC);
            $ownerId = is_array($info) ? (string) ($info['owner_user_id'] ?? '') : '';
            $publicNo = is_array($info) ? trim((string) ($info['property_public_no'] ?? '')) : '';
            $stmt = $pdo->prepare(
                "UPDATE properties SET approval_status = 'approved' WHERE id = :id LIMIT 1"
            );
            $stmt->execute([':id' => $id]);
            if ($ownerId !== '') {
                $tokens = vewo_device_tokens_for_user($pdo, $ownerId, false);
                $noLabel = $publicNo !== '' ? $publicNo : $id;
                vewo_fcm_send(
                    $tokens,
                    'تم نشر منشورك',
                    'تم نشر المنشور رقم ' . $noLabel . ' ويمكنك فتحه الآن.',
                    [
                        'type' => 'property_approved',
                        'property_id' => $id,
                        'property_public_no' => $publicNo,
                    ]
                );
                vewo_app_notification_add(
                    $pdo,
                    $ownerId,
                    'property_approved',
                    'تمت الموافقة على العقار',
                    'تم نشر المنشور رقم ' . $noLabel . ' ويمكنك فتحه الآن.',
                    ['type' => 'property_approved', 'property_id' => $id, 'property_public_no' => $publicNo]
                );
            }
            if (function_exists('vewo_moderation_log_current')) {
                $pubInt = $publicNo !== '' && ctype_digit($publicNo) ? (int) $publicNo : null;
                vewo_moderation_log_current($pdo, 'property', $id, 'approve', $pubInt);
            }
            echo json_encode(['ok' => true, 'updated' => $stmt->rowCount()], JSON_UNESCAPED_UNICODE);

            return;
        }
        if ($action === 'update') {
            $title = trim((string) ($in['title'] ?? ''));
            $gov = trim((string) ($in['governorate'] ?? ''));
            $address = trim((string) ($in['address_line'] ?? ''));
            $purpose = trim((string) ($in['purpose'] ?? 'sale'));
            $price = (int) ($in['price_iqd'] ?? 0);
            $area = (int) ($in['area_sqm'] ?? 0);
            $desc = trim((string) ($in['description'] ?? ''));
            $requiresReview = (int) ($in['requires_review'] ?? 0) === 1;
            if ($title === '' || mb_strlen($title) < 2) {
                json_error(400, 'عنوان المنشور مطلوب');
            }
            if ($gov === '' || mb_strlen($gov) < 2) {
                json_error(400, 'المحافظة مطلوبة');
            }
            if (!in_array($purpose, ['sale', 'rent'], true)) {
                $purpose = 'sale';
            }
            if ($price < 0 || $area < 0) {
                json_error(400, 'السعر أو المساحة غير صالح');
            }
            if ($desc === '' || mb_strlen($desc) < 5) {
                json_error(400, 'الوصف مطلوب');
            }
            $stmt = $pdo->prepare(
                'UPDATE properties
                 SET title = :t, governorate = :g, address_line = :a, purpose = :pu,
                     price_iqd = :pr, area_sqm = :ar, description = :d,
                     approval_status = CASE WHEN :rv = 1 THEN \'pending\' ELSE approval_status END
                 WHERE id = :id LIMIT 1'
            );
            $stmt->execute([
                ':t' => $title,
                ':g' => $gov,
                ':a' => $address,
                ':pu' => $purpose,
                ':pr' => $price,
                ':ar' => $area,
                ':d' => $desc,
                ':rv' => $requiresReview ? 1 : 0,
                ':id' => $id,
            ]);
            $ownStmt = $pdo->prepare('SELECT owner_user_id FROM properties WHERE id = :id LIMIT 1');
            $ownStmt->execute([':id' => $id]);
            $ownerId = (string) ($ownStmt->fetchColumn() ?: '');
            if ($ownerId !== '') {
                $tokens = vewo_device_tokens_for_user($pdo, $ownerId, false);
                vewo_fcm_send(
                    $tokens,
                    'تم تعديل المنشور',
                    'تم تعديل بيانات منشورك من قبل الإدارة.',
                    ['type' => 'property_updated', 'property_id' => $id]
                );
                vewo_app_notification_add(
                    $pdo,
                    $ownerId,
                    'property_updated',
                    'تم تعديل المنشور',
                    'تم تعديل بيانات منشورك من قبل الإدارة.',
                    ['type' => 'property_updated', 'property_id' => $id]
                );
            }
            if (function_exists('vewo_moderation_log_current')) {
                vewo_moderation_log_current($pdo, 'property', $id, 'update', vewo_property_public_no_of($pdo, $id));
            }
            echo json_encode(['ok' => true, 'updated' => $stmt->rowCount()], JSON_UNESCAPED_UNICODE);

            return;
        }
        if ($action === 'reject') {
            $note = trim((string) ($in['reject_note'] ?? ''));
            $allowResubmit = (int) ($in['resubmission_allowed'] ?? 0) === 1 ? 1 : 0;
            if (function_exists('vewo_properties_has_review_meta_columns') && vewo_properties_has_review_meta_columns($pdo)) {
                $stmt = $pdo->prepare(
                    'UPDATE properties SET approval_status = \'rejected\', reject_note = :n, resubmission_allowed = :a WHERE id = :id LIMIT 1'
                );
                $stmt->execute([
                    ':n' => $note !== '' ? $note : null,
                    ':a' => $allowResubmit,
                    ':id' => $id,
                ]);
            } else {
                $stmt = $pdo->prepare(
                    "UPDATE properties SET approval_status = 'rejected' WHERE id = :id LIMIT 1"
                );
                $stmt->execute([':id' => $id]);
            }
            $ownStmt = $pdo->prepare('SELECT owner_user_id FROM properties WHERE id = :id LIMIT 1');
            $ownStmt->execute([':id' => $id]);
            $ownerId = (string) ($ownStmt->fetchColumn() ?: '');
            if ($ownerId !== '') {
                $tokens = vewo_device_tokens_for_user($pdo, $ownerId, false);
                $pushTitle = 'تم رفض المنشور';
                $pushBody = $note !== '' ? $note : 'يمكنك المراجعة وإعادة الإرسال من التطبيق إن وُجدت صلاحية.';
                vewo_fcm_send($tokens, $pushTitle, $pushBody, [
                    'type' => 'property_rejected',
                    'property_id' => $id,
                ]);
                vewo_app_notification_add(
                    $pdo,
                    $ownerId,
                    'property_rejected',
                    $pushTitle,
                    $pushBody,
                    ['type' => 'property_rejected', 'property_id' => $id]
                );
            }
            if (function_exists('vewo_moderation_log_current')) {
                vewo_moderation_log_current($pdo, 'property', $id, 'reject', vewo_property_public_no_of($pdo, $id), $note);
            }
            echo json_encode(['ok' => true, 'updated' => $stmt->rowCount()], JSON_UNESCAPED_UNICODE);

            return;
        }
        if ($action === 'mark_sold') {
            $stmt = $pdo->prepare(
                'UPDATE properties SET is_sold = 1, sold_at = NOW(3) WHERE id = :id LIMIT 1'
            );
            $stmt->execute([':id' => $id]);
            $ownStmt = $pdo->prepare('SELECT owner_user_id FROM properties WHERE id = :id LIMIT 1');
            $ownStmt->execute([':id' => $id]);
            $ownerId = (string) ($ownStmt->fetchColumn() ?: '');
            if ($ownerId !== '') {
                $tokens = vewo_device_tokens_for_user($pdo, $ownerId, false);
                vewo_fcm_send(
                    $tokens,
                    'تم بيع العقار',
                    'تم تعليم منشورك كمباع.',
                    ['type' => 'property_sold', 'property_id' => $id]
                );
                vewo_app_notification_add(
                    $pdo,
                    $ownerId,
                    'property_sold',
                    'تم بيع العقار',
                    'تم تعليم منشورك كمباع.',
                    ['type' => 'property_sold', 'property_id' => $id]
                );
            }
            if (function_exists('vewo_moderation_log_current')) {
                vewo_moderation_log_current($pdo, 'property', $id, 'mark_sold', vewo_property_public_no_of($pdo, $id));
            }
            echo json_encode(['ok' => true, 'updated' => $stmt->rowCount()], JSON_UNESCAPED_UNICODE);

            return;
        }
        if ($action === 'unmark_sold') {
            $admin = require_admin_from_bearer($pdo);
            if (($admin['role'] ?? '') !== 'admin' && !vewo_admin_has_permission($admin, 'unsold')) {
                json_error(403, 'لا تملك صلاحية إلغاء تم البيع');
            }
            $stmt = $pdo->prepare(
                'UPDATE properties SET is_sold = 0, sold_at = NULL WHERE id = :id LIMIT 1'
            );
            $stmt->execute([':id' => $id]);
            if (function_exists('vewo_moderation_log_current')) {
                vewo_moderation_log_current($pdo, 'property', $id, 'unmark_sold', vewo_property_public_no_of($pdo, $id));
            }
            echo json_encode(['ok' => true, 'updated' => $stmt->rowCount(), 'is_sold' => 0], JSON_UNESCAPED_UNICODE);

            return;
        }
        if ($action === 'urgent_sale') {
            $infoStmt = $pdo->prepare(
                'SELECT owner_user_id, details_json, title, governorate, address_line, price_iqd, area_sqm
                 FROM properties WHERE id = :id LIMIT 1'
            );
            $infoStmt->execute([':id' => $id]);
            $info = $infoStmt->fetch(PDO::FETCH_ASSOC);
            if (!is_array($info)) {
                json_error(404, 'المنشور غير موجود');
            }
            $days = (int) ($in['urgent_sale_days'] ?? $in['days'] ?? 1);
            if ($days < 1 || $days > 365) {
                json_error(400, 'مدة البيع العاجل يجب أن تكون بين 1 و 365 يوم');
            }
            // إشعار المستخدمين اختياري — التفعيل وحده لا يرسل إشعاراً جماعياً.
            $notifyAll = array_key_exists('notify_all', $in)
                && vewo_truthy_flag($in['notify_all']);
            $ownerId = (string) ($info['owner_user_id'] ?? '');
            $details = [];
            $rawDetails = (string) ($info['details_json'] ?? '');
            if ($rawDetails !== '') {
                $decoded = json_decode($rawDetails, true);
                if (is_array($decoded)) {
                    $details = $decoded;
                }
            }
            $details['urgent_sale'] = true;
            $details['urgent_sale_enabled_at'] = date('c');
            $details['urgent_sale_days'] = $days;
            $details['urgent_sale_expires_at'] = (new DateTimeImmutable('now'))
                ->modify('+' . $days . ' days')
                ->format(DateTimeInterface::ATOM);
            $stmt = $pdo->prepare(
                'UPDATE properties SET details_json = :dj WHERE id = :id LIMIT 1'
            );
            $stmt->execute([
                ':dj' => json_encode($details, JSON_UNESCAPED_UNICODE),
                ':id' => $id,
            ]);
            if ($ownerId !== '') {
                $tokens = vewo_device_tokens_for_user($pdo, $ownerId, false);
                vewo_fcm_send(
                    $tokens,
                    'تم تفعيل البيع العاجل',
                    'تم إظهار منشورك ضمن قسم البيع العاجل.',
                    ['type' => 'property_urgent_sale', 'property_id' => $id]
                );
                vewo_app_notification_add(
                    $pdo,
                    $ownerId,
                    'property_urgent_sale',
                    'تم تفعيل البيع العاجل',
                    'تم إظهار منشورك ضمن قسم البيع العاجل.',
                    ['type' => 'property_urgent_sale', 'property_id' => $id]
                );
            }
            $pushCount = 0;
            if ($notifyAll) {
                $publicBody = vewo_urgent_sale_public_body($info);
                $pushCount = vewo_fcm_notify_all_users(
                    $pdo,
                    'بيع عاجل',
                    $publicBody,
                    [
                        'type' => 'urgent_sale_public',
                        'property_id' => $id,
                        'title' => 'بيع عاجل',
                        'body' => $publicBody,
                    ]
                );
            }
            if (function_exists('vewo_moderation_log_current')) {
                vewo_moderation_log_current($pdo, 'property', $id, 'urgent_sale', vewo_property_public_no_of($pdo, $id));
            }
            echo json_encode([
                'ok' => true,
                'updated' => $stmt->rowCount(),
                'notify_all' => $notifyAll,
                'push_tokens' => $pushCount,
            ], JSON_UNESCAPED_UNICODE);

            return;
        }
        if ($action === 'cancel_urgent_sale') {
            $infoStmt = $pdo->prepare('SELECT details_json FROM properties WHERE id = :id LIMIT 1');
            $infoStmt->execute([':id' => $id]);
            $info = $infoStmt->fetch(PDO::FETCH_ASSOC);
            if (!is_array($info)) {
                json_error(404, 'المنشور غير موجود');
            }
            $details = [];
            $rawDetails = (string) ($info['details_json'] ?? '');
            if ($rawDetails !== '') {
                $decoded = json_decode($rawDetails, true);
                if (is_array($decoded)) {
                    $details = $decoded;
                }
            }
            $details['urgent_sale'] = false;
            unset(
                $details['urgent_sale_enabled_at'],
                $details['urgent_sale_days'],
                $details['urgent_sale_expires_at']
            );
            $stmt = $pdo->prepare(
                'UPDATE properties SET details_json = :dj WHERE id = :id LIMIT 1'
            );
            $stmt->execute([
                ':dj' => json_encode($details, JSON_UNESCAPED_UNICODE),
                ':id' => $id,
            ]);
            if (function_exists('vewo_moderation_log_current')) {
                vewo_moderation_log_current($pdo, 'property', $id, 'cancel_urgent_sale', vewo_property_public_no_of($pdo, $id));
            }
            echo json_encode(['ok' => true, 'updated' => $stmt->rowCount()], JSON_UNESCAPED_UNICODE);

            return;
        }
        json_error(400, 'إجراء غير معروف');
    }
    json_error(405, 'Method not allowed');
}

/**
 * @param array<string,mixed> $data
 */
function json_error(int $code, string $message, array $data = []): void
{
    while (ob_get_level() > 0) {
        @ob_end_clean();
    }
    http_response_code($code);
    if (!headers_sent()) {
        header('Content-Type: application/json; charset=utf-8');
    }
    echo json_encode(array_merge(['ok' => false, 'error' => $message], $data), JSON_UNESCAPED_UNICODE);
    exit;
}

/** @param array<string,mixed> $f */
function vewo_require_uploaded_file(array $f): string
{
    $err = (int) ($f['error'] ?? UPLOAD_ERR_NO_FILE);
    if ($err !== UPLOAD_ERR_OK) {
        $msg = match ($err) {
            UPLOAD_ERR_INI_SIZE, UPLOAD_ERR_FORM_SIZE => 'لم يكتمل رفع الملف على السيرفر، أعد المحاولة',
            UPLOAD_ERR_PARTIAL => 'لم يكتمل رفع الملف، أعد المحاولة',
            UPLOAD_ERR_NO_FILE => 'لم يُرفع ملف',
            UPLOAD_ERR_NO_TMP_DIR => 'مجلد الرفع المؤقت غير موجود',
            UPLOAD_ERR_CANT_WRITE => 'تعذر حفظ الملف على السيرفر',
            UPLOAD_ERR_EXTENSION => 'تم منع الرفع من السيرفر',
            default => 'فشل الرفع',
        };
        json_error(400, $msg);
    }
    $tmp = (string) ($f['tmp_name'] ?? '');
    if ($tmp === '' || !is_uploaded_file($tmp)) {
        json_error(400, 'ملف غير صالح');
    }
    return $tmp;
}
