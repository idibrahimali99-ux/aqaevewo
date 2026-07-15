<?php

/** @var array<string,mixed> $data */
/** @var array<string,mixed> $section */
/** @var string $sectionKey */

$items = admin_items_from_response($data);
$scope = trim((string) ($_GET['scope'] ?? 'pending'));
if ($scope !== 'approved') {
    $scope = 'pending';
}
$sort = trim((string) ($_GET['sort'] ?? 'created_desc'));
if (!in_array($sort, ['created_desc', 'name_asc', 'name_desc', 'phone_asc'], true)) {
    $sort = 'created_desc';
}
$items = admin_sort_rows($items, $sort, 'admin_office_label');

require __DIR__ . '/../partials/section-alerts.php';

$sortOptions = [
    'created_desc' => 'الأحدث',
    'name_asc' => 'الاسم أ-ي',
    'name_desc' => 'الاسم ي-أ',
    'phone_asc' => 'الهاتف',
];
?>

<div class="admin-section-head">
    <div class="admin-tabs">
        <?= admin_section_tab($sectionKey, 'بانتظار الموافقة', ['scope' => 'pending']) ?>
        <?= admin_section_tab($sectionKey, 'معتمدون وتوثيق', ['scope' => 'approved']) ?>
    </div>
    <div class="admin-toolbar">
        <form class="admin-inline-search" method="get" action="<?= e(url('/admin/' . $sectionKey)) ?>">
            <input type="hidden" name="scope" value="<?= e($scope) ?>">
            <input type="hidden" name="sort" value="<?= e($sort) ?>">
            <input type="search" name="q" value="<?= e($_GET['q'] ?? '') ?>" placeholder="بحث بالاسم أو الهاتف أو المكتب">
            <button type="submit" class="btn btn-primary btn-sm rounded-pill">بحث</button>
        </form>
        <form method="get" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="admin-sort-form">
            <input type="hidden" name="scope" value="<?= e($scope) ?>">
            <?php if (trim((string) ($_GET['q'] ?? '')) !== ''): ?>
                <input type="hidden" name="q" value="<?= e((string) $_GET['q']) ?>">
            <?php endif; ?>
            <label class="small text-secondary mb-0">ترتيب</label>
            <?= admin_sort_select($sectionKey, $sort, $sortOptions) ?>
        </form>
    </div>
</div>

<?php if ($items === []): ?>
    <div class="panel-card text-center py-5 text-secondary">لا توجد مكاتب في هذا القسم.</div>
<?php else: ?>
    <div class="panel-card admin-list-panel">
        <div class="table-responsive">
            <table class="table admin-data-table align-middle mb-0">
                <thead>
                    <tr>
                        <th>المكتب</th>
                        <th>المالك</th>
                        <th>الهاتف</th>
                        <th>الحالة</th>
                        <th>التاريخ</th>
                        <th class="text-end">إجراءات</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($items as $office): ?>
                        <?php
                        $uid = (string) ($office['id'] ?? '');
                        $photo = trim((string) ($office['office_photo_url'] ?? $office['profile_photo_url'] ?? ''));
                        $photo = $photo !== '' ? $photo : asset_url('images/placeholder-property.svg');
                        $verified = !empty($office['office_verified']);
                        $isMarketer = !empty($office['is_marketer']);
                        $payload = htmlspecialchars(json_encode($office, JSON_UNESCAPED_UNICODE), ENT_QUOTES, 'UTF-8');
                        ?>
                        <tr data-office="<?= $payload ?>" data-scope="<?= e($scope) ?>">
                            <td>
                                <div class="admin-list-cell">
                                    <img src="<?= e($photo) ?>" alt="" class="admin-entity-avatar">
                                    <div class="min-w-0">
                                        <strong><?= e(admin_office_label($office)) ?></strong>
                                        <?php if ($isMarketer): ?><span class="badge text-bg-info ms-1">مسوق</span><?php endif; ?>
                                    </div>
                                </div>
                            </td>
                            <td><?= e((string) ($office['full_name'] ?? '—')) ?></td>
                            <td dir="ltr" class="font-monospace small"><?= e((string) ($office['phone'] ?? '—')) ?></td>
                            <td>
                                <?php if ($scope === 'pending'): ?>
                                    <span class="badge rounded-pill text-bg-warning">بانتظار الموافقة</span>
                                <?php else: ?>
                                    <span class="badge rounded-pill <?= $verified ? 'text-bg-success' : 'text-bg-secondary' ?>">
                                        <?= $verified ? 'موثّق' : 'غير موثّق' ?>
                                    </span>
                                <?php endif; ?>
                            </td>
                            <td class="small text-secondary"><?= e((string) ($office['created_at'] ?? '')) ?></td>
                            <td class="text-end">
                                <div class="admin-row-actions">
                                    <button type="button" class="btn btn-outline-primary btn-sm rounded-pill" data-office-open>معاينة</button>
                                    <?php if ($scope === 'pending'): ?>
                                        <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="d-inline">
                                            <?= csrf_field() ?>
                                            <input type="hidden" name="_operation" value="approve">
                                            <input type="hidden" name="user_id" value="<?= e($uid) ?>">
                                            <button type="submit" class="btn btn-success btn-sm rounded-pill">موافقة</button>
                                        </form>
                                    <?php else: ?>
                                        <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="d-inline">
                                            <?= csrf_field() ?>
                                            <input type="hidden" name="_operation" value="set_verified">
                                            <input type="hidden" name="user_id" value="<?= e($uid) ?>">
                                            <input type="hidden" name="verified" value="<?= $verified ? '0' : '1' ?>">
                                            <button type="submit" class="btn btn-<?= $verified ? 'outline-secondary' : 'warning' ?> btn-sm rounded-pill">
                                                <?= $verified ? 'إلغاء التوثيق' : 'توثيق' ?>
                                            </button>
                                        </form>
                                    <?php endif; ?>
                                </div>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </div>
<?php endif; ?>

<div class="modal fade" id="adminOfficeModal" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-lg modal-dialog-scrollable">
        <div class="modal-content rounded-4 border-0">
            <div class="modal-header border-0">
                <h5 class="modal-title">مراجعة بيانات المكتب</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="إغلاق"></button>
            </div>
            <div class="modal-body" id="adminOfficeModalBody"></div>
            <div class="modal-footer border-0" id="adminOfficeModalActions"></div>
        </div>
    </div>
</div>
