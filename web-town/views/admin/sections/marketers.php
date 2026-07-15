<?php

/** @var array<string,mixed> $data */
/** @var array<string,mixed> $section */
/** @var string $sectionKey */

$items = admin_items_from_response($data);
$packagesData = admin_section_data('posting_packages');
$packages = admin_items_from_response($packagesData);

require __DIR__ . '/../partials/section-alerts.php';

?>

<?php if ($items === []): ?>
    <div class="panel-card text-center py-5 text-secondary">لا يوجد مسوقون.</div>
<?php else: ?>
    <div class="panel-card admin-list-panel mb-4">
        <div class="panel-head"><h2>المسوقون</h2></div>
        <div class="table-responsive">
            <table class="table admin-data-table align-middle mb-0">
                <thead>
                    <tr>
                        <th>المسوق</th>
                        <th>الهاتف</th>
                        <th>الباقة / الرصيد</th>
                        <th>المتابعون</th>
                        <th>الحالة</th>
                        <th class="text-end">إجراءات</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($items as $row): ?>
                        <?php if (!is_array($row)) continue; ?>
                        <?php
                        $uid = (string) ($row['id'] ?? '');
                        $active = !isset($row['is_active']) || !empty($row['is_active']);
                        $approved = !empty($row['office_approved']);
                        ?>
                        <tr>
                            <td>
                                <strong><?= e((string) ($row['full_name'] ?? '')) ?></strong>
                                <div class="small text-secondary"><?= e((string) ($row['office_name'] ?? '')) ?></div>
                            </td>
                            <td dir="ltr" class="font-monospace small"><?= e((string) ($row['phone'] ?? '—')) ?></td>
                            <td>
                                <?= e((string) ($row['posting_package_name'] ?? '—')) ?>
                                <div class="small text-secondary">
                                    <?= !empty($row['posting_is_unlimited']) ? 'غير محدود' : e(compact_number($row['posting_listings_remaining'] ?? 0)) . ' متبقي' ?>
                                </div>
                            </td>
                            <td><?= e(compact_number($row['followers_count'] ?? $row['follower_count'] ?? 0)) ?></td>
                            <td>
                                <span class="badge rounded-pill <?= $approved ? 'text-bg-success' : 'text-bg-warning' ?>"><?= $approved ? 'معتمد' : 'معلق' ?></span>
                                <span class="badge rounded-pill <?= $active ? 'text-bg-light border' : 'text-bg-secondary' ?>"><?= $active ? 'نشط' : 'موقوف' ?></span>
                            </td>
                            <td class="text-end">
                                <a href="<?= e(url('/admin/user_profile', ['id' => $uid])) ?>" class="btn btn-light btn-sm rounded-pill">الملف</a>
                                <button type="button" class="btn btn-outline-primary btn-sm rounded-pill" data-bs-toggle="collapse" data-bs-target="#pkg-<?= e($uid) ?>">تعديل باقة</button>
                            </td>
                        </tr>
                        <tr class="collapse" id="pkg-<?= e($uid) ?>">
                            <td colspan="6">
                                <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="admin-form-card row g-2">
                                    <?= csrf_field() ?>
                                    <input type="hidden" name="_operation" value="assign_package">
                                    <input type="hidden" name="user_id" value="<?= e($uid) ?>">
                                    <div class="col-md-4">
                                        <label class="form-label small">الباقة</label>
                                        <select name="posting_package_id" class="form-select form-select-sm">
                                            <option value="">— اختر —</option>
                                            <?php foreach ($packages as $pkg): ?>
                                                <?php if (!is_array($pkg)) continue; ?>
                                                <option value="<?= e((string) ($pkg['id'] ?? '')) ?>"><?= e((string) ($pkg['name'] ?? '')) ?></option>
                                            <?php endforeach; ?>
                                        </select>
                                    </div>
                                    <div class="col-md-3">
                                        <label class="form-label small">الرصيد المتبقي</label>
                                        <input type="number" name="posting_listings_remaining" class="form-control form-control-sm" min="0">
                                    </div>
                                    <div class="col-md-3 d-flex align-items-end">
                                        <button type="submit" class="btn btn-success btn-sm rounded-pill">حفظ</button>
                                    </div>
                                </form>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </div>
<?php endif; ?>
