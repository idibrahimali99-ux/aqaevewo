<div class="panel-card p-4">
    <h1 class="h4 mb-3">الإشعارات</h1>
    <?php if (!empty($error)): ?><div class="alert alert-danger"><?= e($error) ?></div><?php endif; ?>
    <?php
    $counts = is_array($counts ?? null) ? $counts : [];
    $chatUnread = (int) ($counts['chat_unread'] ?? 0);
    ?>
    <?php if ($chatUnread > 0): ?>
        <a class="notification-item-card mb-3 d-flex align-items-center gap-3 text-decoration-none" href="<?= e(url('/messages')) ?>">
            <span class="notification-item-icon"><i class="fa-solid fa-comments"></i></span>
            <div><strong>محادثات غير مقروءة</strong><div class="small text-secondary"><?= e($chatUnread) ?> رسالة</div></div>
            <span class="notif-count-badge ms-auto"><?= e($chatUnread > 99 ? '99+' : (string) $chatUnread) ?></span>
        </a>
    <?php endif; ?>
    <?php if ($items === []): ?>
        <p class="text-secondary mb-0">لا توجد إشعارات حالياً.</p>
    <?php else: ?>
        <div class="vstack gap-2">
            <?php foreach ($items as $item): ?>
                <?php if (!is_array($item)) continue; ?>
                <a class="notification-item-card d-flex gap-3 text-decoration-none<?= empty($item['read_at']) ? ' unread' : '' ?>" href="<?= e(notification_item_url($item)) ?>">
                    <?php if (!empty($item['property']['thumb_url'])): ?>
                        <img src="<?= e((string) $item['property']['thumb_url']) ?>" alt="" class="notification-item-thumb">
                    <?php else: ?>
                        <span class="notification-item-icon"><i class="fa-solid fa-bell"></i></span>
                    <?php endif; ?>
                    <div class="min-w-0">
                        <strong><?= e((string) ($item['title'] ?? 'إشعار')) ?></strong>
                        <p class="mb-0 text-secondary small"><?= e((string) ($item['body'] ?? '')) ?></p>
                        <?php if (!empty($item['property']['property_public_no'])): ?>
                            <span class="badge text-bg-light border mt-1">#<?= e((string) $item['property']['property_public_no']) ?></span>
                        <?php endif; ?>
                    </div>
                </a>
            <?php endforeach; ?>
        </div>
    <?php endif; ?>
</div>
