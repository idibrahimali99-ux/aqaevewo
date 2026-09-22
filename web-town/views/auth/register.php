<?php
$old = is_array($old ?? null) ? $old : [];
$governorates = is_array($governorates ?? null) ? $governorates : [];
$kindNow = (string) ($old['account_kind'] ?? 'customer');
$govNow = (string) ($old['governorate'] ?? '');
?>
<div class="container-xl py-5">
    <div class="row justify-content-center">
        <div class="col-lg-6">
            <div class="auth-card card border-0 shadow-lg rounded-4 p-4 p-md-5">
                <h1 class="h3 mb-2">إنشاء حساب</h1>
                <?php if (!empty($error)): ?><div class="alert alert-danger rounded-4"><?= e($error) ?></div><?php endif; ?>
                <form method="post" action="<?= e(url('/register')) ?>" class="row g-3" id="registerForm">
                    <?= csrf_field() ?>
                    <div class="col-12"><select class="form-select" name="account_kind" id="accountKind">
                        <option value="customer"<?= $kindNow === 'customer' ? ' selected' : '' ?>>زبون</option>
                        <option value="office"<?= $kindNow === 'office' ? ' selected' : '' ?>>مكتب عقاري</option>
                        <option value="marketer"<?= $kindNow === 'marketer' ? ' selected' : '' ?>>مسوق عقاري</option>
                    </select></div>
                    <div class="col-md-6"><input class="form-control" name="full_name" placeholder="الاسم الكامل" required value="<?= e((string) ($old['full_name'] ?? '')) ?>"></div>
                    <div class="col-md-6"><input class="form-control" name="phone" placeholder="07XXXXXXXXX" required value="<?= e((string) ($old['phone'] ?? '')) ?>"></div>
                    <div class="col-md-6"><input class="form-control" name="email" placeholder="البريد" value="<?= e((string) ($old['email'] ?? '')) ?>"></div>
                    <div class="col-md-6"><input class="form-control" name="password" type="password" placeholder="كلمة المرور" required></div>
                    <div class="col-md-6"><input class="form-control" name="office_name" placeholder="اسم المكتب" value="<?= e((string) ($old['office_name'] ?? '')) ?>"></div>
                    <div class="col-md-6"><input class="form-control" name="office_address" placeholder="العنوان" value="<?= e((string) ($old['office_address'] ?? '')) ?>"></div>
                    <div class="col-12"><button class="btn btn-primary rounded-pill px-4" type="submit">إنشاء الحساب</button></div>
                </form>
            </div>
        </div>
    </div>
</div>
