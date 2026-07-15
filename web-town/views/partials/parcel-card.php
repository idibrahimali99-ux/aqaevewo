<?php /** @var array<string,mixed> $parcel */
$id = (string) ($parcel['id'] ?? '');
$name = parcel_display_name($parcel);
$posts = int_stat($parcel['posts_count'] ?? 0);
$gov = trim((string) ($parcel['governorate'] ?? ''));
$district = trim((string) ($parcel['district_name'] ?? ''));
?>
<article class="entity-card parcel-card-pro">
    <a href="<?= e(url('/parcels/' . $id, ['title' => $name])) ?>" class="entity-card-link"></a>
    <div class="entity-card-icon"><i class="fa-solid fa-border-all"></i></div>
    <div class="entity-card-body">
        <strong><?= e($name) ?></strong>
        <div class="entity-meta">
            <i class="fa-solid fa-map"></i>
            <?= e(trim($gov . ($district !== '' ? ' · ' . $district : ''))) ?: 'العراق' ?>
        </div>
        <div class="entity-stats">
            <span class="entity-stat-primary"><i class="fa-solid fa-house"></i> <?= e(compact_number($posts)) ?> منشور</span>
            <?php if (int_stat($parcel['follower_count'] ?? 0) > 0): ?>
                <span><i class="fa-solid fa-user-group"></i> <?= e(compact_number($parcel['follower_count'])) ?></span>
            <?php endif; ?>
        </div>
    </div>
</article>
