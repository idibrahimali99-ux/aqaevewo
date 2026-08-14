<?php
/** @var array<int,array<string,mixed>> $properties */
/** @var array<int,array<string,mixed>> $offices */
$promotions = isset($bootstrap['promotions']) && is_array($bootstrap['promotions']) ? $bootstrap['promotions'] : [];
?>
<section class="hero">
    <div class="hero-card">
        <span class="eyebrow">عقار تاون | AQAR TOWN</span>
        <h1>منصة عقارية عراقية بتجربة أوضح وأفخم.</h1>
        <p>ابحث عن العقار المناسب، تابع المكاتب والمسوقين، وادخل إلى لوحة حسابك حسب نوعك.</p>
        <div class="actions">
            <a class="btn primary" href="<?= e(url('/properties')) ?>">تصفح العقارات</a>
            <a class="btn ghost" href="<?= e(url('/login')) ?>">دخول لوحة التحكم</a>
        </div>
    </div>
    <div class="hero-card hero-visual">
        <div class="visual-tile">
            <span class="pill">عقار تاون</span>
            <h2>عقارات، مكاتب، ومسوقون في مكان واحد.</h2>
        </div>
        <div class="stats-row">
            <div class="stat"><strong><?= e(compact_number(count($properties))) ?></strong><span>عقارات مختارة</span></div>
            <div class="stat"><strong><?= e(compact_number(count($offices))) ?></strong><span>مكاتب ومسوقون</span></div>
            <div class="stat"><strong><?= e(compact_number(count($promotions))) ?></strong><span>إعلانات نشطة</span></div>
        </div>
    </div>
</section>

<?php if (!empty($api_error)): ?>
    <div class="alert"><?= e($api_error) ?></div>
<?php endif; ?>

<section class="section">
    <div class="section-head">
        <div>
            <h2>عقارات مميزة</h2>
            <p>أحدث العروض المتاحة حالياً.</p>
        </div>
        <a class="btn ghost" href="<?= e(url('/properties')) ?>">عرض الكل</a>
    </div>
    <div class="grid properties">
        <?php foreach (array_slice($properties, 0, 8) as $property): ?>
            <?php require __DIR__ . '/partials/property-card.php'; ?>
        <?php endforeach; ?>
    </div>
</section>

<section class="section">
    <div class="section-head">
        <div>
            <h2>مكاتب ومسوقون</h2>
            <p>حسابات مكاتب ومسوقين حسب بيانات النظام.</p>
        </div>
        <a class="btn ghost" href="<?= e(url('/offices')) ?>">عرض الكل</a>
    </div>
    <div class="grid offices">
        <?php foreach (array_slice($offices, 0, 6) as $office): ?>
            <?php require __DIR__ . '/partials/office-card.php'; ?>
        <?php endforeach; ?>
    </div>
</section>
