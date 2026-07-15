(() => {
  const modalEl = document.getElementById('adminReelModal');
  const bodyEl = document.getElementById('adminReelModalBody');
  const actionsEl = document.getElementById('adminReelModalActions');
  if (!modalEl || !bodyEl || !actionsEl) return;

  const modal = window.bootstrap ? new window.bootstrap.Modal(modalEl) : null;
  const csrf = document.querySelector('meta[name="csrf-token"]')?.content || '';
  const sectionUrl = document.body.dataset.adminSectionUrl || '';

  const escapeHtml = (s) => String(s).replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));

  let activeVideo = null;
  const stopVideo = () => {
    if (activeVideo) {
      activeVideo.pause();
      activeVideo = null;
    }
  };

  modalEl.addEventListener('hidden.bs.modal', stopVideo);

  const renderReel = (reel, status) => {
    const video = reel.video_public_url || reel.video_url || '';
    const publicNo = reel.reel_public_no ? `#${reel.reel_public_no}` : '';
    const id = reel.id || '';

    bodyEl.innerHTML = `
      <div class="admin-reel-preview">
        ${video
          ? `<video id="adminReelPreviewVideo" src="${escapeHtml(video)}" controls autoplay loop playsinline></video>`
          : '<div class="admin-reel-placeholder py-5"><i class="fa-solid fa-clapperboard"></i></div>'}
        <div class="p-3">
          ${publicNo ? `<span class="badge rounded-pill text-bg-dark">${escapeHtml(publicNo)}</span>` : ''}
          <h2 class="h5 mt-2 mb-1">${escapeHtml(reel.caption || 'ريل')}</h2>
          <div class="small text-secondary">${escapeHtml(reel.owner_display_name || reel.owner_full_name || '')}</div>
          <div class="small text-secondary mt-2">
            <i class="fa-solid fa-eye ms-1"></i> ${escapeHtml(String(reel.view_count || reel.views || 0))}
            <i class="fa-solid fa-heart ms-2"></i> ${escapeHtml(String(reel.like_count || reel.likes || 0))}
          </div>
          ${reel.reject_note ? `<div class="alert alert-warning py-2 px-3 small mt-3 mb-0">${escapeHtml(reel.reject_note)}</div>` : ''}
        </div>
      </div>`;

    activeVideo = document.getElementById('adminReelPreviewVideo');

    if (status === 'pending') {
      actionsEl.innerHTML = `
        <button type="button" class="btn btn-light rounded-pill" data-bs-dismiss="modal">رجوع</button>
        <button type="button" class="btn btn-outline-danger rounded-pill" data-bs-toggle="collapse" data-bs-target="#adminReelRejectForm">رفض</button>
        <form method="post" action="${escapeHtml(sectionUrl)}" class="d-inline">
          <input type="hidden" name="_csrf" value="${escapeHtml(csrf)}">
          <input type="hidden" name="_operation" value="approve">
          <input type="hidden" name="id" value="${escapeHtml(id)}">
          <button type="submit" class="btn btn-success rounded-pill">موافقة ونشر</button>
        </form>
        <div class="collapse w-100 mt-2" id="adminReelRejectForm">
          <form method="post" action="${escapeHtml(sectionUrl)}" class="row g-2 p-3 rounded-4 bg-light">
            <input type="hidden" name="_csrf" value="${escapeHtml(csrf)}">
            <input type="hidden" name="_operation" value="reject">
            <input type="hidden" name="id" value="${escapeHtml(id)}">
            <div class="col-12"><input class="form-control" name="reject_note" placeholder="سبب الرفض" required></div>
            <div class="col-12"><button type="submit" class="btn btn-danger rounded-pill">تأكيد الرفض</button></div>
          </form>
        </div>`;
    } else {
      actionsEl.innerHTML = `
        <button type="button" class="btn btn-light rounded-pill" data-bs-dismiss="modal">إغلاق</button>
        <form method="post" action="${escapeHtml(sectionUrl)}" class="d-inline" onsubmit="return confirm('حذف هذا الريل؟');">
          <input type="hidden" name="_csrf" value="${escapeHtml(csrf)}">
          <input type="hidden" name="_operation" value="delete">
          <input type="hidden" name="id" value="${escapeHtml(id)}">
          <button type="submit" class="btn btn-outline-danger rounded-pill">حذف</button>
        </form>`;
    }
  };

  document.querySelectorAll('[data-reel-open]').forEach((btn) => {
    btn.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();
      const card = btn.closest('[data-reel]');
      if (!card) return;
      try {
        renderReel(JSON.parse(card.dataset.reel || '{}'), card.dataset.status || 'pending');
        modal?.show();
      } catch (_) {}
    });
  });
})();
