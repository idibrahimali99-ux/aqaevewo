<?php
/** @var array<string,mixed> $user */
/** @var string $sectionKey */
/** @var array<string,mixed> $section */
/** @var array<string,mixed> $data */
/** @var array<string,mixed>|null $operationResult */
$items = admin_items_from_response($data);
$tabs = is_array($section['tabs'] ?? null) ? $section['tabs'] : [];
$operations = is_array($section['operations'] ?? null) ? $section['operations'] : [];
$visibleSections = admin_visible_sections();
$stats = $sectionKey === 'overview' || $sectionKey === 'notifications' ? $data : api_client()->get('admin/stats', [], auth_token());

ob_start();
?>
<div class="admin-page-head">
    <div>
        <div class="breadcrumbs"><span>لوحة التحكم</span><span>/</span><span><?= e((string) $section['label']) ?></span></div>
        <h1><?= e((string) $section['label']) ?></h1>
        <p class="muted"><?= e((string) ($section['description'] ?? '')) ?></p>
    </div>
    <div class="actions">
        <a class="btn ghost" href="<?= e(url('/dashboard/admin/notifications')) ?>">الإشعارات</a>
        <a class="btn dark" href="<?= e(url('/dashboard/admin/reports')) ?>">التقارير</a>
    </div>
</div>

<?php if ($operationResult !== null): ?>
    <div class="alert" style="<?= !empty($operationResult['ok']) ? 'border-color:#c7f0df;background:#f0fff8;color:#178f5f' : '' ?>">
        <?= !empty($operationResult['ok']) ? 'تم تنفيذ العملية بنجاح.' : e((string) ($operationResult['error'] ?? 'تعذر تنفيذ العملية')) ?>
    </div>
<?php endif; ?>

<?php if (empty($data['ok']) && !empty($data['error'])): ?>
    <div class="alert"><?= e((string) $data['error']) ?></div>
<?php endif; ?>

<div class="tab-strip">
    <?php foreach ($tabs as $tab): ?>
        <span class="tab-chip"><?= e((string) $tab) ?></span>
    <?php endforeach; ?>
</div>

<?php if ($sectionKey === 'overview' || $sectionKey === 'notifications'): ?>
    <div class="meta-grid">
        <div class="meta-card"><strong><?= e(compact_number(admin_stat_value($stats, ['pending_properties', 'properties_pending', 'pending']))) ?></strong><span>منشورات معلقة</span></div>
        <div class="meta-card"><strong><?= e(compact_number(admin_stat_value($stats, ['pending_offices', 'offices_pending']))) ?></strong><span>مكاتب معلقة</span></div>
        <div class="meta-card"><strong><?= e(compact_number(admin_stat_value($stats, ['active_users', 'users', 'total_users']))) ?></strong><span>مستخدمون نشطون</span></div>
        <div class="meta-card"><strong><?= e(compact_number(admin_stat_value($stats, ['unread_chats', 'chat_unread', 'unread_threads']))) ?></strong><span>محادثات غير مقروءة</span></div>
        <div class="meta-card"><strong><?= e(compact_number(admin_stat_value($stats, ['reels', 'total_reels']))) ?></strong><span>ريلز</span></div>
        <div class="meta-card"><strong><?= e(compact_number(admin_stat_value($stats, ['views', 'total_views']))) ?></strong><span>مشاهدات</span></div>
        <div class="meta-card"><strong><?= e(compact_number(admin_stat_value($stats, ['urgent_sale', 'urgent_properties']))) ?></strong><span>بيع عاجل</span></div>
        <div class="meta-card"><strong><?= e(count($visibleSections)) ?></strong><span>أقسام متاحة</span></div>
    </div>

    <section class="section">
        <div class="section-head"><div><h2>اختصارات الأقسام</h2><p>نفس أقسام تطبيق Admin مرتبة في Console واحدة.</p></div></div>
        <div class="admin-section-cards">
            <?php foreach ($visibleSections as $key => $item): ?>
                <?php if ($key === 'overview') { continue; } ?>
                <a class="quick-card" href="<?= e(url('/dashboard/admin/' . $key)) ?>">
                    <span class="pill"><?= e((string) $item['icon']) ?></span>
                    <h3><?= e((string) $item['label']) ?></h3>
                    <p class="muted"><?= e((string) $item['description']) ?></p>
                </a>
            <?php endforeach; ?>
        </div>
    </section>

    <section class="section">
        <div class="section-head"><div><h2>آخر الأنشطة</h2><p>ملخص عملي من عدادات النظام والروابط السريعة.</p></div></div>
        <div class="activity-list">
            <a class="activity-item" href="<?= e(url('/dashboard/admin/properties', ['status' => 'pending'])) ?>"><span>منشورات بانتظار المراجعة</span><strong><?= e(compact_number(admin_stat_value($stats, ['pending_properties', 'properties_pending', 'pending']))) ?></strong></a>
            <a class="activity-item" href="<?= e(url('/dashboard/admin/offices', ['scope' => 'pending'])) ?>"><span>مكاتب بانتظار الموافقة</span><strong><?= e(compact_number(admin_stat_value($stats, ['pending_offices', 'offices_pending']))) ?></strong></a>
            <a class="activity-item" href="<?= e(url('/dashboard/admin/chats')) ?>"><span>محادثات غير مقروءة</span><strong><?= e(compact_number(admin_stat_value($stats, ['unread_chats', 'chat_unread', 'unread_threads']))) ?></strong></a>
        </div>
    </section>
<?php else: ?>
    <form class="admin-toolbar" method="get" action="<?= e(url('/dashboard/admin/' . $sectionKey)) ?>">
        <input class="input" name="q" value="<?= e($_GET['q'] ?? '') ?>" placeholder="بحث / رقم / اسم">
        <input class="input" name="status" value="<?= e($_GET['status'] ?? '') ?>" placeholder="status">
        <input class="input" name="scope" value="<?= e($_GET['scope'] ?? '') ?>" placeholder="scope">
        <input class="input" name="from" value="<?= e($_GET['from'] ?? '') ?>" placeholder="from YYYY-MM-DD">
        <input class="input" name="to" value="<?= e($_GET['to'] ?? '') ?>" placeholder="to YYYY-MM-DD">
        <button class="btn primary" type="submit">تطبيق</button>
    </form>

    <section class="admin-content-card">
    <div class="content-card-head">
        <div>
            <h2>بيانات القسم</h2>
            <p class="muted">عرض مرتب من نفس endpoint الموجود في تطبيق Admin.</p>
        </div>
        <span class="pill"><?= e((string) ($section['endpoint'] ?? '')) ?></span>
    </div>
    <div class="admin-table-wrap">
        <table class="admin-table">
            <thead>
            <tr>
                <?php
                $first = is_array($items[0] ?? null) ? $items[0] : [];
                $headers = array_slice(array_keys($first), 0, 8);
                if ($headers === []) { $headers = ['الحالة', 'المسار', 'الملاحظة']; }
                foreach ($headers as $header): ?>
                    <th><?= e((string) $header) ?></th>
                <?php endforeach; ?>
            </tr>
            </thead>
            <tbody>
            <?php if ($items !== []): ?>
                <?php foreach (array_slice($items, 0, 30) as $row): ?>
                    <tr>
                        <?php foreach ($headers as $header): ?>
                            <td><?= e(is_scalar($row[$header] ?? '') ? (string) ($row[$header] ?? '') : json_encode($row[$header] ?? '', JSON_UNESCAPED_UNICODE)) ?></td>
                        <?php endforeach; ?>
                    </tr>
                <?php endforeach; ?>
            <?php else: ?>
                <tr>
                    <td colspan="<?= e((string) count($headers)) ?>">لا توجد بيانات للعرض حاليا، أو أن endpoint يحتاج فلاتر إضافية.</td>
                </tr>
            <?php endif; ?>
            </tbody>
        </table>
    </div>
    </section>
<?php endif; ?>

<?php if ($operations !== []): ?>
    <section class="section">
        <div class="section-head"><div><h2>العمليات الموجودة</h2><p>هذه العمليات مأخوذة من تطبيق Admin الحالي فقط وتنفذ نفس endpoints.</p></div></div>
        <div class="operation-grid">
            <?php foreach ($operations as $operationKey => $operation): ?>
                <?php if (admin_operation($sectionKey, (string) $operationKey) === null) { continue; } ?>
                <details class="operation-card">
                    <summary>
                        <span><?= e((string) $operation['label']) ?></span>
                        <small><?= e((string) $operation['method']) ?> · <?= e((string) $operation['endpoint']) ?></small>
                    </summary>
                    <form class="operation-form" method="post" action="<?= e(url('/dashboard/admin/' . $sectionKey)) ?>" <?= strtoupper((string) ($operation['method'] ?? 'POST')) === 'UPLOAD' ? 'enctype="multipart/form-data"' : '' ?>>
                        <?= csrf_field() ?>
                        <input type="hidden" name="_operation" value="<?= e((string) $operationKey) ?>">
                        <?php if (strtoupper((string) ($operation['method'] ?? 'POST')) === 'UPLOAD'): ?>
                            <input class="input" type="file" name="file" required>
                        <?php endif; ?>
                        <?php foreach (($operation['fields'] ?? []) as $name => $placeholder): ?>
                            <input class="input" name="<?= e((string) $name) ?>" placeholder="<?= e((string) $placeholder) ?>">
                        <?php endforeach; ?>
                        <button class="btn primary" type="submit">تنفيذ</button>
                    </form>
                </details>
            <?php endforeach; ?>
        </div>
    </section>
<?php endif; ?>
<?php
$slot = ob_get_clean();
require __DIR__ . '/../partials/dashboard-shell.php';
