<div class="panel-card p-4"><h1 class="h4">طلب عقار</h1><?php if($success): ?><div class="alert alert-success"><?= e($success) ?></div><?php endif; ?><?php if($error): ?><div class="alert alert-danger"><?= e($error) ?></div><?php endif; ?>
<form method="post" action="<?= e(url('/request-property')) ?>" class="row g-3">
    <?= csrf_field() ?>
<div class="col-md-6"><input class="form-control" name="governorate" placeholder="المحافظة" required></div>
<div class="col-md-6"><input class="form-control" name="district" placeholder="المنطقة"></div>
<div class="col-md-4"><select class="form-select" name="purpose"><option value="sale">شراء</option><option value="rent">إيجار</option></select></div>
<div class="col-md-4"><input class="form-control" name="category" value="house"></div>
<div class="col-md-4"><input class="form-control" name="budget_iqd" type="number" placeholder="الميزانية"></div>
<div class="col-12"><textarea class="form-control" name="notes" rows="4" placeholder="تفاصيل الطلب"></textarea></div>
<div class="col-12"><button class="btn btn-primary rounded-pill">إرسال الطلب</button></div></form></div>
