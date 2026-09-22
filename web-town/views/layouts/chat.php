<?php
/** @var string $content */
$title = page_title((string) ($title ?? ''));
$activeThread = (string) ($activeThread ?? '');
$user = auth_user();
?>
<!doctype html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= e($title) ?></title>
    <meta name="theme-color" content="#F5B400">
    <meta name="csrf-token" content="<?= e(csrf_token()) ?>">
    <meta name="app-base" content="<?= e(base_path()) ?>">
    <link href="https://fonts.googleapis.com/css2?family=Tajawal:wght@400;500;700;800;900&display=swap" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.rtl.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.2/css/all.min.css" rel="stylesheet">
    <link href="<?= e(asset_url('css/main.css')) ?>" rel="stylesheet">
    <link href="<?= e(asset_url('css/chat.css')) ?>" rel="stylesheet">
</head>
<body class="site-body chat-body" data-user-id="<?= e((string) ($user['id'] ?? '')) ?>" data-user-role="<?= e((string) ($user['role'] ?? '')) ?>">
<?php if (is_logged_in()): ?>
<header class="chat-topbar">
    <a href="<?= e(url('/')) ?>" class="btn btn-light btn-sm rounded-circle" title="الرئيسية"><i class="fa-solid fa-house"></i></a>
    <strong>الرسائل</strong>
    <div class="d-flex align-items-center gap-1">
        <a class="btn btn-light btn-sm rounded-circle" href="<?= e(url('/notifications')) ?>" title="الإشعارات"><i class="fa-solid fa-bell"></i></a>
        <a class="btn btn-light btn-sm rounded-circle" href="<?= e(url('/profile')) ?>" title="الملف"><i class="fa-solid fa-user"></i></a>
        <a href="<?= e(url('/logout')) ?>" class="btn btn-outline-danger btn-sm rounded-pill">خروج</a>
    </div>
</header>
<?php endif; ?>
<?= $content ?>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
<script src="<?= e(asset_url('js/chat.js')) ?>" defer></script>
<?php if ($user): ?>
<script src="<?= e(asset_url('js/notifications.js')) ?>" defer></script>
<?php endif; ?>
</body>
</html>
