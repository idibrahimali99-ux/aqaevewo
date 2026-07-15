<?php

/** @var list<array<string,mixed>> $items */

$startId = trim((string) ($_GET['reel'] ?? $_GET['id'] ?? ''));

$itemsJson = json_encode($items, JSON_UNESCAPED_UNICODE | JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT);

?>

<div class="reels-app" id="reelsApp" data-start="<?= e($startId) ?>">

    <header class="reels-topbar">

        <a href="<?= e(url('/')) ?>" class="btn btn-sm btn-dark rounded-circle"><i class="fa-solid fa-arrow-right"></i></a>

        <strong>ريلز</strong>

        <?php if (is_logged_in()): ?>
            <a href="<?= e(url('/logout')) ?>" class="btn btn-sm btn-outline-light rounded-pill">خروج</a>
        <?php else: ?>
            <a href="<?= e(url('/login')) ?>" class="btn btn-sm btn-outline-light rounded-pill">دخول</a>
        <?php endif; ?>

    </header>

    <?php if (!empty($error)): ?>

        <div class="reels-empty"><?= e($error) ?></div>

    <?php elseif ($items === []): ?>

        <div class="reels-empty">لا توجد ريلز منشورة بعد</div>

    <?php else: ?>

        <div class="reels-feed" id="reelsFeed">

            <?php foreach ($items as $i => $reel): ?>

                <?php

                $rid = (string) ($reel['id'] ?? '');

                $video = trim((string) ($reel['video_public_url'] ?? ''));

                $publisher = trim((string) ($reel['publisher_display'] ?? $reel['owner_display_name'] ?? 'عقار تاون'));

                $caption = trim((string) ($reel['caption'] ?? ''));

                $likes = (int) ($reel['likes_count'] ?? 0);
                $likedByMe = !empty($reel['liked_by_me']);
                $propertyId = (string) ($reel['property_id'] ?? '');

                ?>

                <section class="reel-slide<?= ($startId !== '' && $startId === $rid) || ($startId === '' && $i === 0) ? ' is-active' : '' ?>" data-reel-id="<?= e($rid) ?>" data-property-id="<?= e($propertyId) ?>">

                    <div class="reel-frame">

                    <?php if ($video !== ''): ?>

                        <video class="reel-video" src="<?= e($video) ?>" playsinline loop muted preload="metadata"<?= $i === 0 ? ' autoplay' : '' ?>></video>

                    <?php else: ?>

                        <div class="reel-video-placeholder"><i class="fa-solid fa-clapperboard"></i></div>

                    <?php endif; ?>

                    <div class="reel-gradient"></div>

                    </div>

                    <div class="reel-actions">

                        <button type="button" class="reel-action-btn<?= $likedByMe ? ' liked' : '' ?>" data-like="<?= e($rid) ?>" title="إعجاب"><i class="fa-<?= $likedByMe ? 'solid' : 'regular' ?> fa-heart"></i><span><?= e((string) $likes) ?></span></button>

                        <?php if ($propertyId !== ''): ?>

                            <a href="<?= e(url('/property/' . $propertyId)) ?>" class="reel-action-btn" title="العقار"><i class="fa-solid fa-house"></i></a>

                        <?php endif; ?>

                        <button type="button" class="reel-action-btn" data-chat="<?= e($rid) ?>" data-property="<?= e($propertyId) ?>" title="تواصل"><i class="fa-solid fa-comment-dots"></i></button>

                    </div>

                    <div class="reel-meta">

                        <strong><?= e($publisher) ?></strong>

                        <?php if ($caption !== ''): ?><p><?= e($caption) ?></p><?php endif; ?>

                    </div>

                </section>

            <?php endforeach; ?>

        </div>

    <?php endif; ?>

</div>

<script>window.AQAR_REELS = <?= $itemsJson ?: '[]' ?>;</script>

