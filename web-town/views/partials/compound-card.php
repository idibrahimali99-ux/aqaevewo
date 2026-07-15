<?php /** @var array<string,mixed> $compound */
$id = (string) ($compound['id'] ?? '');
$name = compound_display_name($compound);
$posts = int_stat($compound['posts_count'] ?? 0);
$gov = trim((string) ($compound['governorate'] ?? ''));
$district = trim((string) ($compound['district_name'] ?? ''));
$photo = trim((string) ($compound['photo_url'] ?? ''));
?>
<article class="entity-card compound-card-pro">
    <a href="<?= e(url('/compounds/' . $id, ['title' => $name])) ?>" class="entity-card-link"></a>
    <?php if ($photo !== ''): ?>
        <div class="entity-card-media entity-card-media-sm">
            <img src="<?= e($photo) ?>" alt="<?= e($name) ?>" loading="lazy">
        </div>
    <?php else: ?>
        <div class="entity-card-icon"><i class="fa-solid fa-city"></i></div>
    <?php endif; ?>
    <div class="entity-card-body">
        <strong><?= e($name) ?></strong>
        <div class="entity-meta">
            <i class="fa-solid fa-map"></i>
            <?= e(trim($gov . ($district !== '' ? ' · ' . $district : ''))) ?: 'العراق' ?>
        </div>
        <div class="entity-stats">
            <span class="entity-stat-primary"><i class="fa-solid fa-house"></i> <?= e(compact_number($posts)) ?> منشور</span>
            <?php if (int_stat($compound['follower_count'] ?? 0) > 0): ?>
                <span><i class="fa-solid fa-user-group"></i> <?= e(compact_number($compound['follower_count'])) ?></span>
            <?php endif; ?>
        </div>
    </div>
</article>
