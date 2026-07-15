(() => {
  const modalEl = document.getElementById('adminOfficeModal');
  const bodyEl = document.getElementById('adminOfficeModalBody');
  const actionsEl = document.getElementById('adminOfficeModalActions');
  if (!modalEl || !bodyEl || !actionsEl) return;

  const modal = window.bootstrap ? new window.bootstrap.Modal(modalEl) : null;
  const csrf = document.querySelector('meta[name="csrf-token"]')?.content || '';
  const sectionUrl = document.body.dataset.adminSectionUrl || '';

  const escapeHtml = (s) => String(s).replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));

  const renderOffice = (office, scope) => {
    const profile = office.profile_photo_url || '';
    const officePhoto = office.office_photo_url || '';
    const isMarketer = office.is_marketer === 1 || office.is_marketer === true || office.is_marketer === '1';
    const verified = office.office_verified === 1 || office.office_verified === true || office.office_verified === '1';
    const uid = office.id || '';

    bodyEl.innerHTML = `
      <div class="row g-3 mb-3">
        ${profile ? `<div class="col-6"><div class="small text-secondary mb-1">صورة شخصية</div><img src="${escapeHtml(profile)}" class="admin-preview-photo rounded-4" alt=""></div>` : ''}
        ${officePhoto ? `<div class="col-6"><div class="small text-secondary mb-1">صورة المكتب</div><img src="${escapeHtml(officePhoto)}" class="admin-preview-photo rounded-4" alt=""></div>` : ''}
      </div>
      <div class="admin-detail-grid">
        <div><span>اسم المكتب</span><strong>${escapeHtml(office.office_name || '—')}</strong></div>
        <div><span>المالك</span><strong>${escapeHtml(office.full_name || '—')}</strong></div>
        <div><span>الهاتف</span><strong dir="ltr">${escapeHtml(office.phone || '—')}</strong></div>
        <div><span>البريد</span><strong>${escapeHtml(office.email || '—')}</strong></div>
        <div><span>العنوان</span><strong>${escapeHtml(office.office_address || '—')}</strong></div>
        <div><span>رقم الإجازة</span><strong>${escapeHtml(office.office_license_no || '—')}</strong></div>
        <div><span>نوع الحساب</span><strong>${isMarketer ? 'مسوق' : 'مكتب'}</strong></div>
        <div><span>تاريخ التسجيل</span><strong>${escapeHtml(office.created_at || '—')}</strong></div>
      </div>`;

    if (scope === 'pending') {
      actionsEl.innerHTML = `
        <button type="button" class="btn btn-light rounded-pill" data-bs-dismiss="modal">رجوع</button>
        <form method="post" action="${escapeHtml(sectionUrl)}" class="d-inline">
          <input type="hidden" name="_csrf" value="${escapeHtml(csrf)}">
          <input type="hidden" name="_operation" value="approve">
          <input type="hidden" name="user_id" value="${escapeHtml(uid)}">
          <button type="submit" class="btn btn-success rounded-pill">موافقة على المكتب</button>
        </form>`;
    } else {
      actionsEl.innerHTML = `
        <button type="button" class="btn btn-light rounded-pill" data-bs-dismiss="modal">إغلاق</button>
        <form method="post" action="${escapeHtml(sectionUrl)}" class="d-inline">
          <input type="hidden" name="_csrf" value="${escapeHtml(csrf)}">
          <input type="hidden" name="_operation" value="set_verified">
          <input type="hidden" name="user_id" value="${escapeHtml(uid)}">
          <input type="hidden" name="verified" value="${verified ? '0' : '1'}">
          <button type="submit" class="btn btn-${verified ? 'outline-secondary' : 'warning'} rounded-pill">
            ${verified ? 'إلغاء التوثيق' : 'توثيق المكتب'}
          </button>
        </form>`;
    }
  };

  document.querySelectorAll('[data-office-open]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const row = btn.closest('[data-office]');
      if (!row) return;
      try {
        const office = JSON.parse(row.dataset.office || '{}');
        renderOffice(office, row.dataset.scope || 'pending');
        modal?.show();
      } catch (_) {}
    });
  });
})();
