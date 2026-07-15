<div class="panel-card p-4">
    <div class="d-flex justify-content-between align-items-center mb-3">
        <h1 class="h4 mb-0">الرسائل</h1>
        <form class="d-flex gap-2" method="get"><input class="form-control form-control-sm" name="q" value="<?= e($_GET['q'] ?? '') ?>" placeholder="بحث"><button class="btn btn-sm btn-primary rounded-pill">بحث</button></form>
    </div>
    <?php if (!empty($error)): ?><div class="alert alert-danger"><?= e($error) ?></div><?php endif; ?>
    <?php if ($items === []): ?>
        <p class="text-secondary mb-0">لا توجد محادثات.</p>
    <?php else: ?>
        <div class="list-group list-group-flush">
            <?php foreach ($items as $thread): ?>
                <?php $tid = (string) ($thread['id'] ?? $thread['thread_id'] ?? ''); ?>
                <a class="list-group-item list-group-item-action rounded-4 mb-2 border" href="<?= e(url('/messages/' . $tid)) ?>">
                    <strong><?= e((string) ($thread['title'] ?? $thread['peer_name'] ?? 'محادثة')) ?></strong>
                    <div class="small text-secondary"><?= e((string) ($thread['last_message'] ?? $thread['preview'] ?? '')) ?></div>
                </a>
            <?php endforeach; ?>
        </div>
    <?php endif; ?>
</div>
