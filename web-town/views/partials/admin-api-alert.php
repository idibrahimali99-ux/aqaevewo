<?php
/** @var array<string,mixed> $apiMeta */
/** @var array<string,mixed> $stats */
$apiMeta = is_array($apiMeta ?? null) ? $apiMeta : [];
$statsOk = !empty($apiMeta['stats_ok']) || !empty($stats['ok']);
$statsError = (string) ($apiMeta['stats_error'] ?? $stats['error'] ?? '');
?>
<?php if (!$statsOk && $statsError !== ''): ?>
    <div class="alert alert-danger rounded-4 border-0 shadow-sm mb-4">
        <strong>تعذر جلب بيانات لوحة التحكم</strong>
        <div class="small mt-2"><?= e($statsError) ?></div>
    </div>
<?php elseif (!$statsOk): ?>
    <div class="alert alert-warning rounded-4 border-0 shadow-sm mb-4">
        <strong>لا توجد بيانات حالياً</strong>
        <div class="small mt-2">أعد تسجيل الدخول أو تحقق من اتصال الخادم.</div>
    </div>
<?php endif; ?>
