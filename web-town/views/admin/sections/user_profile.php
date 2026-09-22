<?php

/** @var array<string,mixed> $data */
/** @var array<string,mixed> $section */
/** @var string $sectionKey */

$userId = admin_text($_GET['id'] ?? $_GET['user_id'] ?? '');
$profile = is_array($data['user'] ?? null) ? $data['user'] : null;
if (is_array($profile) && $userId !== '') {
    $profileId = admin_text($profile['id'] ?? '');
    if ($profileId !== '' && strcasecmp($profileId, $userId) !== 0) {
        $profile = null;
    }
}
if (is_array($profile) && $userId === '') {
    $userId = admin_text($profile['id'] ?? '');
}

$properties = admin_items_from_response(['items' => $data['properties'] ?? []]);
if ($properties === [] && isset($data['items']) && is_array($data['items'])) {
    $properties = admin_items_from_response($data);
}

require __DIR__ . '/../partials/section-alerts.php';

?>

<?php if ($userId === ''): ?>
    <div class="panel-card text-center py-5">
        <p class="text-secondary mb-3">اختر مستخدماً من <a href="<?= e(url('/admin/users')) ?>">قائمة المستخدمين</a>.</p>
    </div>
<?php elseif (!is_array($profile)): ?>
    <div class="panel-card text-center py-5">
        <p class="text-secondary mb-3">تعذر تحميل ملف هذا المستخدم.</p>
        <a href="<?= e(url('/admin/users')) ?>" class="btn btn-primary rounded-pill">العودة للمستخدمين</a>
    </div>
<?php else: ?>
    <?php
    $photo = admin_text($profile['avatar_url'] ?? '');
    if ($photo === '') {
        $photo = admin_text($profile['profile_photo_url'] ?? '');
    }
    if ($photo === '') {
        $photo = admin_text($profile['office_photo_url'] ?? '');
    }
    $avatar = admin_media_url($photo);
    $phone = admin_text($profile['phone'] ?? '');
    $role = admin_text($profile['role'] ?? '');
    $isMarketer = !empty($profile['is_marketer']);
    $roleLabel = admin_role_label($role, $isMarketer);
    $displayName = admin_text($profile['full_name'] ?? '', 'مستخدم');
    $officeName = admin_text($profile['office_name'] ?? '');
    $email = admin_text($profile['email'] ?? '');
    $wa = preg_match('/^07[0-9]{9}$/', $phone) ? 'https://wa.me/964' . substr($phone, 1) : '';
    $userActive = array_key_exists('is_active', $profile) ? admin_flag_on($profile['is_active'], true) : true;
    $placeholder = asset_url('images/placeholder-property.svg');
    ?>
    <div class="panel-card mb-4">
        <div class="d-flex flex-wrap gap-3 align-items-center">
            <img src="<?= e($avatar) ?>" alt="" class="admin-thumb-lg" onerror="this.onerror=null;this.src='<?= e($placeholder) ?>';">
            <div class="flex-grow-1">
                <h1 class="h4 mb-1"><?= e($displayName) ?></h1>
                <?php if ($officeName !== ''): ?><div class="text-secondary"><?= e($officeName) ?></div><?php endif; ?>
                <div class="small font-monospace text-secondary mt-1"><?= e(admin_text($profile['id'] ?? $userId)) ?></div>
            </div>
            <div class="admin-row-actions">
                <?php if ($wa !== ''): ?><a href="<?= e($wa) ?>" target="_blank" class="btn btn-success rounded-pill"><i class="fa-brands fa-whatsapp ms-1"></i> واتساب</a><?php endif; ?>
                <a href="<?= e(url('/admin/users')) ?>" class="btn btn-light rounded-pill">رجوع</a>
            </div>
        </div>
        <div class="admin-detail-grid mt-4">
            <div><span>الهاتف</span><strong dir="ltr"><?= e($phone !== '' ? $phone : '—') ?></strong></div>
            <div><span>البريد</span><strong><?= e($email !== '' ? $email : '—') ?></strong></div>
            <div><span>الدور</span><strong><?= e($roleLabel) ?></strong></div>
            <div>
                <span>الحالة</span>
                <strong>
                    <span class="badge rounded-pill <?= $userActive ? 'text-bg-success' : 'text-bg-secondary' ?>">
                        <?= $userActive ? 'نشط' : 'معطّل' ?>
                    </span>
                </strong>
            </div>
        </div>
    </div>

    <?php if ($properties !== []): ?>
        <div class="panel-card">
            <div class="panel-head"><h2>منشورات المستخدم</h2></div>
            <div class="admin-property-grid">
                <?php foreach ($properties as $property): ?>
                    <?php if (!is_array($property)) continue; ?>
                    <article class="admin-property-card">
                        <div class="admin-property-media">
                            <img src="<?= e(first_image($property)) ?>" alt="">
                        </div>
                        <div class="admin-property-body">
                            <strong><?= e(admin_text($property['title'] ?? '')) ?></strong>
                            <div class="admin-property-price"><?= e(money_iqd($property['price_iqd'] ?? null)) ?></div>
                        </div>
                    </article>
                <?php endforeach; ?>
            </div>
        </div>
    <?php endif; ?>
<?php endif; ?>
