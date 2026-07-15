<?php
/** @var array<int,array<string,mixed>> $properties */
/** @var array<int,array<string,mixed>> $promotions */
/** @var array<int,array<string,mixed>> $news */
/** @var array<int,array<string,mixed>> $sections */
?>
<section class="home-hero">
    <div class="container-xl position-relative">
        <div class="row align-items-center g-4">
            <div class="col-lg-7">
                <span class="hero-badge"><i class="fa-solid fa-crown"></i> Aqar Town · عقار تاون</span>
                <h1>اكتشف عقارك القادم<br>بثقة واحتراف</h1>
                <p class="home-hero-lead mt-3">منصة عقارية عراقية — بحث ذكي، محادثات فورية، وريلز عقارية.</p>

                <div class="home-quick-nav mb-4">
                    <a class="home-quick-card home-quick-card-map" href="<?= e(url('/map')) ?>">
                        <span class="home-quick-icon"><i class="fa-solid fa-map-location-dot"></i></span>
                        <span class="home-quick-text"><strong>الخريطة</strong><small>استكشف على الخريطة</small></span>
                    </a>
                    <a class="home-quick-card home-quick-card-reels" href="<?= e(url('/reels')) ?>">
                        <span class="home-quick-icon"><i class="fa-solid fa-clapperboard"></i></span>
                        <span class="home-quick-text"><strong>ريلز</strong><small>فيديوهات عقارية</small></span>
                    </a>
                    <a class="home-quick-card home-quick-card-request" href="<?= e(url(is_logged_in() ? '/request-property' : '/login')) ?>">
                        <span class="home-quick-icon"><i class="fa-solid fa-clipboard-list"></i></span>
                        <span class="home-quick-text"><strong>طلب عقار</strong><small>اطلب ما تبحث عنه</small></span>
                    </a>
                    <?php if (is_logged_in() && in_array(account_kind(auth_user()), ['office', 'marketer'], true)): ?>
                        <a class="home-quick-card home-quick-card-add" href="<?= e(url('/property/add')) ?>">
                            <span class="home-quick-icon"><i class="fa-solid fa-circle-plus"></i></span>
                            <span class="home-quick-text"><strong>إضافة عقار</strong><small>انشر إعلانك</small></span>
                        </a>
                    <?php endif; ?>
                </div>

                <form class="search-hero-pro" action="<?= e(url('/search')) ?>" method="get">
                    <input type="text" name="q" placeholder="ابحث بالمحافظة، العنوان، أو رقم المنشور #20000001">
                    <a class="btn btn-light rounded-circle search-filter-btn" href="<?= e(url('/search', ['filter' => '1'])) ?>" title="فلترة متقدمة"><i class="fa-solid fa-sliders"></i></a>
                    <button type="submit" class="btn btn-primary rounded-pill px-4"><i class="fa-solid fa-magnifying-glass ms-1"></i> بحث</button>
                </form>
            </div>
            <div class="col-lg-5">
                <div class="hero-stats">
                    <div class="hero-stat-card"><strong><?= e((string) count($properties)) ?></strong><span>عقارات معروضة</span></div>
                    <div class="hero-stat-card"><strong><?= e((string) count($offices)) ?></strong><span>مكاتب ومسوقون</span></div>
                    <div class="hero-stat-card"><strong><?= e((string) count($parcels)) ?></strong><span>مقاطعات</span></div>
                </div>
            </div>
        </div>
    </div>
</section>

<?php if (!empty($api_error)): ?>
<div class="container-xl py-3"><div class="alert alert-warning rounded-4"><?= e($api_error) ?></div></div>
<?php endif; ?>

<?php if (!empty($sections)): ?>
<section class="container-xl py-5">
    <span class="section-label">تصفح حسب النوع</span>
    <h2 class="section-title mb-4">أقسام سريعة</h2>
    <div class="category-grid">
        <?php foreach ($sections as $sec): ?>
            <a class="category-tile" href="<?= e(web_route_from_app((string) ($sec['route_target'] ?? '/'))) ?>">
                <i class="fa-solid <?= e(home_section_icon((string) ($sec['icon_name'] ?? ''))) ?>"></i>
                <strong><?= e((string) ($sec['label'] ?? '')) ?></strong>
            </a>
        <?php endforeach; ?>
    </div>
</section>
<?php endif; ?>

<?php if (!empty($promotions)): ?>
<section class="container-xl pb-5">
    <span class="section-label">عروض</span>
    <h2 class="section-title mb-4">إعلانات مميزة</h2>
    <div class="row g-3">
        <?php foreach (array_slice($promotions, 0, 3) as $promo): ?>
            <div class="col-md-4">
                <a class="promo-card" href="<?= e(url('/properties')) ?>">
                    <?php if (!empty($promo['image_url'])): ?><img src="<?= e((string) $promo['image_url']) ?>" alt=""><?php endif; ?>
                    <div class="overlay">
                        <strong><?= e((string) ($promo['title'] ?? '')) ?></strong>
                        <span><?= e((string) ($promo['subtitle'] ?? '')) ?></span>
                    </div>
                </a>
            </div>
        <?php endforeach; ?>
    </div>
</section>
<?php endif; ?>

<section class="container-xl py-2">
    <div class="d-flex justify-content-between align-items-end mb-4">
        <div><span class="section-label">مختارات</span><h2 class="section-title">أحدث العقارات</h2></div>
        <a href="<?= e(url('/properties')) ?>" class="btn btn-outline-dark rounded-pill">عرض الكل</a>
    </div>
    <div class="row g-4">
        <?php foreach ($properties as $property): ?>
            <div class="col-md-6 col-xl-3"><?php require __DIR__ . '/../partials/property-card.php'; ?></div>
        <?php endforeach; ?>
    </div>
</section>

<?php if (!empty($news)): ?>
<section class="container-xl py-5">
    <span class="section-label">أخبار</span>
    <h2 class="section-title mb-4">أخبار العقارات</h2>
    <div class="row g-3">
        <?php foreach (array_slice($news, 0, 4) as $item): ?>
            <div class="col-md-6 col-lg-3">
                <a class="news-card" href="<?= e(url('/news/' . ($item['id'] ?? ''))) ?>">
                    <?php if (!empty($item['image_url'])): ?><img src="<?= e((string) $item['image_url']) ?>" alt=""><?php endif; ?>
                    <div class="p-3"><strong><?= e((string) ($item['title'] ?? '')) ?></strong></div>
                </a>
            </div>
        <?php endforeach; ?>
    </div>
</section>
<?php endif; ?>

<section class="container-xl py-4">
    <div class="row g-4">
        <div class="col-lg-6">
            <div class="d-flex justify-content-between mb-3"><h3 class="h5 mb-0">مقاطعات</h3><a href="<?= e(url('/parcels')) ?>">الكل</a></div>
            <div class="row g-2">
                <?php foreach (array_slice($parcels, 0, 4) as $p): ?>
                    <?php $pname = parcel_display_name($p); ?>
                    <div class="col-6"><a class="parcel-chip p-3 d-block" href="<?= e(url('/parcels/' . ($p['id'] ?? ''), ['title' => $pname])) ?>">
                        <strong><?= e($pname) ?></strong>
                        <div class="small text-secondary"><?= e(compact_number(int_stat($p['posts_count'] ?? 0))) ?> منشور</div>
                    </a></div>
                <?php endforeach; ?>
            </div>
        </div>
        <div class="col-lg-6">
            <div class="d-flex justify-content-between mb-3"><h3 class="h5 mb-0">مجمعات سكنية</h3><a href="<?= e(url('/compounds')) ?>">الكل</a></div>
            <div class="row g-2">
                <?php foreach (array_slice($compounds, 0, 4) as $c): ?>
                    <?php $cname = compound_display_name($c); ?>
                    <div class="col-6"><a class="parcel-chip p-3 d-block" href="<?= e(url('/compounds/' . ($c['id'] ?? ''), ['title' => $cname])) ?>">
                        <strong><?= e($cname) ?></strong>
                        <div class="small text-secondary"><?= e(compact_number(int_stat($c['posts_count'] ?? 0))) ?> منشور</div>
                    </a></div>
                <?php endforeach; ?>
            </div>
        </div>
    </div>
</section>

<section class="container-xl pb-5">
    <div class="d-flex justify-content-between mb-4"><h2 class="section-title">مكاتب معتمدة</h2><a href="<?= e(url('/offices')) ?>" class="btn btn-outline-dark rounded-pill">عرض الكل</a></div>
    <div class="row g-4">
        <?php foreach ($offices as $office): ?>
            <div class="col-md-6 col-lg-4"><?php require __DIR__ . '/../partials/office-card.php'; ?></div>
        <?php endforeach; ?>
    </div>
</section>
