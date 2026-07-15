<?php

/** @var array<string,mixed> $data */
/** @var array<string,mixed> $section */
/** @var string $sectionKey */

$items = admin_items_from_response($data);
$status = trim((string) ($_GET['status'] ?? 'pending'));
$sort = trim((string) ($_GET['sort'] ?? ''));

if ($status === 'approved' && $sort === 'popular') {
    // keep popular sort
} elseif (!in_array($status, ['pending', 'approved', 'rejected'], true)) {
    $status = 'pending';
    $sort = '';
}

if ($status !== 'approved') {
    $sort = '';
}

if ($status === 'approved' && $sort === 'popular') {
    $items = admin_sort_rows($items, 'views_desc', static fn (array $row): string => (string) ($row['caption'] ?? ''));
}

require __DIR__ . '/../partials/section-alerts.php';

?>

<div class="admin-section-head">
    <div class="admin-tabs">
        <?= admin_section_tab($sectionKey, 'مراجعة', ['status' => 'pending']) ?>
        <?= admin_section_tab($sectionKey, 'منشورة', ['status' => 'approved']) ?>
        <?= admin_section_tab($sectionKey, 'مرفوضة', ['status' => 'rejected']) ?>
        <?php if ($status === 'approved'): ?>
            <a class="admin-tab<?= $sort === 'popular' ? ' active' : '' ?>" href="<?= e(url('/admin/' . $sectionKey, ['status' => 'approved', 'sort' => 'popular'])) ?>">الأكثر شعبية</a>
            <?php if ($sort === 'popular'): ?>
                <a class="admin-tab" href="<?= e(url('/admin/' . $sectionKey, ['status' => 'approved'])) ?>">الأحدث</a>
            <?php endif; ?>
        <?php endif; ?>
    </div>
    <form class="admin-inline-search" method="get" action="<?= e(url('/admin/' . $sectionKey)) ?>">
        <input type="hidden" name="status" value="<?= e($status) ?>">
        <?php if ($sort === 'popular'): ?><input type="hidden" name="sort" value="popular"><?php endif; ?>
        <input type="search" name="q" value="<?= e($_GET['q'] ?? '') ?>" placeholder="بحث برقم الريل #">
        <button type="submit" class="btn btn-primary btn-sm rounded-pill">بحث</button>
    </form>
</div>

<?php if ($items === []): ?>
    <div class="panel-card text-center py-5 text-secondary">لا توجد ريلز في هذا القسم.</div>
<?php else: ?>
    <div class="admin-reels-grid">
        <?php foreach ($items as $reel): ?>
            <?php
            $rid = (string) ($reel['id'] ?? '');
            $publicNo = (string) ($reel['reel_public_no'] ?? '');
            $video = trim((string) ($reel['video_public_url'] ?? $reel['video_url'] ?? ''));
            $payload = htmlspecialchars(json_encode($reel, JSON_UNESCAPED_UNICODE), ENT_QUOTES, 'UTF-8');
            $views = (int) ($reel['view_count'] ?? $reel['views'] ?? 0);
            $likes = (int) ($reel['like_count'] ?? $reel['likes'] ?? 0);
            ?>
            <article class="admin-reel-card" data-reel="<?= $payload ?>" data-status="<?= e($status) ?>">
                <button type="button" class="admin-property-open" data-reel-open aria-label="معاينة الريل">
                    <div class="admin-reel-media">
                        <?php if ($video !== ''): ?>
                            <video src="<?= e($video) ?>" muted preload="metadata" playsinline></video>
                        <?php else: ?>
                            <div class="admin-reel-placeholder"><i class="fa-solid fa-clapperboard"></i></div>
                        <?php endif; ?>
                        <?php if ($publicNo !== ''): ?><span class="admin-property-no">#<?= e($publicNo) ?></span><?php endif; ?>
                        <span class="admin-preview-badge"><i class="fa-solid fa-play"></i></span>
                    </div>
                    <div class="admin-property-body">
                        <strong><?= e((string) ($reel['caption'] ?? 'ريل')) ?></strong>
                        <div class="small text-secondary"><?= e((string) ($reel['owner_display_name'] ?? $reel['owner_full_name'] ?? '')) ?></div>
                        <div class="small text-secondary mt-1">
                            <i class="fa-solid fa-eye ms-1"></i> <?= e(compact_number($views)) ?>
                            <i class="fa-solid fa-heart ms-2"></i> <?= e(compact_number($likes)) ?>
                        </div>
                        <?php if (!empty($reel['reject_note'])): ?>
                            <div class="alert alert-warning py-2 px-3 small mb-0 mt-2"><?= e((string) $reel['reject_note']) ?></div>
                        <?php endif; ?>
                    </div>
                </button>
                <div class="admin-entity-actions flex-wrap mt-3 px-3 pb-3">
                    <?php if ($status === 'pending'): ?>
                        <button type="button" class="btn btn-warning btn-sm rounded-pill" data-reel-open><i class="fa-solid fa-play ms-1"></i> معاينة وموافقة</button>
                    <?php else: ?>
                        <button type="button" class="btn btn-light btn-sm rounded-pill" data-reel-open>معاينة</button>
                        <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="d-inline" onsubmit="return confirm('حذف هذا الريل؟');">
                            <?= csrf_field() ?>
                            <input type="hidden" name="_operation" value="delete">
                            <input type="hidden" name="id" value="<?= e($rid) ?>">
                            <button type="submit" class="btn btn-outline-danger btn-sm rounded-pill">حذف</button>
                        </form>
                    <?php endif; ?>
                </div>
            </article>
        <?php endforeach; ?>
    </div>
<?php endif; ?>

<div class="modal fade" id="adminReelModal" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content rounded-4 border-0 overflow-hidden">
            <div class="modal-header border-0">
                <h5 class="modal-title">معاينة الريل</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="إغلاق"></button>
            </div>
            <div class="modal-body p-0" id="adminReelModalBody"></div>
            <div class="modal-footer border-0 flex-wrap gap-2" id="adminReelModalActions"></div>
        </div>
    </div>
</div>
