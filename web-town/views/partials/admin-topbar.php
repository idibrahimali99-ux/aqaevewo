<?php

$stats = $stats ?? api_client()->get('admin/stats', [], auth_token());

$adminNotifTotal = admin_notification_total(is_array($stats) ? $stats : []);

$pendingProps = (int) admin_stat_value($stats, ['pending_properties']);

$pendingOffices = (int) admin_stat_value($stats, ['pending_offices']);

$pendingReels = (int) admin_stat_value($stats, ['pending_reels']);

$chatUnread = (int) admin_stat_value($stats, ['chat_unread_threads', 'chat_unread']);

?>

<header class="admin-topbar">

    <div class="d-flex align-items-center gap-3">

        <button class="btn btn-light btn-icon d-lg-none" type="button" id="sidebarOpen"><i class="fa-solid fa-bars"></i></button>

        <div>

            <div class="topbar-kicker">لوحة التحكم</div>

            <h1 class="topbar-title mb-0"><?= e((string) ($title ?? 'Admin')) ?></h1>

        </div>

    </div>

    <div class="d-flex align-items-center gap-2">

        <button class="btn btn-light btn-icon" type="button" id="themeToggle" aria-label="تبديل الوضع"><i class="fa-solid fa-moon"></i></button>

        <button class="btn btn-light btn-icon position-relative" type="button" id="notificationsToggle" title="الإشعارات">

            <i class="fa-solid fa-bell"></i>

            <?php if ($adminNotifTotal > 0): ?>

                <span class="notif-count-badge notif-count-badge-sm"><?= e($adminNotifTotal > 99 ? '99+' : (string) $adminNotifTotal) ?></span>

            <?php endif; ?>

        </button>

        <a class="btn btn-primary rounded-pill px-4" href="<?= e(url('/admin/reports')) ?>"><i class="fa-solid fa-chart-line ms-1"></i> التقارير</a>

        <a class="btn btn-outline-danger rounded-pill px-3" href="<?= e(url('/logout')) ?>" title="تسجيل الخروج"><i class="fa-solid fa-right-from-bracket"></i></a>

    </div>

</header>


