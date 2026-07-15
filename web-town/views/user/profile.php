<div class="panel-card p-4">
    <h1 class="h4 mb-3">الملف الشخصي</h1>
    <?php if (!empty($success)): ?><div class="alert alert-success rounded-4"><?= e($success) ?></div><?php endif; ?>
    <?php if (!empty($error)): ?><div class="alert alert-danger rounded-4"><?= e($error) ?></div><?php endif; ?>
    <form method="post" action="<?= e(url('/profile')) ?>" class="row g-3">
        <?= csrf_field() ?>
        <div class="col-md-6"><label class="form-label">الاسم</label><input class="form-control" name="full_name" value="<?= e((string) ($user['full_name'] ?? '')) ?>" required></div>
        <?php if (in_array(account_kind($user), ['office', 'marketer'], true)): ?>
            <div class="col-md-6"><label class="form-label">اسم المكتب</label><input class="form-control" name="office_name" value="<?= e((string) ($user['office_name'] ?? '')) ?>"></div>
        <?php endif; ?>
        <div class="col-12"><button class="btn btn-primary rounded-pill px-4" type="submit">حفظ</button></div>
    </form>
</div>
<?php if ($properties !== []): ?>
    <div class="panel-card p-4 mt-4">
        <h2 class="h5">منشوراتي</h2>
        <div class="row g-3 mt-1">
            <?php foreach ($properties as $property): ?>
                <div class="col-md-6 col-xl-4"><?php require __DIR__ . '/../partials/property-card.php'; ?></div>
            <?php endforeach; ?>
        </div>
    </div>
<?php endif; ?>
