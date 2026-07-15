<?php
/** @var string $content */
$title = page_title((string) ($title ?? ''));
$user = auth_user();
?>
<!doctype html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="csrf-token" content="<?= e(csrf_token()) ?>">
    <meta name="app-base" content="<?= e(base_path()) ?>">
    <link href="https://fonts.googleapis.com/css2?family=Tajawal:wght@400;500;700;800;900&display=swap" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.rtl.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.2/css/all.min.css" rel="stylesheet">
    <link href="<?= e(asset_url('css/main.css')) ?>" rel="stylesheet">
    <style>
        .user-shell { display:grid; grid-template-columns:280px minmax(0,1fr); gap:1.25rem; }
        .user-sidebar .nav-link { color:#6f675a; }
        .user-sidebar .nav-link.active, .user-sidebar .nav-link:hover { background:#fff3cc; color:#1d1a13; font-weight:700; }
        @media (max-width: 992px) { .user-shell { grid-template-columns:1fr; } }
    </style>
</head>
<body class="site-body">
<?php require dirname(__DIR__) . '/partials/navbar.php'; ?>
<main class="site-main container-xl py-4">
    <div class="user-shell">
        <?php require dirname(__DIR__) . '/partials/user-sidebar.php'; ?>
        <div><?= $content ?></div>
    </div>
</main>
<?php require dirname(__DIR__) . '/partials/footer.php'; ?>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
<script src="<?= e(asset_url('js/main.js')) ?>"></script>
<?php if ($user): ?>
<script src="<?= e(asset_url('js/notifications.js')) ?>" defer></script>
<?php endif; ?>
</body>
</html>
