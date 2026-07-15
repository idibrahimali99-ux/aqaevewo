<?php

/** @var string $sectionKey */
/** @var array<string,mixed> $section */

if (empty($showAdvancedOperations)) {
    return;
}

$operations = is_array($section['operations'] ?? null) ? $section['operations'] : [];
if ($operations === []) {
    return;
}

?>
<div class="panel-card mt-4 admin-advanced-ops">
    <div class="panel-head"><h2>عمليات إضافية</h2></div>
    <div class="accordion accordion-flush" id="opsAccordion">
        <?php $i = 0; foreach ($operations as $operationKey => $operation): ?>
            <?php if (admin_operation($sectionKey, (string) $operationKey) === null) continue; $i++; ?>
            <div class="accordion-item border-0 bg-transparent">
                <h2 class="accordion-header">
                    <button class="accordion-button collapsed rounded-4 mb-2 shadow-sm" type="button" data-bs-toggle="collapse" data-bs-target="#op<?= $i ?>">
                        <?= e((string) $operation['label']) ?>
                    </button>
                </h2>
                <div id="op<?= $i ?>" class="accordion-collapse collapse" data-bs-parent="#opsAccordion">
                    <div class="accordion-body pt-0">
                        <form method="post" action="<?= e(url('/admin/' . $sectionKey)) ?>" class="row g-3" <?= strtoupper((string) ($operation['method'] ?? 'POST')) === 'UPLOAD' ? 'enctype="multipart/form-data"' : '' ?>>
                            <?= csrf_field() ?>
                            <input type="hidden" name="_operation" value="<?= e((string) $operationKey) ?>">
                            <?php if (strtoupper((string) ($operation['method'] ?? 'POST')) === 'UPLOAD'): ?>
                                <div class="col-12"><input class="form-control" type="file" name="file" required></div>
                            <?php endif; ?>
                            <?php foreach (($operation['fields'] ?? []) as $name => $placeholder): ?>
                                <div class="col-md-6"><input class="form-control" name="<?= e((string) $name) ?>" placeholder="<?= e((string) $placeholder) ?>"></div>
                            <?php endforeach; ?>
                            <div class="col-12"><button class="btn btn-primary rounded-pill px-4" type="submit">تنفيذ</button></div>
                        </form>
                    </div>
                </div>
            </div>
        <?php endforeach; ?>
    </div>
</div>
