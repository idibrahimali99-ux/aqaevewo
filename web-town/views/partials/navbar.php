<?php $user = auth_user(); ?>

<nav class="navbar navbar-expand-lg site-navbar sticky-top">
    <div class="container-xl">
        <a class="navbar-brand brand-lockup" href="<?= e(url('/')) ?>">
            <span class="brand-icon"><i class="fa-solid fa-building"></i></span>
            <span><strong>عقار تاون</strong><small>Aqar Town</small></span>
        </a>
        <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#siteNav"><span class="navbar-toggler-icon"></span></button>
        <div class="collapse navbar-collapse" id="siteNav">
            <ul class="navbar-nav me-auto mb-2 mb-lg-0">
                <li class="nav-item"><a class="nav-link" href="<?= e(url('/')) ?>">الرئيسية</a></li>
                <li class="nav-item"><a class="nav-link" href="<?= e(url('/properties')) ?>">العقارات</a></li>
                <li class="nav-item"><a class="nav-link" href="<?= e(url('/search')) ?>">البحث</a></li>
                <li class="nav-item"><a class="nav-link" href="<?= e(url('/map')) ?>">الخريطة</a></li>
                <li class="nav-item"><a class="nav-link" href="<?= e(url('/reels')) ?>">ريلز</a></li>
                <li class="nav-item"><a class="nav-link" href="<?= e(url('/offices')) ?>">المكاتب</a></li>
            </ul>
            <div class="d-flex gap-2 align-items-center">
                <?php if ($user): ?>
                    <?php if (in_array(account_kind($user), ['office', 'marketer'], true)): ?>
                        <a class="btn btn-primary btn-sm rounded-pill d-none d-md-inline-flex" href="<?= e(url('/property/add')) ?>"><i class="fa-solid fa-plus ms-1"></i> إضافة عقار</a>
                    <?php endif; ?>
                    <a class="btn btn-link text-dark position-relative nav-icon-btn" href="<?= e(url('/messages')) ?>" title="الرسائل"><i class="fa-solid fa-comments"></i></a>
                    <a class="btn btn-link text-dark" href="<?= e(url('/favorites')) ?>" title="المفضلة"><i class="fa-solid fa-heart"></i></a>
                    <?php require __DIR__ . '/notification-bell.php'; ?>
                    <div class="dropdown">
                        <button class="btn btn-outline-dark rounded-pill px-3 dropdown-toggle" type="button" data-bs-toggle="dropdown" aria-expanded="false">
                            <?= e((string) ($user['full_name'] ?? 'حسابي')) ?>
                        </button>
                        <ul class="dropdown-menu dropdown-menu-end">
                            <li><span class="dropdown-item-text small text-secondary"><?= e(account_kind_label($user)) ?></span></li>
                            <li><hr class="dropdown-divider"></li>
                            <li><a class="dropdown-item" href="<?= e(url(dashboard_path($user))) ?>"><i class="fa-solid fa-gauge ms-2"></i> لوحتي</a></li>
                            <li><a class="dropdown-item" href="<?= e(url('/profile')) ?>"><i class="fa-solid fa-user ms-2"></i> الملف الشخصي</a></li>
                            <?php if (in_array(account_kind($user), ['office', 'marketer'], true)): ?>
                                <li><a class="dropdown-item" href="<?= e(url('/property/add')) ?>"><i class="fa-solid fa-plus ms-2"></i> إضافة عقار</a></li>
                            <?php endif; ?>
                            <li><a class="dropdown-item" href="<?= e(url('/request-property')) ?>"><i class="fa-solid fa-clipboard-list ms-2"></i> طلب عقار</a></li>
                            <?php if (is_admin_area_user($user)): ?>
                                <li><a class="dropdown-item" href="<?= e(url('/admin')) ?>"><i class="fa-solid fa-shield-halved ms-2"></i> لوحة الإدارة</a></li>
                            <?php endif; ?>
                            <li><hr class="dropdown-divider"></li>
                            <li><a class="dropdown-item text-danger" href="<?= e(url('/logout')) ?>"><i class="fa-solid fa-right-from-bracket ms-2"></i> تسجيل الخروج</a></li>
                        </ul>
                    </div>
                <?php else: ?>
                    <a class="btn btn-outline-dark rounded-pill px-3" href="<?= e(url('/login')) ?>">دخول</a>
                    <a class="btn btn-primary rounded-pill px-3" href="<?= e(url('/register')) ?>">حساب جديد</a>
                <?php endif; ?>
            </div>
        </div>
    </div>
</nav>
