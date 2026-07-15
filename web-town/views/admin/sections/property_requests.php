<?php

/** @var array<string,mixed> $data */
/** @var array<string,mixed> $section */
/** @var string $sectionKey */

$items = admin_items_from_response($data);
$status = trim((string) ($_GET['status'] ?? ''));

require __DIR__ . '/../partials/section-alerts.php';

$statusLabels = [
    'pending' => 'قيد الانتظار',
    'in_progress' => 'قيد المتابعة',
    'closed' => 'مغلق',
];

?>

<div class="admin-section-head">
    <div class="admin-tabs">
        <?php
        $tabs = [
            'all' => 'الكل',
            'pending' => 'انتظار',
            'in_progress' => 'متابعة',
            'closed' => 'مغلق',
        ];
        $currentStatus = trim((string) ($_GET['status'] ?? 'all'));
        if ($currentStatus === '') {
            $currentStatus = 'all';
        }
        foreach ($tabs as $key => $label):
            $active = $currentStatus === $key ? ' active' : '';
            $href = $key === 'all' ? url('/admin/' . $sectionKey) : url('/admin/' . $sectionKey, ['status' => $key]);
        ?>
            <a class="admin-tab<?= $active ?>" href="<?= e($href) ?>"><?= e($label) ?></a>
        <?php endforeach; ?>
    </div>
    <form class="admin-inline-search" method="get" action="<?= e(url('/admin/' . $sectionKey)) ?>">
        <?php if ($status !== ''): ?><input type="hidden" name="status" value="<?= e($status) ?>"><?php endif; ?>
        <input type="search" name="q" value="<?= e($_GET['q'] ?? '') ?>" placeholder="بحث برقم الطلب #">
        <input type="date" name="from" value="<?= e($_GET['from'] ?? '') ?>" class="form-control form-control-sm" style="width:auto;border-radius:999px">
        <input type="date" name="to" value="<?= e($_GET['to'] ?? '') ?>" class="form-control form-control-sm" style="width:auto;border-radius:999px">
        <button type="submit" class="btn btn-primary btn-sm rounded-pill">بحث</button>
    </form>
</div>

<?php if ($items === []): ?>
    <div class="panel-card text-center py-5 text-secondary">لا توجد طلبات.</div>
<?php else: ?>
    <div class="panel-card admin-list-panel">
        <div class="table-responsive">
            <table class="table admin-data-table align-middle mb-0">
                <thead>
                    <tr>
                        <th>الطلب</th>
                        <th>الزبون</th>
                        <th>التفاصيل</th>
                        <th>الحالة</th>
                        <th>التاريخ</th>
                        <th class="text-end">تحديث</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($items as $req): ?>
                        <?php if (!is_array($req)) continue; ?>
                        <?php $rid = (string) ($req['id'] ?? ''); ?>
                        <tr>
                            <td><strong>#<?= e((string) ($req['request_no'] ?? '')) ?></strong></td>
                            <td><?= e((string) ($req['customer_name'] ?? $req['full_name'] ?? '')) ?></td>
                            <td class="small"><?= e(mb_substr((string) ($req['details_text'] ?? $req['notes'] ?? ''), 0, 80)) ?></td>
                            <td><span class="badge rounded-pill text-bg-light border"><?= e($statusLabels[(string) ($req['status'] ?? '')] ?? (string) ($req['status'] ?? '')) ?></span></td>
                            <td class="small text-secondary"><?= e((string) ($req['created_at'] ?? '')) ?></td>
                            <td class="text-end">
                                <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="d-inline-flex gap-1">
                                    <?= csrf_field() ?>
                                    <input type="hidden" name="_operation" value="status">
                                    <input type="hidden" name="id" value="<?= e($rid) ?>">
                                    <select name="status" class="form-select form-select-sm" style="width:auto" onchange="this.form.submit()">
                                        <?php foreach ($statusLabels as $key => $label): ?>
                                            <option value="<?= e($key) ?>"<?= (string) ($req['status'] ?? '') === $key ? ' selected' : '' ?>><?= e($label) ?></option>
                                        <?php endforeach; ?>
                                    </select>
                                </form>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </div>
<?php endif; ?>
