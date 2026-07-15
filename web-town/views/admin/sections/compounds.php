<?php

/** @var array<string,mixed> $data */
/** @var array<string,mixed> $section */
/** @var string $sectionKey */

$items = admin_items_from_response($data);
$sort = trim((string) ($_GET['sort'] ?? 'sort_order'));
if (!in_array($sort, ['sort_order', 'name_asc', 'created_desc'], true)) {
    $sort = 'sort_order';
}
$items = admin_sort_rows($items, $sort, 'compound_display_name');
$govOptions = admin_governorate_options();
$districtOptions = admin_district_options();

require __DIR__ . '/../partials/section-alerts.php';

?>

<div class="admin-section-head">
    <form class="admin-inline-search" method="get" action="<?= e(url('/admin/' . $sectionKey)) ?>">
        <input type="search" name="q" value="<?= e($_GET['q'] ?? '') ?>" placeholder="بحث باسم المجمع">
        <button type="submit" class="btn btn-primary btn-sm rounded-pill">بحث</button>
    </form>
    <form method="get" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="admin-sort-form">
        <?= admin_sort_select($sectionKey, $sort, ['sort_order' => 'الترتيب', 'name_asc' => 'الاسم أ-ي', 'created_desc' => 'الأحدث']) ?>
    </form>
</div>

<?php if ($items === []): ?>
    <div class="panel-card text-center py-5 text-secondary">لا توجد مجمعات.</div>
<?php else: ?>
    <div class="admin-cards-grid mb-4">
        <?php foreach ($items as $row): ?>
            <?php if (!is_array($row)) continue; ?>
            <?php
            $cid = (string) ($row['id'] ?? '');
            $photo = trim((string) ($row['photo_url'] ?? $row['compound_photo_url'] ?? ''));
            $photo = $photo !== '' ? $photo : asset_url('images/placeholder-property.svg');
            ?>
            <article class="admin-entity-card">
                <div class="admin-entity-head">
                    <img src="<?= e($photo) ?>" alt="" class="admin-entity-avatar">
                    <div class="min-w-0 flex-grow-1">
                        <strong><?= e(compound_display_name($row)) ?></strong>
                        <div class="small text-secondary"><?= e((string) ($row['governorate_name'] ?? '')) ?> · <?= e((string) ($row['district_name'] ?? '')) ?></div>
                    </div>
                    <span class="badge rounded-pill <?= !empty($row['is_active']) ? 'text-bg-success' : 'text-bg-secondary' ?>"><?= !empty($row['is_active']) ? 'فعّال' : 'موقوف' ?></span>
                </div>
                <div class="admin-entity-actions flex-wrap">
                    <button type="button" class="btn btn-outline-primary btn-sm rounded-pill" data-bs-toggle="collapse" data-bs-target="#compound-<?= e($cid) ?>">تعديل</button>
                    <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="d-inline" onsubmit="return confirm('حذف المجمع؟');">
                        <?= csrf_field() ?>
                        <input type="hidden" name="_operation" value="delete">
                        <input type="hidden" name="id" value="<?= e($cid) ?>">
                        <button type="submit" class="btn btn-outline-danger btn-sm rounded-pill">حذف</button>
                    </form>
                </div>
                <div class="collapse mt-3 w-100" id="compound-<?= e($cid) ?>">
                    <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="admin-form-card row g-2">
                        <?= csrf_field() ?>
                        <input type="hidden" name="_operation" value="upsert">
                        <input type="hidden" name="id" value="<?= e($cid) ?>">
                        <div class="col-12"><?= admin_select_field('governorate_id', $govOptions, 'المحافظة', (string) ($row['governorate_id'] ?? ''), true) ?></div>
                        <div class="col-12"><?= admin_select_field('district_id', $districtOptions, 'القضاء', (string) ($row['district_id'] ?? '')) ?></div>
                        <div class="col-12"><input type="text" name="name" class="form-control form-control-sm" value="<?= e((string) ($row['compound_name'] ?? $row['name'] ?? '')) ?>" required></div>
                        <div class="col-12"><input type="url" name="photo_url" class="form-control form-control-sm" value="<?= e((string) ($row['photo_url'] ?? '')) ?>" placeholder="رابط الصورة"></div>
                        <div class="col-6"><input type="number" name="sort_order" class="form-control form-control-sm" value="<?= e((string) ($row['sort_order'] ?? '0')) ?>"></div>
                        <div class="col-6"><button type="submit" class="btn btn-success btn-sm rounded-pill w-100">حفظ</button></div>
                    </form>
                </div>
            </article>
        <?php endforeach; ?>
    </div>
<?php endif; ?>

<div class="panel-card admin-form-card">
    <h2 class="h5 mb-3">إضافة مجمع جديد</h2>
    <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="row g-2">
        <?= csrf_field() ?>
        <input type="hidden" name="_operation" value="upsert">
        <div class="col-md-3"><?= admin_select_field('governorate_id', $govOptions, 'المحافظة', null, true) ?></div>
        <div class="col-md-3"><?= admin_select_field('district_id', $districtOptions, 'القضاء') ?></div>
        <div class="col-md-3"><input type="text" name="name" class="form-control" placeholder="اسم المجمع" required></div>
        <div class="col-md-3"><input type="url" name="photo_url" class="form-control" placeholder="رابط الصورة"></div>
        <div class="col-md-2"><input type="number" name="sort_order" class="form-control" value="0"></div>
        <div class="col-md-2"><button type="submit" class="btn btn-primary rounded-pill w-100">إضافة</button></div>
    </form>
</div>
