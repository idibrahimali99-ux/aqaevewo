<?php

/** @var array<string,mixed> $data */
/** @var array<string,mixed> $section */
/** @var string $sectionKey */

$items = admin_items_from_response($data);
$items = admin_sort_rows($items, 'name_asc', static fn (array $row): string => (string) ($row['name'] ?? ''));
$govOptions = admin_governorate_options();

require __DIR__ . '/../partials/section-alerts.php';

?>

<?php if ($items === []): ?>
    <div class="panel-card text-center py-5 text-secondary">لا توجد محافظات.</div>
<?php else: ?>
    <div class="panel-card admin-list-panel mb-4">
        <div class="table-responsive">
            <table class="table admin-data-table align-middle mb-0">
                <thead><tr><th>المحافظة</th><th>الترتيب</th><th>الحالة</th><th class="text-end">إجراءات</th></tr></thead>
                <tbody>
                    <?php foreach ($items as $gov): ?>
                        <?php if (!is_array($gov)) continue; ?>
                        <?php $gid = (string) ($gov['id'] ?? ''); ?>
                        <tr>
                            <td><strong><?= e((string) ($gov['name'] ?? '')) ?></strong></td>
                            <td><?= e((string) ($gov['sort_order'] ?? '0')) ?></td>
                            <td><span class="badge rounded-pill <?= !empty($gov['is_active']) ? 'text-bg-success' : 'text-bg-secondary' ?>"><?= !empty($gov['is_active']) ? 'فعّالة' : 'موقوفة' ?></span></td>
                            <td class="text-end">
                                <button type="button" class="btn btn-outline-primary btn-sm rounded-pill" data-bs-toggle="collapse" data-bs-target="#edit-gov-<?= e($gid) ?>">تعديل</button>
                                <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="d-inline" onsubmit="return confirm('حذف المحافظة؟');">
                                    <?= csrf_field() ?>
                                    <input type="hidden" name="_operation" value="delete">
                                    <input type="hidden" name="id" value="<?= e($gid) ?>">
                                    <button type="submit" class="btn btn-outline-danger btn-sm rounded-pill">حذف</button>
                                </form>
                            </td>
                        </tr>
                        <tr class="collapse" id="edit-gov-<?= e($gid) ?>">
                            <td colspan="4">
                                <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="admin-form-card row g-2">
                                    <?= csrf_field() ?>
                                    <input type="hidden" name="_operation" value="upsert">
                                    <input type="hidden" name="id" value="<?= e($gid) ?>">
                                    <div class="col-md-4"><input type="text" name="name" class="form-control form-control-sm" value="<?= e((string) ($gov['name'] ?? '')) ?>" required></div>
                                    <div class="col-md-2"><input type="number" name="sort_order" class="form-control form-control-sm" value="<?= e((string) ($gov['sort_order'] ?? '0')) ?>"></div>
                                    <div class="col-md-2"><select name="is_active" class="form-select form-select-sm"><option value="1"<?= !empty($gov['is_active']) ? ' selected' : '' ?>>فعّالة</option><option value="0"<?= empty($gov['is_active']) ? ' selected' : '' ?>>موقوفة</option></select></div>
                                    <div class="col-md-2"><button type="submit" class="btn btn-success btn-sm rounded-pill w-100">حفظ</button></div>
                                </form>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </div>
<?php endif; ?>

<div class="panel-card admin-form-card mb-4">
    <h2 class="h5 mb-3">إضافة محافظة جديدة</h2>
    <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="row g-2">
        <?= csrf_field() ?>
        <input type="hidden" name="_operation" value="create">
        <div class="col-md-5"><input type="text" name="name" class="form-control" placeholder="اسم المحافظة" required></div>
        <div class="col-md-2"><input type="number" name="sort_order" class="form-control" value="0" placeholder="الترتيب"></div>
        <div class="col-md-2"><select name="is_active" class="form-select"><option value="1">فعّالة</option><option value="0">موقوفة</option></select></div>
        <div class="col-md-3"><button type="submit" class="btn btn-primary rounded-pill w-100">إضافة</button></div>
    </form>
</div>

<div class="panel-card admin-form-card">
    <h2 class="h5 mb-3">إضافة قضاء / منطقة</h2>
    <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="row g-2">
        <?= csrf_field() ?>
        <input type="hidden" name="_operation" value="district_upsert">
        <div class="col-md-4">
            <label class="form-label small">المحافظة</label>
            <?= admin_select_field('governorate_id', $govOptions, 'اختر المحافظة', null, true) ?>
        </div>
        <div class="col-md-4">
            <label class="form-label small">اسم القضاء</label>
            <input type="text" name="name" class="form-control" required>
        </div>
        <div class="col-md-2">
            <label class="form-label small">الترتيب</label>
            <input type="number" name="sort_order" class="form-control" value="0">
        </div>
        <div class="col-md-2 d-flex align-items-end">
            <button type="submit" class="btn btn-primary rounded-pill w-100">إضافة</button>
        </div>
    </form>
</div>
