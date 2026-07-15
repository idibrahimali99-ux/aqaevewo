<div class="container-xl py-4 py-lg-5">

    <?php require __DIR__ . '/../partials/property-detail-full.php'; ?>

    <?php if (!empty($_GET['error'])): ?>

        <div class="alert alert-danger mt-3 rounded-4"><?= e((string) $_GET['error']) ?></div>

    <?php endif; ?>

</div>

<?php if ($coords = property_coordinates($property)): ?>

<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">

<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>

<script>

document.addEventListener('DOMContentLoaded', () => {

  const el = document.getElementById('propertyDetailMap');

  if (!el || typeof L === 'undefined') return;

  const lat = parseFloat(el.dataset.lat);

  const lng = parseFloat(el.dataset.lng);

  const map = L.map(el).setView([lat, lng], 15);

  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 19 }).addTo(map);

  L.marker([lat, lng]).addTo(map);

  setTimeout(() => map.invalidateSize(), 150);

});

</script>

<?php endif; ?>

