<?php

/** @var array<string,mixed> $data */
/** @var array<string,mixed> $section */
/** @var string $sectionKey */

$from = trim((string) ($_GET['from'] ?? date('Y-m-01')));
$to = trim((string) ($_GET['to'] ?? date('Y-m-d')));

require __DIR__ . '/../partials/section-alerts.php';

$summary = is_array($data) ? $data : [];

?>

<div class="admin-section-head">
    <form class="admin-inline-search" method="get" action="<?= e(url('/admin/' . $sectionKey)) ?>">
        <label class="small text-secondary mb-0">من</label>
        <input type="date" name="from" value="<?= e($from) ?>" class="form-control form-control-sm" style="width:auto;border-radius:999px">
        <label class="small text-secondary mb-0">إلى</label>
        <input type="date" name="to" value="<?= e($to) ?>" class="form-control form-control-sm" style="width:auto;border-radius:999px">
        <button type="submit" class="btn btn-primary btn-sm rounded-pill">عرض التقرير</button>
    </form>
</div>

<div class="row g-3 mb-4">
    <?php
    $cards = [
        ['منشورات جديدة', admin_stat_value($summary, ['new_properties', 'properties_created']), 'fa-house'],
        ['مستخدمون جدد', admin_stat_value($summary, ['new_users', 'users_created']), 'fa-users'],
        ['محادثات', admin_stat_value($summary, ['new_chats', 'chat_threads']), 'fa-comments'],
        ['ريلز', admin_stat_value($summary, ['new_reels', 'reels_created']), 'fa-clapperboard'],
    ];
    foreach ($cards as [$label, $value, $icon]): ?>
        <div class="col-md-6 col-xl-3">
            <div class="stat-card" style="cursor:default">
                <div class="stat-icon"><i class="fa-solid <?= e($icon) ?>"></i></div>
                <div><strong><?= e(compact_number($value)) ?></strong><span><?= e($label) ?></span></div>
            </div>
        </div>
    <?php endforeach; ?>
</div>

<?php if (!empty($summary['roles']) && is_array($summary['roles'])): ?>
    <div class="panel-card admin-list-panel mb-4">
        <div class="panel-head"><h2>توزيع الأدوار</h2></div>
        <div class="table-responsive">
            <table class="table admin-data-table mb-0">
                <thead><tr><th>الدور</th><th>العدد</th></tr></thead>
                <tbody>
                    <?php foreach ($summary['roles'] as $role => $count): ?>
                        <tr><td><?= e((string) $role) ?></td><td><?= e(compact_number($count)) ?></td></tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </div>
<?php endif; ?>

<div class="panel-card admin-form-card">
    <p class="text-secondary mb-0">لتصدير CSV استخدم تطبيق Admin أو endpoint <code>admin/reports</code> مع نفس فترة التاريخ.</p>
</div>
