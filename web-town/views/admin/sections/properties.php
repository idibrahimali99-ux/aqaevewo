<?php
/** @var array<string,mixed> $data */
/** @var array<string,mixed> $section */
/** @var string $sectionKey */
$items = admin_items_from_response($data);
$status = trim((string) ($_GET['status'] ?? 'pending'));
if (!in_array($status, ['pending', 'unsold', 'sold'], true)) {
    $status = 'pending';
}
require __DIR__ . '/../partials/section-alerts.php';
?>
<div class="admin-section-head">
    <div class="admin-tabs">
        <?= admin_section_tab($sectionKey, 'مراجعة', ['status' => 'pending']) ?>
        <?= admin_section_tab($sectionKey, 'لم يبع', ['status' => 'unsold']) ?>
        <?= admin_section_tab($sectionKey, 'تم البيع', ['status' => 'sold']) ?>
    </div>
    <form class="admin-inline-search" method="get" action="<?= e(url('/admin/' . $sectionKey)) ?>">
        <input type="hidden" name="status" value="<?= e($status) ?>">
        <input type="search" name="q" value="<?= e($_GET['q'] ?? '') ?>" placeholder="بحث برقم المنشور # أو العنوان">
        <button type="submit" class="btn btn-primary btn-sm rounded-pill">بحث</button>
    </form>
</div>

<?php if ($items === []): ?>
    <div class="panel-card text-center py-5 text-secondary">لا توجد منشورات في هذا القسم.</div>
<?php else: ?>
    <div class="admin-property-grid">
        <?php foreach ($items as $property): ?>
            <?php
            $pid = (string) ($property['id'] ?? '');
            $publicNo = (string) ($property['property_public_no'] ?? '');
            $thumb = first_image($property);
            $owner = trim((string) ($property['owner_office_name'] ?? $property['office_name'] ?? $property['owner_full_name'] ?? $property['owner_name'] ?? ''));
            $isSold = !empty($property['is_sold']);
            $isUrgent = !empty($property['is_urgent_sale']) || !empty($property['urgent_sale_until']);
            $payload = htmlspecialchars(json_encode($property, JSON_UNESCAPED_UNICODE), ENT_QUOTES, 'UTF-8');
            ?>
            <article class="admin-property-card" data-property="<?= $payload ?>" data-status="<?= e($status) ?>">
                <button type="button" class="admin-property-open" data-property-open aria-label="معاينة المنشور">
                    <div class="admin-property-media">
                        <img src="<?= e($thumb) ?>" alt="">
                        <?php if ($publicNo !== ''): ?><span class="admin-property-no">#<?= e($publicNo) ?></span><?php endif; ?>
                        <?php if ($isUrgent): ?><span class="admin-property-no" style="top:auto;bottom:.75rem;background:#b45309">عاجل</span><?php endif; ?>
                        <span class="admin-preview-badge"><i class="fa-solid fa-eye"></i> معاينة</span>
                    </div>
                    <div class="admin-property-body">
                        <div class="d-flex justify-content-between gap-2 align-items-start">
                            <strong><?= e((string) ($property['title'] ?? 'منشور')) ?></strong>
                            <span class="badge text-bg-light border"><?= e((string) ($property['purpose'] ?? 'sale')) ?></span>
                        </div>
                        <div class="text-secondary small"><?= e(trim((string) ($property['governorate'] ?? '') . ' ' . (string) ($property['address_line'] ?? ''))) ?></div>
                        <div class="admin-property-price"><?= e(money_iqd($property['price_iqd'] ?? null)) ?></div>
                        <?php if ($owner !== ''): ?><div class="small"><i class="fa-solid fa-user ms-1"></i> <?= e($owner) ?></div><?php endif; ?>
                        <div class="small text-secondary"><i class="fa-solid fa-eye ms-1"></i> <?= e(compact_number($property['views'] ?? 0)) ?> مشاهدة</div>
                        <?php if (!empty($property['reject_note'])): ?>
                            <div class="alert alert-warning py-2 px-3 small mb-0 mt-2"><?= e((string) $property['reject_note']) ?></div>
                        <?php endif; ?>
                    </div>
                </button>
                <div class="admin-entity-actions flex-wrap mt-3 px-3 pb-3">
                    <button type="button" class="btn btn-warning btn-sm rounded-pill" data-property-open>
                        <?= $status === 'pending' ? 'معاينة ونشر' : 'التفاصيل الكاملة' ?>
                    </button>
                    <?php if ($status === 'unsold' && !$isSold): ?>
                        <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="d-inline">
                            <?= csrf_field() ?>
                            <input type="hidden" name="_operation" value="mark_sold">
                            <input type="hidden" name="id" value="<?= e($pid) ?>">
                            <button type="submit" class="btn btn-outline-secondary btn-sm rounded-pill">تم البيع</button>
                        </form>
                        <?php if (!$isUrgent): ?>
                            <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="d-inline-flex gap-1 align-items-center">
                                <?= csrf_field() ?>
                                <input type="hidden" name="_operation" value="urgent_sale">
                                <input type="hidden" name="id" value="<?= e($pid) ?>">
                                <input type="number" name="days" value="7" min="1" max="365" class="form-control form-control-sm" style="width:4rem" title="أيام">
                                <button type="submit" class="btn btn-outline-warning btn-sm rounded-pill">بيع عاجل</button>
                            </form>
                        <?php else: ?>
                            <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="d-inline">
                                <?= csrf_field() ?>
                                <input type="hidden" name="_operation" value="cancel_urgent_sale">
                                <input type="hidden" name="id" value="<?= e($pid) ?>">
                                <button type="submit" class="btn btn-outline-warning btn-sm rounded-pill">إلغاء العاجل</button>
                            </form>
                        <?php endif; ?>
                    <?php endif; ?>
                    <?php if ($status !== 'pending'): ?>
                        <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="d-inline" onsubmit="return confirm('حذف هذا المنشور نهائياً؟');">
                            <?= csrf_field() ?>
                            <input type="hidden" name="_operation" value="delete">
                            <input type="hidden" name="id" value="<?= e($pid) ?>">
                            <button type="submit" class="btn btn-outline-danger btn-sm rounded-pill">حذف</button>
                        </form>
                    <?php endif; ?>
                </div>
            </article>
        <?php endforeach; ?>
    </div>
<?php endif; ?>

<div class="modal fade" id="adminPropertyModal" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-xl modal-dialog-scrollable">
        <div class="modal-content rounded-4 border-0">
            <div class="modal-header border-0">
                <h5 class="modal-title">معاينة المنشور</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="إغلاق"></button>
            </div>
            <div class="modal-body" id="adminPropertyModalBody"></div>
            <div class="modal-footer border-0 flex-wrap gap-2" id="adminPropertyModalActions"></div>
        </div>
    </div>
</div>
