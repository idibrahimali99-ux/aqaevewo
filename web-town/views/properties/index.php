<div class="container-xl py-5">
    <h1 class="h3 mb-4"><?= e((string) ($title ?? 'العقارات')) ?></h1>
    <?php
    $q = trim((string) ($_GET['q'] ?? ''));
    $purpose = trim((string) ($_GET['purpose'] ?? ''));
    $category = trim((string) ($_GET['cat'] ?? $_GET['category'] ?? ''));
    $segment = trim((string) ($_GET['segment'] ?? ''));
    $governorate = trim((string) ($_GET['governorate'] ?? ''));
    $showFilters = isset($_GET['filter']) || $purpose !== '' || $category !== '' || $segment !== '' || $governorate !== '';
    $govList = is_array($governorates ?? null) ? $governorates : [];
    ?>
    <div class="panel-card mb-4 search-filter-panel">
        <form class="row g-3 align-items-end" method="get" action="<?= e(url('/search')) ?>">
            <div class="col-lg-4">
                <label class="form-label small">بحث</label>
                <input class="form-control" name="q" value="<?= e($q) ?>" placeholder="عنوان، محافظة، أو #رقم المنشور">
            </div>
            <div class="col-md-3 col-lg-2">
                <label class="form-label small">المحافظة</label>
                <?php if ($govList !== []): ?>
                    <select class="form-select" name="governorate">
                        <option value="">الكل</option>
                        <?php foreach ($govList as $gov): ?>
                            <?php $gname = is_array($gov) ? (string) ($gov['name'] ?? '') : (string) $gov; ?>
                            <?php if ($gname === '') continue; ?>
                            <option value="<?= e($gname) ?>"<?= $governorate === $gname ? ' selected' : '' ?>><?= e($gname) ?></option>
                        <?php endforeach; ?>
                    </select>
                <?php else: ?>
                    <input class="form-control" name="governorate" value="<?= e($governorate) ?>" placeholder="المحافظة">
                <?php endif; ?>
            </div>
            <div class="col-md-3 col-lg-2">
                <label class="form-label small">الغرض</label>
                <select class="form-select" name="purpose">
                    <?php foreach (property_purpose_options() as $val => $label): ?>
                        <option value="<?= e($val) ?>"<?= $purpose === $val ? ' selected' : '' ?>><?= e($label) ?></option>
                    <?php endforeach; ?>
                </select>
            </div>
            <div class="col-md-3 col-lg-2">
                <label class="form-label small">الفئة</label>
                <select class="form-select" name="cat">
                    <?php foreach (property_category_options() as $val => $label): ?>
                        <option value="<?= e($val) ?>"<?= $category === $val ? ' selected' : '' ?>><?= e($label) ?></option>
                    <?php endforeach; ?>
                </select>
            </div>
            <div class="col-md-3 col-lg-2">
                <label class="form-label small">النوع</label>
                <select class="form-select" name="segment">
                    <option value=""<?= $segment === '' ? ' selected' : '' ?>>الكل</option>
                    <option value="standard"<?= $segment === 'standard' ? ' selected' : '' ?>>عادي</option>
                    <option value="parcel"<?= $segment === 'parcel' ? ' selected' : '' ?>>مقاطعة</option>
                </select>
            </div>
            <div class="col-12 d-flex flex-wrap gap-2">
                <button class="btn btn-primary rounded-pill px-4" type="submit"><i class="fa-solid fa-magnifying-glass ms-1"></i> تطبيق الفلتر</button>
                <a class="btn btn-light rounded-pill" href="<?= e(url('/search')) ?>">مسح</a>
            </div>
        </form>
    </div>

    <?php if (!empty($error)): ?><div class="alert alert-warning rounded-4"><?= e($error) ?></div><?php endif; ?>

    <?php if ($items === []): ?>
        <div class="panel-card text-center py-5 text-secondary">لا توجد نتائج مطابقة.</div>
    <?php else: ?>
        <div class="mb-3 text-secondary small"><?= e(count($items)) ?> نتيجة</div>
        <div class="row g-4">
            <?php foreach ($items as $property): ?>
                <div class="col-md-6 col-xl-3"><?php require __DIR__ . '/../partials/property-card.php'; ?></div>
            <?php endforeach; ?>
        </div>
    <?php endif; ?>
</div>
