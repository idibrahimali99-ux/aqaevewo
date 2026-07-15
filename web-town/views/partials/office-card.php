<?php /** @var array<string,mixed> $office */
$id = (string) ($office['id'] ?? '');
$isMarketer = !empty($office['is_marketer']) || (($office['account_type'] ?? '') === 'marketer');
$href = $id !== '' ? url($isMarketer ? '/marketer/' . $id : '/office/' . $id) : url('/offices');
$name = office_display_name($office);
$photo = trim((string) ($office['office_photo_url'] ?? $office['profile_photo_url'] ?? ''));
$photo = $photo !== '' ? $photo : asset_url('images/placeholder-property.svg');
$posts = int_stat($office['posts_count'] ?? 0);
$verified = !empty($office['office_verified']);
?>
<article class="entity-card office-card-pro">
    <a href="<?= e($href) ?>" class="entity-card-link"></a>
    <div class="entity-card-media">
        <img src="<?= e($photo) ?>" alt="<?= e($name) ?>" loading="lazy">
        <?php if ($verified): ?><span class="entity-badge entity-badge-verified"><i class="fa-solid fa-circle-check"></i> موثّق</span><?php endif; ?>
    </div>
    <div class="entity-card-body">
        <div class="d-flex justify-content-between gap-2 align-items-start">
            <strong><?= e($name) ?></strong>
            <span class="entity-type-badge"><?= $isMarketer ? 'مسوق' : 'مكتب' ?></span>
        </div>
        <div class="entity-meta"><i class="fa-solid fa-location-dot"></i> <?= e((string) pick($office, 'office_address', 'العراق')) ?></div>
        <?php if (!empty($office['phone'])): ?>
            <div class="entity-meta"><i class="fa-solid fa-phone"></i> <?= e((string) $office['phone']) ?></div>
        <?php endif; ?>
        <div class="entity-stats">
            <span><i class="fa-solid fa-house"></i> <?= e(compact_number($posts)) ?> منشور</span>
        </div>
    </div>
</article>
