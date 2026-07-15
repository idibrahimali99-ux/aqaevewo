<div class="panel-card p-4">
    <div class="d-flex justify-content-between align-items-center mb-3">
        <h1 class="h5 mb-0">محادثة</h1>
        <a href="<?= e(url('/messages')) ?>" class="btn btn-sm btn-outline-dark rounded-pill">رجوع</a>
    </div>
    <?php if (!empty($error)): ?><div class="alert alert-danger"><?= e($error) ?></div><?php endif; ?>
    <div class="chat-stack mb-3" style="max-height:420px;overflow:auto">
        <?php foreach ($messages as $msg): ?>
            <div class="p-3 rounded-4 mb-2 <?= !empty($msg['mine']) ? 'bg-warning-subtle ms-auto' : 'bg-light' ?>" style="max-width:85%">
                <div><?= e((string) ($msg['body'] ?? $msg['text'] ?? '')) ?></div>
                <small class="text-secondary"><?= e((string) ($msg['created_at'] ?? '')) ?></small>
            </div>
        <?php endforeach; ?>
    </div>
    <form method="post" action="<?= e(url('/messages/' . $threadId)) ?>" class="d-flex gap-2">
        <?= csrf_field() ?>
        <input class="form-control" name="body" placeholder="اكتب رسالة..." required>
        <button class="btn btn-primary rounded-pill px-4" type="submit">إرسال</button>
    </form>
</div>
