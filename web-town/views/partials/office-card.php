<?php
/** @var array<string,mixed> $office */
$officeName = (string) pick($office, 'office_name', pick($office, 'full_name', 'مكتب عقاري'));
$isMarketer = !empty($office['is_marketer']);
?>
<article class="card">
    <div class="card-body">
        <span class="pill"><?= $isMarketer ? 'مسوق عقاري' : 'مكتب عقاري' ?></span>
        <h3><?= e($officeName) ?></h3>
        <p class="muted"><?= e((string) pick($office, 'office_address', pick($office, 'governorate', 'العراق'))) ?></p>
        <p class="muted">العقارات: <?= e(compact_number($office['properties_count'] ?? $office['property_count'] ?? 0)) ?></p>
    </div>
</article>
