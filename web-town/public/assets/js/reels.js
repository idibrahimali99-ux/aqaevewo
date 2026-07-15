(() => {
  const feed = document.getElementById('reelsFeed');
  if (!feed) return;

  const base = document.querySelector('meta[name="app-base"]')?.content || '';
  const csrf = document.querySelector('meta[name="csrf-token"]')?.content || '';
  const slides = [...feed.querySelectorAll('.reel-slide')];

  const playActive = () => {
    slides.forEach((slide) => {
      const video = slide.querySelector('video');
      if (!video) return;
      if (slide.classList.contains('is-active')) {
        video.muted = false;
        video.play().catch(() => {
          video.muted = true;
          video.play().catch(() => {});
        });
        const reelId = slide.dataset.reelId;
        if (reelId) {
          fetch(`${base}/reels/view`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': csrf, Accept: 'application/json' },
            body: JSON.stringify({ reel_id: reelId }),
          }).catch(() => {});
        }
      } else {
        video.pause();
        video.currentTime = 0;
      }
    });
  };

  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting || entry.intersectionRatio < 0.6) return;
      slides.forEach((s) => s.classList.remove('is-active'));
      entry.target.classList.add('is-active');
      playActive();
    });
  }, { threshold: [0.6] });

  slides.forEach((slide) => observer.observe(slide));

  const startId = document.getElementById('reelsApp')?.dataset.start || '';
  if (startId) {
    const target = slides.find((s) => s.dataset.reelId === startId);
    if (target) target.scrollIntoView();
  }

  playActive();

  feed.querySelectorAll('[data-like]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const reelId = btn.dataset.like;
      if (!reelId) return;
      const currentlyLiked = btn.classList.contains('liked');
      const res = await fetch(`${base}/reels/react`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': csrf, Accept: 'application/json' },
        body: JSON.stringify({ reel_id: reelId, liked: currentlyLiked ? 0 : 1 }),
      });
      const data = await res.json().catch(() => ({}));
      if (data.ok) {
        btn.classList.toggle('liked', !!data.liked);
        const icon = btn.querySelector('i');
        if (icon) icon.className = data.liked ? 'fa-solid fa-heart' : 'fa-regular fa-heart';
        const span = btn.querySelector('span');
        if (span && data.likes_count != null) span.textContent = String(data.likes_count);
      } else if (data.error) {
        window.location.href = `${base}/login?next=${encodeURIComponent(window.location.pathname)}`;
      }
    });
  });

  feed.querySelectorAll('[data-chat]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const reelId = btn.dataset.chat || '';
      const propertyId = btn.dataset.property || '';
      const res = await fetch(`${base}/messages/api/open`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': csrf, Accept: 'application/json' },
        body: JSON.stringify({ reel_id: reelId, property_id: propertyId }),
      });
      const data = await res.json().catch(() => ({}));
      if (data.ok && data.thread_id) {
        window.location.href = `${base}/messages?thread=${encodeURIComponent(data.thread_id)}`;
      } else {
        window.location.href = `${base}/login?next=${encodeURIComponent(window.location.pathname)}`;
      }
    });
  });
})();
