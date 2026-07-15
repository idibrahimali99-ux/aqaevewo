<?php
/** @var array<string,mixed> $apiMeta */
/** @var array<string,mixed> $stats */
$apiMeta = is_array($apiMeta ?? null) ? $apiMeta : [];
$statsOk = !empty($apiMeta['stats_ok']) || !empty($stats['ok']);
$statsError = (string) ($apiMeta['stats_error'] ?? $stats['error'] ?? '');
?>
<?php if (!$statsOk && $statsError !== ''): ?>
    <div class="alert alert-danger rounded-4 border-0 shadow-sm mb-4">
        <strong>تعذر جلب بيانات الأدمن من API</strong>
        <div class="small mt-2"><?= e($statsError) ?></div>
        <hr>
        <div class="small text-secondary">
            <div>API: <code><?= e((string) ($apiMeta['entry'] ?? app_config('api_entry'))) ?></code></div>
            <div>نوع الرمز: <code><?= e((string) ($apiMeta['token_type'] ?? auth_token_type())) ?></code> — يجب أن يكون <strong>admin</strong> (من <code>auth/admin/login</code>)</div>
            <div class="mt-2">تطبيق vewo_admin يستخدم: <code>GET admin/stats</code> + Bearer من <code>auth/admin/login</code></div>
            <div class="mt-1">إذا كان التطبيق يعمل على سيرفر آخر، عيّن <code>WEB_TOWN_API_ENTRY</code> لنفس عنوان API (مثل <code>http://31.57.156.84/api/index.php</code>)</div>
        </div>
    </div>
<?php elseif (!$statsOk): ?>
    <div class="alert alert-warning rounded-4 border-0 shadow-sm mb-4">
        <strong>لا توجد بيانات من API</strong>
        <div class="small mt-2">تحقق من <code>api/config.php</code> واتصال MySQL، ثم أعد تسجيل الدخول كـ admin.</div>
    </div>
<?php endif; ?>
