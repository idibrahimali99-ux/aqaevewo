<?php

/** @var array<string,mixed> $data */
/** @var array<string,mixed> $section */
/** @var string $sectionKey */

$items = admin_items_from_response($data);
$roleFilter = trim((string) ($_GET['role'] ?? 'all'));
$sort = trim((string) ($_GET['sort'] ?? 'created_desc'));
if (!in_array($sort, ['created_desc', 'name_asc', 'name_desc', 'phone_asc'], true)) {
    $sort = 'created_desc';
}

$openedId = admin_text($openedProfileId ?? $_GET['profile'] ?? '');
$opened = is_array($openedProfile ?? null) ? $openedProfile : null;
$openedIdOfRow = is_array($opened) ? admin_text($opened['id'] ?? '') : '';
if ($openedId !== '' && ($openedIdOfRow === '' || strcasecmp($openedIdOfRow, $openedId) !== 0)) {
    $opened = null;
    foreach ($items as $row) {
        if (!is_array($row)) {
            continue;
        }
        if (strcasecmp(admin_text($row['id'] ?? ''), $openedId) === 0) {
            $opened = $row;
            break;
        }
    }
}

require __DIR__ . '/../partials/section-alerts.php';

if ($openedId !== ''):
    $openedProperties = is_array($openedProfileProperties ?? null) ? $openedProfileProperties : [];
    if (!is_array($opened)) {
        ?>
        <div class="panel-card text-center py-5">
            <p class="text-secondary mb-3">تعذر تحميل ملف هذا المستخدم.</p>
            <a href="<?= e(url('/admin/users')) ?>" class="btn btn-primary rounded-pill">العودة للمستخدمين</a>
        </div>
        <?php
        return;
    }
    $photo = admin_text($opened['avatar_url'] ?? '');
    if ($photo === '') {
        $photo = admin_text($opened['profile_photo_url'] ?? '');
    }
    if ($photo === '') {
        $photo = admin_text($opened['office_photo_url'] ?? '');
    }
    $avatar = admin_media_url($photo);
    $phone = admin_text($opened['phone'] ?? '');
    $role = admin_text($opened['role'] ?? '');
    $isMarketer = !empty($opened['is_marketer']);
    $roleLabel = admin_role_label($role, $isMarketer);
    $displayName = admin_text($opened['full_name'] ?? '', 'مستخدم');
    $officeName = admin_text($opened['office_name'] ?? '');
    $email = admin_text($opened['email'] ?? '');
    $wa = preg_match('/^07[0-9]{9}$/', $phone) ? 'https://wa.me/964' . substr($phone, 1) : '';
    $userActive = array_key_exists('is_active', $opened) ? admin_flag_on($opened['is_active'], true) : true;
    $placeholder = asset_url('images/placeholder-property.svg');
    ?>
    <div class="mb-3">
        <a href="<?= e(url('/admin/users')) ?>" class="btn btn-light rounded-pill"><i class="fa-solid fa-arrow-right ms-1"></i> كل المستخدمين</a>
    </div>
    <div class="panel-card mb-4">
        <div class="d-flex flex-wrap gap-3 align-items-center">
            <img src="<?= e($avatar) ?>" alt="" class="admin-thumb-lg" onerror="this.onerror=null;this.src='<?= e($placeholder) ?>';">
            <div class="flex-grow-1">
                <h1 class="h4 mb-1"><?= e($displayName) ?></h1>
                <?php if ($officeName !== ''): ?><div class="text-secondary"><?= e($officeName) ?></div><?php endif; ?>
                <div class="small font-monospace text-secondary mt-1"><?= e(admin_text($opened['id'] ?? $openedId)) ?></div>
            </div>
            <div class="admin-row-actions">
                <?php if ($wa !== ''): ?><a href="<?= e($wa) ?>" target="_blank" class="btn btn-success rounded-pill"><i class="fa-brands fa-whatsapp ms-1"></i> واتساب</a><?php endif; ?>
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
    <?php if ($openedProperties !== []): ?>
        <div class="panel-card">
            <div class="panel-head"><h2>منشورات المستخدم</h2></div>
            <div class="admin-property-grid">
                <?php foreach ($openedProperties as $property): ?>
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
    <?php
    return;
endif;

$filtered = array_values(array_filter($items, static function (mixed $row) use ($roleFilter): bool {
    if (!is_array($row)) {
        return false;
    }
    $role = (string) ($row['role'] ?? '');
    if ($roleFilter === 'all') {
        return true;
    }
    if ($roleFilter === 'marketer') {
        return $role === 'office' && !empty($row['is_marketer']);
    }
    if ($roleFilter === 'office') {
        return $role === 'office' && empty($row['is_marketer']);
    }
    if ($roleFilter === 'staff') {
        return $role === 'staff' || $role === 'admin';
    }
    return $role === $roleFilter;
}));

$filtered = admin_sort_rows($filtered, $sort, static fn (array $row): string => (string) ($row['full_name'] ?? ''));
$sortOptions = [
    'created_desc' => 'الأحدث',
    'name_asc' => 'الاسم أ-ي',
    'name_desc' => 'الاسم ي-أ',
    'phone_asc' => 'الهاتف',
];
$createTab = trim((string) ($_GET['create'] ?? ''));

?>

<div class="admin-section-head">
    <div class="admin-tabs">
        <?= admin_section_tab($sectionKey, 'الكل', ['role' => 'all']) ?>
        <?= admin_section_tab($sectionKey, 'أشخاص', ['role' => 'customer']) ?>
        <?= admin_section_tab($sectionKey, 'مكاتب', ['role' => 'office']) ?>
        <?= admin_section_tab($sectionKey, 'مسوقون', ['role' => 'marketer']) ?>
        <?= admin_section_tab($sectionKey, 'لوحة التحكم', ['role' => 'staff']) ?>
    </div>
    <div class="admin-toolbar">
        <form class="admin-inline-search" method="get" action="<?= e(url('/admin/' . $sectionKey)) ?>">
            <?php if ($roleFilter !== 'all'): ?><input type="hidden" name="role" value="<?= e($roleFilter) ?>"><?php endif; ?>
            <input type="hidden" name="sort" value="<?= e($sort) ?>">
            <input type="search" name="q" value="<?= e($_GET['q'] ?? '') ?>" placeholder="بحث بالاسم أو الهاتف">
            <button type="submit" class="btn btn-primary btn-sm rounded-pill">بحث</button>
        </form>
        <form method="get" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="admin-sort-form">
            <?php if ($roleFilter !== 'all'): ?><input type="hidden" name="role" value="<?= e($roleFilter) ?>"><?php endif; ?>
            <?php if (trim((string) ($_GET['q'] ?? '')) !== ''): ?><input type="hidden" name="q" value="<?= e((string) $_GET['q']) ?>"><?php endif; ?>
            <label class="small text-secondary mb-0">ترتيب</label>
            <?= admin_sort_select($sectionKey, $sort, $sortOptions) ?>
        </form>
    </div>
</div>

<?php if ($filtered === []): ?>
    <div class="panel-card text-center py-5 text-secondary">لا يوجد مستخدمون مطابقون.</div>
<?php else: ?>
    <div class="panel-card admin-list-panel mb-4">
        <div class="table-responsive">
            <table class="table admin-data-table align-middle mb-0">
                <thead>
                    <tr>
                        <th>المستخدم</th>
                        <th>الهاتف</th>
                        <th>الدور</th>
                        <th>الحالة</th>
                        <th class="text-end">إجراءات</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($filtered as $userRow): ?>
                        <?php
                        $uid = (string) ($userRow['id'] ?? '');
                        $role = (string) ($userRow['role'] ?? '');
                        $isMarketer = !empty($userRow['is_marketer']);
                        $active = !array_key_exists('is_active', $userRow) || admin_flag_on($userRow['is_active'], true);
                        $photo = admin_text($userRow['profile_photo_url'] ?? '');
                        if ($photo === '') {
                            $photo = admin_text($userRow['office_photo_url'] ?? '');
                        }
                        $avatar = admin_media_url($photo);
                        $phone = (string) ($userRow['phone'] ?? '');
                        $roleLabel = admin_role_label($role, $isMarketer);
                        $wa = preg_match('/^07[0-9]{9}$/', $phone) ? 'https://wa.me/964' . substr($phone, 1) : '';
                        $profileHref = admin_user_profile_url($uid);
                        ?>
                        <tr>
                            <td>
                                <div class="admin-list-cell">
                                    <a href="<?= e($profileHref) ?>" class="admin-entity-avatar-link">
                                        <img src="<?= e($avatar) ?>" alt="" class="admin-entity-avatar" onerror="this.onerror=null;this.src='<?= e(asset_url('images/placeholder-property.svg')) ?>';">
                                    </a>
                                    <div class="min-w-0">
                                        <a href="<?= e($profileHref) ?>" class="text-reset text-decoration-none"><strong><?= e((string) ($userRow['full_name'] ?? 'مستخدم')) ?></strong></a>
                                        <?php if (!empty($userRow['office_name'])): ?>
                                            <div class="small text-secondary"><?= e((string) $userRow['office_name']) ?></div>
                                        <?php endif; ?>
                                    </div>
                                </div>
                            </td>
                            <td dir="ltr" class="font-monospace small"><?= e($phone !== '' ? $phone : '—') ?></td>
                            <td><span class="badge rounded-pill text-bg-light border"><?= e($roleLabel) ?></span></td>
                            <td><span class="badge rounded-pill <?= $active ? 'text-bg-success' : 'text-bg-secondary' ?>"><?= $active ? 'نشط' : 'معطّل' ?></span></td>
                            <td class="text-end">
                                <div class="admin-row-actions">
                                    <a href="<?= e($profileHref) ?>" class="btn btn-outline-primary btn-sm rounded-pill">الملف</a>
                                    <?php if ($wa !== ''): ?>
                                        <a href="<?= e($wa) ?>" target="_blank" rel="noopener" class="btn btn-success btn-sm rounded-pill"><i class="fa-brands fa-whatsapp"></i></a>
                                    <?php endif; ?>
                                    <button type="button" class="btn btn-light btn-sm rounded-pill" data-bs-toggle="collapse" data-bs-target="#pwd-<?= e($uid) ?>">كلمة المرور</button>
                                    <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="d-inline">
                                        <?= csrf_field() ?>
                                        <input type="hidden" name="_operation" value="active">
                                        <input type="hidden" name="user_id" value="<?= e($uid) ?>">
                                        <input type="hidden" name="is_active" value="<?= $active ? '0' : '1' ?>">
                                        <button type="submit" class="btn btn-<?= $active ? 'outline-danger' : 'success' ?> btn-sm rounded-pill"><?= $active ? 'تعطيل' : 'تفعيل' ?></button>
                                    </form>
                                </div>
                                <div class="collapse mt-2 text-end" id="pwd-<?= e($uid) ?>">
                                    <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="admin-form-card d-inline-block text-start" style="min-width:260px">
                                        <?= csrf_field() ?>
                                        <input type="hidden" name="_operation" value="reset_password">
                                        <input type="hidden" name="user_id" value="<?= e($uid) ?>">
                                        <label class="small">كلمة مرور جديدة</label>
                                        <input type="password" name="password" class="form-control form-control-sm mb-2" required minlength="4">
                                        <button type="submit" class="btn btn-primary btn-sm rounded-pill">حفظ</button>
                                    </form>
                                </div>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </div>
<?php endif; ?>

<div class="panel-card">
    <div class="panel-head"><h2>إضافة مستخدم</h2></div>
    <div class="admin-tabs mb-3">
        <?php foreach (['customer' => 'زبون', 'office' => 'مكتب', 'marketer' => 'مسوق', 'staff' => 'موظف', 'admin' => 'مسؤول رئيسي'] as $key => $label): ?>
            <a class="admin-tab<?= ($createTab === $key || ($createTab === '' && $key === 'customer')) ? ' active' : '' ?>" href="<?= e(url('/admin/' . $sectionKey, array_filter(['role' => $roleFilter !== 'all' ? $roleFilter : null, 'create' => $key]))) ?>"><?= e($label) ?></a>
        <?php endforeach; ?>
    </div>
    <?php
    $activeCreate = $createTab !== '' ? $createTab : 'customer';
    $op = match ($activeCreate) {
        'office', 'marketer' => 'create_office',
        'staff' => 'create_staff',
        'admin' => 'create_admin',
        default => 'create_customer',
    };
    ?>
    <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="row g-3">
        <?= csrf_field() ?>
        <input type="hidden" name="_operation" value="<?= e($op) ?>">
        <?php if ($activeCreate === 'marketer'): ?>
            <input type="hidden" name="is_marketer" value="1">
        <?php endif; ?>
        <div class="col-md-3">
            <label class="form-label small">الاسم الكامل</label>
            <input type="text" name="full_name" class="form-control" required>
        </div>
        <div class="col-md-2">
            <label class="form-label small">الهاتف</label>
            <input type="text" name="phone" class="form-control" placeholder="07XXXXXXXXX" required>
        </div>
        <div class="col-md-3">
            <label class="form-label small">البريد (اختياري)</label>
            <input type="email" name="email" class="form-control">
        </div>
        <?php if ($activeCreate !== 'customer' && $activeCreate !== 'staff' && $activeCreate !== 'admin'): ?>
            <div class="col-md-2">
                <label class="form-label small">اسم المكتب</label>
                <input type="text" name="office_name" class="form-control" required>
            </div>
        <?php endif; ?>
        <div class="col-md-2">
            <label class="form-label small">كلمة المرور</label>
            <input type="password" name="password" class="form-control" required minlength="<?= $activeCreate === 'admin' ? '8' : '4' ?>">
        </div>
        <?php if ($activeCreate === 'staff'): ?>
            <div class="col-12">
                <label class="form-label small d-block">صلاحيات الموظف</label>
                <div class="admin-perm-grid">
                    <?php foreach (admin_staff_permission_labels() as $perm => $permLabel): ?>
                        <label class="form-check">
                            <input class="form-check-input" type="checkbox" name="permissions[]" value="<?= e($perm) ?>"<?= $perm !== 'unsold' ? ' checked' : '' ?>>
                            <span><?= e($permLabel) ?></span>
                        </label>
                    <?php endforeach; ?>
                </div>
            </div>
        <?php endif; ?>
        <div class="col-12">
            <button type="submit" class="btn btn-primary rounded-pill px-4">إنشاء <?= e(match ($activeCreate) {
                'office' => 'مكتب',
                'marketer' => 'مسوق',
                'staff' => 'موظف',
                'admin' => 'مسؤول رئيسي',
                default => 'زبون',
            }) ?></button>
        </div>
    </form>
</div>
