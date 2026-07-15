<?php $user = auth_user(); ?>

<aside class="user-sidebar panel-card p-3 d-flex flex-column">

    <div class="mb-3">

        <strong><?= e((string) ($user['full_name'] ?? '')) ?></strong>

        <div class="text-secondary small"><?= e(account_kind_label($user)) ?></div>

    </div>

    <nav class="nav flex-column gap-1 flex-grow-1">

        <a class="nav-link rounded-3 <?= in_array(current_path(), [dashboard_path($user), '/user', '/user/office', '/user/marketer'], true) ? 'active' : '' ?>" href="<?= e(url(dashboard_path($user))) ?>"><i class="fa-solid fa-gauge ms-2"></i> لوحتي</a>

        <a class="nav-link rounded-3 <?= is_active_path('/profile') ? 'active' : '' ?>" href="<?= e(url('/profile')) ?>"><i class="fa-solid fa-user ms-2"></i> الملف الشخصي</a>

        <a class="nav-link rounded-3 <?= is_active_path('/favorites') ? 'active' : '' ?>" href="<?= e(url('/favorites')) ?>"><i class="fa-solid fa-heart ms-2"></i> المفضلة</a>

        <a class="nav-link rounded-3 <?= is_active_path('/messages') ? 'active' : '' ?>" href="<?= e(url('/messages')) ?>"><i class="fa-solid fa-comments ms-2"></i> الرسائل</a>

        <a class="nav-link rounded-3 <?= is_active_path('/request-property') ? 'active' : '' ?>" href="<?= e(url('/request-property')) ?>"><i class="fa-solid fa-clipboard-list ms-2"></i> طلب عقار</a>

        <a class="nav-link rounded-3 <?= is_active_path('/notifications') ? 'active' : '' ?>" href="<?= e(url('/notifications')) ?>"><i class="fa-solid fa-bell ms-2"></i> الإشعارات</a>

        <?php if (in_array(account_kind($user), ['office', 'marketer'], true)): ?>

            <a class="nav-link rounded-3 <?= is_active_path('/property/add') ? 'active' : '' ?>" href="<?= e(url('/property/add')) ?>"><i class="fa-solid fa-plus ms-2"></i> إضافة إعلان</a>

        <?php endif; ?>

        <?php if (is_admin_area_user($user)): ?>

            <a class="nav-link rounded-3 <?= str_starts_with(current_path(), '/admin') ? 'active' : '' ?>" href="<?= e(url('/admin')) ?>"><i class="fa-solid fa-shield-halved ms-2"></i> لوحة الإدارة</a>

        <?php endif; ?>

    </nav>

    <a class="btn btn-outline-danger rounded-pill mt-3" href="<?= e(url('/logout')) ?>"><i class="fa-solid fa-right-from-bracket ms-1"></i> تسجيل الخروج</a>

</aside>

