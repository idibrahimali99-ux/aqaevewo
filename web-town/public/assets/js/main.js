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

  document.querySelectorAll('[data-property-contact-form]').forEach((form) => {
    form.addEventListener('submit', async (e) => {
      if (!window.fetch) return;
      e.preventDefault();
      const propertyId = form.getAttribute('data-property-id') || '';
      const button = form.querySelector('[data-contact-submit]');
      const errorBox = form.parentElement?.nextElementSibling?.matches('[data-contact-error]')
        ? form.parentElement.nextElementSibling
        : null;
      const base = document.querySelector('meta[name="app-base"]')?.content || '';
      const csrf = document.querySelector('meta[name="csrf-token"]')?.content || '';
      if (!propertyId || !csrf) {
        form.submit();
        return;
      }
      if (errorBox) {
        errorBox.classList.add('d-none');
        errorBox.textContent = '';
      }
      const original = button?.innerHTML;
      if (button) {
        button.disabled = true;
        button.innerHTML = '<span class="spinner-border spinner-border-sm ms-1"></span> جاري الفتح';
      }
      try {
        const res = await fetch(`${base}/messages/api/open`, {
          method: 'POST',
          headers: {
            Accept: 'application/json',
            'Content-Type': 'application/json',
            'X-CSRF-Token': csrf,
          },
          body: JSON.stringify({ property_id: propertyId }),
        });
        const data = await res.json();
        if (!data.ok || !data.thread_id) {
          throw new Error(data.error || 'تعذر فتح المحادثة');
        }
        window.location.href = `${base}/messages?thread=${encodeURIComponent(data.thread_id)}`;
      } catch (err) {
        if (errorBox) {
          errorBox.textContent = err?.message || 'تعذر فتح المحادثة';
          errorBox.classList.remove('d-none');
        } else {
          form.submit();
        }
      } finally {
        if (button && original !== undefined) {
          button.disabled = false;
          button.innerHTML = original;
        }
      }
    });
  });

  document.querySelectorAll('[data-before-after]').forEach((root) => {
    const frame = root.querySelector('.before-after-frame');
    const wrap = root.querySelector('.ba-before-wrap');
    const handle = root.querySelector('.ba-handle');
    if (!frame || !wrap || !handle) return;
    let dragging = false;
    const setRatio = (clientX) => {
      const rect = frame.getBoundingClientRect();
      let ratio = (clientX - rect.left) / rect.width;
      if (document.documentElement.dir === 'rtl') {
        ratio = 1 - ratio;
      }
      ratio = Math.min(0.95, Math.max(0.05, ratio));
      const pct = (ratio * 100).toFixed(2) + '%';
      wrap.style.width = pct;
      handle.style.insetInlineStart = pct;
    };
    const onMove = (e) => {
      if (!dragging) return;
      const point = e.touches ? e.touches[0] : e;
      setRatio(point.clientX);
    };
    const stop = () => { dragging = false; };
    frame.addEventListener('mousedown', (e) => { dragging = true; setRatio(e.clientX); });
    frame.addEventListener('touchstart', (e) => {
      dragging = true;
      if (e.touches[0]) setRatio(e.touches[0].clientX);
    }, { passive: true });
    window.addEventListener('mousemove', onMove);
    window.addEventListener('touchmove', onMove, { passive: true });
    window.addEventListener('mouseup', stop);
    window.addEventListener('touchend', stop);
  });
});

(() => {
  const indicator = document.createElement('div');
  indicator.className = 'pull-refresh-indicator';
  indicator.innerHTML = '<i class="fa-solid fa-rotate"></i><span>اسحب للتحديث</span>';
  document.body.appendChild(indicator);
  let startY = 0;
  let pulling = false;
  const threshold = 86;
  const onStart = (e) => {
    if (window.scrollY > 4) return;
    startY = e.touches[0].clientY;
    pulling = true;
  };
  const onMove = (e) => {
    if (!pulling) return;
    const dy = e.touches[0].clientY - startY;
    if (dy > 24 && window.scrollY <= 0) {
      indicator.classList.add('is-visible');
    }
  };
  const onEnd = (e) => {
    if (!pulling) return;
    pulling = false;
    const dy = e.changedTouches[0].clientY - startY;
    indicator.classList.remove('is-visible');
    if (dy > threshold && window.scrollY <= 2) {
      location.reload();
    }
  };
  document.addEventListener('touchstart', onStart, { passive: true });
  document.addEventListener('touchmove', onMove, { passive: true });
  document.addEventListener('touchend', onEnd, { passive: true });
})();
