<div class="container-xl py-5">
    <div class="section-head mb-4">
        <div>
            <span class="section-label">تصفح حسب المنطقة</span>
            <h1 class="section-title mb-1">المقاطعات</h1>
            <p class="text-secondary mb-0"><?= e((string) count($items)) ?> مقاطعة نشطة</p>
        </div>
        <?php if (!empty($governorates)): ?>
            <form class="entity-filter" method="get" action="<?= e(url('/parcels')) ?>">
                <select name="governorate" class="form-select form-select-sm rounded-pill" onchange="this.form.submit()">
                    <option value="">كل المحافظات</option>
                    <?php foreach ($governorates as $gov): ?>
                        <?php $gname = is_array($gov) ? (string) ($gov['name'] ?? $gov['governorate'] ?? '') : (string) $gov; ?>
                        <option value="<?= e($gname) ?>"<?= ($_GET['governorate'] ?? '') === $gname ? ' selected' : '' ?>><?= e($gname) ?></option>
                    <?php endforeach; ?>
                </select>
            </form>
        <?php endif; ?>
    </div>
    <?php if (!empty($error)): ?>
        <div class="alert alert-danger rounded-4"><?= e($error) ?></div>
    <?php endif; ?>
    <?php if ($items === []): ?>
        <div class="panel-card text-center py-5 text-secondary">لا توجد مقاطعات في هذا القسم.</div>
    <?php else: ?>
        <div class="entity-grid">
            <?php foreach ($items as $parcel): ?>
                <?php require __DIR__ . '/../partials/parcel-card.php'; ?>
            <?php endforeach; ?>
        </div>
    <?php endif; ?>
</div>
