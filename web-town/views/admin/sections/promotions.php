<?php

/** @var array<string,mixed> $data */
/** @var array<string,mixed> $section */
/** @var string $sectionKey */

$items = admin_items_from_response($data);
$items = admin_sort_rows($items, 'sort_order', static fn (array $row): string => (string) ($row['title'] ?? ''));

require __DIR__ . '/../partials/section-alerts.php';

?>

<?php if ($items === []): ?>
    <div class="panel-card text-center py-5 text-secondary">لا توجد إعلانات.</div>
<?php else: ?>
    <div class="panel-card admin-list-panel mb-4">
        <div class="table-responsive">
            <table class="table admin-data-table align-middle mb-0">
                <thead><tr><th>الإعلان</th><th>الترتيب</th><th>الحالة</th><th>ينتهي</th><th class="text-end">إجراءات</th></tr></thead>
                <tbody>
                    <?php foreach ($items as $row): ?>
                        <?php if (!is_array($row)) continue; ?>
                        <?php $id = (string) ($row['id'] ?? ''); ?>
                        <tr>
                            <td><strong><?= e((string) ($row['title'] ?? '')) ?></strong></td>
                            <td><?= e((string) ($row['sort_order'] ?? '0')) ?></td>
                            <td><span class="badge rounded-pill <?= !empty($row['is_active']) ? 'text-bg-success' : 'text-bg-secondary' ?>"><?= !empty($row['is_active']) ? 'فعّال' : 'موقوف' ?></span></td>
                            <td class="small text-secondary"><?= e((string) ($row['ends_at'] ?? '—')) ?></td>
                            <td class="text-end">
                                <button type="button" class="btn btn-outline-primary btn-sm rounded-pill" data-bs-toggle="collapse" data-bs-target="#promo-<?= e($id) ?>">تعديل</button>
                                <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="d-inline" onsubmit="return confirm('حذف الإعلان؟');">
                                    <?= csrf_field() ?>
                                    <input type="hidden" name="_operation" value="delete">
                                    <input type="hidden" name="id" value="<?= e($id) ?>">
                                    <button type="submit" class="btn btn-outline-danger btn-sm rounded-pill">حذف</button>
                                </form>
                            </td>
                        </tr>
                        <tr class="collapse" id="promo-<?= e($id) ?>">
                            <td colspan="5">
                                <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="admin-form-card row g-2">
                                    <?= csrf_field() ?>
                                    <input type="hidden" name="_operation" value="update">
                                    <input type="hidden" name="id" value="<?= e($id) ?>">
                                    <div class="col-md-3"><input type="text" name="title" class="form-control form-control-sm" value="<?= e((string) ($row['title'] ?? '')) ?>" required></div>
                                    <div class="col-md-3"><input type="url" name="image_url" class="form-control form-control-sm" value="<?= e((string) ($row['image_url'] ?? '')) ?>"></div>
                                    <div class="col-md-2"><input type="number" name="sort_order" class="form-control form-control-sm" value="<?= e((string) ($row['sort_order'] ?? '0')) ?>"></div>
                                    <div class="col-md-2"><input type="number" name="is_active" class="form-control form-control-sm" value="<?= !empty($row['is_active']) ? '1' : '0' ?>"></div>
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

<div class="panel-card admin-form-card">
    <h2 class="h5 mb-3">إضافة إعلان جديد</h2>
    <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="row g-2">
        <?= csrf_field() ?>
        <input type="hidden" name="_operation" value="create">
        <div class="col-md-4"><input type="text" name="title" class="form-control" placeholder="العنوان" required></div>
        <div class="col-md-4"><input type="url" name="image_url" class="form-control" placeholder="رابط الصورة"></div>
        <div class="col-md-2"><input type="number" name="sort_order" class="form-control" value="0"></div>
        <div class="col-md-2"><button type="submit" class="btn btn-primary rounded-pill w-100">إضافة</button></div>
    </form>
</div>
