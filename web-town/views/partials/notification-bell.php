<?php if (!is_logged_in()): return; endif; ?>
<div class="dropdown notification-dropdown">
    <button class="btn btn-link text-dark position-relative nav-icon-btn" type="button" data-bs-toggle="dropdown" data-bs-auto-close="outside" aria-expanded="false" id="notificationBellBtn" title="الإشعارات">
        <i class="fa-solid fa-bell"></i>
        <span class="notif-count-badge d-none" id="notificationCountBadge">0</span>
    </button>
    <div class="dropdown-menu dropdown-menu-end notification-panel p-0 shadow-lg border-0" id="notificationDropdownPanel">
        <div class="notification-panel-head">
            <strong>الإشعارات</strong>
            <a href="<?= e(url('/notifications')) ?>" class="small">عرض الكل</a>
        </div>
        <div class="notification-panel-list" id="notificationDropdownList">
            <div class="notification-panel-empty text-secondary small">جاري التحميل...</div>
        </div>
    </div>
</div>
