<?php /** @var array<string,mixed> $property */
$pid = (string) ($property['id'] ?? '');
$href = $pid !== '' ? url('/property/' . $pid) : url('/properties');
$publicNo = (string) ($property['property_public_no'] ?? '');
$purpose = property_purpose_label((string) ($property['purpose'] ?? ''));
$category = property_category_label((string) ($property['category'] ?? ''));
$segment = property_segment_label((string) ($property['segment'] ?? ''));
?>
<article class="property-card card border-0 shadow-sm h-100 position-relative">
    <a href="<?= e($href) ?>" class="stretched-link" aria-label="<?= e((string) pick($property, 'title', 'عقار')) ?>"></a>
    <div class="ratio ratio-4x3 card-img-wrap">
        <img src="<?= e(first_image($property)) ?>" alt="<?= e((string) pick($property, 'title', 'عقار')) ?>" loading="lazy" class="card-img-top object-fit-cover">
        <?php if ($publicNo !== ''): ?>
            <button type="button" class="property-public-no" data-copy-text="#<?= e($publicNo) ?>" title="نسخ رقم المنشور">#<?= e($publicNo) ?></button>
        <?php endif; ?>
    </div>
    <div class="card-body">
        <div class="d-flex flex-wrap gap-1 mb-2">
            <span class="badge text-bg-warning"><?= e($purpose) ?></span>
            <?php if ($category !== 'عقار'): ?><span class="badge text-bg-light border"><?= e($category) ?></span><?php endif; ?>
            <?php if ($segment !== '' && $segment !== 'عادي'): ?><span class="badge text-bg-secondary"><?= e($segment) ?></span><?php endif; ?>
        </div>
        <h3 class="h6 mb-2"><?= e((string) pick($property, 'title', 'عقار')) ?></h3>
        <p class="text-secondary small mb-2"><?= e(trim((string) pick($property, 'governorate', '') . ' ' . (string) pick($property, 'address_line', ''))) ?></p>
        <div class="price-tag"><?= e(money_iqd($property['price_iqd'] ?? null)) ?></div>
        <span class="property-card-cta">عرض التفاصيل</span>
    </div>
    <?php if ($pid !== '' && is_logged_in()): ?>
        <form method="post" action="<?= e(url('/favorites/toggle')) ?>" class="position-absolute top-0 end-0 m-2" style="z-index:2">
            <?= csrf_field() ?>
            <input type="hidden" name="property_id" value="<?= e($pid) ?>">
            <input type="hidden" name="back" value="<?= e(current_path()) ?>">
            <button type="submit" class="btn btn-sm btn-light rounded-circle shadow-sm" title="المفضلة">
                <i class="fa-solid fa-heart<?= is_favorite($pid) ? '' : '-circle' ?>"></i>
            </button>
        </form>
    <?php endif; ?>
</article>
