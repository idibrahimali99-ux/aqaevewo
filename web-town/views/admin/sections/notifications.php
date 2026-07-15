<?php

/** @var array<string,mixed> $data */

/** @var array<string,mixed> $section */

/** @var array<string,mixed> $stats */

/** @var string $sectionKey */

require __DIR__ . '/../partials/section-alerts.php';

?>

<div class="row g-3 mb-4">

    <?php

    $cards = [

        ['محادثات غير مقروءة', admin_stat_value($stats, ['chat_unread_threads', 'chat_unread']), 'fa-comments', '/admin/chats'],

        ['منشورات معلقة', admin_stat_value($stats, ['pending_properties']), 'fa-house-circle-check', '/admin/properties', ['status' => 'pending']],

        ['مكاتب معلقة', admin_stat_value($stats, ['pending_offices']), 'fa-store', '/admin/offices', ['scope' => 'pending']],

        ['ريلز معلقة', admin_stat_value($stats, ['pending_reels']), 'fa-clapperboard', '/admin/reels', ['status' => 'pending']],

    ];

    foreach ($cards as $card): ?>

        <?php [$label, $value, $icon, $href] = $card; $query = $card[4] ?? []; ?>

        <div class="col-md-6 col-xl-3">

            <a href="<?= e(url($href, $query)) ?>" class="stat-card">

                <div class="stat-icon"><i class="fa-solid <?= e($icon) ?>"></i></div>

                <div><strong><?= e(compact_number($value)) ?></strong><span><?= e($label) ?></span></div>

            </a>

        </div>

    <?php endforeach; ?>

</div>

<div class="panel-card">

    <div class="panel-head"><h2>روابط سريعة</h2></div>

    <div class="activity-stack">

        <a href="<?= e(url('/admin/chats')) ?>">فتح مركز المحادثات</a>

        <a href="<?= e(url('/admin/properties', ['status' => 'pending'])) ?>">مراجعة المنشورات</a>

        <a href="<?= e(url('/admin/offices', ['scope' => 'pending'])) ?>">مراجعة المكاتب</a>

        <a href="<?= e(url('/admin/notifications')) ?>">تحديث العدادات</a>

    </div>

</div>

