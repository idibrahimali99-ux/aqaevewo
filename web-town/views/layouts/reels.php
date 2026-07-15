<?php

/** @var string $content */

$title = page_title((string) ($title ?? ''));

?>

<!doctype html>

<html lang="ar" dir="rtl">

<head>

    <meta charset="utf-8">

    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">

    <title><?= e($title) ?></title>

    <meta name="theme-color" content="#000000">

    <meta name="csrf-token" content="<?= e(csrf_token()) ?>">

    <meta name="app-base" content="<?= e(base_path()) ?>">

    <link href="https://fonts.googleapis.com/css2?family=Tajawal:wght@400;500;700;800;900&display=swap" rel="stylesheet">

    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.rtl.min.css" rel="stylesheet">

    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.2/css/all.min.css" rel="stylesheet">

    <link href="<?= e(asset_url('css/reels.css')) ?>" rel="stylesheet">

</head>

<body class="reels-body">

<?= $content ?>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>

<script src="<?= e(asset_url('js/reels.js')) ?>" defer></script>

</body>

</html>

