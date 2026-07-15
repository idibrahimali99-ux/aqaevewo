<div class="container-xl py-5">
    <div class="row justify-content-center">
        <div class="col-md-5">
            <div class="auth-card card border-0 shadow-lg rounded-4 p-4 p-md-5">
                <h1 class="h3 mb-2">تسجيل الدخول</h1>
                <p class="text-secondary">سيتم توجيهك تلقائياً حسب نوع حسابك</p>
                <?php if (!empty($error)): ?><div class="alert alert-danger rounded-4"><?= e($error) ?></div><?php endif; ?>
                <form method="post" action="<?= e(url('/login')) ?>" class="vstack gap-3 mt-3">
                    <?= csrf_field() ?>
                    <input class="form-control form-control-lg" name="login" value="<?= e($login ?? '') ?>" placeholder="07XXXXXXXXX أو البريد" required>
                    <input class="form-control form-control-lg" name="password" type="password" placeholder="كلمة المرور" required>
                    <button class="btn btn-primary btn-lg rounded-pill" type="submit">دخول</button>
                </form>
                <p class="mt-3 mb-0">ليس لديك حساب؟ <a href="<?= e(url('/register')) ?>">إنشاء حساب</a></p>
            </div>
        </div>
    </div>
</div>
