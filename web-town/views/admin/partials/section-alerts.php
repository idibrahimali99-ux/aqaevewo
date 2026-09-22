<?php /** @var array<string,mixed>|null $operationResult */ ?>

<?php if ($operationResult !== null): ?>

    <div class="alert alert-<?= !empty($operationResult['ok']) ? 'success' : 'danger' ?> rounded-4 border-0 shadow-sm">

        <?= !empty($operationResult['ok']) ? 'تم تنفيذ العملية بنجاح.' : e((string) ($operationResult['error'] ?? 'تعذر تنفيذ العملية')) ?>
        <?php if (!empty($operationResult['ok']) && (isset($operationResult['sent']) || isset($operationResult['mode']))): ?>
            <div class="small mt-2">
                <?php if (isset($operationResult['mode'])): ?>الوضع: <?= e((string) $operationResult['mode']) ?> · <?php endif; ?>
                <?php if (isset($operationResult['sent'])): ?>نجاح: <?= e((string) $operationResult['sent']) ?><?php endif; ?>
                <?php if (isset($operationResult['failed'])): ?> · فشل: <?= e((string) $operationResult['failed']) ?><?php endif; ?>
                <?php if (!empty($operationResult['hint'])): ?><div class="mt-1"><?= e((string) $operationResult['hint']) ?></div><?php endif; ?>
            </div>
        <?php endif; ?>

    </div>

<?php endif; ?>



<?php if (empty($data['ok']) && !empty($data['error'])): ?>

    <div class="alert alert-danger rounded-4 border-0">

        <?= e((string) $data['error']) ?>

    </div>

<?php endif; ?>

