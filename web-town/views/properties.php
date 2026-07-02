<?php /** @var array<int,array<string,mixed>> $items */ ?>
<section class="section">
    <div class="section-head">
        <div>
            <h1>العقارات</h1>
            <p>ابحث في العقارات المنشورة من قاعدة بيانات عقار تاون.</p>
        </div>
    </div>
    <form class="search-form" method="get" action="<?= e(url('/properties')) ?>">
        <input class="input" name="q" value="<?= e($_GET['q'] ?? '') ?>" placeholder="ابحث باسم العقار أو المنطقة">
        <input class="input" name="governorate" value="<?= e($_GET['governorate'] ?? '') ?>" placeholder="المحافظة">
        <select name="purpose">
            <option value="">الكل</option>
            <option value="sale" <?= ($_GET['purpose'] ?? '') === 'sale' ? 'selected' : '' ?>>بيع</option>
            <option value="rent" <?= ($_GET['purpose'] ?? '') === 'rent' ? 'selected' : '' ?>>إيجار</option>
        </select>
        <button class="btn primary" type="submit">بحث</button>
    </form>
    <?php if (!empty($error)): ?>
        <div class="alert"><?= e($error) ?></div>
    <?php endif; ?>
    <div class="grid properties">
        <?php foreach ($items as $property): ?>
            <?php require __DIR__ . '/partials/property-card.php'; ?>
        <?php endforeach; ?>
    </div>
    <?php if (empty($items)): ?>
        <p class="muted">لا توجد عقارات مطابقة حاليا.</p>
    <?php endif; ?>
</section>
