<?php
$cards = [
    ['المستخدمون', $stats['users'] ?? $stats['total_users'] ?? 0, 'users'],
    ['العقارات', $stats['properties'] ?? $stats['total_properties'] ?? 0, 'properties'],
    ['بانتظار الموافقة', $stats['pending_properties'] ?? $stats['pending'] ?? 0, 'properties'],
    ['المكاتب', $stats['offices'] ?? $stats['total_offices'] ?? 0, 'offices'],
];
ob_start();
?>
<h1>لوحة الإدارة</h1>
<p class="muted">إدارة مركزية لويب تاون مرتبطة بنفس API وقاعدة البيانات. تظهر إمكانيات الموظف حسب صلاحياته.</p>
<?php if (empty($stats['ok']) && !empty($stats['error'])): ?>
    <div class="alert"><?= e($stats['error']) ?></div>
<?php endif; ?>
<div class="dashboard-grid">
    <?php foreach ($cards as [$label, $value, $permission]): ?>
        <?php if (can_staff($permission)): ?>
            <div class="stat"><strong><?= e(compact_number($value)) ?></strong><span><?= e($label) ?></span></div>
        <?php endif; ?>
    <?php endforeach; ?>
</div>
<div class="quick-grid">
    <?php if (can_staff('properties')): ?><div class="quick-card"><h3>مراجعة العقارات</h3><p class="muted">اعتماد، رفض، ومتابعة المنشورات.</p></div><?php endif; ?>
    <?php if (can_staff('reels')): ?><div class="quick-card"><h3>إدارة الريلز</h3><p class="muted">مراجعة فيديوهات العقارات والتفاعل.</p></div><?php endif; ?>
    <?php if (can_staff('promotions')): ?><div class="quick-card"><h3>الإعلانات</h3><p class="muted">تحكم بسلايدر وإعلانات الرئيسية.</p></div><?php endif; ?>
    <?php if (can_staff('users')): ?><div class="quick-card"><h3>المستخدمون</h3><p class="muted">إدارة الزبائن، المكاتب، والمسوقين.</p></div><?php endif; ?>
    <?php if (can_staff('settings')): ?><div class="quick-card"><h3>إعدادات النظام</h3><p class="muted">المحافظات، المناطق، الأقسام، والكتالوج.</p></div><?php endif; ?>
    <?php if (can_staff('chats')): ?><div class="quick-card"><h3>المحادثات</h3><p class="muted">متابعة الرسائل والوساطة.</p></div><?php endif; ?>
</div>
<?php
$slot = ob_get_clean();
require __DIR__ . '/../partials/dashboard-shell.php';
