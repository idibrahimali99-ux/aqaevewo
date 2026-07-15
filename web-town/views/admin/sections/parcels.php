<?php

/** @var array<string,mixed> $data */
/** @var array<string,mixed> $section */
/** @var string $sectionKey */

$items = admin_items_from_response($data);
$sort = trim((string) ($_GET['sort'] ?? 'sort_order'));
if (!in_array($sort, ['sort_order', 'name_asc', 'created_desc'], true)) {
    $sort = 'sort_order';
}
$items = admin_sort_rows($items, $sort, static fn (array $row): string => parcel_display_name($row));
$govOptions = admin_governorate_options();
$districtOptions = admin_district_options();

require __DIR__ . '/../partials/section-alerts.php';

?>

<div class="admin-section-head">
    <form class="admin-inline-search" method="get" action="<?= e(url('/admin/' . $sectionKey)) ?>">
        <input type="search" name="q" value="<?= e($_GET['q'] ?? '') ?>" placeholder="بحث بالاسم أو رقم المقاطعة">
        <button type="submit" class="btn btn-primary btn-sm rounded-pill">بحث</button>
    </form>
    <form method="get" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="admin-sort-form">
        <?= admin_sort_select($sectionKey, $sort, ['sort_order' => 'الترتيب', 'name_asc' => 'الاسم أ-ي', 'created_desc' => 'الأحدث']) ?>
    </form>
</div>

<?php if ($items === []): ?>
    <div class="panel-card text-center py-5 text-secondary">لا توجد مقاطعات.</div>
<?php else: ?>
    <div class="panel-card admin-list-panel mb-4">
        <div class="table-responsive">
            <table class="table admin-data-table align-middle mb-0">
                <thead>
                    <tr>
                        <th>المقاطعة</th>
                        <th>المحافظة / القضاء</th>
                        <th>الرقم</th>
                        <th>الترتيب</th>
                        <th>الحالة</th>
                        <th class="text-end">إجراءات</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($items as $row): ?>
                        <?php if (!is_array($row)) continue; ?>
                        <?php $rid = (string) ($row['id'] ?? ''); ?>
                        <tr>
                            <td><strong><?= e(parcel_display_name($row)) ?></strong></td>
                            <td class="small"><?= e((string) ($row['governorate_name'] ?? '')) ?> · <?= e((string) ($row['district_name'] ?? '')) ?></td>
                            <td><?= e((string) ($row['parcel_no'] ?? '')) ?></td>
                            <td><?= e((string) ($row['sort_order'] ?? '0')) ?></td>
                            <td><span class="badge rounded-pill <?= !empty($row['is_active']) ? 'text-bg-success' : 'text-bg-secondary' ?>"><?= !empty($row['is_active']) ? 'فعّال' : 'موقوف' ?></span></td>
                            <td class="text-end">
                                <button type="button" class="btn btn-outline-primary btn-sm rounded-pill" data-bs-toggle="collapse" data-bs-target="#parcel-<?= e($rid) ?>">تعديل</button>
                                <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="d-inline" onsubmit="return confirm('حذف المقاطعة؟');">
                                    <?= csrf_field() ?>
                                    <input type="hidden" name="_operation" value="delete">
                                    <input type="hidden" name="id" value="<?= e($rid) ?>">
                                    <button type="submit" class="btn btn-outline-danger btn-sm rounded-pill">حذف</button>
                                </form>
                            </td>
                        </tr>
                        <tr class="collapse" id="parcel-<?= e($rid) ?>">
                            <td colspan="6">
                                <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="admin-form-card row g-2">
                                    <?= csrf_field() ?>
                                    <input type="hidden" name="_operation" value="upsert">
                                    <input type="hidden" name="id" value="<?= e($rid) ?>">
                                    <div class="col-md-3"><?= admin_select_field('governorate_id', $govOptions, 'المحافظة', (string) ($row['governorate_id'] ?? ''), true) ?></div>
                                    <div class="col-md-3"><?= admin_select_field('district_id', $districtOptions, 'القضاء', (string) ($row['district_id'] ?? '')) ?></div>
                                    <div class="col-md-2"><input type="text" name="name" class="form-control form-control-sm" value="<?= e((string) ($row['parcel_name'] ?? $row['name'] ?? '')) ?>" required></div>
                                    <div class="col-md-2"><input type="text" name="parcel_no" class="form-control form-control-sm" value="<?= e((string) ($row['parcel_no'] ?? '')) ?>"></div>
                                    <div class="col-md-1"><input type="number" name="sort_order" class="form-control form-control-sm" value="<?= e((string) ($row['sort_order'] ?? '0')) ?>"></div>
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

<div class="panel-card admin-form-card">
    <h2 class="h5 mb-3">إضافة مقاطعة جديدة</h2>
    <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="row g-2">
        <?= csrf_field() ?>
        <input type="hidden" name="_operation" value="upsert">
        <div class="col-md-3">
            <label class="form-label small">المحافظة</label>
            <?= admin_select_field('governorate_id', $govOptions, 'اختر المحافظة', null, true) ?>
        </div>
        <div class="col-md-3">
            <label class="form-label small">القضاء</label>
            <?= admin_select_field('district_id', $districtOptions, 'اختر القضاء') ?>
        </div>
        <div class="col-md-2">
            <label class="form-label small">الاسم</label>
            <input type="text" name="name" class="form-control form-control-sm" required>
        </div>
        <div class="col-md-2">
            <label class="form-label small">رقم المقاطعة</label>
            <input type="text" name="parcel_no" class="form-control form-control-sm">
        </div>
        <div class="col-md-1">
            <label class="form-label small">ترتيب</label>
            <input type="number" name="sort_order" class="form-control form-control-sm" value="0">
        </div>
        <div class="col-md-1 d-flex align-items-end">
            <button type="submit" class="btn btn-primary btn-sm rounded-pill w-100">إضافة</button>
        </div>
    </form>
</div>
