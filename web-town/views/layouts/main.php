<?php
/** @var string $content */
$title = page_title((string) ($title ?? ''));
$description = (string) ($description ?? 'عقار تاون — منصة عقارية عراقية احترافية');
$user = auth_user();
?>
<!doctype html>
<html lang="ar" dir="rtl" data-bs-theme="light">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= e($title) ?></title>
    <meta name="description" content="<?= e($description) ?>">
    <meta name="theme-color" content="#F5B400">
    <meta name="csrf-token" content="<?= e(csrf_token()) ?>">
    <meta name="app-base" content="<?= e(base_path()) ?>">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Tajawal:wght@400;500;700;800;900&display=swap" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.rtl.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.2/css/all.min.css" rel="stylesheet">
    <link href="<?= e(asset_url('css/main.css')) ?>" rel="stylesheet">
</head>
<body class="site-body"<?= $user ? ' data-logged-in="1"' : '' ?>>
<?php require dirname(__DIR__) . '/partials/navbar.php'; ?>
<main class="site-main">
    <?= $content ?>
</main>
<?php require dirname(__DIR__) . '/partials/footer.php'; ?>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
<script src="<?= e(asset_url('js/main.js')) ?>"></script>
<?php if ($user): ?>
<script src="<?= e(asset_url('js/notifications.js')) ?>" defer></script>
<?php endif; ?>
</body>
</html>
