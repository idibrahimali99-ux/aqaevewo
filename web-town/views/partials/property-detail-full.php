<?php
/** @var array<string,mixed> $property */
/** @var list<string> $images */
/** @var bool $compact */
$images = $images ?? property_image_list($property);
$compact = !empty($compact);
$details = property_details_array($property) ?? [];
$coords = property_coordinates($property);
$publicNo = (string) ($property['property_public_no'] ?? '');
$videoUrl = trim((string) ($property['video_url'] ?? $videoUrl ?? ''));
$owner = property_owner_label($property);
$specRows = property_spec_rows($property);
?>
<div class="property-detail-full<?= $compact ? ' property-detail-compact' : '' ?>">
    <div class="row g-4">
        <div class="col-lg-7">
            <div id="propertyGallery" class="carousel slide property-gallery rounded-4 overflow-hidden shadow-sm" data-bs-ride="carousel">
                <div class="carousel-inner">
                    <?php foreach ($images as $i => $img): ?>
                        <div class="carousel-item<?= $i === 0 ? ' active' : '' ?>">
                            <div class="ratio ratio-16x9">
                                <img src="<?= e($img) ?>" alt="" class="object-fit-cover">
                            </div>
                        </div>
                    <?php endforeach; ?>
                </div>
                <?php if (count($images) > 1): ?>
                    <button class="carousel-control-prev" type="button" data-bs-target="#propertyGallery" data-bs-slide="prev"><span class="carousel-control-prev-icon"></span></button>
                    <button class="carousel-control-next" type="button" data-bs-target="#propertyGallery" data-bs-slide="next"><span class="carousel-control-next-icon"></span></button>
                <?php endif; ?>
            </div>
            <?php if ($videoUrl !== ''): ?>
                <div class="ratio ratio-16x9 rounded-4 overflow-hidden shadow-sm mt-3">
                    <video src="<?= e($videoUrl) ?>" controls playsinline class="w-100 h-100 object-fit-cover"></video>
                </div>
            <?php endif; ?>
            <?php if ($coords !== null): ?>
                <div class="property-detail-map rounded-4 overflow-hidden mt-3" id="propertyDetailMap" data-lat="<?= e((string) $coords['lat']) ?>" data-lng="<?= e((string) $coords['lng']) ?>"></div>
            <?php endif; ?>
        </div>
        <div class="col-lg-5">
            <div class="property-detail-side">
                <div class="d-flex flex-wrap gap-2 mb-2">
                    <?php if ($publicNo !== ''): ?>
                        <button type="button" class="property-public-no property-public-no-lg" data-copy-text="#<?= e($publicNo) ?>" title="اضغط لنسخ رقم المنشور">#<?= e($publicNo) ?></button>
                    <?php endif; ?>
                    <span class="badge rounded-pill text-bg-warning"><?= e(property_purpose_label((string) ($property['purpose'] ?? ''))) ?></span>
                    <span class="badge rounded-pill text-bg-light border"><?= e(property_category_label((string) ($property['category'] ?? ''))) ?></span>
                    <?php if (!empty($property['is_sold'])): ?><span class="badge rounded-pill text-bg-secondary">تم البيع</span><?php endif; ?>
                </div>
                <h1 class="h3 mb-2"><?= e((string) ($property['title'] ?? 'عقار')) ?></h1>
                <p class="text-secondary mb-3"><?= e(trim((string) ($property['governorate'] ?? '') . ' · ' . (string) ($property['address_line'] ?? ''))) ?></p>
                <div class="property-detail-price mb-3"><?= e(money_iqd($property['price_iqd'] ?? null)) ?></div>

                <?php if ($specRows !== []): ?>
                    <div class="property-spec-grid mb-3">
                        <?php foreach ($specRows as $row): ?>
                            <div class="property-spec-item">
                                <span><?= e($row['label']) ?></span>
                                <strong><?= e($row['value']) ?></strong>
                            </div>
                        <?php endforeach; ?>
                    </div>
                <?php endif; ?>

                <div class="property-owner-card mb-3">
                    <div class="small text-secondary mb-1">الناشر</div>
                    <strong><?= e($owner) ?></strong>
                    <?php if (!empty($property['owner_phone'])): ?>
                        <div class="small mt-1"><i class="fa-solid fa-phone ms-1"></i> <?= e((string) $property['owner_phone']) ?></div>
                    <?php endif; ?>
                </div>

                <?php if (!empty($property['description'])): ?>
                    <div class="property-description mb-3">
                        <div class="small text-secondary mb-1">الوصف</div>
                        <p class="mb-0"><?= nl2br(e((string) $property['description'])) ?></p>
                    </div>
                <?php endif; ?>

                <?php if (empty($compact) && !empty($property['id']) && is_logged_in()): ?>
                    <div class="d-flex flex-wrap gap-2">
                        <form method="post" action="<?= e(url('/property/' . $property['id'] . '/contact')) ?>">
                            <?= csrf_field() ?>
                            <button class="btn btn-primary rounded-pill px-4" type="submit"><i class="fa-solid fa-comments ms-1"></i> تواصل</button>
                        </form>
                        <form method="post" action="<?= e(url('/favorites/toggle')) ?>" class="d-inline">
                            <?= csrf_field() ?>
                            <input type="hidden" name="property_id" value="<?= e((string) $property['id']) ?>">
                            <input type="hidden" name="back" value="<?= e(current_path()) ?>">
                            <button class="btn btn-outline-dark rounded-pill" type="submit"><i class="fa-solid fa-heart ms-1"></i> <?= is_favorite((string) $property['id']) ? 'محفوظ' : 'حفظ' ?></button>
                        </form>
                    </div>
                <?php elseif (empty($compact) && !empty($property['id'])): ?>
                    <a class="btn btn-primary rounded-pill px-4" href="<?= e(url('/login')) ?>">سجّل للتواصل</a>
                <?php endif; ?>
            </div>
        </div>
    </div>
</div>
