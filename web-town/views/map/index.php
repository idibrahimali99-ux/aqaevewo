<?php

/** @var list<array<string,mixed>> $items */

/** @var list<array<string,mixed>> $markers */

$markerJson = json_encode($markers, JSON_UNESCAPED_UNICODE | JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT);

?>

<div class="map-page">

    <div class="map-page-head container-xl py-4">

        <div class="d-flex flex-wrap justify-content-between align-items-end gap-3">

            <div>

                <h1 class="section-title mb-1">خريطة العقارات</h1>

                <p class="text-secondary mb-0">

                    <?= e((string) count($markers)) ?> عقار على الخريطة من أصل <?= e((string) count($items)) ?> منشور

                </p>

            </div>

            <div class="d-flex gap-2 flex-wrap">

                <span class="badge rounded-pill text-bg-light border px-3 py-2"><i class="fa-solid fa-location-dot ms-1"></i> OpenStreetMap</span>

                <?php if ($mapsKey !== ''): ?>

                    <span class="badge rounded-pill text-bg-warning px-3 py-2">Google Maps متاح</span>

                <?php endif; ?>

            </div>

        </div>

    </div>



    <?php if (!empty($error)): ?>

        <div class="container-xl pb-3">

            <div class="alert alert-danger rounded-4 border-0"><?= e($error) ?></div>

        </div>

    <?php endif; ?>



    <?php if ($markers === []): ?>

        <div class="container-xl pb-5">

            <div class="alert alert-info rounded-4 border-0">

                لا توجد إحداثيات GPS في المنشورات الحالية. تأكد أن العقارات تحتوي موقعاً داخل <code>details_json.location</code>.

            </div>

            <div class="row g-3">

                <?php foreach ($items as $property): ?>

                    <div class="col-md-4"><?php require __DIR__ . '/../partials/property-card.php'; ?></div>

                <?php endforeach; ?>

            </div>

        </div>

    <?php else: ?>

        <div class="map-shell">

            <aside class="map-sidebar" id="mapSidebar">

                <div class="map-sidebar-head">

                    <strong>العقارات على الخريطة</strong>

                    <input type="search" class="form-control form-control-sm rounded-pill mt-2" id="mapSearch" placeholder="بحث بالعنوان أو المحافظة">

                </div>

                <div class="map-sidebar-list" id="mapSidebarList"></div>

            </aside>

            <div id="propertiesMap" class="map-canvas"></div>

        </div>

        <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">

        <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>

        <script>window.AQAR_MAP_MARKERS = <?= $markerJson ?: '[]' ?>;</script>

        <script src="<?= e(asset_url('js/map.js')) ?>"></script>

    <?php endif; ?>

</div>

