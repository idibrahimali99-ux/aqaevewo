<?php
/** @var string $sectionKey */
/** @var array<string,mixed> $section */
/** @var array<string,mixed> $data */
/** @var array<string,mixed>|null $operationResult */
/** @var array<string,mixed> $stats */
$items = admin_items_from_response($data);
$tabs = is_array($section['tabs'] ?? null) ? $section['tabs'] : [];
$operations = is_array($section['operations'] ?? null) ? $section['operations'] : [];
$visibleSections = admin_visible_sections();
?>

<?php if ($operationResult !== null): ?>
    <div class="alert alert-<?= !empty($operationResult['ok']) ? 'success' : 'danger' ?> rounded-4 border-0 shadow-sm">
        <?= !empty($operationResult['ok']) ? 'تم تنفيذ العملية بنجاح.' : e((string) ($operationResult['error'] ?? 'تعذر تنفيذ العملية')) ?>
    </div>
<?php endif; ?>

<?php if (empty($data['ok']) && !empty($data['error'])): ?>
    <div class="alert alert-danger rounded-4 border-0"><?= e((string) $data['error']) ?> — endpoint: <code><?= e((string) ($section['endpoint'] ?? '')) ?></code></div>
<?php endif; ?>

<div class="d-flex flex-wrap gap-2 mb-4">
    <?php foreach ($tabs as $tab): ?>
        <span class="badge rounded-pill text-bg-light border px-3 py-2"><?= e((string) $tab) ?></span>
    <?php endforeach; ?>
</div>

<?php if ($sectionKey === 'overview' || $sectionKey === 'notifications'): ?>
    <div class="row g-3 mb-4">
        <?php
        $cards = [
            ['منشورات معلقة', admin_stat_value($stats, ['pending_properties']), 'fa-house-circle-check', '/admin/properties?status=pending'],
            ['مكاتب معلقة', admin_stat_value($stats, ['pending_offices']), 'fa-store', '/admin/offices?scope=pending'],
            ['مستخدمون نشطون', admin_stat_value($stats, ['active_users']), 'fa-users', '/admin/users'],
            ['محادثات غير مقروءة', admin_stat_value($stats, ['chat_unread_threads', 'chat_unread']), 'fa-comments', '/admin/chats'],
            ['ريلز معلقة', admin_stat_value($stats, ['pending_reels']), 'fa-clapperboard', '/admin/reels?status=pending'],
            ['مشاهدات العقارات', admin_stat_value($stats, ['total_property_views']), 'fa-eye', '/admin/reports'],
        ];
        foreach ($cards as [$label, $value, $icon, $href]): ?>
            <div class="col-md-6 col-xl-4">
                <a href="<?= e(url($href)) ?>" class="stat-card">
                    <div class="stat-icon"><i class="fa-solid <?= e($icon) ?>"></i></div>
                    <div><strong><?= e(compact_number($value)) ?></strong><span><?= e($label) ?></span></div>
                </a>
            </div>
        <?php endforeach; ?>
    </div>
    <div class="row g-4 mb-4">
        <div class="col-xl-8">
            <div class="panel-card">
                <div class="panel-head"><h2>Analytics</h2></div>
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
                </div>
            </div>
        </div>
    </div>
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
<?php else: ?>
    <form class="panel-card mb-4" method="get" action="<?= e(url('/admin/' . $sectionKey)) ?>">
        <div class="row g-3 align-items-end">
            <div class="col-md-4"><label class="form-label">بحث</label><input class="form-control" name="q" value="<?= e($_GET['q'] ?? '') ?>"></div>
            <div class="col-md-2"><label class="form-label">status</label><input class="form-control" name="status" value="<?= e($_GET['status'] ?? '') ?>"></div>
            <div class="col-md-2"><label class="form-label">scope</label><input class="form-control" name="scope" value="<?= e($_GET['scope'] ?? '') ?>"></div>
            <div class="col-md-2"><label class="form-label">from</label><input class="form-control" name="from" value="<?= e($_GET['from'] ?? '') ?>"></div>
            <div class="col-md-2"><button class="btn btn-primary w-100 rounded-pill" type="submit">تطبيق</button></div>
        </div>
    </form>
    <div class="panel-card">
        <div class="panel-head d-flex justify-content-between align-items-center">
            <div><h2 class="mb-1">بيانات القسم</h2><p class="text-secondary mb-0"><?= e((string) ($section['endpoint'] ?? '')) ?></p></div>
        </div>
        <div class="table-responsive">
            <table class="table table-hover align-middle datatable">
                <thead>
                <tr>
                    <?php
                    $first = is_array($items[0] ?? null) ? $items[0] : [];
                    $headers = array_slice(array_keys($first), 0, 8);
                    if ($headers === []) { $headers = ['message']; }
                    foreach ($headers as $header): ?>
                        <th><?= e((string) $header) ?></th>
                    <?php endforeach; ?>
                </tr>
                </thead>
                <tbody>
                <?php if ($items !== []): ?>
                    <?php foreach ($items as $row): ?>
                        <tr>
                            <?php foreach ($headers as $header): ?>
                                <td><?= e(is_scalar($row[$header] ?? '') ? (string) ($row[$header] ?? '') : json_encode($row[$header] ?? '', JSON_UNESCAPED_UNICODE)) ?></td>
                            <?php endforeach; ?>
                        </tr>
                    <?php endforeach; ?>
                <?php else: ?>
                    <tr><td colspan="<?= count($headers) ?>">لا توجد بيانات للعرض.</td></tr>
                <?php endif; ?>
                </tbody>
            </table>
        </div>
    </div>
<?php endif; ?>

<?php if ($operations !== []): ?>
    <div class="panel-card mt-4">
        <div class="panel-head"><h2>العمليات</h2><p class="text-secondary mb-0">نفس endpoints تطبيق Admin — بدون تغيير منطق.</p></div>
        <div class="accordion accordion-flush" id="opsAccordion">
            <?php $i = 0; foreach ($operations as $operationKey => $operation): ?>
                <?php if (admin_operation($sectionKey, (string) $operationKey) === null) continue; $i++; ?>
                <div class="accordion-item border-0 bg-transparent">
                    <h2 class="accordion-header">
                        <button class="accordion-button collapsed rounded-4 mb-2 shadow-sm" type="button" data-bs-toggle="collapse" data-bs-target="#op<?= $i ?>">
                            <?= e((string) $operation['label']) ?>
                        </button>
                    </h2>
                    <div id="op<?= $i ?>" class="accordion-collapse collapse" data-bs-parent="#opsAccordion">
                        <div class="accordion-body pt-0">
                            <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="row g-3" <?= strtoupper((string) ($operation['method'] ?? 'POST')) === 'UPLOAD' ? 'enctype="multipart/form-data"' : '' ?>>
                                <?= csrf_field() ?>
                                <input type="hidden" name="_operation" value="<?= e((string) $operationKey) ?>">
                                <?php if (strtoupper((string) ($operation['method'] ?? 'POST')) === 'UPLOAD'): ?>
                                    <div class="col-12"><input class="form-control" type="file" name="file" required></div>
                                <?php endif; ?>
                                <?php foreach (($operation['fields'] ?? []) as $name => $placeholder): ?>
                                    <div class="col-md-6"><input class="form-control" name="<?= e((string) $name) ?>" placeholder="<?= e((string) $placeholder) ?>"></div>
                                <?php endforeach; ?>
                                <div class="col-12"><button class="btn btn-primary rounded-pill px-4" type="submit">تنفيذ</button></div>
                            </form>
                        </div>
                    </div>
                </div>
            <?php endforeach; ?>
        </div>
    </div>
<?php endif; ?>
