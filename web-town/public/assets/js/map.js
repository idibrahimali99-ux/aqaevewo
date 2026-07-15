(() => {
  const markers = Array.isArray(window.AQAR_MAP_MARKERS) ? window.AQAR_MAP_MARKERS : [];
  const mapEl = document.getElementById('propertiesMap');
  const listEl = document.getElementById('mapSidebarList');
  const searchEl = document.getElementById('mapSearch');
  if (!mapEl || !markers.length) return;

  const map = L.map(mapEl, { zoomControl: true }).setView([33.3152, 44.3661], 6);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    attribution: '&copy; OpenStreetMap',
  }).addTo(map);

  const layerGroup = L.layerGroup().addTo(map);
  const markerRefs = new Map();

  const popupHtml = (item) => `
    <div class="map-popup">
      <img src="${item.thumb}" alt="">
      <div>
        <strong>${item.title}</strong>
        <div class="small text-secondary">${item.governorate || ''}</div>
        <div class="fw-bold">${item.price}</div>
        <a href="${item.url}" class="btn btn-sm btn-warning rounded-pill mt-2">عرض التفاصيل</a>
      </div>
    </div>`;

  const renderList = (query = '') => {
    const q = query.trim().toLowerCase();
    const filtered = markers.filter((item) => {
      if (!q) return true;
      return `${item.title} ${item.governorate}`.toLowerCase().includes(q);
    });
    if (!listEl) return;
    listEl.innerHTML = filtered.map((item) => `
      <button type="button" class="map-list-item" data-id="${item.id}">
        <img src="${item.thumb}" alt="">
        <div>
          <strong>${item.title}</strong>
          <span>${item.governorate || '—'}</span>
          <small>${item.price}</small>
        </div>
      </button>`).join('');

    listEl.querySelectorAll('[data-id]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const ref = markerRefs.get(btn.dataset.id);
        if (ref) {
          map.setView(ref.getLatLng(), 15, { animate: true });
          ref.openPopup();
        }
      });
    });
  };

  markers.forEach((item) => {
    const marker = L.marker([item.lat, item.lng]).bindPopup(popupHtml(item));
    marker.addTo(layerGroup);
    markerRefs.set(item.id, marker);
  });

  if (markers.length === 1) {
    map.setView([markers[0].lat, markers[0].lng], 14);
  } else {
    const bounds = L.latLngBounds(markers.map((m) => [m.lat, m.lng]));
    map.fitBounds(bounds.pad(0.12));
  }

  renderList();
  searchEl?.addEventListener('input', () => renderList(searchEl.value));
  setTimeout(() => map.invalidateSize(), 120);
})();
