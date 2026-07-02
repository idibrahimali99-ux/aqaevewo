<?php /** @var array<int,array<string,mixed>> $items */ ?>
<section class="section">
    <div class="section-head">
        <div>
            <h1>المكاتب والمسوقون</h1>
            <p>دليل الحسابات العقارية المعتمدة في النظام.</p>
        </div>
        <a class="btn primary" href="<?= e(url('/register')) ?>">انضم كمكتب أو مسوق</a>
    </div>
    <?php if (!empty($error)): ?>
        <div class="alert"><?= e($error) ?></div>
    <?php endif; ?>
    <div class="grid offices">
        <?php foreach ($items as $office): ?>
            <?php require __DIR__ . '/partials/office-card.php'; ?>
        <?php endforeach; ?>
    </div>
    <?php if (empty($items)): ?>
        <p class="muted">لا توجد مكاتب أو مسوقون للعرض حاليا.</p>
    <?php endif; ?>
</section>
