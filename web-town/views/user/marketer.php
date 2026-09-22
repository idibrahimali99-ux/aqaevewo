<div class="panel-card p-4 mb-3">
    <h1 class="h3">لوحة المسوق</h1>
    <p class="text-secondary mb-0"><?= e((string) ($user['office_name'] ?? $user['full_name'] ?? '')) ?></p>
</div>
<div class="row g-3">
    <div class="col-md-4"><a class="shortcut-card" href="<?= e(url('/property/add')) ?>"><strong>إضافة إعلان</strong><span>نشر عقار ضمن حصتك</span></a></div>
    <div class="col-md-4"><a class="shortcut-card" href="<?= e(url('/reels/add')) ?>"><strong>نشر ريل</strong><span>فيديو من 30 ثانية إلى 3 دقائق</span></a></div>
    <div class="col-md-4"><a class="shortcut-card" href="<?= e(url('/messages')) ?>"><strong>الرسائل</strong><span>متابعة العملاء</span></a></div>
</div>
<?php require __DIR__ . '/_owner-content.php'; ?>
