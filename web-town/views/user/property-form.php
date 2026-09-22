<?php
$govs = api_client()->get('app/governorates');
$govNames = [];
foreach (($govs['items'] ?? $govs['governorates'] ?? []) as $gov) {
    if (is_array($gov) && !empty($gov['name'])) {
        $govNames[] = (string) $gov['name'];
    } elseif (is_string($gov)) {
        $govNames[] = $gov;
    }
}
$property = is_array($property ?? null) ? $property : [];
$isEdit = !empty($property['id']);
$details = property_details_array($property) ?? [];
$existingImageUrls = [];
foreach (property_image_list($property) as $url) {
    if ($url !== '' && !str_contains($url, 'placeholder')) {
        $existingImageUrls[] = $url;
    }
}
$field = static function (array $row, string $key, mixed $fallback = '') {
    $v = $row[$key] ?? $fallback;
    return is_scalar($v) ? (string) $v : (string) $fallback;
};
$purposeNow = $field($property, 'purpose', 'sale');
$rentPeriodNow = strtolower((string) ($details['rent_period'] ?? 'monthly'));
if (!in_array($rentPeriodNow, ['monthly', 'yearly'], true)) {
    $rentPeriodNow = 'monthly';
}
$govNow = $field($property, 'governorate');
$catNow = $field($property, 'category', 'house');
$segNow = $field($property, 'segment', 'standard');
$furnishedNow = (string) ($details['furnished'] ?? '');
?>
<div class="panel-card p-4">
    <h1 class="h4 mb-2"><?= $isEdit ? 'تعديل الإعلان' : 'إضافة إعلان عقاري' ?></h1>
    <p class="text-secondary small mb-4"><?= $isEdit ? 'عدّل الصور والنصوص ثم احفظ — بدون فيديو في قسم نشر العقار.' : 'بعد الإرسال يمر المنشور بمراجعة الإدارة ثم يُنشر. الصور فقط، بدون فيديو.' ?></p>
    <?php if (!empty($success)): ?><div class="alert alert-success rounded-4"><?= e($success) ?></div><?php endif; ?>
    <?php if (!empty($error)): ?><div class="alert alert-danger rounded-4"><?= e($error) ?></div><?php endif; ?>
    <form method="post" action="<?= e(url($isEdit ? '/property/' . $property['id'] . '/edit' : '/property/add')) ?>" class="row g-3" enctype="multipart/form-data" id="propertyAddForm">
        <?= csrf_field() ?>
        <div class="col-md-8">
            <label class="form-label">عنوان الإعلان</label>
            <input class="form-control" name="title" required placeholder="مثال: دار للبيع في بغداد" value="<?= e($field($property, 'title')) ?>">
        </div>
        <div class="col-md-4">
            <label class="form-label">الغرض</label>
            <select class="form-select" name="purpose" id="propertyPurpose" required>
                <option value="sale"<?= $purposeNow === 'sale' ? ' selected' : '' ?>>للبيع</option>
                <option value="rent"<?= $purposeNow === 'rent' ? ' selected' : '' ?>>للإيجار</option>
            </select>
        </div>
        <div class="col-md-4" id="rentPeriodWrap"<?= $purposeNow === 'rent' ? '' : ' hidden' ?>>
            <label class="form-label">نوع الإيجار</label>
            <select class="form-select" name="rent_period" id="propertyRentPeriod">
                <option value="monthly"<?= $rentPeriodNow === 'monthly' ? ' selected' : '' ?>>شهري</option>
                <option value="yearly"<?= $rentPeriodNow === 'yearly' ? ' selected' : '' ?>>سنوي</option>
            </select>
        </div>
        <div class="col-md-4">
            <label class="form-label">المحافظة</label>
            <?php if ($govNames !== []): ?>
                <select class="form-select" name="governorate" required>
                    <option value="">— اختر —</option>
                    <?php foreach ($govNames as $gname): ?>
                        <option value="<?= e($gname) ?>"<?= $govNow === $gname ? ' selected' : '' ?>><?= e($gname) ?></option>
                    <?php endforeach; ?>
                </select>
            <?php else: ?>
                <input class="form-control" name="governorate" required value="<?= e($govNow) ?>">
            <?php endif; ?>
        </div>
        <div class="col-md-8">
            <label class="form-label">العنوان التفصيلي</label>
            <input class="form-control" name="address_line" required placeholder="المنطقة، الشارع، أقرب نقطة" value="<?= e($field($property, 'address_line')) ?>">
        </div>
        <div class="col-md-4">
            <label class="form-label">الفئة</label>
            <select class="form-select" name="category" required>
                <?php foreach (property_category_options() as $opt => $label): ?>
                    <?php if ($opt === '') continue; ?>
                    <option value="<?= e($opt) ?>"<?= $catNow === $opt ? ' selected' : '' ?>><?= e($label) ?></option>
                <?php endforeach; ?>
            </select>
        </div>
        <div class="col-md-4">
            <label class="form-label">نوع المنشور</label>
            <select class="form-select" name="segment">
                <option value="standard"<?= $segNow === 'standard' ? ' selected' : '' ?>>عادي</option>
                <option value="parcel"<?= $segNow === 'parcel' ? ' selected' : '' ?>>مقاطعة</option>
            </select>
        </div>
        <div class="col-md-4">
            <label class="form-label" id="priceIqdLabel"><?= $purposeNow === 'rent' ? ($rentPeriodNow === 'yearly' ? 'الإيجار السنوي (د.ع)' : 'الإيجار الشهري (د.ع)') : 'السعر (د.ع)' ?></label>
            <input class="form-control" name="price_iqd" type="number" min="0" required value="<?= e($field($property, 'price_iqd', '0')) ?>">
        </div>
        <div class="col-md-4">
            <label class="form-label">المساحة m²</label>
            <input class="form-control" name="area_sqm" type="number" min="1" required value="<?= e($field($property, 'area_sqm', '1')) ?>">
        </div>
        <div class="col-md-2">
            <label class="form-label">الغرف</label>
            <input class="form-control" name="rooms" type="number" min="0" placeholder="—" value="<?= e((string) ($details['rooms'] ?? '')) ?>">
        </div>
        <div class="col-md-2">
            <label class="form-label">غرف النوم</label>
            <input class="form-control" name="bedrooms" type="number" min="0" value="<?= e((string) ($details['bedrooms'] ?? '')) ?>">
        </div>
        <div class="col-md-2">
            <label class="form-label">الحمامات</label>
            <input class="form-control" name="bathrooms" type="number" min="0" value="<?= e((string) ($details['bathrooms'] ?? '')) ?>">
        </div>
        <div class="col-md-2">
            <label class="form-label">الطابق</label>
            <input class="form-control" name="floor" type="number" value="<?= e((string) ($details['floor'] ?? '')) ?>">
        </div>
        <div class="col-md-2">
            <label class="form-label">عدد الطوابق</label>
            <input class="form-control" name="floors_count" type="number" min="0" value="<?= e((string) ($details['floors_count'] ?? '')) ?>">
        </div>
        <div class="col-md-2">
            <label class="form-label">المطبخ</label>
            <input class="form-control" name="kitchen" placeholder="نعم / لا" value="<?= e((string) ($details['kitchen'] ?? '')) ?>">
        </div>
        <div class="col-md-2">
            <label class="form-label">الصالة</label>
            <input class="form-control" name="living_room" placeholder="—" value="<?= e((string) ($details['living_room'] ?? '')) ?>">
        </div>
        <div class="col-md-2">
            <label class="form-label">موقف سيارات</label>
            <input class="form-control" name="parking" placeholder="—" value="<?= e((string) ($details['parking'] ?? '')) ?>">
        </div>
        <div class="col-md-3">
            <label class="form-label">الواجهة</label>
            <input class="form-control" name="facade" placeholder="شمالية..." value="<?= e((string) ($details['facade'] ?? '')) ?>">
        </div>
        <div class="col-md-3">
            <label class="form-label">نوع السند</label>
            <input class="form-control" name="deed_type" placeholder="طابو / زراعي" value="<?= e((string) ($details['deed_type'] ?? '')) ?>">
        </div>
        <div class="col-md-3">
            <label class="form-label">مفروش</label>
            <select class="form-select" name="furnished">
                <option value="">—</option>
                <?php foreach (['نعم', 'لا', 'جزئياً'] as $opt): ?>
                    <option value="<?= e($opt) ?>"<?= $furnishedNow === $opt ? ' selected' : '' ?>><?= e($opt) ?></option>
                <?php endforeach; ?>
            </select>
        </div>
        <div class="col-12">
            <label class="form-label">تفاصيل إضافية للغرفة/العقار</label>
            <textarea class="form-control" name="extra_notes" rows="2" placeholder="إضافات: مولد، كاميرات، حديقة، مصعد..."><?= e((string) ($details['extra_notes'] ?? '')) ?></textarea>
        </div>
        <div class="col-12">
            <label class="form-label">الوصف</label>
            <textarea class="form-control" name="description" rows="4" required placeholder="تفاصيل العقار..."><?= e($field($property, 'description')) ?></textarea>
        </div>
        <div class="col-12">
            <label class="form-label">صور العقار</label>
            <input class="form-control" type="file" name="images[]" accept="image/*" multiple>
            <div class="form-text">صور فقط — بدون فيديو. ارفع صوراً جديدة أو أبقِ الروابط الحالية.</div>
            <textarea class="form-control mt-2" name="image_urls" rows="2" placeholder="روابط اختيارية، سطر لكل صورة"><?= e(implode("\n", $existingImageUrls)) ?></textarea>
        </div>
        <div class="col-12">
            <button class="btn btn-primary rounded-pill px-4" type="submit" id="propertyAddSubmit"><i class="fa-solid fa-paper-plane ms-1"></i> <?= $isEdit ? 'حفظ التعديل' : 'إرسال للمراجعة' ?></button>
        </div>
    </form>
</div>
<div id="publishProgressBar" class="publish-progress-bar" hidden>
    <div class="publish-progress-card">
        <div class="publish-progress-label">جاري رفع المنشور… يمكنك إبقاء الصفحة مفتوحة حتى يكتمل الإرسال</div>
        <div class="publish-progress-track"><span></span></div>
    </div>
</div>
<script>
(function () {
  var form = document.getElementById('propertyAddForm');
  if (!form) return;
  var purpose = document.getElementById('propertyPurpose');
  var wrap = document.getElementById('rentPeriodWrap');
  var period = document.getElementById('propertyRentPeriod');
  var priceLabel = document.getElementById('priceIqdLabel');
  function syncRent() {
    var rent = purpose && purpose.value === 'rent';
    if (wrap) wrap.hidden = !rent;
    if (priceLabel) {
      if (!rent) priceLabel.textContent = 'السعر (د.ع)';
      else if (period && period.value === 'yearly') priceLabel.textContent = 'الإيجار السنوي (د.ع)';
      else priceLabel.textContent = 'الإيجار الشهري (د.ع)';
    }
  }
  if (purpose) purpose.addEventListener('change', syncRent);
  if (period) period.addEventListener('change', syncRent);
  syncRent();
  form.addEventListener('submit', function () {
    var bar = document.getElementById('publishProgressBar');
    var btn = document.getElementById('propertyAddSubmit');
    if (bar) bar.hidden = false;
    if (btn) {
      btn.disabled = true;
      btn.innerHTML = '<i class="fa-solid fa-spinner fa-spin ms-1"></i> جاري الرفع…';
    }
  });
})();
</script>
