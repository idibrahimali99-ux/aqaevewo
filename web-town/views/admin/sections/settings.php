<?php

/** @var array<string,mixed> $data */
/** @var array<string,mixed> $section */
/** @var string $sectionKey */
/** @var array<string,mixed>|null $apiMeta */
/** @var list<array<string,mixed>> $homeSections */

$health = is_array($data) ? $data : [];
$homeSections = is_array($homeSections ?? null) ? $homeSections : [];
$iconChoices = [
    'home' => 'بيت',
    'apartment' => 'عمارة / مكاتب',
    'building' => 'بناية',
    'city' => 'مدينة / مجمع',
    'grid' => 'شبكة / مقاطعات',
    'land' => 'أرض',
    'shop' => 'محل',
    'villa' => 'فيلا',
    'key' => 'مفتاح',
    'sale' => 'للبيع',
];

require __DIR__ . '/../partials/section-alerts.php';

?>

<div class="row g-4 mb-4">
    <div class="col-lg-6">
        <div class="panel-card h-100">
            <div class="panel-head"><h2>حالة الاتصال</h2></div>
            <?php if (!empty($health['ok'])): ?>
                <div class="alert alert-success rounded-4 border-0"><i class="fa-solid fa-circle-check ms-1"></i> الخدمة تعمل بشكل طبيعي</div>
            <?php else: ?>
                <div class="alert alert-danger rounded-4 border-0"><?= e((string) ($health['error'] ?? 'تعذر الاتصال')) ?></div>
            <?php endif; ?>
            <ul class="list-unstyled small text-secondary mb-0">
                <li>API: <code><?= e((string) ($apiMeta['entry'] ?? app_config('api_entry'))) ?></code></li>
                <li>نوع الرمز: <?= e((string) ($apiMeta['token_type'] ?? '—')) ?></li>
                <li>إحصاءات اللوحة: <?= !empty($apiMeta['stats_ok']) ? 'متصلة' : 'غير متصلة' ?></li>
                <li>الوقت: <?= e((string) ($health['time'] ?? date('c'))) ?></li>
            </ul>
        </div>
    </div>
    <div class="col-lg-6">
        <div class="panel-card admin-form-card h-100">
            <h2 class="h5 mb-3">إشعار فوري</h2>
            <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="row g-2">
                <?= csrf_field() ?>
                <input type="hidden" name="_operation" value="broadcast">
                <div class="col-md-6">
                    <select name="target" class="form-select" aria-label="المستلمين">
                        <option value="users" selected>كل مستخدمي التطبيق</option>
                        <option value="admins">أجهزة الأدمن فقط</option>
                        <option value="all">الجميع</option>
                    </select>
                </div>
                <div class="col-md-6">
                    <select name="kind" class="form-select" aria-label="نوع الإشعار">
                        <option value="broadcast" selected>إشعار عام</option>
                        <option value="reminder">تذكير</option>
                    </select>
                </div>
                <div class="col-12"><input type="text" name="title" class="form-control" placeholder="العنوان" required></div>
                <div class="col-12"><textarea name="body" class="form-control" rows="3" placeholder="المحتوى" required></textarea></div>
                <div class="col-12"><button type="submit" class="btn btn-warning rounded-pill">إرسال</button></div>
            </form>
        </div>
    </div>
</div>

<?php
$serverStats = is_array($serverStats ?? null) ? $serverStats : [];
$telegramMeta = is_array($telegramMeta ?? null) ? $telegramMeta : [];
$cpuPct = (float) ($serverStats['cpu_usage_pct'] ?? 0);
$uptimeH = !empty($serverStats['uptime']) ? round(((float) $serverStats['uptime']) / 3600, 1) : 0;
?>

<div class="panel-card mb-4">
    <div class="panel-head"><h2>إحصائيات السيرفر</h2></div>
    <div class="admin-server-grid">
        <div><span>الدولة</span><strong><?= e((string) ($serverStats['country'] ?? 'العراق')) ?></strong></div>
        <div><span>المعالج</span><strong><?= e((string) ($serverStats['cpu_model'] ?? '—')) ?></strong></div>
        <div><span>الأنوية</span><strong><?= e((string) ($serverStats['cpu_cores'] ?? '—')) ?></strong></div>
        <div><span>استخدام المعالج</span><strong><?= e(number_format($cpuPct, 1)) ?>%</strong></div>
        <div><span>الحمل (1 د)</span><strong><?= e((string) ($serverStats['load_1'] ?? '—')) ?></strong></div>
        <div><span>الذاكرة المستخدمة</span><strong><?= e(admin_format_bytes((int) ($serverStats['memory_used'] ?? 0))) ?> / <?= e(admin_format_bytes((int) ($serverStats['memory_total'] ?? 0))) ?></strong></div>
        <div><span>مساحة القرص الحرة</span><strong><?= e(admin_format_bytes((int) ($serverStats['disk_free'] ?? 0))) ?> / <?= e(admin_format_bytes((int) ($serverStats['disk_total'] ?? 0))) ?></strong></div>
        <div><span>تنزيل تراكمي</span><strong><?= e(admin_format_bytes((int) ($serverStats['net_rx'] ?? 0))) ?></strong></div>
        <div><span>رفع تراكمي</span><strong><?= e(admin_format_bytes((int) ($serverStats['net_tx'] ?? 0))) ?></strong></div>
        <div><span>نظام التشغيل</span><strong><?= e((string) ($serverStats['os'] ?? '—')) ?></strong></div>
        <div><span>مدة التشغيل</span><strong><?= e((string) $uptimeH) ?> ساعة</strong></div>
        <div><span>PHP</span><strong><?= e((string) ($serverStats['php'] ?? PHP_VERSION)) ?></strong></div>
    </div>
</div>

<div class="panel-card admin-form-card mb-4">
    <div class="panel-head"><h2>نسخ احتياطي تيليغرام</h2></div>
    <p class="text-secondary small">كل ساعة تُرسل نسختان: ملف SQL لقاعدة البيانات، وأرشيف لمشروع api + الويب. البوت يراقب الـ API كل دقيقة ويعيد تشغيل Nginx/PHP إذا توقف، مع زر «إصلاح الويب» داخل تيليغرام.</p>
    <?php if (!empty($telegramMeta['configured'])): ?>
        <div class="alert alert-success rounded-4 border-0 py-2">البوت مربوط<?= !empty($telegramMeta['chat_id']) ? ' · chat ' . e((string) $telegramMeta['chat_id']) : '' ?></div>
    <?php else: ?>
        <div class="alert alert-warning rounded-4 border-0 py-2">البوت غير مربوط بعد — احفظ التوكن ومعرّف المحادثة.</div>
    <?php endif; ?>
    <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="row g-2 mb-3">
        <?= csrf_field() ?>
        <input type="hidden" name="_operation" value="telegram_save">
        <div class="col-md-6"><input type="text" name="bot_token" class="form-control" placeholder="توكن البوت (يُترك فارغاً للإبقاء على الحالي)" autocomplete="off"></div>
        <div class="col-md-4"><input type="text" name="chat_id" class="form-control" placeholder="Chat ID" value="<?= e((string) ($telegramMeta['chat_id'] ?? '')) ?>"></div>
        <div class="col-md-2"><button type="submit" class="btn btn-primary rounded-pill w-100">حفظ</button></div>
    </form>
    <div class="d-flex flex-wrap gap-2">
        <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>">
            <?= csrf_field() ?>
            <input type="hidden" name="_operation" value="telegram_test">
            <button type="submit" class="btn btn-outline-dark rounded-pill">حالة السيرفر للبوت</button>
        </form>
        <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" onsubmit="return confirm('إعادة تشغيل Nginx وPHP-FPM الآن؟');">
            <?= csrf_field() ?>
            <input type="hidden" name="_operation" value="repair_web">
            <button type="submit" class="btn btn-danger rounded-pill">إصلاح الويب (Nginx/PHP)</button>
        </form>
        <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" onsubmit="return confirm('إرسال نسخة احتياطية الآن إلى تيليغرام؟');">
            <?= csrf_field() ?>
            <input type="hidden" name="_operation" value="backup_now">
            <button type="submit" class="btn btn-warning rounded-pill">نسخ احتياطي الآن</button>
        </form>
    </div>
</div>

<div class="panel-card admin-form-card mb-4">
    <div class="d-flex justify-content-between align-items-center mb-3">
        <h2 class="h5 mb-0">اختبار إشعار الجهاز (FCM)</h2>
        <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>">
            <?= csrf_field() ?>
            <input type="hidden" name="_operation" value="fcm_test">
            <button type="submit" class="btn btn-outline-dark rounded-pill">إرسال اختبار لجهازي</button>
        </form>
    </div>
    <p class="text-secondary small mb-0">يرسل إشعاراً فورياً لأجهزة حساب الأدمن الحالي. افتح تطبيق الأدمن على جهاز حقيقي وهو متصل بالإنترنت.</p>
</div>

<?php
$appUpdate = is_array($appUpdate ?? null) ? $appUpdate : [];
$androidOn = !empty($appUpdate['android_enabled']) && (string) $appUpdate['android_enabled'] !== '0';
$iosOn = !empty($appUpdate['ios_enabled']) && (string) $appUpdate['ios_enabled'] !== '0';
$androidVersion = trim((string) ($appUpdate['android_latest_version'] ?? $appUpdate['android_min_version'] ?? ''));
$iosVersion = trim((string) ($appUpdate['ios_latest_version'] ?? $appUpdate['ios_min_version'] ?? ''));
$androidForced = $androidOn && (
    $androidVersion !== ''
    || (int) ($appUpdate['android_min_build'] ?? 0) > 0
);
$iosForced = $iosOn && (
    $iosVersion !== ''
    || (int) ($appUpdate['ios_min_build'] ?? 0) > 0
);
?>
<div class="panel-card admin-form-card mb-4">
    <div class="d-flex flex-wrap justify-content-between align-items-center gap-2 mb-2">
        <h2 class="h5 mb-0">تحديث التطبيقات — أندرويد و App Store منفصلان</h2>
    </div>
    <p class="text-secondary small mb-3">كل منصة لها رابط وإصدار وتفعيل مستقل. الحفظ بدون تفعيل لا يوقف المستخدمين. الصق رابط APK أو Google Play لأندرويد، ورابط App Store لآيفون.</p>
    <div class="row g-3 mb-3">
        <div class="col-md-4">
            <label class="form-label small mb-1">عنوان التنبيه المشترك</label>
            <input type="text" class="form-control" id="appUpdateTitleShared" value="<?= e((string) ($appUpdate['title'] ?? '')) ?>" placeholder="يتوفر إصدار جديد">
        </div>
        <div class="col-md-8">
            <label class="form-label small mb-1">نص التنبيه المشترك</label>
            <input type="text" class="form-control" id="appUpdateMessageShared" value="<?= e((string) ($appUpdate['message'] ?? '')) ?>" placeholder="حدّث تطبيق عقار تاون للاستمرار">
        </div>
    </div>
    <div class="row g-3">
        <div class="col-lg-6">
            <div class="border rounded-4 p-3 h-100" style="background:#f8fafc">
                <div class="d-flex flex-wrap justify-content-between align-items-center gap-2 mb-2">
                    <h3 class="h6 mb-0">تحديث أندرويد</h3>
                    <?php if ($androidForced): ?>
                        <span class="badge text-bg-danger rounded-pill">مفعّل<?= $androidVersion !== '' ? ' · ' . e($androidVersion) : '' ?></span>
                    <?php else: ?>
                        <span class="badge text-bg-secondary rounded-pill">متوقف</span>
                    <?php endif; ?>
                </div>
                <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="row g-2 js-app-update-form">
                    <?= csrf_field() ?>
                    <input type="hidden" name="_operation" value="app_update_save_android">
                    <input type="hidden" name="android_enabled" value="0">
                    <input type="hidden" name="title" class="js-app-update-title" value="<?= e((string) ($appUpdate['title'] ?? '')) ?>">
                    <input type="hidden" name="message" class="js-app-update-message" value="<?= e((string) ($appUpdate['message'] ?? '')) ?>">
                    <div class="col-6">
                        <label class="form-label small mb-1">أحدث إصدار</label>
                        <input type="text" name="android_latest_version" class="form-control" placeholder="1.1.22" value="<?= e((string) ($appUpdate['android_latest_version'] ?? '')) ?>">
                    </div>
                    <div class="col-6">
                        <label class="form-label small mb-1">الحد الأدنى</label>
                        <input type="text" name="android_min_version" class="form-control" placeholder="نفس الإصدار" value="<?= e((string) ($appUpdate['android_min_version'] ?? '')) ?>">
                    </div>
                    <div class="col-6">
                        <label class="form-label small mb-1">رقم البناء</label>
                        <input type="number" name="android_min_build" class="form-control" min="0" value="<?= e((string) ($appUpdate['android_min_build'] ?? '0')) ?>">
                    </div>
                    <div class="col-6 d-flex align-items-end">
                        <div class="form-check mb-2">
                            <input class="form-check-input" type="checkbox" name="android_enabled" value="1" id="androidUpdateEnabled" <?= $androidOn ? 'checked' : '' ?>>
                            <label class="form-check-label fw-bold" for="androidUpdateEnabled">تفعيل أندرويد</label>
                        </div>
                    </div>
                    <div class="col-12">
                        <label class="form-label small mb-1">رابط البرنامج (APK أو Google Play)</label>
                        <div class="input-group">
                            <input type="url" name="android_store_url" class="form-control" id="androidStoreUrl" placeholder="https://.../AQAR-TOWN.apk" value="<?= e((string) ($appUpdate['android_store_url'] ?? '')) ?>">
                            <button type="button" class="btn btn-outline-secondary" onclick="navigator.clipboard.writeText(document.getElementById('androidStoreUrl').value)">نسخ</button>
                        </div>
                    </div>
                    <div class="col-12">
                        <button type="submit" class="btn btn-primary rounded-pill">حفظ تحديث أندرويد</button>
                    </div>
                </form>
                <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="mt-2" onsubmit="return confirm('إيقاف تحديث أندرويد فقط؟ مستخدمو iOS لن يتأثروا.');">
                    <?= csrf_field() ?>
                    <input type="hidden" name="_operation" value="app_update_clear_android">
                    <button type="submit" class="btn btn-outline-danger rounded-pill btn-sm">إيقاف أندرويد</button>
                </form>
            </div>
        </div>
        <div class="col-lg-6">
            <div class="border rounded-4 p-3 h-100" style="background:#f8fafc">
                <div class="d-flex flex-wrap justify-content-between align-items-center gap-2 mb-2">
                    <h3 class="h6 mb-0">تحديث App Store</h3>
                    <?php if ($iosForced): ?>
                        <span class="badge text-bg-danger rounded-pill">مفعّل<?= $iosVersion !== '' ? ' · ' . e($iosVersion) : '' ?></span>
                    <?php else: ?>
                        <span class="badge text-bg-secondary rounded-pill">متوقف</span>
                    <?php endif; ?>
                </div>
                <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="row g-2 js-app-update-form">
                    <?= csrf_field() ?>
                    <input type="hidden" name="_operation" value="app_update_save_ios">
                    <input type="hidden" name="ios_enabled" value="0">
                    <input type="hidden" name="title" class="js-app-update-title" value="<?= e((string) ($appUpdate['title'] ?? '')) ?>">
                    <input type="hidden" name="message" class="js-app-update-message" value="<?= e((string) ($appUpdate['message'] ?? '')) ?>">
                    <div class="col-6">
                        <label class="form-label small mb-1">أحدث إصدار</label>
                        <input type="text" name="ios_latest_version" class="form-control" placeholder="1.1.22" value="<?= e((string) ($appUpdate['ios_latest_version'] ?? '')) ?>">
                    </div>
                    <div class="col-6">
                        <label class="form-label small mb-1">الحد الأدنى</label>
                        <input type="text" name="ios_min_version" class="form-control" placeholder="نفس الإصدار" value="<?= e((string) ($appUpdate['ios_min_version'] ?? '')) ?>">
                    </div>
                    <div class="col-6">
                        <label class="form-label small mb-1">رقم البناء</label>
                        <input type="number" name="ios_min_build" class="form-control" min="0" value="<?= e((string) ($appUpdate['ios_min_build'] ?? '0')) ?>">
                    </div>
                    <div class="col-6 d-flex align-items-end">
                        <div class="form-check mb-2">
                            <input class="form-check-input" type="checkbox" name="ios_enabled" value="1" id="iosUpdateEnabled" <?= $iosOn ? 'checked' : '' ?>>
                            <label class="form-check-label fw-bold" for="iosUpdateEnabled">تفعيل App Store</label>
                        </div>
                    </div>
                    <div class="col-12">
                        <label class="form-label small mb-1">رابط App Store</label>
                        <div class="input-group">
                            <input type="url" name="ios_store_url" class="form-control" id="iosStoreUrl" placeholder="https://apps.apple.com/app/idXXXX" value="<?= e((string) ($appUpdate['ios_store_url'] ?? '')) ?>">
                            <button type="button" class="btn btn-outline-secondary" onclick="navigator.clipboard.writeText(document.getElementById('iosStoreUrl').value)">نسخ</button>
                        </div>
                    </div>
                    <div class="col-12">
                        <button type="submit" class="btn btn-primary rounded-pill">حفظ تحديث App Store</button>
                    </div>
                </form>
                <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="mt-2" onsubmit="return confirm('إيقاف تحديث App Store فقط؟ مستخدمو أندرويد لن يتأثروا.');">
                    <?= csrf_field() ?>
                    <input type="hidden" name="_operation" value="app_update_clear_ios">
                    <button type="submit" class="btn btn-outline-danger rounded-pill btn-sm">إيقاف App Store</button>
                </form>
            </div>
        </div>
    </div>
    <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="mt-3" onsubmit="return confirm('إيقاف التحديث على أندرويد و App Store معاً؟');">
        <?= csrf_field() ?>
        <input type="hidden" name="_operation" value="app_update_clear">
        <button type="submit" class="btn btn-outline-secondary rounded-pill">إيقاف المنصتين</button>
    </form>
</div>
<script>
(function () {
  var title = document.getElementById('appUpdateTitleShared');
  var message = document.getElementById('appUpdateMessageShared');
  if (!title || !message) return;
  function syncShared() {
    document.querySelectorAll('.js-app-update-title').forEach(function (el) { el.value = title.value; });
    document.querySelectorAll('.js-app-update-message').forEach(function (el) { el.value = message.value; });
  }
  title.addEventListener('input', syncShared);
  message.addEventListener('input', syncShared);
  document.querySelectorAll('.js-app-update-form').forEach(function (form) {
    form.addEventListener('submit', syncShared);
  });
})();
</script>

<div class="panel-card mb-4">
    <div class="panel-head"><h2>أقسام الرئيسية</h2></div>
    <p class="text-secondary small">نفس الأيقونات التي تظهر في التطبيق الرئيسي وموقع الويب.</p>
    <?php if ($homeSections === []): ?>
        <p class="text-secondary">لا توجد أقسام بعد. أضف قسماً من النموذج أدناه.</p>
    <?php else: ?>
        <div class="d-grid gap-3">
            <?php foreach ($homeSections as $row): ?>
                <?php
                $key = (string) ($row['section_key'] ?? '');
                $iconName = (string) ($row['icon_name'] ?? 'home');
                ?>
                <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="home-section-row">
                    <?= csrf_field() ?>
                    <input type="hidden" name="_operation" value="home_section">
                    <input type="hidden" name="section_key" value="<?= e($key) ?>">
                    <div class="row g-2 align-items-end">
                        <div class="col-md-3">
                            <label class="form-label small mb-1"><i class="fa-solid <?= e(home_section_icon($iconName)) ?> ms-1"></i> التسمية</label>
                            <input class="form-control form-control-sm" name="label" value="<?= e((string) ($row['label'] ?? '')) ?>" required>
                        </div>
                        <div class="col-md-2">
                            <label class="form-label small mb-1">الأيقونة</label>
                            <select name="icon_name" class="form-select form-select-sm">
                                <?php foreach ($iconChoices as $iconKey => $iconLabel): ?>
                                    <option value="<?= e($iconKey) ?>" <?= $iconName === $iconKey ? 'selected' : '' ?>><?= e($iconLabel) ?></option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                        <div class="col-md-3">
                            <label class="form-label small mb-1">المسار</label>
                            <input class="form-control form-control-sm" name="route_target" value="<?= e((string) ($row['route_target'] ?? '')) ?>" required>
                        </div>
                        <div class="col-md-1">
                            <label class="form-label small mb-1">ترتيب</label>
                            <input type="number" name="sort_order" class="form-control form-control-sm" value="<?= e((string) ($row['sort_order'] ?? 0)) ?>">
                        </div>
                        <div class="col-md-2">
                            <label class="form-label small mb-1">الظهور</label>
                            <select name="is_active" class="form-select form-select-sm">
                                <option value="1" <?= (int) ($row['is_active'] ?? 1) === 1 ? 'selected' : '' ?>>ظاهر</option>
                                <option value="0" <?= (int) ($row['is_active'] ?? 1) === 0 ? 'selected' : '' ?>>مخفي</option>
                            </select>
                        </div>
                        <div class="col-md-1">
                            <button type="submit" class="btn btn-primary btn-sm rounded-pill w-100">حفظ</button>
                        </div>
                    </div>
                </form>
            <?php endforeach; ?>
        </div>
    <?php endif; ?>

    <h3 class="h6 mt-4">إضافة قسم جديد</h3>
    <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="row g-2">
        <?= csrf_field() ?>
        <input type="hidden" name="_operation" value="home_section">
        <div class="col-md-2"><input type="text" name="section_key" class="form-control form-control-sm" placeholder="المفتاح" required></div>
        <div class="col-md-2"><input type="text" name="label" class="form-control form-control-sm" placeholder="التسمية" required></div>
        <div class="col-md-2">
            <select name="icon_name" class="form-select form-select-sm">
                <?php foreach ($iconChoices as $iconKey => $iconLabel): ?>
                    <option value="<?= e($iconKey) ?>"><?= e($iconLabel) ?></option>
                <?php endforeach; ?>
            </select>
        </div>
        <div class="col-md-3"><input type="text" name="route_target" class="form-control form-control-sm" placeholder="الوجهة مثل /search" required></div>
        <div class="col-md-1"><input type="number" name="sort_order" class="form-control form-control-sm" placeholder="ترتيب" value="0"></div>
        <div class="col-md-1">
            <select name="is_active" class="form-select form-select-sm">
                <option value="1" selected>ظاهر</option>
                <option value="0">مخفي</option>
            </select>
        </div>
        <div class="col-md-1"><button type="submit" class="btn btn-dark btn-sm rounded-pill">إضافة</button></div>
    </form>
</div>

<div class="panel-card border border-danger">
    <div class="panel-head"><h2 class="text-danger">منطقة خطرة</h2></div>
    <p class="text-secondary small">تتطلب إدخال رمز PIN للتأكيد. لا يمكن التراجع.</p>
    <div class="d-flex flex-wrap gap-2">
        <?php foreach (['maintenance_on' => 'تشغيل الصيانة', 'maintenance_off' => 'إيقاف الصيانة', 'delete_all_properties' => 'حذف كل المنشورات', 'delete_all_chats' => 'تصفير كل المحادثات', 'delete_all_users_except_me' => 'حذف المستخدمين عداي'] as $op => $label): ?>
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
