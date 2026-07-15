(() => {

  const modalEl = document.getElementById('adminPropertyModal');

  const bodyEl = document.getElementById('adminPropertyModalBody');

  const actionsEl = document.getElementById('adminPropertyModalActions');

  if (!modalEl || !bodyEl || !actionsEl) return;



  const modal = window.bootstrap ? new window.bootstrap.Modal(modalEl) : null;

  const base = document.querySelector('meta[name="app-base"]')?.content || '';

  const csrf = document.querySelector('meta[name="csrf-token"]')?.content || '';

  const sectionUrl = document.body.dataset.adminSectionUrl || '';



  const purposeLabel = (v) => ({ sale: 'للبيع', rent: 'للإيجار' }[String(v || '').toLowerCase()] || v || 'عقار');
  const categoryLabel = (v) => ({
    house: 'بيت', apartment: 'شقة', villa: 'فيلا', land: 'أرض', shop: 'محل', compound: 'مجمع',
  }[String(v || '').toLowerCase()] || v || '');

  const escapeHtml = (s) => String(s).replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));



  const imagesFromProperty = (property) => {

    const images = [];

    const raw = String(property.image_urls_raw || '');

    if (raw) raw.split('|||').forEach((url) => { url = url.trim(); if (url) images.push(url); });

    if (Array.isArray(property.image_urls)) property.image_urls.forEach((url) => { if (url && !images.includes(url)) images.push(url); });

    if (property.thumb_url && !images.includes(property.thumb_url)) images.unshift(property.thumb_url);

    return images.length ? images : [`${base}/assets/images/placeholder-property.svg`];

  };



  const coordsFromProperty = (property) => {

    let lat = null;

    let lng = null;

    if (property.lat != null && property.lng != null) {

      lat = Number(property.lat);

      lng = Number(property.lng);

    } else if (property.details_json) {

      try {

        const details = typeof property.details_json === 'string'

          ? JSON.parse(property.details_json)

          : property.details_json;

        lat = Number(details?.location?.lat);

        lng = Number(details?.location?.lng);

      } catch (_) {}

    }

    return Number.isFinite(lat) && Number.isFinite(lng) ? { lat, lng } : null;

  };



  let mapInstance = null;

  const destroyMap = () => {

    if (mapInstance) {

      mapInstance.remove();

      mapInstance = null;

    }

  };



  const initMap = (coords) => {

    if (!coords || !window.L) return;

    const mapEl = document.getElementById('adminPropertyMap');

    if (!mapEl) return;

    destroyMap();

    mapInstance = window.L.map(mapEl).setView([coords.lat, coords.lng], 15);

    window.L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {

      maxZoom: 19,

      attribution: '&copy; OpenStreetMap',

    }).addTo(mapInstance);

    window.L.marker([coords.lat, coords.lng]).addTo(mapInstance);

    setTimeout(() => mapInstance?.invalidateSize(), 200);

  };



  const renderActions = (property, status) => {
    const id = property.id || '';
    if (status === 'pending') {
      actionsEl.innerHTML = `
        <button type="button" class="btn btn-light rounded-pill" data-bs-dismiss="modal">رجوع</button>
        <button type="button" class="btn btn-outline-danger rounded-pill" data-bs-toggle="collapse" data-bs-target="#adminRejectForm">رفض</button>
        <form method="post" action="${escapeHtml(sectionUrl)}" class="d-inline">
          <input type="hidden" name="_csrf" value="${escapeHtml(csrf)}">
          <input type="hidden" name="_operation" value="approve">
          <input type="hidden" name="id" value="${escapeHtml(id)}">
          <button type="submit" class="btn btn-success rounded-pill">موافقة ونشر</button>
        </form>
        <div class="collapse w-100 mt-2" id="adminRejectForm">
          <form method="post" action="${escapeHtml(sectionUrl)}" class="row g-2 p-3 rounded-4 bg-light">
            <input type="hidden" name="_csrf" value="${escapeHtml(csrf)}">
            <input type="hidden" name="_operation" value="reject">
            <input type="hidden" name="id" value="${escapeHtml(id)}">
            <div class="col-12"><input class="form-control" name="reject_note" placeholder="سبب الرفض" required></div>
            <div class="col-12"><label class="small"><input type="checkbox" name="resubmission_allowed" value="1"> السماح بإعادة الإرسال</label></div>
            <div class="col-12"><button type="submit" class="btn btn-danger rounded-pill">تأكيد الرفض</button></div>
          </form>
        </div>`;
      return;
    }
    const publicLink = id ? `<a href="${base}/property/${encodeURIComponent(id)}" target="_blank" class="btn btn-outline-primary rounded-pill">صفحة العرض</a>` : '';
    const soldBtn = (status === 'unsold' && !property.is_sold) ? `
      <form method="post" action="${escapeHtml(sectionUrl)}" class="d-inline">
        <input type="hidden" name="_csrf" value="${escapeHtml(csrf)}">
        <input type="hidden" name="_operation" value="mark_sold">
        <input type="hidden" name="id" value="${escapeHtml(id)}">
        <button type="submit" class="btn btn-outline-secondary rounded-pill">تم البيع</button>
      </form>` : '';
    actionsEl.innerHTML = `
      <button type="button" class="btn btn-light rounded-pill" data-bs-dismiss="modal">إغلاق</button>
      ${publicLink}
      ${soldBtn}
      <form method="post" action="${escapeHtml(sectionUrl)}" class="d-inline" onsubmit="return confirm('حذف هذا المنشور؟');">
        <input type="hidden" name="_csrf" value="${escapeHtml(csrf)}">
        <input type="hidden" name="_operation" value="delete">
        <input type="hidden" name="id" value="${escapeHtml(id)}">
        <button type="submit" class="btn btn-outline-danger rounded-pill">حذف</button>
      </form>`;
  };



  const renderDetail = (property, status) => {

    const images = imagesFromProperty(property);

    const publicNo = property.property_public_no ? `#${property.property_public_no}` : '';

    const owner = property.office_name || property.owner_office_name || property.owner_name || property.owner_full_name || 'ناشر';

    const coords = coordsFromProperty(property);

    const video = property.video_url ? String(property.video_url).trim() : '';

    const gallery = images.map((img, i) => `

      <div class="carousel-item${i === 0 ? ' active' : ''}">

        <div class="ratio ratio-16x9"><img src="${escapeHtml(img)}" class="object-fit-cover" alt=""></div>

      </div>`).join('');



    bodyEl.innerHTML = `

      <div class="property-detail-full property-detail-compact">

        <div id="adminPropertyGallery" class="carousel slide property-gallery rounded-4 overflow-hidden mb-3">

          <div class="carousel-inner">${gallery}</div>

          ${images.length > 1 ? `

            <button class="carousel-control-prev" type="button" data-bs-target="#adminPropertyGallery" data-bs-slide="prev"><span class="carousel-control-prev-icon"></span></button>

            <button class="carousel-control-next" type="button" data-bs-target="#adminPropertyGallery" data-bs-slide="next"><span class="carousel-control-next-icon"></span></button>` : ''}

        </div>

        ${video ? `<div class="ratio ratio-16x9 rounded-4 overflow-hidden mb-3"><video src="${escapeHtml(video)}" controls playsinline class="w-100 h-100 object-fit-cover"></video></div>` : ''}

        ${coords ? '<div class="property-detail-map rounded-4 overflow-hidden mb-3" id="adminPropertyMap"></div>' : ''}

        <div class="d-flex flex-wrap gap-2 mb-2">

          ${publicNo ? `<button type="button" class="property-public-no property-public-no-lg" data-copy-text="${escapeHtml(publicNo.startsWith('#') ? publicNo : '#' + publicNo)}">${escapeHtml(publicNo.startsWith('#') ? publicNo : '#' + publicNo)}</button>` : ''}

          <span class="badge rounded-pill text-bg-warning">${escapeHtml(purposeLabel(property.purpose))}</span>

          <span class="badge rounded-pill text-bg-light border">${escapeHtml(categoryLabel(property.category))}</span>

        </div>

        <h2 class="h4">${escapeHtml(property.title || 'منشور')}</h2>

        <p class="text-secondary">${escapeHtml(`${property.governorate || ''} ${property.address_line || ''}`.trim())}</p>

        <div class="property-detail-price mb-3">${escapeHtml(String(property.price_iqd || 'السعر عند الاتصال'))} ${property.price_iqd ? 'د.ع' : ''}</div>

        <div class="property-owner-card mb-3"><div class="small text-secondary">الناشر</div><strong>${escapeHtml(owner)}</strong>

          ${property.owner_phone ? `<div class="small mt-1">${escapeHtml(property.owner_phone)}</div>` : ''}</div>

        ${property.area_sqm ? `<div class="mb-2"><strong>المساحة:</strong> ${escapeHtml(String(property.area_sqm))} م²</div>` : ''}

        ${property.description ? `<div class="property-description"><div class="small text-secondary">الوصف</div><p>${escapeHtml(property.description).replace(/\n/g, '<br>')}</p></div>` : ''}

      </div>`;



    renderActions(property, status);

    if (coords) initMap(coords);

  };



  modalEl.addEventListener('hidden.bs.modal', destroyMap);



  document.querySelectorAll('[data-property-open]').forEach((btn) => {

    btn.addEventListener('click', (e) => {

      e.preventDefault();

      e.stopPropagation();

      const card = btn.closest('[data-property]');

      if (!card) return;

      try {

        const property = JSON.parse(card.dataset.property || '{}');

        renderDetail(property, card.dataset.status || 'pending');

        modal?.show();

      } catch (_) {}

    });

  });

})();

