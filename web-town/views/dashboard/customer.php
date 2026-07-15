<?php ob_start(); ?>
<h1>لوحة الزبون</h1>
<p class="muted">مرحبا <?= e((string) ($user['full_name'] ?? '')) ?>، هنا تتابع طلباتك ومفضلتك ومحادثاتك.</p>
<div class="dashboard-grid">
    <div class="stat"><strong>0</strong><span>طلبات عقار</span></div>
    <div class="stat"><strong>0</strong><span>مفضلة</span></div>
    <div class="stat"><strong>0</strong><span>محادثات</span></div>
    <div class="stat"><strong>نشط</strong><span>حالة الحساب</span></div>
</div>
<div class="quick-grid">
    <a class="quick-card" href="<?= e(url('/properties')) ?>"><h3>ابحث عن عقار</h3><p class="muted">تصفح العقارات المتاحة الآن.</p></a>
    <div class="quick-card"><h3>طلب عقار</h3><p class="muted">سيتم ربطها بمسارات الطلبات في المرحلة التالية.</p></div>
    <div class="quick-card"><h3>المحادثات</h3><p class="muted">تابع رسائل المكاتب والوسطاء.</p></div>
</div>
<?php $slot = ob_get_clean(); require __DIR__ . '/../partials/dashboard-shell.php'; ?>
