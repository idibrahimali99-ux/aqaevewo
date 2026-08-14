<?php
/** @var string $content */
$title = page_title((string) ($title ?? ''));
$description = (string) ($description ?? 'عقار تاون، منصة عقارية عراقية احترافية لعرض العقارات والمكاتب والمسوقين.');
$user = auth_user();
$isAdminConsole = str_starts_with(current_path(), '/dashboard/admin');
?>
<!doctype html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= e($title) ?></title>
    <meta name="description" content="<?= e($description) ?>">
    <meta property="og:title" content="<?= e($title) ?>">
    <meta property="og:description" content="<?= e($description) ?>">
    <meta name="theme-color" content="#F6B60C">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Tajawal:wght@400;500;700;800;900&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="<?= e(asset_url('css/app.css')) ?>">
</head>
<body class="<?= $isAdminConsole ? 'admin-console-body' : '' ?>">
<div class="site-shell <?= $isAdminConsole ? 'admin-site-shell' : '' ?>">
    <?php if (!$isAdminConsole): ?>
    <header class="topbar">
        <a class="brand" href="<?= e(url('/')) ?>" aria-label="عقار تاون">
            <span class="brand-mark">AT</span>
            <span>
                <strong>عقار تاون</strong>
                <small>AQAR TOWN</small>
            </span>
        </a>
        <nav class="main-nav" aria-label="التنقل الرئيسي">
            <a class="<?= is_active_path('/') ? 'active' : '' ?>" href="<?= e(url('/')) ?>">الرئيسية</a>
            <a class="<?= is_active_path('/properties') ? 'active' : '' ?>" href="<?= e(url('/properties')) ?>">العقارات</a>
            <a class="<?= is_active_path('/offices') ? 'active' : '' ?>" href="<?= e(url('/offices')) ?>">المكاتب</a>
        </nav>
        <div class="topbar-actions">
            <?php if ($user): ?>
                <a class="btn ghost" href="<?= e(url('/dashboard')) ?>">لوحتي</a>
                <a class="btn dark" href="<?= e(url('/logout')) ?>">خروج</a>
            <?php else: ?>
                <a class="btn ghost" href="<?= e(url('/login')) ?>">دخول</a>
                <a class="btn primary" href="<?= e(url('/register')) ?>">إنشاء حساب</a>
            <?php endif; ?>
        </div>
    </header>
    <?php endif; ?>

    <main>
        <?= $content ?>
    </main>

    <?php if (!$isAdminConsole): ?>
    <footer class="footer">
        <div>
            <strong>عقار تاون</strong>
            <p>منصة عقارية عراقية لعرض العقارات والمكاتب والمسوقين.</p>
        </div>
        <a href="tel:<?= e((string) app_config('support_phone')) ?>">الدعم: <?= e((string) app_config('support_phone')) ?></a>
        <div style="margin-top:12px;display:flex;gap:10px;flex-wrap:wrap">
            <a href="https://www.facebook.com/profile.php?id=61591583834702" target="_blank" rel="noopener noreferrer">فيسبوك</a>
            <span>·</span>
            <a href="https://www.instagram.com/aqaretown" target="_blank" rel="noopener noreferrer">إنستغرام</a>
        </div>
    </footer>
    <?php endif; ?>
</div>
<script src="<?= e(asset_url('js/app.js')) ?>"></script>
</body>
</html>
