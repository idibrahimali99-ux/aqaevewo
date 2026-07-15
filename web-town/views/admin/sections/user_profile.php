<?php

/** @var array<string,mixed> $data */
/** @var array<string,mixed> $section */
/** @var string $sectionKey */

$userId = trim((string) ($_GET['id'] ?? ''));
$user = is_array($data['user'] ?? null) ? $data['user'] : (is_array($data) && isset($data['id']) ? $data : null);
$properties = admin_items_from_response(['items' => $data['properties'] ?? []]);
if ($properties === [] && isset($data['items']) && is_array($data['items'])) {
    $properties = admin_items_from_response($data);
}

require __DIR__ . '/../partials/section-alerts.php';

?>

<?php if ($userId === ''): ?>
    <div class="panel-card text-center py-5">
        <p class="text-secondary mb-3">اختر مستخدماً من <a href="<?= e(url('/admin/users')) ?>">قائمة المستخدمين</a> أو أضف <code>?id=UUID</code> في الرابط.</p>
    </div>
<?php elseif (!is_array($user)): ?>
    <div class="panel-card text-center py-5 text-secondary">تعذر تحميل ملف المستخدم.</div>
<?php else: ?>
    <?php
    $avatar = trim((string) ($user['profile_photo_url'] ?? $user['office_photo_url'] ?? ''));
    $avatar = $avatar !== '' ? $avatar : asset_url('images/placeholder-property.svg');
    $phone = (string) ($user['phone'] ?? '');
    $wa = preg_match('/^07[0-9]{9}$/', $phone) ? 'https://wa.me/964' . substr($phone, 1) : '';
    ?>
    <div class="panel-card mb-4">
        <div class="d-flex flex-wrap gap-3 align-items-center">
            <img src="<?= e($avatar) ?>" alt="" class="admin-thumb-lg">
            <div class="flex-grow-1">
                <h1 class="h4 mb-1"><?= e((string) ($user['full_name'] ?? 'مستخدم')) ?></h1>
                <?php if (!empty($user['office_name'])): ?><div class="text-secondary"><?= e((string) $user['office_name']) ?></div><?php endif; ?>
                <div class="small font-monospace text-secondary mt-1"><?= e((string) ($user['id'] ?? '')) ?></div>
            </div>
            <div class="admin-row-actions">
                <?php if ($wa !== ''): ?><a href="<?= e($wa) ?>" target="_blank" class="btn btn-success rounded-pill"><i class="fa-brands fa-whatsapp ms-1"></i> واتساب</a><?php endif; ?>
                <a href="<?= e(url('/admin/users')) ?>" class="btn btn-light rounded-pill">رجوع</a>
            </div>
        </div>
        <div class="admin-detail-grid mt-4">
            <div><span>الهاتف</span><strong dir="ltr"><?= e($phone !== '' ? $phone : '—') ?></strong></div>
            <div><span>البريد</span><strong><?= e((string) ($user['email'] ?? '—')) ?></strong></div>
            <div><span>الدور</span><strong><?= e((string) ($user['role'] ?? '')) ?></strong></div>
            <div><span>الحالة</span><strong><?= !empty($user['is_active']) ? 'نشط' : 'معطّل' ?></strong></div>
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
                            <strong><?= e((string) ($property['title'] ?? '')) ?></strong>
                            <div class="admin-property-price"><?= e(money_iqd($property['price_iqd'] ?? null)) ?></div>
                        </div>
                    </article>
                <?php endforeach; ?>
            </div>
        </div>
    <?php endif; ?>
<?php endif; ?>
