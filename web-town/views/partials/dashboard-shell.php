<?php
/** @var array<string,mixed> $user */
/** @var string $slot */
$kind = account_kind($user);
$isAdminConsole = in_array($kind, ['admin', 'staff'], true);
$currentSection = (string) ($currentSection ?? 'overview');
if ($isAdminConsole) {
    $visibleSections = admin_visible_sections();
    $consoleStats = is_array($stats ?? null) ? $stats : [];
    $groups = [];
    foreach ($visibleSections as $key => $section) {
        $groups[(string) ($section['group'] ?? 'أخرى')][$key] = $section;
    }
} else {
    $groups = [];
}
$accountItems = [
    ['/dashboard/customer', 'لوحة الزبون', 'CU', $kind === 'customer'],
    ['/dashboard/office', 'لوحة المكتب', 'OF', $kind === 'office'],
    ['/dashboard/marketer', 'لوحة المسوق', 'MK', $kind === 'marketer'],
    ['/properties', 'العقارات العامة', 'PO', true],
    ['/offices', 'المكاتب والمسوقون', 'AG', true],
];
?>
<button class="drawer-toggle" type="button" data-dashboard-drawer>القائمة</button>
<section class="dashboard-layout <?= $isAdminConsole ? 'admin-console-layout' : '' ?>" data-dashboard-layout>
    <aside class="sidebar admin-sidebar" data-dashboard-sidebar>
        <div class="side-head">
            <a class="brand compact-brand" href="<?= e(url('/dashboard')) ?>">
                <span class="brand-mark">WT</span>
                <span class="side-title"><strong>Web Town</strong><small>Admin Console</small></span>
            </a>
            <button class="collapse-toggle" type="button" data-dashboard-collapse aria-label="طي القائمة">⇔</button>
        </div>
        <div class="side-user">
            <strong><?= e((string) ($user['full_name'] ?? 'مستخدم')) ?></strong>
            <p class="muted"><?= e(match ($kind) {
                'admin' => 'مدير النظام',
                'staff' => 'موظف لوحة التحكم',
                'office' => 'مكتب عقاري',
                'marketer' => 'مسوق عقاري',
                'customer' => 'زبون',
                default => 'حساب',
            }) ?></p>
        </div>
        <nav class="side-nav" aria-label="لوحة التحكم">
            <?php if ($isAdminConsole): ?>
                <?php foreach ($groups as $group => $sections): ?>
                    <div class="nav-group">
                        <span class="nav-group-title"><?= e($group) ?></span>
                        <?php foreach ($sections as $key => $section): ?>
                            <a class="<?= $currentSection === $key ? 'active' : '' ?>" href="<?= e(url('/dashboard/admin/' . $key)) ?>" title="<?= e((string) $section['label']) ?>">
                                <span class="nav-icon"><?= e((string) $section['icon']) ?></span>
                                <span class="nav-label"><?= e((string) $section['label']) ?></span>
                            </a>
                        <?php endforeach; ?>
                    </div>
                <?php endforeach; ?>
            <?php else: ?>
                <div class="nav-group">
                    <span class="nav-group-title">الحساب</span>
                    <?php foreach ($accountItems as [$href, $label, $icon, $show]): ?>
                        <?php if ($show): ?>
                            <a class="<?= is_active_path($href) ? 'active' : '' ?>" href="<?= e(url($href)) ?>">
                                <span class="nav-icon"><?= e($icon) ?></span>
                                <span class="nav-label"><?= e($label) ?></span>
                            </a>
                        <?php endif; ?>
                    <?php endforeach; ?>
                </div>
            <?php endif; ?>
            <div class="nav-group bottom-group">
                <a href="<?= e(url('/')) ?>"><span class="nav-icon">HM</span><span class="nav-label">الموقع</span></a>
                <a href="<?= e(url('/logout')) ?>"><span class="nav-icon">EX</span><span class="nav-label">تسجيل الخروج</span></a>
            </div>
        </nav>
    </aside>
    <div class="dashboard-main">
        <?= $slot ?>
    </div>
    <?php if ($isAdminConsole): ?>
        <aside class="admin-notifications-panel" aria-label="الإشعارات الجانبية">
            <div class="notice-head">
                <span class="eyebrow">إشعارات</span>
                <a href="<?= e(url('/dashboard/admin/notifications')) ?>">عرض الكل</a>
            </div>
            <div class="notice-list">
                <a class="notice-card urgent" href="<?= e(url('/dashboard/admin/properties', ['status' => 'pending'])) ?>">
                    <span>منشورات بانتظار المراجعة</span>
                    <strong><?= e(compact_number(admin_stat_value($consoleStats, ['pending_properties', 'properties_pending', 'pending']))) ?></strong>
                </a>
                <a class="notice-card" href="<?= e(url('/dashboard/admin/offices', ['scope' => 'pending'])) ?>">
                    <span>مكاتب بانتظار الموافقة</span>
                    <strong><?= e(compact_number(admin_stat_value($consoleStats, ['pending_offices', 'offices_pending']))) ?></strong>
                </a>
                <a class="notice-card" href="<?= e(url('/dashboard/admin/chats')) ?>">
                    <span>محادثات غير مقروءة</span>
                    <strong><?= e(compact_number(admin_stat_value($consoleStats, ['unread_chats', 'chat_unread', 'unread_threads']))) ?></strong>
                </a>
            </div>
            <div class="notice-actions">
                <a class="btn primary" href="<?= e(url('/dashboard/admin/reports')) ?>">التقارير</a>
                <a class="btn ghost" href="<?= e(url('/dashboard/admin/settings')) ?>">الإعدادات</a>
            </div>
        </aside>
    <?php endif; ?>
</section>
<div class="drawer-backdrop" data-dashboard-backdrop></div>
