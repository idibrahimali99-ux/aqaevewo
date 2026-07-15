<?php
/** @var string $content */
$title = page_title((string) ($title ?? ''));
$user = auth_user();
if (!isset($stats) || !is_array($stats)) {
    $stats = admin_fetch_stats();
}
if (!isset($apiMeta) || !is_array($apiMeta)) {
    $apiMeta = [
        'entry' => (string) app_config('api_entry'),
        'token_type' => auth_token_type(),
        'stats_ok' => !empty($stats['ok']),
        'stats_error' => (string) ($stats['error'] ?? ''),
    ];
}
?>
<!doctype html>
<html lang="ar" dir="rtl" data-bs-theme="light">
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
    <link href="https://cdn.datatables.net/1.13.8/css/dataTables.bootstrap5.min.css" rel="stylesheet">
    <link href="<?= e(asset_url('css/admin.css')) ?>" rel="stylesheet">
    <link href="<?= e(asset_url('css/admin-sections.css')) ?>" rel="stylesheet">
    <link href="<?= e(asset_url('css/chat.css')) ?>" rel="stylesheet">
</head>
<body class="admin-body" data-user-id="<?= e((string) ($user['id'] ?? '')) ?>" data-user-role="<?= e((string) ($user['role'] ?? '')) ?>" data-admin-section-url="<?= e(url('/admin/' . ($currentSection ?? ''))) ?>">
<div class="admin-app" id="adminApp">
    <?php require dirname(__DIR__) . '/partials/admin-sidebar.php'; ?>
    <div class="admin-main-wrap">
        <?php require dirname(__DIR__) . '/partials/admin-topbar.php'; ?>
        <main class="admin-content">
            <?php require dirname(__DIR__) . '/partials/admin-api-alert.php'; ?>
            <?= $content ?>
        </main>
    </div>
    <?php require dirname(__DIR__) . '/partials/admin-notifications.php'; ?>
</div>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/apexcharts@3.49.1/dist/apexcharts.min.js"></script>
<script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
<script src="https://cdn.datatables.net/1.13.8/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/1.13.8/js/dataTables.bootstrap5.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/dropzone/5.9.3/min/dropzone.min.js"></script>
<script src="<?= e(asset_url('js/admin.js')) ?>"></script>
<script src="<?= e(asset_url('js/main.js')) ?>"></script>
<?php $sectionJs = (string) ($currentSection ?? ''); ?>
<?php if ($sectionJs === 'properties'): ?>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<script src="<?= e(asset_url('js/admin-properties.js')) ?>" defer></script>
<?php elseif ($sectionJs === 'offices'): ?>
<script src="<?= e(asset_url('js/admin-offices.js')) ?>" defer></script>
<?php elseif ($sectionJs === 'reels'): ?>
<script src="<?= e(asset_url('js/admin-reels.js')) ?>" defer></script>
<?php endif; ?>
<script src="<?= e(asset_url('js/chat.js')) ?>" defer></script>
</body>
</html>
