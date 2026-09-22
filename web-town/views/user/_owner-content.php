<?php
$properties = is_array($properties ?? null) ? $properties : [];
$reels = is_array($reels ?? null) ? $reels : [];
$canManage = is_logged_in();
?>
<?php if ($canManage): ?>
    <div class="d-flex flex-wrap gap-2 mb-3">
        <a class="btn btn-primary rounded-pill" href="<?= e(url('/property/add')) ?>"><i class="fa-solid fa-plus ms-1"></i> إعلان جديد</a>
        <a class="btn btn-outline-dark rounded-pill" href="<?= e(url('/reels/add')) ?>"><i class="fa-solid fa-clapperboard ms-1"></i> ريل جديد</a>
    </div>
<?php endif; ?>
<?php if ($properties !== []): ?>
    <div class="panel-card p-4 mt-4">
        <h2 class="h5 mb-3">منشوراتي</h2>
        <div class="row g-3">
            <?php foreach ($properties as $property): ?>
                <?php if (!is_array($property)) continue; ?>
                <?php $pid = (string) ($property['id'] ?? ''); ?>
                <div class="col-md-6 col-xl-4">
                    <?php require __DIR__ . '/../partials/property-card.php'; ?>
                    <?php if ($canManage && $pid !== ''): ?>
                        <div class="d-flex gap-2 mt-2" style="position:relative;z-index:3">
                            <a class="btn btn-sm btn-outline-primary rounded-pill flex-fill" href="<?= e(url('/property/' . $pid . '/edit')) ?>">تعديل</a>
                            <form method="post" action="<?= e(url('/property/' . $pid . '/delete')) ?>" onsubmit="return confirm('حذف هذا المنشور؟');">
                                <?= csrf_field() ?>
                                <button class="btn btn-sm btn-outline-danger rounded-pill" type="submit">حذف</button>
                            </form>
                        </div>
                    <?php endif; ?>
                </div>
            <?php endforeach; ?>
        </div>
    </div>
<?php endif; ?>
<?php if ($reels !== []): ?>
    <div class="panel-card p-4 mt-4">
        <h2 class="h5 mb-3">ريلزاتي</h2>
        <div class="row g-3">
            <?php foreach ($reels as $reel): ?>
                <?php if (!is_array($reel)) continue; ?>
                <?php
                $rid = (string) ($reel['id'] ?? '');
                $caption = trim((string) ($reel['caption'] ?? ''));
                $status = (string) ($reel['approval_status'] ?? '');
                ?>
                <div class="col-md-6 col-xl-4">
                    <div class="border rounded-4 p-3 h-100">
                        <strong><?= e($caption !== '' ? $caption : 'ريل عقاري') ?></strong>
                        <?php if ($status !== ''): ?>
                            <div class="small text-secondary mt-1"><?= e($status) ?></div>
                        <?php endif; ?>
                        <div class="d-flex gap-2 mt-3">
                            <a class="btn btn-sm btn-outline-dark rounded-pill" href="<?= e(url('/reels', ['reel' => $rid])) ?>">عرض</a>
                            <?php if ($canManage && $rid !== ''): ?>
                                <a class="btn btn-sm btn-outline-primary rounded-pill" href="<?= e(url('/reels/' . $rid . '/edit')) ?>">تعديل</a>
                                <form method="post" action="<?= e(url('/reels/' . $rid . '/delete')) ?>" onsubmit="return confirm('حذف هذا الريل؟');">
                                    <?= csrf_field() ?>
                                    <button class="btn btn-sm btn-outline-danger rounded-pill" type="submit">حذف</button>
                                </form>
                            <?php endif; ?>
                        </div>
                    </div>
                </div>
            <?php endforeach; ?>
        </div>
    </div>
<?php endif; ?>
