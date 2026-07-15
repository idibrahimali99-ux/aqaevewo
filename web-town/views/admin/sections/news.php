<?php

/** @var array<string,mixed> $data */
/** @var array<string,mixed> $section */
/** @var string $sectionKey */

$items = admin_items_from_response($data);
$items = admin_sort_rows($items, 'sort_order', static fn (array $row): string => (string) ($row['title'] ?? ''));

require __DIR__ . '/../partials/section-alerts.php';

?>

<?php if ($items === []): ?>
    <div class="panel-card text-center py-5 text-secondary">لا توجد أخبار.</div>
<?php else: ?>
    <div class="admin-cards-grid mb-4">
        <?php foreach ($items as $row): ?>
            <?php if (!is_array($row)) continue; ?>
            <?php
            $id = (string) ($row['id'] ?? '');
            $img = trim((string) ($row['image_url'] ?? $row['thumb_url'] ?? ''));
            ?>
            <article class="admin-entity-card">
                <?php if ($img !== ''): ?><img src="<?= e($img) ?>" alt="" class="admin-preview-photo rounded-4 mb-2"><?php endif; ?>
                <strong><?= e((string) ($row['title'] ?? '')) ?></strong>
                <div class="small text-secondary mt-1"><?= e(mb_substr((string) ($row['body'] ?? ''), 0, 120)) ?></div>
                <div class="admin-entity-actions flex-wrap mt-3">
                    <button type="button" class="btn btn-outline-primary btn-sm rounded-pill" data-bs-toggle="collapse" data-bs-target="#news-<?= e($id) ?>">تعديل</button>
                    <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="d-inline" onsubmit="return confirm('حذف الخبر؟');">
                        <?= csrf_field() ?>
                        <input type="hidden" name="_operation" value="delete">
                        <input type="hidden" name="id" value="<?= e($id) ?>">
                        <button type="submit" class="btn btn-outline-danger btn-sm rounded-pill">حذف</button>
                    </form>
                </div>
                <div class="collapse mt-3 w-100" id="news-<?= e($id) ?>">
                    <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="admin-form-card">
                        <?= csrf_field() ?>
                        <input type="hidden" name="_operation" value="update">
                        <input type="hidden" name="id" value="<?= e($id) ?>">
                        <input type="text" name="title" class="form-control form-control-sm mb-2" value="<?= e((string) ($row['title'] ?? '')) ?>" required>
                        <textarea name="body" class="form-control form-control-sm mb-2" rows="3"><?= e((string) ($row['body'] ?? '')) ?></textarea>
                        <input type="url" name="image_url" class="form-control form-control-sm mb-2" value="<?= e((string) ($row['image_url'] ?? '')) ?>">
                        <button type="submit" class="btn btn-success btn-sm rounded-pill">حفظ</button>
                    </form>
                </div>
            </article>
        <?php endforeach; ?>
    </div>
<?php endif; ?>

<div class="panel-card admin-form-card">
    <h2 class="h5 mb-3">إضافة خبر جديد</h2>
    <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="row g-2">
        <?= csrf_field() ?>
        <input type="hidden" name="_operation" value="create">
        <div class="col-md-4"><input type="text" name="title" class="form-control" placeholder="العنوان" required></div>
        <div class="col-12"><textarea name="body" class="form-control" rows="3" placeholder="المحتوى"></textarea></div>
        <div class="col-md-4"><input type="url" name="image_url" class="form-control" placeholder="رابط الصورة"></div>
        <div class="col-md-2"><input type="number" name="sort_order" class="form-control" value="0"></div>
        <div class="col-md-2"><button type="submit" class="btn btn-primary rounded-pill w-100">إضافة</button></div>
    </form>
</div>
