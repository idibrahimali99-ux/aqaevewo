<?php

/** @var array<string,mixed> $data */
/** @var array<string,mixed> $section */
/** @var string $sectionKey */

$items = admin_items_from_response($data);
$tab = trim((string) ($_GET['tab'] ?? 'office'));
if (!in_array($tab, ['office', 'marketer', 'assign'], true)) {
    $tab = 'office';
}

$officePackages = array_values(array_filter($items, static fn (mixed $row): bool => is_array($row) && (string) ($row['applies_to'] ?? '') === 'office'));
$marketerPackages = array_values(array_filter($items, static fn (mixed $row): bool => is_array($row) && (string) ($row['applies_to'] ?? '') === 'marketer'));
$userOptions = admin_users_options($tab === 'marketer' ? 'marketer' : 'office');

require __DIR__ . '/../partials/section-alerts.php';

?>

<div class="admin-section-head">
    <div class="admin-tabs">
        <?= admin_section_tab($sectionKey, 'باقات المكاتب', ['tab' => 'office']) ?>
        <?= admin_section_tab($sectionKey, 'باقات المسوقين', ['tab' => 'marketer']) ?>
        <?= admin_section_tab($sectionKey, 'تعيين باقة', ['tab' => 'assign']) ?>
    </div>
</div>

<?php if ($tab === 'assign'): ?>
    <div class="panel-card admin-form-card mb-4">
        <h2 class="h5 mb-3">تعيين باقة لمستخدم</h2>
        <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="row g-3">
            <?= csrf_field() ?>
            <input type="hidden" name="_operation" value="assign">
            <div class="col-md-5">
                <label class="form-label">المستخدم</label>
                <?= admin_select_field('user_id', $userOptions, 'اختر المستخدم', null, true) ?>
            </div>
            <div class="col-md-4">
                <label class="form-label">الباقة</label>
                <select name="posting_package_id" class="form-select" required>
                    <option value="">— اختر الباقة —</option>
                    <?php foreach ($items as $pkg): ?>
                        <?php if (!is_array($pkg)) continue; ?>
                        <option value="<?= e((string) ($pkg['id'] ?? '')) ?>"><?= e((string) ($pkg['name'] ?? '')) ?> (<?= e((string) ($pkg['applies_to'] ?? '')) ?>)</option>
                    <?php endforeach; ?>
                </select>
            </div>
            <div class="col-md-2">
                <label class="form-label">الرصيد</label>
                <input type="number" name="posting_listings_remaining" class="form-control" min="0">
            </div>
            <div class="col-md-1 d-flex align-items-end">
                <button type="submit" class="btn btn-success rounded-pill w-100">تعيين</button>
            </div>
        </form>
    </div>
<?php else: ?>
    <?php $list = $tab === 'marketer' ? $marketerPackages : $officePackages; ?>
    <?php if ($list === []): ?>
        <div class="panel-card text-center py-5 text-secondary">لا توجد باقات في هذا القسم.</div>
    <?php else: ?>
        <div class="panel-card admin-list-panel mb-4">
            <div class="table-responsive">
                <table class="table admin-data-table align-middle mb-0">
                    <thead>
                        <tr>
                            <th>الباقة</th>
                            <th>الحد</th>
                            <th>الحالة</th>
                            <th class="text-end">إجراءات</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($list as $pkg): ?>
                            <?php $pid = (string) ($pkg['id'] ?? ''); ?>
                            <tr>
                                <td><strong><?= e((string) ($pkg['name'] ?? '')) ?></strong></td>
                                <td><?= !empty($pkg['is_unlimited']) ? 'غير محدود' : e(compact_number($pkg['listings_limit'] ?? 0)) ?></td>
                                <td><span class="badge rounded-pill <?= !empty($pkg['is_active']) ? 'text-bg-success' : 'text-bg-secondary' ?>"><?= !empty($pkg['is_active']) ? 'فعّالة' : 'موقوفة' ?></span></td>
                                <td class="text-end">
                                    <button type="button" class="btn btn-outline-primary btn-sm rounded-pill" data-bs-toggle="collapse" data-bs-target="#pkg-edit-<?= e($pid) ?>">تعديل</button>
                                    <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="d-inline" onsubmit="return confirm('حذف الباقة؟');">
                                        <?= csrf_field() ?>
                                        <input type="hidden" name="_operation" value="delete">
                                        <input type="hidden" name="id" value="<?= e($pid) ?>">
                                        <button type="submit" class="btn btn-outline-danger btn-sm rounded-pill">حذف</button>
                                    </form>
                                </td>
                            </tr>
                            <tr class="collapse" id="pkg-edit-<?= e($pid) ?>">
                                <td colspan="4">
                                    <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="admin-form-card row g-2">
                                        <?= csrf_field() ?>
                                        <input type="hidden" name="_operation" value="upsert">
                                        <input type="hidden" name="id" value="<?= e($pid) ?>">
                                        <div class="col-md-3"><input type="text" name="name" class="form-control form-control-sm" value="<?= e((string) ($pkg['name'] ?? '')) ?>" required></div>
                                        <div class="col-md-2"><input type="number" name="listings_limit" class="form-control form-control-sm" value="<?= e((string) ($pkg['listings_limit'] ?? '')) ?>"></div>
                                        <div class="col-md-2"><input type="number" name="is_unlimited" class="form-control form-control-sm" value="<?= !empty($pkg['is_unlimited']) ? '1' : '0' ?>"></div>
                                        <div class="col-md-2"><input type="text" name="applies_to" class="form-control form-control-sm" value="<?= e((string) ($pkg['applies_to'] ?? '')) ?>" readonly></div>
                                        <div class="col-md-2"><input type="number" name="is_active" class="form-control form-control-sm" value="<?= !empty($pkg['is_active']) ? '1' : '0' ?>"></div>
                                        <div class="col-md-1"><button type="submit" class="btn btn-success btn-sm rounded-pill w-100">حفظ</button></div>
                                    </form>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        </div>
    <?php endif; ?>
<?php endif; ?>

<div class="panel-card admin-form-card">
    <h2 class="h5 mb-3">إضافة باقة جديدة</h2>
    <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="row g-3">
        <?= csrf_field() ?>
        <input type="hidden" name="_operation" value="upsert">
        <div class="col-md-3"><input type="text" name="name" class="form-control" placeholder="اسم الباقة" required></div>
        <div class="col-md-2"><input type="number" name="listings_limit" class="form-control" placeholder="الحد"></div>
        <div class="col-md-2">
            <select name="applies_to" class="form-select">
                <option value="office">مكاتب</option>
                <option value="marketer">مسوقون</option>
            </select>
        </div>
        <div class="col-md-2">
            <select name="is_unlimited" class="form-select">
                <option value="0">محدود</option>
                <option value="1">غير محدود</option>
            </select>
        </div>
        <div class="col-md-2">
            <select name="is_active" class="form-select">
                <option value="1">فعّالة</option>
                <option value="0">موقوفة</option>
            </select>
        </div>
        <div class="col-md-1 d-flex align-items-end"><button type="submit" class="btn btn-primary rounded-pill w-100">إضافة</button></div>
    </form>
</div>
