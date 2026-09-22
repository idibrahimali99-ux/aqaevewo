<?php

$stats = $stats ?? api_client()->get('admin/stats', [], auth_token());

?>

<header class="admin-topbar">

    <div class="d-flex align-items-center gap-3">

        <button class="btn btn-light btn-icon d-lg-none" type="button" id="sidebarOpen"><i class="fa-solid fa-bars"></i></button>

        <div>

            <div class="topbar-kicker">لوحة التحكم</div>

            <h1 class="topbar-title mb-0"><?= e((string) ($title ?? 'Admin')) ?></h1>

        </div>

    </div>

    <div class="d-flex align-items-center gap-2">

        <button class="btn btn-light btn-icon" type="button" id="themeToggle" aria-label="تبديل الوضع"><i class="fa-solid fa-moon"></i></button>
        <button class="btn btn-light rounded-pill" type="button" id="adminCommandOpen" title="بحث سريع Ctrl+K"><i class="fa-solid fa-magnifying-glass ms-1"></i> بحث</button>

        <a class="btn btn-primary rounded-pill px-4" href="<?= e(url('/admin/reports')) ?>"><i class="fa-solid fa-chart-line ms-1"></i> التقارير</a>

        <a class="btn btn-outline-danger rounded-pill px-3" href="<?= e(url('/logout')) ?>" title="تسجيل الخروج"><i class="fa-solid fa-right-from-bracket"></i></a>

    </div>

</header>
