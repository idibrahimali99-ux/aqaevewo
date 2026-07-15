<div class="container-xl py-5">
    <div class="section-head mb-4">
        <div>
            <span class="section-label">مجمعات سكنية</span>
            <h1 class="section-title mb-1">المجمعات السكنية</h1>
            <p class="text-secondary mb-0"><?= e((string) count($items)) ?> مجمع</p>
        </div>
    </div>
    <?php if (!empty($error)): ?>
        <div class="alert alert-danger rounded-4"><?= e($error) ?></div>
    <?php endif; ?>
    <?php if ($items === []): ?>
        <div class="panel-card text-center py-5 text-secondary">لا توجد مجمعات مسجلة حالياً.</div>
    <?php else: ?>
        <div class="entity-grid">
            <?php foreach ($items as $compound): ?>
                <?php require __DIR__ . '/../partials/compound-card.php'; ?>
            <?php endforeach; ?>
        </div>
    <?php endif; ?>
</div>
