<div class="panel-card p-4">
    <h1 class="h4 mb-3">المفضلة</h1>
    <?php if ($items === []): ?>
        <p class="text-secondary mb-0">لا توجد عقارات محفوظة — نفس منطق التطبيق (محلياً في الجلسة).</p>
    <?php else: ?>
        <div class="row g-3">
            <?php foreach ($items as $property): ?>
                <div class="col-md-6 col-xl-4"><?php require __DIR__ . '/../partials/property-card.php'; ?></div>
            <?php endforeach; ?>
        </div>
    <?php endif; ?>
</div>
