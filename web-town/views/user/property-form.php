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
?>
<div class="panel-card p-4">
    <h1 class="h4 mb-2">إضافة إعلان عقاري</h1>
    <p class="text-secondary small mb-4">بعد الإرسال يمر المنشور بمراجعة الإدارة ثم يُنشر — مثل التطبيق الرئيسي.</p>
    <?php if (!empty($success)): ?><div class="alert alert-success rounded-4"><?= e($success) ?></div><?php endif; ?>
    <?php if (!empty($error)): ?><div class="alert alert-danger rounded-4"><?= e($error) ?></div><?php endif; ?>
    <form method="post" action="<?= e(url('/property/add')) ?>" class="row g-3" enctype="multipart/form-data" id="propertyAddForm">
        <?= csrf_field() ?>
        <div class="col-md-8">
            <label class="form-label">عنوان الإعلان</label>
            <input class="form-control" name="title" required placeholder="مثال: دار للبيع في بغداد">
        </div>
        <div class="col-md-4">
            <label class="form-label">الغرض</label>
            <select class="form-select" name="purpose" required>
                <option value="sale">للبيع</option>
                <option value="rent">للإيجار</option>
            </select>
        </div>
        <div class="col-md-4">
            <label class="form-label">المحافظة</label>
            <?php if ($govNames !== []): ?>
                <select class="form-select" name="governorate" required>
                    <option value="">— اختر —</option>
                    <?php foreach ($govNames as $gname): ?>
                        <option value="<?= e($gname) ?>"><?= e($gname) ?></option>
                    <?php endforeach; ?>
                </select>
            <?php else: ?>
                <input class="form-control" name="governorate" required>
            <?php endif; ?>
        </div>
        <div class="col-md-8">
            <label class="form-label">العنوان التفصيلي</label>
            <input class="form-control" name="address_line" required placeholder="المنطقة، الشارع، أقرب نقطة">
        </div>
        <div class="col-md-4">
            <label class="form-label">الفئة</label>
            <select class="form-select" name="category" required>
                <?php foreach (property_category_options() as $val => $label): ?>
                    <?php if ($val === '') continue; ?>
                    <option value="<?= e($val) ?>"<?= $val === 'house' ? ' selected' : '' ?>><?= e($label) ?></option>
                <?php endforeach; ?>
            </select>
        </div>
        <div class="col-md-4">
            <label class="form-label">نوع المنشور</label>
            <select class="form-select" name="segment">
                <option value="standard">عادي</option>
                <option value="parcel">مقاطعة</option>
            </select>
        </div>
        <div class="col-md-4">
            <label class="form-label">السعر (د.ع)</label>
            <input class="form-control" name="price_iqd" type="number" min="0" required>
        </div>
        <div class="col-md-4">
            <label class="form-label">المساحة m²</label>
            <input class="form-control" name="area_sqm" type="number" min="1" required>
        </div>
        <div class="col-12">
            <label class="form-label">الوصف</label>
            <textarea class="form-control" name="description" rows="4" required placeholder="تفاصيل العقار..."></textarea>
        </div>
        <div class="col-12">
            <label class="form-label">روابط الصور (سطر لكل صورة)</label>
            <textarea class="form-control" name="image_urls" rows="3" placeholder="https://..."></textarea>
            <div class="form-text">أو ارفع صورة واحدة على الأقل:</div>
            <input class="form-control mt-2" type="file" name="image_file" accept="image/*">
        </div>
        <div class="col-12">
            <button class="btn btn-primary rounded-pill px-4" type="submit"><i class="fa-solid fa-paper-plane ms-1"></i> إرسال للمراجعة</button>
        </div>
    </form>
</div>
