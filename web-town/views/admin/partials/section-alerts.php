<?php /** @var array<string,mixed>|null $operationResult */ ?>

<?php if ($operationResult !== null): ?>

    <div class="alert alert-<?= !empty($operationResult['ok']) ? 'success' : 'danger' ?> rounded-4 border-0 shadow-sm">

        <?= !empty($operationResult['ok']) ? 'تم تنفيذ العملية بنجاح.' : e((string) ($operationResult['error'] ?? 'تعذر تنفيذ العملية')) ?>

    </div>

<?php endif; ?>



<?php if (empty($data['ok']) && !empty($data['error'])): ?>

    <div class="alert alert-danger rounded-4 border-0">

        <?= e((string) $data['error']) ?> — endpoint: <code><?= e((string) ($section['endpoint'] ?? '')) ?></code>

    </div>

<?php endif; ?>

