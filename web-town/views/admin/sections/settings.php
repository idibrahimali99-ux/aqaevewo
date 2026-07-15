<?php

/** @var array<string,mixed> $data */
/** @var array<string,mixed> $section */
/** @var string $sectionKey */

$health = is_array($data) ? $data : [];

require __DIR__ . '/../partials/section-alerts.php';

?>

<div class="row g-4 mb-4">
    <div class="col-lg-6">
        <div class="panel-card h-100">
            <div class="panel-head"><h2>حالة API</h2></div>
            <?php if (!empty($health['ok'])): ?>
                <div class="alert alert-success rounded-4 border-0 mb-0"><i class="fa-solid fa-circle-check ms-1"></i> الخدمة تعمل بشكل طبيعي</div>
            <?php else: ?>
                <div class="alert alert-danger rounded-4 border-0 mb-0"><?= e((string) ($health['error'] ?? 'تعذر الاتصال')) ?></div>
            <?php endif; ?>
        </div>
    </div>
    <div class="col-lg-6">
        <div class="panel-card admin-form-card h-100">
            <h2 class="h5 mb-3">رسالة broadcast</h2>
            <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="row g-2">
                <?= csrf_field() ?>
                <input type="hidden" name="_operation" value="broadcast">
                <div class="col-12"><input type="text" name="title" class="form-control" placeholder="العنوان" required></div>
                <div class="col-12"><textarea name="body" class="form-control" rows="3" placeholder="المحتوى" required></textarea></div>
                <div class="col-12"><button type="submit" class="btn btn-warning rounded-pill">إرسال</button></div>
            </form>
        </div>
    </div>
</div>

<div class="panel-card admin-form-card mb-4">
    <h2 class="h5 mb-3">قسم الرئيسية</h2>
    <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="row g-2">
        <?= csrf_field() ?>
        <input type="hidden" name="_operation" value="home_section">
        <div class="col-md-3"><input type="text" name="section_key" class="form-control form-control-sm" placeholder="section_key" required></div>
        <div class="col-md-3"><input type="text" name="label" class="form-control form-control-sm" placeholder="التسمية"></div>
        <div class="col-md-3"><input type="text" name="route_target" class="form-control form-control-sm" placeholder="route_target"></div>
        <div class="col-md-2"><input type="number" name="sort_order" class="form-control form-control-sm" placeholder="ترتيب"></div>
        <div class="col-md-1"><input type="number" name="is_active" class="form-control form-control-sm" value="1"></div>
        <div class="col-12"><button type="submit" class="btn btn-primary btn-sm rounded-pill">حفظ</button></div>
    </form>
</div>

<div class="panel-card border border-danger">
    <div class="panel-head"><h2 class="text-danger">منطقة خطرة</h2></div>
    <p class="text-secondary small">تتطلب PIN (1111) كما في تطبيق Admin.</p>
    <div class="d-flex flex-wrap gap-2">
        <?php foreach (['maintenance_on' => 'تشغيل الصيانة', 'maintenance_off' => 'إيقاف الصيانة', 'delete_all_properties' => 'حذف كل المنشورات', 'delete_all_users_except_me' => 'حذف المستخدمين عداي'] as $op => $label): ?>
            <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="admin-form-card" onsubmit="return confirm('تأكيد: <?= e($label) ?>؟');">
                <?= csrf_field() ?>
                <input type="hidden" name="_operation" value="<?= e($op) ?>">
                <label class="small fw-bold d-block mb-1"><?= e($label) ?></label>
                <input type="password" name="pin" class="form-control form-control-sm mb-2" placeholder="PIN" required>
                <button type="submit" class="btn btn-outline-danger btn-sm rounded-pill">تنفيذ</button>
            </form>
        <?php endforeach; ?>
    </div>
</div>
