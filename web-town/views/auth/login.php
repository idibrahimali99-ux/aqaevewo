<section class="auth-wrap">
    <div class="auth-card">
        <span class="eyebrow">دخول ذكي حسب نوع الحساب</span>
        <h1>تسجيل الدخول</h1>
        <p class="muted">أدخل رقم الهاتف أو البريد، وسيتم توجيهك تلقائيا إلى اللوحة المناسبة.</p>
        <?php if (!empty($error)): ?>
            <div class="alert"><?= e($error) ?></div>
        <?php endif; ?>
        <form class="form-stack" method="post" action="<?= e(url('/login')) ?>">
            <?= csrf_field() ?>
            <input class="input" name="login" value="<?= e($login ?? '') ?>" placeholder="07XXXXXXXXX أو البريد الإلكتروني" required>
            <input class="input" name="password" type="password" placeholder="كلمة المرور" required>
            <button class="btn primary" type="submit">دخول</button>
        </form>
        <p class="muted">ليس لديك حساب؟ <a href="<?= e(url('/register')) ?>">أنشئ حسابا جديدا</a></p>
    </div>
</section>
