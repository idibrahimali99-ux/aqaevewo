<?php
$reel = is_array($reel ?? null) ? $reel : [];
$isEdit = !empty($reel['id']);
?>
<div class="panel-card p-4">
    <h1 class="h4 mb-2"><?= $isEdit ? 'تعديل الريل' : 'نشر ريل' ?></h1>
    <p class="text-secondary small mb-4">المدة من 30 ثانية إلى 3 دقائق. الفيديو يظهر في قسم الريلز بعد المراجعة أو مباشرة لحساب المكتب المعتمد.</p>
    <?php if (!empty($success)): ?><div class="alert alert-success rounded-4"><?= e($success) ?></div><?php endif; ?>
    <?php if (!empty($error)): ?><div class="alert alert-danger rounded-4"><?= e($error) ?></div><?php endif; ?>
    <form method="post" action="<?= e(url($isEdit ? '/reels/' . $reel['id'] . '/edit' : '/reels/add')) ?>" class="row g-3" enctype="multipart/form-data" id="reelForm">
        <?= csrf_field() ?>
        <div class="col-12">
            <label class="form-label">الفيديو <?= $isEdit ? '(اختياري للاستبدال)' : '' ?></label>
            <input class="form-control" type="file" name="video" accept="video/*" <?= $isEdit ? '' : 'required' ?> id="reelVideoInput">
            <div class="form-text">بين 30 ثانية و3 دقائق.</div>
            <input type="hidden" name="duration_seconds" id="reelDurationSeconds" value="">
        </div>
        <div class="col-12">
            <label class="form-label">الوصف</label>
            <textarea class="form-control" name="caption" rows="3" maxlength="200" placeholder="وصف مختصر"><?= e((string) ($reel['caption'] ?? '')) ?></textarea>
        </div>
        <div class="col-12">
            <button class="btn btn-primary rounded-pill px-4" type="submit"><?= $isEdit ? 'حفظ التعديل' : 'نشر الريل' ?></button>
        </div>
    </form>
</div>
<script>
(function () {
  var form = document.getElementById('reelForm');
  var input = document.getElementById('reelVideoInput');
  var durationField = document.getElementById('reelDurationSeconds');
  if (!form || !input) return;
  var lastDuration = 0;
  input.addEventListener('change', function () {
    var file = input.files && input.files[0];
    if (!file) return;
    var url = URL.createObjectURL(file);
    var video = document.createElement('video');
    video.preload = 'metadata';
    video.onloadedmetadata = function () {
      lastDuration = video.duration || 0;
      durationField.value = String(lastDuration);
      URL.revokeObjectURL(url);
      if (lastDuration + 0.05 < 30) {
        alert('الريل يجب ألا يقل عن 30 ثانية');
        input.value = '';
        durationField.value = '';
      } else if (lastDuration > 180.5) {
        alert('الريل يجب ألا يتجاوز 3 دقائق');
        input.value = '';
        durationField.value = '';
      }
    };
    video.src = url;
  });
  form.addEventListener('submit', function (e) {
    if (!input.files || !input.files[0]) return;
    var d = parseFloat(durationField.value || '0');
    if (d > 0 && (d + 0.05 < 30 || d > 180.5)) {
      e.preventDefault();
      alert('مدة الريل يجب أن تكون بين 30 ثانية و3 دقائق');
    }
  });
})();
</script>
