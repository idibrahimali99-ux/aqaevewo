<?php
/** @var array<string,mixed> $old */
$old = is_array($old ?? null) ? $old : [];
?>
<section class="auth-wrap">
    <div class="auth-card">
        <span class="eyebrow">حساب جديد</span>
        <h1>انضم إلى ويب تاون</h1>
        <p class="muted">يمكنك التسجيل كزبون أو مكتب أو مسوق عقاري. حسابات المكاتب والمسوقين تخضع للمراجعة.</p>
        <?php if (!empty($error)): ?>
            <div class="alert"><?= e($error) ?></div>
        <?php endif; ?>
        <form class="form-stack" method="post" action="<?= e(url('/register')) ?>">
            <?= csrf_field() ?>
            <select name="account_kind">
                <option value="customer" <?= ($old['account_kind'] ?? '') === 'customer' ? 'selected' : '' ?>>زبون</option>
                <option value="office" <?= ($old['account_kind'] ?? '') === 'office' ? 'selected' : '' ?>>مكتب عقاري</option>
                <option value="marketer" <?= ($old['account_kind'] ?? '') === 'marketer' ? 'selected' : '' ?>>مسوق عقاري</option>
            </select>
            <input class="input" name="full_name" value="<?= e($old['full_name'] ?? '') ?>" placeholder="الاسم الكامل" required>
            <input class="input" name="phone" value="<?= e($old['phone'] ?? '') ?>" placeholder="07XXXXXXXXX" required>
            <input class="input" name="email" value="<?= e($old['email'] ?? '') ?>" placeholder="البريد الإلكتروني اختياري">
            <input class="input" name="password" type="password" placeholder="كلمة المرور، أحرف وأرقام" required>
            <input class="input" name="office_name" value="<?= e($old['office_name'] ?? '') ?>" placeholder="اسم المكتب أو اسم النشاط للمسوق">
            <input class="input" name="office_address" value="<?= e($old['office_address'] ?? '') ?>" placeholder="عنوان المكتب">
            <input class="input" name="office_license_no" value="<?= e($old['office_license_no'] ?? '') ?>" placeholder="رقم الإجازة">
            <input class="input" name="office_photo_url" value="<?= e($old['office_photo_url'] ?? '') ?>" placeholder="رابط صورة المكتب أو الشعار">
            <button class="btn primary" type="submit">إنشاء الحساب</button>
        </form>
    </div>
</section>
