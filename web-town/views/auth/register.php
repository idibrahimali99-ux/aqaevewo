<?php $old = is_array($old ?? null) ? $old : []; ?>
<div class="container-xl py-5">
    <div class="row justify-content-center">
        <div class="col-lg-6">
            <div class="auth-card card border-0 shadow-lg rounded-4 p-4 p-md-5">
                <h1 class="h3 mb-2">إنشاء حساب</h1>
                <?php if (!empty($error)): ?><div class="alert alert-danger rounded-4"><?= e($error) ?></div><?php endif; ?>
                <form method="post" action="<?= e(url('/register')) ?>" class="row g-3">
                    <?= csrf_field() ?>
                    <div class="col-12"><select class="form-select" name="account_kind">
                        <option value="customer">زبون</option>
                        <option value="office">مكتب عقاري</option>
                        <option value="marketer">مسوق عقاري</option>
                    </select></div>
                    <div class="col-md-6"><input class="form-control" name="full_name" placeholder="الاسم الكامل" required></div>
                    <div class="col-md-6"><input class="form-control" name="phone" placeholder="07XXXXXXXXX" required></div>
                    <div class="col-md-6"><input class="form-control" name="email" placeholder="البريد"></div>
                    <div class="col-md-6"><input class="form-control" name="password" type="password" placeholder="كلمة المرور" required></div>
                    <div class="col-md-6"><input class="form-control" name="office_name" placeholder="اسم المكتب"></div>
                    <div class="col-md-6"><input class="form-control" name="office_address" placeholder="العنوان"></div>
                    <div class="col-12"><button class="btn btn-primary rounded-pill px-4" type="submit">إنشاء الحساب</button></div>
                </form>
            </div>
        </div>
    </div>
</div>
