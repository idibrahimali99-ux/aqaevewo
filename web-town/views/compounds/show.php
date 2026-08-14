<?php
/** @var string $title */
/** @var string $compoundId */
/** @var array<int,array<string,mixed>> $properties */
?>
<div class="container-xl py-5">
    <div class="section-head mb-4">
        <div>
            <span class="section-label">مجمع سكني</span>
            <h1 class="section-title"><?= e($title) ?></h1>
            <p class="text-secondary mb-0"><?= e((string) count($properties)) ?> منشور</p>
        </div>
        <a class="btn btn-outline-dark rounded-pill" href="<?= e(url('/compounds')) ?>">كل المجمعات</a>
    </div>

    <h2 class="h5 fw-black mb-3">منشورات المجمع</h2>
    <?php if ($properties === []): ?>
        <div class="panel-card text-center text-secondary py-5">لا توجد منشورات لهذا المجمع بعد.</div>
    <?php else: ?>
        <div class="row g-3">
            <?php foreach ($properties as $property): ?>
                <div class="col-md-6 col-xl-4"><?php require __DIR__ . '/../partials/property-card.php'; ?></div>
            <?php endforeach; ?>
        </div>
    <?php endif; ?>
</div>
