<?php

/** @var array<string,mixed> $data */
/** @var array<string,mixed> $section */
/** @var string $sectionKey */

$items = admin_items_from_response($data);
$tab = trim((string) ($_GET['tab'] ?? 'office'));
if (!in_array($tab, ['office', 'marketer', 'assign'], true)) {
    $tab = 'office';
}

$officePackages = array_values(array_filter($items, static function (mixed $row): bool {
    if (!is_array($row)) {
        return false;
    }
    $applies = (string) ($row['applies_to'] ?? 'both');

    return $applies === 'office' || $applies === 'both' || $applies === '';
}));
$marketerPackages = array_values(array_filter($items, static function (mixed $row): bool {
    if (!is_array($row)) {
        return false;
    }
    $applies = (string) ($row['applies_to'] ?? 'both');

    return $applies === 'marketer' || $applies === 'both' || $applies === '';
}));

$assignments = [];
if (isset($data['assignments']) && is_array($data['assignments'])) {
    foreach ($data['assignments'] as $row) {
        if (is_array($row)) {
            $assignments[] = $row;
        }
    }
}
if ($assignments === []) {
    foreach ($items as $pkg) {
        if (!is_array($pkg)) {
            continue;
        }
        foreach ((array) ($pkg['assignees'] ?? []) as $assignee) {
            if (is_array($assignee)) {
                $assignments[] = $assignee;
            }
        }
    }
}

$assignByUser = [];
foreach ($assignments as $row) {
    $uid = (string) ($row['id'] ?? '');
    if ($uid !== '') {
        $assignByUser[$uid] = $row;
    }
}

$userOptions = admin_users_options($tab === 'marketer' ? 'marketer' : 'office');
if ($tab === 'assign') {
    $userOptions = admin_users_options('office') + admin_users_options('marketer');
}
foreach ($userOptions as $uid => $label) {
    if (isset($assignByUser[$uid])) {
        $userOptions[$uid] = $label . ' — ' . admin_posting_quota_summary($assignByUser[$uid]);
    }
}

require __DIR__ . '/../partials/section-alerts.php';

$renderAssignees = static function (array $pkg): void {
    $assignees = [];
    foreach ((array) ($pkg['assignees'] ?? []) as $row) {
        if (is_array($row)) {
            $assignees[] = $row;
        }
    }
    if ($assignees === []) {
        echo '<div class="small text-secondary py-2">لم تُعيَّن هذه الباقة لأي مكتب أو مسوّق بعد.</div>';

        return;
    }
    ?>
    <div class="table-responsive">
        <table class="table table-sm align-middle mb-0">
            <thead>
                <tr>
                    <th>النوع</th>
                    <th>الاسم</th>
                    <th>الهاتف</th>
                    <th>المتبقي</th>
                    <th>نُشر</th>
                    <th>ريلز</th>
                    <th>الانتهاء</th>
                    <th>الحالة</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($assignees as $a): ?>
                    <?php
                    $unlimited = !empty($a['posting_trial_unlimited']) || !empty($a['posting_is_unlimited']);
                    $remaining = $unlimited ? 'بلا حدود' : compact_number($a['posting_listings_remaining'] ?? 0);
                    $published = (int) ($a['published_count'] ?? 0);
                    $approvedPub = (int) ($a['published_approved_count'] ?? $published);
                    $limit = $a['posting_package_limit'] ?? null;
                    $used = $a['used_count'] ?? null;
                    $pubTxt = compact_number($published);
                    if ($approvedPub !== $published) {
                        $pubTxt .= ' (معتمد ' . compact_number($approvedPub) . ')';
                    }
                    if ($limit !== null && $limit !== '' && !$unlimited) {
                        $pubTxt .= ' / ' . compact_number($limit);
                    }
                    if ($used !== null && $used !== '' && !$unlimited) {
                        $pubTxt .= ' · مستخدم ' . compact_number($used);
                    }
                    $exp = trim((string) ($a['posting_subscription_expires_at'] ?? ''));
                    $exp = $exp !== '' ? explode(' ', $exp)[0] : '—';
                    ?>
                    <tr>
                        <td><span class="badge rounded-pill <?= ($a['kind'] ?? '') === 'marketer' ? 'text-bg-info' : 'text-bg-primary' ?>"><?= e((string) ($a['kind_label'] ?? (($a['kind'] ?? '') === 'marketer' ? 'مسوق' : 'مكتب'))) ?></span></td>
                        <td>
                            <strong><?= e((string) ($a['display_name'] ?? $a['office_name'] ?? $a['full_name'] ?? '—')) ?></strong>
                            <?php if (!empty($a['full_name']) && (string) ($a['display_name'] ?? '') !== (string) $a['full_name']): ?>
                                <div class="small text-secondary"><?= e((string) $a['full_name']) ?></div>
                            <?php endif; ?>
                        </td>
                        <td dir="ltr" class="font-monospace small"><?= e((string) ($a['phone'] ?? '—')) ?></td>
                        <td><?= e((string) $remaining) ?></td>
                        <td><?= e($pubTxt) ?></td>
                        <td><?= e(compact_number($a['reels_count'] ?? 0)) ?></td>
                        <td class="small"><?= e($exp) ?></td>
                        <td>
                            <span class="badge rounded-pill <?= !empty($a['office_approved']) ? 'text-bg-success' : 'text-bg-warning' ?>"><?= !empty($a['office_approved']) ? 'معتمد' : 'معلق' ?></span>
                            <span class="badge rounded-pill <?= !isset($a['is_active']) || !empty($a['is_active']) ? 'text-bg-light border' : 'text-bg-secondary' ?>"><?= !isset($a['is_active']) || !empty($a['is_active']) ? 'نشط' : 'موقوف' ?></span>
                        </td>
                    </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
    <?php
};

?>

<div class="admin-section-head">
    <div class="admin-tabs">
        <?= admin_section_tab($sectionKey, 'باقات المكاتب', ['tab' => 'office']) ?>
        <?= admin_section_tab($sectionKey, 'باقات المسوقين', ['tab' => 'marketer']) ?>
        <?= admin_section_tab($sectionKey, 'تعيين باقة', ['tab' => 'assign']) ?>
    </div>
</div>

<?php if ($tab === 'assign'): ?>
    <div class="panel-card admin-list-panel mb-4">
        <div class="panel-head"><h2>التعيينات الحالية</h2></div>
        <?php if ($assignments === []): ?>
            <div class="text-center py-4 text-secondary">لا توجد باقات معيّنة حالياً.</div>
        <?php else: ?>
            <div class="table-responsive">
                <table class="table admin-data-table align-middle mb-0">
                    <thead>
                        <tr>
                            <th>النوع</th>
                            <th>المكتب / المسوق</th>
                            <th>الباقة</th>
                            <th>المتبقي</th>
                            <th>نُشر</th>
                            <th>ريلز</th>
                            <th>الانتهاء</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($assignments as $a): ?>
                            <?php
                            $unlimited = !empty($a['posting_trial_unlimited']) || !empty($a['posting_is_unlimited']);
                            $pkgName = trim((string) ($a['posting_package_name'] ?? ''));
                            if ($pkgName === '') {
                                continue;
                            }
                            ?>
                            <tr>
                                <td><span class="badge rounded-pill <?= ($a['kind'] ?? '') === 'marketer' ? 'text-bg-info' : 'text-bg-primary' ?>"><?= e((string) ($a['kind_label'] ?? 'مكتب')) ?></span></td>
                                <td>
                                    <strong><?= e((string) ($a['display_name'] ?? $a['office_name'] ?? $a['full_name'] ?? '—')) ?></strong>
                                    <div class="small text-secondary" dir="ltr"><?= e((string) ($a['phone'] ?? '')) ?></div>
                                </td>
                                <td><?= e($pkgName) ?></td>
                                <td><?= $unlimited ? 'بلا حدود' : e(compact_number($a['posting_listings_remaining'] ?? 0)) ?></td>
                                <td><?= e(compact_number($a['published_count'] ?? 0)) ?><?php if (!empty($a['used_count']) && !$unlimited): ?> <span class="small text-secondary">مستخدم <?= e(compact_number($a['used_count'])) ?></span><?php endif; ?></td>
                                <td><?= e(compact_number($a['reels_count'] ?? 0)) ?></td>
                                <td class="small"><?php $exp = trim((string) ($a['posting_subscription_expires_at'] ?? '')); echo e($exp !== '' ? explode(' ', $exp)[0] : '—'); ?></td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        <?php endif; ?>
    </div>
    <div class="panel-card admin-form-card mb-4">
        <h2 class="h5 mb-3">تعيين باقة لمستخدم</h2>
        <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="row g-3">
            <?= csrf_field() ?>
            <input type="hidden" name="_operation" value="assign">
            <div class="col-md-5">
                <label class="form-label">المستخدم</label>
                <?= admin_select_field('user_id', $userOptions, 'اختر المستخدم', null, true) ?>
            </div>
            <div class="col-md-4">
                <label class="form-label">الباقة</label>
                <select name="posting_package_id" class="form-select" required>
                    <option value="">— اختر الباقة —</option>
                    <?php foreach ($items as $pkg): ?>
                        <?php if (!is_array($pkg)) continue; ?>
                        <option value="<?= e((string) ($pkg['id'] ?? '')) ?>"><?= e((string) ($pkg['name'] ?? $pkg['name_ar'] ?? '')) ?> (<?= e((string) ($pkg['applies_to'] ?? '')) ?>)</option>
                    <?php endforeach; ?>
                </select>
            </div>
            <div class="col-md-2">
                <label class="form-label">الرصيد</label>
                <input type="number" name="posting_listings_remaining" class="form-control" min="0">
            </div>
            <div class="col-md-1 d-flex align-items-end">
                <button type="submit" class="btn btn-success rounded-pill w-100">تعيين</button>
            </div>
        </form>
    </div>
<?php else: ?>
    <?php $list = $tab === 'marketer' ? $marketerPackages : $officePackages; ?>
    <?php if ($list === []): ?>
        <div class="panel-card text-center py-5 text-secondary">لا توجد باقات في هذا القسم.</div>
    <?php else: ?>
        <?php foreach ($list as $pkg): ?>
            <?php
            $pid = (string) ($pkg['id'] ?? '');
            $assignees = array_values(array_filter((array) ($pkg['assignees'] ?? []), static fn (mixed $row): bool => is_array($row)));
            $count = (int) ($pkg['assignees_count'] ?? count($assignees));
            $pkgName = (string) ($pkg['name'] ?? $pkg['name_ar'] ?? '');
            $unlimited = !empty($pkg['is_unlimited']);
            $limit = $pkg['listings_limit'] ?? $pkg['listing_limit'] ?? 0;
            ?>
            <div class="panel-card admin-list-panel mb-4">
                <div class="d-flex flex-wrap justify-content-between align-items-center gap-2 mb-3">
                    <div>
                        <h2 class="h5 mb-1"><?= e($pkgName) ?></h2>
                        <div class="small text-secondary">
                            <?= $unlimited ? 'غير محدود' : e(compact_number($limit)) . ' منشور' ?>
                            · <?= e(compact_number($count)) ?> معيّن
                            · <span class="badge rounded-pill <?= !empty($pkg['is_active']) ? 'text-bg-success' : 'text-bg-secondary' ?>"><?= !empty($pkg['is_active']) ? 'فعّالة' : 'موقوفة' ?></span>
                        </div>
                    </div>
                    <div class="d-flex gap-2">
                        <button type="button" class="btn btn-outline-primary btn-sm rounded-pill" data-bs-toggle="collapse" data-bs-target="#pkg-edit-<?= e($pid) ?>">تعديل</button>
                        <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="d-inline" onsubmit="return confirm('حذف الباقة؟');">
                            <?= csrf_field() ?>
                            <input type="hidden" name="_operation" value="delete">
                            <input type="hidden" name="id" value="<?= e($pid) ?>">
                            <button type="submit" class="btn btn-outline-danger btn-sm rounded-pill">حذف</button>
                        </form>
                    </div>
                </div>
                <div class="collapse mb-3" id="pkg-edit-<?= e($pid) ?>">
                    <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="admin-form-card row g-2">
                        <?= csrf_field() ?>
                        <input type="hidden" name="_operation" value="upsert">
                        <input type="hidden" name="id" value="<?= e($pid) ?>">
                        <div class="col-md-3"><input type="text" name="name" class="form-control form-control-sm" value="<?= e($pkgName) ?>" required></div>
                        <div class="col-md-2"><input type="number" name="listings_limit" class="form-control form-control-sm" value="<?= e((string) ($pkg['listings_limit'] ?? $pkg['listing_limit'] ?? '')) ?>"></div>
                        <div class="col-md-2"><input type="number" name="is_unlimited" class="form-control form-control-sm" value="<?= $unlimited ? '1' : '0' ?>"></div>
                        <div class="col-md-2"><input type="text" name="applies_to" class="form-control form-control-sm" value="<?= e((string) ($pkg['applies_to'] ?? '')) ?>" readonly></div>
                        <div class="col-md-2"><input type="number" name="is_active" class="form-control form-control-sm" value="<?= !empty($pkg['is_active']) ? '1' : '0' ?>"></div>
                        <div class="col-md-1"><button type="submit" class="btn btn-success btn-sm rounded-pill w-100">حفظ</button></div>
                    </form>
                </div>
                <?php $renderAssignees($pkg); ?>
            </div>
        <?php endforeach; ?>
    <?php endif; ?>
<?php endif; ?>

<div class="panel-card admin-form-card">
    <h2 class="h5 mb-3">إضافة باقة جديدة</h2>
    <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="row g-3">
        <?= csrf_field() ?>
        <input type="hidden" name="_operation" value="upsert">
        <div class="col-md-3"><input type="text" name="name" class="form-control" placeholder="اسم الباقة" required></div>
        <div class="col-md-2"><input type="number" name="listings_limit" class="form-control" placeholder="الحد"></div>
        <div class="col-md-2">
            <select name="applies_to" class="form-select">
                <option value="office">مكاتب</option>
                <option value="marketer">مسوقون</option>
                <option value="both">الاثنان</option>
            </select>
        </div>
        <div class="col-md-2">
            <select name="is_unlimited" class="form-select">
                <option value="0">محدود</option>
                <option value="1">غير محدود</option>
            </select>
        </div>
        <div class="col-md-2">
            <select name="is_active" class="form-select">
                <option value="1">فعّالة</option>
                <option value="0">موقوفة</option>
            </select>
        </div>
        <div class="col-md-1 d-flex align-items-end"><button type="submit" class="btn btn-primary rounded-pill w-100">إضافة</button></div>
    </form>
</div>
