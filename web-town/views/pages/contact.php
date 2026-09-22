<div class="container-xl py-5">
    <div class="panel-card p-5">
        <h1 class="h3 mb-3">تواصل معنا</h1>
        <p class="text-secondary">فريق عقار تاون جاهز لمساعدتك عبر الهاتف أو المحادثة داخل الموقع.</p>
        <div class="d-flex flex-wrap gap-2 mt-3">
            <a class="btn btn-primary rounded-pill px-4" href="tel:<?= e((string) app_config('support_phone')) ?>">
                <i class="fa-solid fa-phone ms-1"></i> <?= e((string) app_config('support_phone')) ?>
            </a>
            <?php if (is_logged_in()): ?>
                <button type="button" class="btn btn-outline-dark rounded-pill" id="contactSupportChat">
                    <i class="fa-solid fa-headset ms-1"></i> محادثة الدعم
                </button>
            <?php else: ?>
                <a class="btn btn-outline-dark rounded-pill" href="<?= e(url('/login')) ?>">سجّل لفتح محادثة الدعم</a>
            <?php endif; ?>
        </div>
    </div>
</div>
<?php if (is_logged_in()): ?>
<script>
document.getElementById('contactSupportChat')?.addEventListener('click', async () => {
  const base = document.querySelector('meta[name="app-base"]')?.content || '';
  const csrf = document.querySelector('meta[name="csrf-token"]')?.content || '';
  const btn = document.getElementById('contactSupportChat');
  if (btn) btn.disabled = true;
  try {
    const res = await fetch(`${base}/messages/api/open`, {
      method: 'POST',
      headers: { Accept: 'application/json', 'Content-Type': 'application/json', 'X-CSRF-Token': csrf },
      body: JSON.stringify({ support: 1 }),
    });
    const data = await res.json();
    if (!data.ok || !data.thread_id) throw new Error(data.error || 'تعذر فتح المحادثة');
    window.location.href = `${base}/messages?thread=${encodeURIComponent(data.thread_id)}`;
  } catch (_) {
    if (btn) btn.disabled = false;
    alert('تعذر فتح محادثة الدعم');
  }
});
</script>
<?php endif; ?>
