<div class="container-xl py-5">
    <div class="section-head mb-4">
        <div>
            <span class="section-label">دليل المكاتب</span>
            <h1 class="section-title mb-1">المكاتب العقارية</h1>
            <p class="text-secondary mb-0"><?= e((string) count($items)) ?> مكتب معتمد</p>
        </div>
    </div>
    <?php if (!empty($error)): ?>
        <div class="alert alert-danger rounded-4"><?= e($error) ?></div>
    <?php endif; ?>
    <?php if ($items === []): ?>
        <div class="panel-card text-center py-5 text-secondary">لا توجد مكاتب معتمدة حالياً.</div>
    <?php else: ?>
        <div class="entity-grid">
            <?php foreach ($items as $office): ?>
                <?php require __DIR__ . '/../partials/office-card.php'; ?>
            <?php endforeach; ?>
        </div>
    <?php endif; ?>
</div>
