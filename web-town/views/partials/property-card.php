<?php
/** @var array<string,mixed> $property */
$propertyTitle = (string) pick($property, 'title', 'عقار بدون عنوان');
$address = trim((string) pick($property, 'address_line', '') . ' ' . (string) pick($property, 'governorate', ''));
?>
<article class="card property-card">
    <div class="media">
        <img src="<?= e(first_image($property)) ?>" alt="<?= e($propertyTitle) ?>" loading="lazy">
    </div>
    <div class="card-body">
        <span class="pill"><?= e((string) pick($property, 'purpose', 'عقار')) ?></span>
        <h3><?= e($propertyTitle) ?></h3>
        <p class="muted"><?= e($address !== '' ? $address : 'العراق') ?></p>
        <div class="price"><?= e(money_iqd($property['price_iqd'] ?? null)) ?></div>
    </div>
</article>
