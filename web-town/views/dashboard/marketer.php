<?php ob_start(); ?>
<h1>لوحة المسوق العقاري</h1>
<p class="muted">مرحبا <?= e((string) ($user['office_name'] ?? $user['full_name'] ?? '')) ?>، حسابك معرف كمسوق عقاري داخل النظام.</p>
<div class="dashboard-grid">
    <div class="stat"><strong><?= !empty($user['office_approved']) ? 'معتمد' : 'قيد المراجعة' ?></strong><span>حالة المسوق</span></div>
    <div class="stat"><strong><?= e($user['posting_trial_unlimited'] ?? true ? 'مفتوح' : (string) ($user['posting_listings_remaining'] ?? 0)) ?></strong><span>حصة النشر</span></div>
    <div class="stat"><strong>0</strong><span>عقارات مسوقة</span></div>
    <div class="stat"><strong>0</strong><span>محادثات</span></div>
</div>
<div class="quick-grid">
    <div class="quick-card"><h3>نشر عقار</h3><p class="muted">إضافة عقارات وتسويقها من نفس API.</p></div>
    <div class="quick-card"><h3>مناطق العمل</h3><p class="muted">تظهر المحافظات والمناطق بعد ربط بيانات المسوق.</p></div>
    <div class="quick-card"><h3>الأداء</h3><p class="muted">مشاهدات، تفاعلات، وطلبات العملاء.</p></div>
</div>
<?php $slot = ob_get_clean(); require __DIR__ . '/../partials/dashboard-shell.php'; ?>
