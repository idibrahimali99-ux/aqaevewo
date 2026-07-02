<?php
/** @var array<string,mixed> $user */
/** @var string $slot */
$kind = account_kind($user);
$items = [
    ['/dashboard/admin', 'لوحة الإدارة', in_array($kind, ['admin', 'staff'], true)],
    ['/dashboard/customer', 'لوحة الزبون', $kind === 'customer'],
    ['/dashboard/office', 'لوحة المكتب', $kind === 'office'],
    ['/dashboard/marketer', 'لوحة المسوق', $kind === 'marketer'],
    ['/properties', 'العقارات العامة', true],
    ['/offices', 'المكاتب والمسوقون', true],
];
?>
<section class="dashboard-layout">
    <aside class="sidebar">
        <div class="side-user">
            <strong><?= e((string) ($user['full_name'] ?? 'مستخدم')) ?></strong>
            <p class="muted"><?= e(match ($kind) {
                'admin' => 'مدير النظام',
                'staff' => 'موظف',
                'office' => 'مكتب عقاري',
                'marketer' => 'مسوق عقاري',
                'customer' => 'زبون',
                default => 'حساب',
            }) ?></p>
        </div>
        <nav class="side-nav">
            <?php foreach ($items as [$href, $label, $show]): ?>
                <?php if ($show): ?>
                    <a class="<?= is_active_path($href) ? 'active' : '' ?>" href="<?= e(url($href)) ?>"><?= e($label) ?></a>
                <?php endif; ?>
            <?php endforeach; ?>
            <a href="<?= e(url('/logout')) ?>">تسجيل الخروج</a>
        </nav>
    </aside>
    <div class="dashboard-main">
        <?= $slot ?>
    </div>
</section>
