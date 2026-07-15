<?php
/** @var array<string,mixed>|null $user */
$currentSection = (string) ($currentSection ?? 'overview');
$visibleSections = admin_visible_sections();
$groups = [];
foreach ($visibleSections as $key => $section) {
    $groups[(string) ($section['group'] ?? 'أخرى')][$key] = $section;
}
$iconMap = [
    'overview' => 'fa-gauge-high',
    'promotions' => 'fa-bullhorn',
    'news' => 'fa-newspaper',
    'offices' => 'fa-store',
    'governorates' => 'fa-map-location-dot',
    'parcels' => 'fa-border-all',
    'compounds' => 'fa-city',
    'properties' => 'fa-house-chimney',
    'reels' => 'fa-clapperboard',
    'property_requests' => 'fa-clipboard-list',
    'chats' => 'fa-comments',
    'chat_room' => 'fa-comment-dots',
    'users' => 'fa-users',
    'user_profile' => 'fa-id-card',
    'marketers' => 'fa-user-tie',
    'posting_packages' => 'fa-box-open',
    'reports' => 'fa-chart-line',
    'notifications' => 'fa-bell',
    'settings' => 'fa-gear',
];
?>
<aside class="admin-sidebar" id="adminSidebar">
    <div class="sidebar-brand">
        <a href="<?= e(url('/admin')) ?>">
            <span class="sidebar-logo"><i class="fa-solid fa-building"></i></span>
            <span class="sidebar-text"><strong>Aqar Town</strong><small>Admin Console</small></span>
        </a>
        <button type="button" class="sidebar-collapse-btn" id="sidebarCollapse" aria-label="طي القائمة"><i class="fa-solid fa-angles-right"></i></button>
    </div>
    <div class="sidebar-user">
        <strong><?= e((string) (auth_user()['full_name'] ?? '')) ?></strong>
        <span><?= e((string) (auth_user()['role'] ?? '')) ?></span>
    </div>
    <nav class="sidebar-nav">
        <?php foreach ($groups as $group => $sections): ?>
            <div class="nav-group-label"><?= e($group) ?></div>
            <?php foreach ($sections as $key => $section): ?>
                <?php $icon = $iconMap[$key] ?? 'fa-circle'; ?>
                <a class="sidebar-link <?= $currentSection === $key ? 'active' : '' ?>" href="<?= e(url('/admin/' . $key)) ?>" title="<?= e((string) $section['label']) ?>">
                    <i class="fa-solid <?= e($icon) ?>"></i>
                    <span><?= e((string) $section['label']) ?></span>
                </a>
            <?php endforeach; ?>
        <?php endforeach; ?>
    </nav>
    <div class="sidebar-footer">
        <a href="<?= e(url('/')) ?>"><i class="fa-solid fa-globe"></i><span>الموقع</span></a>
        <a href="<?= e(url('/logout')) ?>"><i class="fa-solid fa-right-from-bracket"></i><span>خروج</span></a>
    </div>
</aside>
