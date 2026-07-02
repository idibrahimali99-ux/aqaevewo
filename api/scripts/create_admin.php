<?php
/**
 * إنشاء أو تحديث حساب المسؤول الرئيسي (role = admin) في قاعدة vewo.
 *
 * شغّل الأمر من مجلد **api** (حيث يوجد config.php):
 *   cd api
 *   php scripts/create_admin.php 07871234567 "MySecurePass123" "مسؤول النظام"
 *
 * على **Windows + XAMPP** إذا ظهر «php is not recognized» استخدم المسار الكامل:
 *   C:\xampp\php\php.exe scripts\create_admin.php 07871234567 "MySecurePass123" "مسؤول النظام"
 *
 * في **PowerShell** إذا كانت كلمة المرور فيها ! استخدم مفردات:
 *   php scripts/create_admin.php 07871234567 'ChangeMe!123' "مسؤول"
 *
 * متطلبات: ملف config.php بجانب index.php واتصال MySQL يعمل.
 *
 * من المتصفح (localhost فقط)، مثال:
 *   http://localhost/api/scripts/create_admin.php?phone=07871456361&password=07871456361
 * بدون باراميترات على localhost يُنشئ: 07871456361 / نفس الرقم ككلمة مرور.
 *
 * الحساب الافتراضي بعد init.mysql.sql قد يختلف — راجع التوثيق في backend/db.
 */
declare(strict_types=1);

/** مخرجات الأخطاء: STDERR غير معرّف في بعض أوضاع Apache/CGI على Windows. */
function create_admin_err(string $msg): void
{
    if (\defined('STDERR')) {
        @fwrite(\STDERR, $msg);

        return;
    }
    $fp = @fopen('php://stderr', 'wb');
    if (\is_resource($fp)) {
        fwrite($fp, $msg);
        fclose($fp);

        return;
    }
    echo $msg;
    error_log(rtrim($msg));
}

function create_admin_is_localhost_request(): bool
{
    $h = strtolower((string) ($_SERVER['HTTP_HOST'] ?? ''));
    $h = preg_replace('/:\d+$/', '', $h) ?? '';

    return $h === 'localhost' || $h === '127.0.0.1' || $h === '::1';
}

if (\PHP_SAPI !== 'cli' && \PHP_SAPI !== 'phpdbg') {
    header('Content-Type: text/plain; charset=utf-8');
}

/**
 * تحويل أرقام عربية/فارسية إلى لاتينية وإزالة المسافات والشرطات.
 */
function normalize_cli_phone(string $raw): string
{
    $s = trim($raw);
    $map = [
        '٠' => '0', '١' => '1', '٢' => '2', '٣' => '3', '٤' => '4',
        '٥' => '5', '٦' => '6', '٧' => '7', '٨' => '8', '٩' => '9',
        '۰' => '0', '۱' => '1', '۲' => '2', '۳' => '3', '۴' => '4',
        '۵' => '5', '۶' => '6', '۷' => '7', '۸' => '8', '۹' => '9',
    ];
    $s = strtr($s, $map);
    $digits = preg_replace('/\D+/', '', $s) ?? '';
    if (strlen($digits) === 13 && str_starts_with($digits, '964')) {
        $digits = '0' . substr($digits, 3);
    }
    if (strlen($digits) === 10 && str_starts_with($digits, '7')) {
        $digits = '0' . $digits;
    }

    return $digits;
}

$configPath = dirname(__DIR__) . '/config.php';
if (!is_file($configPath)) {
    create_admin_err("خطأ: لم يُعثر على config.php — انسخ config.example.php إلى config.php بجانب index.php\n");
    create_admin_err('المسار المتوقع: ' . $configPath . "\n");
    exit(1);
}

/** @var array $config */
$config = require $configPath;
$db = $config['db'];

$isCli = \PHP_SAPI === 'cli' || \PHP_SAPI === 'phpdbg';

if ($isCli) {
    $phoneRaw = isset($argv[1]) ? (string) $argv[1] : '';
    $password = isset($argv[2]) ? (string) $argv[2] : '';
    $fullName = isset($argv[3]) ? trim((string) $argv[3]) : 'Admin Root';
} else {
    $phoneRaw = (string) ($_GET['phone'] ?? $_POST['phone'] ?? '');
    $password = (string) ($_GET['password'] ?? $_POST['password'] ?? '');
    $fullName = trim((string) ($_GET['name'] ?? $_POST['name'] ?? 'Admin Root'));
    if ($phoneRaw === '' && $password === '' && create_admin_is_localhost_request()) {
        $phoneRaw = '07871456361';
        $password = '07871456361';
        $fullName = $fullName !== '' ? $fullName : 'Admin Root';
    }
}

$phone = normalize_cli_phone($phoneRaw);

if ($phone === '' || $password === '') {
    create_admin_err("إنشاء/تحديث حساب admin في جدول users\n\n");
    create_admin_err("الاستخدام (من داخل مجلد api):\n");
    create_admin_err('  php scripts/' . basename(__FILE__) . " 07XXXXXXXXX \"كلمة_المرور\" \"الاسم الاختياري\"\n\n");
    create_admin_err("أو من المتصفح (localhost):\n");
    create_admin_err('  ' . basename(__FILE__) . "?phone=07871456361&password=07871456361&name=Admin\n\n");
    create_admin_err("مثال CLI:\n");
    create_admin_err('  php scripts/' . basename(__FILE__) . " 07871234567 \"MySecurePass123\" \"مسؤول النظام\"\n\n");
    create_admin_err("PowerShell مع ! في كلمة المرور استخدم مفردات: 'ChangeMe!123'\n");
    exit(1);
}

if (!preg_match('/^07[0-9]{9}$/', $phone)) {
    create_admin_err("خطأ: رقم الهاتف يجب أن يكون 11 رقماً يبدأ بـ 07 (بعد التطبيع).\n");
    create_admin_err('ما أدخلته (بعد التطبيع): [' . $phone . "] طول=" . strlen($phone) . "\n");
    exit(1);
}
if (strlen($password) < 4) {
    create_admin_err("خطأ: كلمة المرور قصيرة جداً (الحد الأدنى 4)\n");
    exit(1);
}
if (mb_strlen($fullName) < 2) {
    create_admin_err("خطأ: الاسم غير صالح\n");
    exit(1);
}

$dsn = sprintf(
    'mysql:host=%s;port=%d;dbname=%s;charset=%s',
    $db['host'],
    (int) $db['port'],
    $db['name'],
    $db['charset']
);

try {
    $pdo = new PDO($dsn, $db['user'], $db['pass'], [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
} catch (Throwable $e) {
    create_admin_err('فشل الاتصال بقاعدة البيانات: ' . $e->getMessage() . "\n");
    exit(1);
}

echo "— قاعدة البيانات: {$db['host']}:{$db['port']} / {$db['name']} —\n";
echo "— الرقم بعد التطبيع: {$phone} —\n\n";

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

function verify_plain_against_hash(string $plain, string $stored): bool
{
    if (str_starts_with($stored, 'PLAIN:')) {
        return hash_equals(substr($stored, 6), $plain);
    }

    return password_verify($plain, $stored);
}

$hash = password_hash($password, PASSWORD_DEFAULT);

$sel = $pdo->prepare('SELECT id FROM users WHERE phone = :ph LIMIT 1');
$sel->execute([':ph' => $phone]);
$existing = $sel->fetchColumn();

if ($existing) {
    $upd = $pdo->prepare(
        'UPDATE users SET full_name = :fn, office_name = \'\', office_address = \'\',
         office_license_no = \'\', office_photo_url = \'\', password_hash = :pw, role = \'admin\',
         office_approved = 1, is_active = 1 WHERE phone = :ph LIMIT 1'
    );
    $upd->execute([
        ':fn' => $fullName,
        ':pw' => $hash,
        ':ph' => $phone,
    ]);
    echo "تم تحديث المستخدم الموجود (نفس رقم الهاتف) إلى دور admin.\n";
    echo "المعرّف: {$existing}\n";
} else {
    $id = uuid_v4();
    $ins = $pdo->prepare(
        'INSERT INTO users (id, full_name, office_name, phone, office_address, office_license_no, office_photo_url, password_hash, role, office_approved, is_active, created_by, created_at)
         VALUES (:id, :fn, \'\', :ph, \'\', \'\', \'\', :pw, \'admin\', 1, 1, NULL, NOW(3))'
    );
    $ins->execute([
        ':id' => $id,
        ':fn' => $fullName,
        ':ph' => $phone,
        ':pw' => $hash,
    ]);
    echo "تم إنشاء حساب admin جديد.\n";
    echo "المعرّف: {$id}\n";
}

$check = $pdo->prepare(
    'SELECT id, phone, role, is_active, password_hash FROM users WHERE phone = :ph LIMIT 1'
);
$check->execute([':ph' => $phone]);
$row = $check->fetch(PDO::FETCH_ASSOC);
if (!is_array($row)) {
    create_admin_err("خطأ: لم يُعثر على السجل بعد الحفظ.\n");
    exit(1);
}

$okVerify = verify_plain_against_hash($password, (string) $row['password_hash']);
echo "\nالتحقق من كلمة المرور مباشرة على قاعدة البيانات: " . ($okVerify ? "ناجح ✓" : "فشل ✗") . "\n";
if (!$okVerify) {
    create_admin_err("تحذير: كلمة المرور لا تطابق الهاش المخزّن — راجع إصدار PHP أو امتداد password_hash.\n");
}

echo "\nالهاتف: {$phone}\n";
echo "الدور في الجدول: " . ($row['role'] ?? '') . " | is_active: " . ($row['is_active'] ?? '') . "\n";
echo "\nسجّل الدخول في vewo_admin بنفس الرقم وكلمة المرور التي أدخلتها للسكربت.\n";
echo "تأكد أن تطبيق vewo_admin يستخدم نفس الخادم (VEWO_API_BASE) الذي يشير إلى هذا الـAPI ونفس قاعدة البيانات.\n";
