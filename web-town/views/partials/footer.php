<footer class="site-footer">
    <div class="container-xl">
        <div class="row g-4">
            <div class="col-lg-4">
                <h5>عقار تاون</h5>
                <p class="text-secondary">منصة عقارية عراقية لعرض وبيع وتأجير العقارات.</p>
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
                <h6>تابعنا</h6>
                <div class="d-flex flex-wrap gap-2 mb-3">
                    <a class="social-link facebook" href="https://www.facebook.com/profile.php?id=61591583834702" target="_blank" rel="noopener noreferrer" aria-label="فيسبوك عقار تاون">
                        <i class="fa-brands fa-facebook-f"></i>
                        <span>فيسبوك</span>
                    </a>
                    <a class="social-link instagram" href="https://www.instagram.com/aqaretown" target="_blank" rel="noopener noreferrer" aria-label="إنستغرام عقار تاون">
                        <i class="fa-brands fa-instagram"></i>
                        <span>إنستغرام</span>
                    </a>
                </div>
                <h6>الدعم</h6>
                <a href="tel:<?= e((string) app_config('support_phone')) ?>"><?= e((string) app_config('support_phone')) ?></a>
            </div>
        </div>
    </div>
</footer>
