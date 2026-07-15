<div class="panel-card p-4 mb-3">
    <h1 class="h3">لوحة المكتب</h1>
    <p class="text-secondary mb-0"><?= e((string) ($user['office_name'] ?? $user['full_name'] ?? '')) ?></p>
</div>
<div class="row g-3">
    <div class="col-md-4"><a class="shortcut-card" href="<?= e(url('/property/add')) ?>"><strong>إضافة إعلان</strong><span>نشر عقار جديد عبر API</span></a></div>
    <div class="col-md-4"><a class="shortcut-card" href="<?= e(url('/profile')) ?>"><strong>منشوراتي</strong><span>إدارة الحساب والعقارات</span></a></div>
    <div class="col-md-4"><a class="shortcut-card" href="<?= e(url('/messages')) ?>"><strong>الرسائل</strong><span>محادثات العملاء</span></a></div>
</div>
