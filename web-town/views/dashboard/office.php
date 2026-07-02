<?php ob_start(); ?>
<h1>لوحة المكتب</h1>
<p class="muted">مرحبا <?= e((string) ($user['office_name'] ?? $user['full_name'] ?? '')) ?>، هذه مساحة إدارة عقاراتك وطلباتك.</p>
<div class="dashboard-grid">
    <div class="stat"><strong><?= !empty($user['office_approved']) ? 'معتمد' : 'قيد المراجعة' ?></strong><span>حالة المكتب</span></div>
    <div class="stat"><strong><?= e($user['posting_trial_unlimited'] ?? true ? 'مفتوح' : (string) ($user['posting_listings_remaining'] ?? 0)) ?></strong><span>حصة النشر</span></div>
    <div class="stat"><strong>0</strong><span>عقاراتي</span></div>
    <div class="stat"><strong>0</strong><span>رسائل</span></div>
</div>
<div class="quick-grid">
    <div class="quick-card"><h3>إضافة عقار</h3><p class="muted">واجهة الإنشاء ستربط بمسار properties/create.</p></div>
    <div class="quick-card"><h3>عقاراتي</h3><p class="muted">متابعة الموافقات والمشاهدات.</p></div>
    <div class="quick-card"><h3>الباقات</h3><p class="muted">إدارة حصة النشر والباقات.</p></div>
</div>
<?php $slot = ob_get_clean(); require __DIR__ . '/../partials/dashboard-shell.php'; ?>
