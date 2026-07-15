<?php

/** @var array<string,mixed> $stats */

/** @var array<string,mixed>|null $operationResult */

/** @var array<string,mixed> $data */

/** @var array<string,mixed> $section */

$visibleSections = admin_visible_sections();

require __DIR__ . '/../partials/section-alerts.php';

?>

<div class="row g-3 mb-4">

    <?php

    $cards = [

        ['منشورات معلقة', admin_stat_value($stats, ['pending_properties']), 'fa-house-circle-check', '/admin/properties', ['status' => 'pending']],

        ['مكاتب معلقة', admin_stat_value($stats, ['pending_offices']), 'fa-store', '/admin/offices', ['scope' => 'pending']],

        ['مستخدمون نشطون', admin_stat_value($stats, ['active_users']), 'fa-users', '/admin/users', []],

        ['محادثات غير مقروءة', admin_stat_value($stats, ['chat_unread_threads', 'chat_unread']), 'fa-comments', '/admin/chats', []],

        ['ريلز معلقة', admin_stat_value($stats, ['pending_reels']), 'fa-clapperboard', '/admin/reels', ['status' => 'pending']],

        ['مشاهدات العقارات', admin_stat_value($stats, ['total_property_views']), 'fa-eye', '/admin/reports', []],

        ['منشورات معتمدة', admin_stat_value($stats, ['approved_properties']), 'fa-circle-check', '/admin/properties', ['status' => 'unsold']],

        ['بيع عاجل', admin_stat_value($stats, ['urgent_sale_count']), 'fa-bolt', '/admin/properties', ['status' => 'unsold']],
        ['زبائن', admin_stat_value($stats, ['customers', 'customer_count']), 'fa-user', '/admin/users', ['role' => 'customer']],
        ['مكاتب', admin_stat_value($stats, ['offices', 'office_count']), 'fa-building', '/admin/users', ['role' => 'office']],
        ['ريلز منشورة', admin_stat_value($stats, ['approved_reels']), 'fa-video', '/admin/reels', ['status' => 'approved']],

    ];

    foreach ($cards as [$label, $value, $icon, $href, $query]): ?>

        <div class="col-md-6 col-xl-3">

            <a href="<?= e(url($href, $query)) ?>" class="stat-card">

                <div class="stat-icon"><i class="fa-solid <?= e($icon) ?>"></i></div>

                <div><strong><?= e(compact_number($value)) ?></strong><span><?= e($label) ?></span></div>

            </a>

        </div>

    <?php endforeach; ?>

</div>



<div class="row g-4 mb-4">

    <div class="col-xl-8">

        <div class="panel-card">

            <div class="panel-head"><h2>نظرة تحليلية</h2></div>

            <div id="overviewChart" style="min-height:320px"></div>

        </div>

    </div>

    <div class="col-xl-4">

        <div class="panel-card h-100">

            <div class="panel-head"><h2>آخر الأنشطة</h2></div>

            <div class="activity-stack">

                <a href="<?= e(url('/admin/properties', ['status' => 'pending'])) ?>">منشورات بانتظار المراجعة</a>

                <a href="<?= e(url('/admin/offices', ['scope' => 'pending'])) ?>">مكاتب بانتظار الموافقة</a>

                <a href="<?= e(url('/admin/chats')) ?>">محادثات غير مقروءة</a>

                <a href="<?= e(url('/admin/reels', ['status' => 'pending'])) ?>">ريلز بانتظار المراجعة</a>

            </div>

        </div>

    </div>

</div>



<?php

$topProperty = is_array($stats['top_property'] ?? null) ? $stats['top_property'] : null;

$topReel = is_array($stats['top_reel'] ?? null) ? $stats['top_reel'] : null;

$urgentItems = is_array($stats['urgent_sale_items'] ?? null) ? $stats['urgent_sale_items'] : [];

?>

<?php if ($urgentItems !== []): ?>
    <div class="panel-card mb-4">
        <div class="panel-head d-flex justify-content-between align-items-center flex-wrap gap-2">
            <h2 class="mb-0"><i class="fa-solid fa-bolt text-warning ms-1"></i> بيع عاجل نشط</h2>
            <span class="badge rounded-pill text-bg-warning"><?= e(count($urgentItems)) ?> منشور</span>
        </div>
        <div class="admin-list-panel">
            <div class="table-responsive">
                <table class="table admin-data-table align-middle mb-0">
                    <thead>
                        <tr>
                            <th>المنشور</th>
                            <th>ينتهي</th>
                            <th class="text-end">إجراء</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($urgentItems as $urgent): ?>
                            <?php if (!is_array($urgent)) continue; ?>
                            <tr>
                                <td>
                                    <strong><?= e((string) ($urgent['title'] ?? 'منشور')) ?></strong>
                                    <div class="small text-secondary">#<?= e((string) ($urgent['property_public_no'] ?? '')) ?></div>
                                </td>
                                <td class="small text-secondary"><?= e((string) ($urgent['urgent_sale_until'] ?? $urgent['expires_at'] ?? '—')) ?></td>
                                <td class="text-end">
                                    <form method="post" action="<?= e(url('/admin/overview')) ?>" class="d-inline">
                                        <?= csrf_field() ?>
                                        <input type="hidden" name="_operation" value="cancel_urgent_sale">
                                        <input type="hidden" name="property_id" value="<?= e((string) ($urgent['id'] ?? '')) ?>">
                                        <button type="submit" class="btn btn-outline-danger btn-sm rounded-pill">إلغاء العاجل</button>
                                    </form>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
<?php endif; ?>

<?php if ($topProperty !== null || $topReel !== null): ?>

    <div class="row g-4 mb-4">

        <?php if ($topProperty !== null): ?>

            <div class="col-lg-6">

                <div class="panel-card admin-highlight-card h-100">

                    <div class="panel-head"><h2>أكثر عقار مشاهدة</h2></div>

                    <div class="d-flex gap-3 align-items-center">

                        <img src="<?= e((string) ($topProperty['thumb_url'] ?? asset_url('images/placeholder-property.svg'))) ?>" alt="" class="admin-thumb-lg">

                        <div>

                            <strong><?= e((string) ($topProperty['title'] ?? '')) ?></strong>

                            <div class="text-secondary small">#<?= e((string) ($topProperty['property_public_no'] ?? '')) ?></div>

                            <div class="badge text-bg-light border mt-2"><?= e(compact_number($topProperty['views'] ?? 0)) ?> مشاهدة</div>

                        </div>

                    </div>

                </div>

            </div>

        <?php endif; ?>

        <?php if ($topReel !== null): ?>

            <div class="col-lg-6">

                <div class="panel-card admin-highlight-card h-100">

                    <div class="panel-head"><h2>أكثر ريل تفاعلاً</h2></div>

                    <div>

                        <strong><?= e((string) ($topReel['caption'] ?? 'ريل')) ?></strong>

                        <div class="text-secondary small">#<?= e((string) ($topReel['reel_public_no'] ?? '')) ?></div>

                        <div class="badge text-bg-light border mt-2"><?= e(compact_number($topReel['view_count'] ?? 0)) ?> مشاهدة</div>

                    </div>

                </div>

            </div>

        <?php endif; ?>

    </div>

<?php endif; ?>



<div class="panel-card">

    <div class="panel-head"><h2>اختصارات الأقسام</h2></div>

    <div class="row g-3">

        <?php foreach ($visibleSections as $key => $item): ?>

            <?php if ($key === 'overview') continue; ?>

            <div class="col-md-6 col-xl-4">

                <a class="shortcut-card" href="<?= e(url('/admin/' . $key)) ?>">

                    <strong><?= e((string) $item['label']) ?></strong>

                    <span><?= e((string) $item['description']) ?></span>

                </a>

            </div>

        <?php endforeach; ?>

    </div>

</div>



