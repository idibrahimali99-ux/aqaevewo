document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('.property-card').forEach((card) => {
    card.style.transition = 'transform .25s ease, box-shadow .25s ease';
    card.addEventListener('mouseenter', () => {
      card.style.transform = 'translateY(-4px)';
      card.style.boxShadow = '0 20px 40px rgba(29,26,19,.12)';
    });
    card.addEventListener('mouseleave', () => {
      card.style.transform = '';
      card.style.boxShadow = '';
    });
  });

  const copyToast = (() => {
    let el = document.getElementById('copyToast');
    if (!el) {
      el = document.createElement('div');
      el.id = 'copyToast';
      el.className = 'copy-toast';
      el.setAttribute('role', 'status');
      el.setAttribute('aria-live', 'polite');
      document.body.appendChild(el);
    }
    let timer;
    return (text) => {
      el.textContent = `تم نسخ ${text}`;
      el.classList.add('show');
      clearTimeout(timer);
      timer = setTimeout(() => el.classList.remove('show'), 1800);
    };
  })();

  document.addEventListener('click', async (e) => {
    const btn = e.target.closest('[data-copy-text]');
    if (!btn) return;
    e.preventDefault();
    e.stopPropagation();
    const text = btn.getAttribute('data-copy-text') || btn.textContent.trim();
    try {
      await navigator.clipboard.writeText(text);
      copyToast(text);
      btn.classList.add('copied');
      setTimeout(() => btn.classList.remove('copied'), 1200);
    } catch (_) {
      const ta = document.createElement('textarea');
      ta.value = text;
      document.body.appendChild(ta);
      ta.select();
      document.execCommand('copy');
      ta.remove();
      copyToast(text);
    }
  });
});
