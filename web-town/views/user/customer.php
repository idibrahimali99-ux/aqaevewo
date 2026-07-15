<div class="panel-card p-4 mb-3">
    <h1 class="h3">لوحة الزبون</h1>
    <p class="text-secondary mb-0">مرحباً <?= e((string) ($user['full_name'] ?? '')) ?></p>
</div>
<div class="row g-3 mb-4">
    <div class="col-md-4"><a class="stat-card d-block text-decoration-none" href="<?= e(url('/favorites')) ?>"><div class="stat-icon"><i class="fa-solid fa-heart"></i></div><div><strong><?= e((string) count(favorite_ids())) ?></strong><span>مفضلة</span></div></a></div>
    <div class="col-md-4"><a class="stat-card d-block text-decoration-none" href="<?= e(url('/messages')) ?>"><div class="stat-icon"><i class="fa-solid fa-comments"></i></div><div><strong>—</strong><span>محادثات</span></div></a></div>
    <div class="col-md-4"><a class="stat-card d-block text-decoration-none" href="<?= e(url('/properties')) ?>"><div class="stat-icon"><i class="fa-solid fa-magnifying-glass"></i></div><div><strong>بحث</strong><span>عقارات</span></div></a></div>
</div>
<div class="row g-3">
    <div class="col-md-4"><a class="shortcut-card" href="<?= e(url('/search')) ?>"><strong>البحث المتقدم</strong><span>فلترة حسب المحافظة والغرض</span></a></div>
    <div class="col-md-4"><a class="shortcut-card" href="<?= e(url('/offices')) ?>"><strong>المكاتب</strong><span>تواصل مع مكاتب معتمدة</span></a></div>
    <div class="col-md-4"><a class="shortcut-card" href="<?= e(url('/profile')) ?>"><strong>الملف الشخصي</strong><span>إدارة بياناتك</span></a></div>
</div>
