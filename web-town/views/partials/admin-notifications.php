<?php

$stats = $stats ?? api_client()->get('admin/stats', [], auth_token());

$pendingProps = (int) admin_stat_value($stats, ['pending_properties']);

$pendingOffices = (int) admin_stat_value($stats, ['pending_offices']);

$pendingReels = (int) admin_stat_value($stats, ['pending_reels']);

$chatUnread = (int) admin_stat_value($stats, ['chat_unread_threads', 'chat_unread']);

?>

<aside class="admin-notifications" id="adminNotifications">

    <div class="notifications-head">

        <h2>الإشعارات</h2>

        <button type="button" class="btn btn-sm btn-light" id="notificationsClose"><i class="fa-solid fa-xmark"></i></button>

    </div>

    <div class="notifications-list">

        <a class="notification-item urgent" href="<?= e(url('/admin/properties', ['status' => 'pending'])) ?>">

            <i class="fa-solid fa-house-circle-check"></i>

            <div><strong>منشورات معلقة</strong><span><?= e($pendingProps) ?> بانتظار المراجعة</span></div>

            <?php if ($pendingProps > 0): ?><span class="notif-count-badge ms-auto"><?= e($pendingProps > 99 ? '99+' : (string) $pendingProps) ?></span><?php endif; ?>

        </a>

        <a class="notification-item" href="<?= e(url('/admin/offices', ['scope' => 'pending'])) ?>">

            <i class="fa-solid fa-store"></i>

            <div><strong>مكاتب معلقة</strong><span><?= e($pendingOffices) ?> طلب موافقة</span></div>

            <?php if ($pendingOffices > 0): ?><span class="notif-count-badge ms-auto"><?= e($pendingOffices > 99 ? '99+' : (string) $pendingOffices) ?></span><?php endif; ?>

        </a>

        <a class="notification-item" href="<?= e(url('/admin/reels', ['status' => 'pending'])) ?>">

            <i class="fa-solid fa-clapperboard"></i>

            <div><strong>ريلز معلقة</strong><span><?= e($pendingReels) ?> بانتظار الموافقة</span></div>

            <?php if ($pendingReels > 0): ?><span class="notif-count-badge ms-auto"><?= e($pendingReels > 99 ? '99+' : (string) $pendingReels) ?></span><?php endif; ?>

        </a>

        <a class="notification-item" href="<?= e(url('/admin/chats')) ?>">

            <i class="fa-solid fa-comments"></i>

            <div><strong>محادثات</strong><span><?= e($chatUnread) ?> غير مقروءة</span></div>

            <?php if ($chatUnread > 0): ?><span class="notif-count-badge ms-auto"><?= e($chatUnread > 99 ? '99+' : (string) $chatUnread) ?></span><?php endif; ?>

        </a>

    </div>

</aside>

<div class="admin-backdrop" id="adminBackdrop"></div>


