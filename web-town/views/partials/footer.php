<footer class="site-footer">
    <div class="container-xl">
        <div class="row g-4">
            <div class="col-lg-4">
                <h5>عقار تاون</h5>
                <p class="text-secondary">منصة عقارية عراقية متصلة بنفس بيانات تطبيق Aqar Town.</p>
            </div>
            <div class="col-lg-4">
                <h6>روابط</h6>
                <div class="d-flex flex-column gap-2">
                    <a href="<?= e(url('/about')) ?>">من نحن</a>
                    <a href="<?= e(url('/contact')) ?>">تواصل معنا</a>
                    <a href="<?= e(url('/privacy')) ?>">سياسة الخصوصية</a>
                    <a href="<?= e(url('/terms')) ?>">الشروط والأحكام</a>
                </div>
            </div>
            <div class="col-lg-4">
                <h6>الدعم</h6>
                <a href="tel:<?= e((string) app_config('support_phone')) ?>"><?= e((string) app_config('support_phone')) ?></a>
            </div>
        </div>
    </div>
</footer>
