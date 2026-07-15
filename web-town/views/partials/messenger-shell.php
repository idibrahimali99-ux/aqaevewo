<?php /** @var string $activeThread */ ?>
<div class="messenger-shell<?= !empty($isAdminMessenger) ? ' messenger-shell-admin' : '' ?>"
     id="messengerApp"
     data-active-thread="<?= e($activeThread) ?>"
     data-admin="<?= !empty($isAdminMessenger) ? '1' : '0' ?>">
    <aside class="messenger-sidebar" id="messengerSidebar">
        <div class="messenger-sidebar-head">
            <div>
                <h1 class="h5 mb-0"><?= !empty($isAdminMessenger) ? 'محادثات الإدارة' : 'الرسائل' ?></h1>
                <small class="text-secondary">مرتبة حسب آخر نشاط</small>
            </div>
            <button type="button" class="btn btn-light btn-sm rounded-circle d-lg-none" id="messengerCloseList" aria-label="إغلاق"><i class="fa-solid fa-xmark"></i></button>
        </div>
        <div class="messenger-filters" id="threadFilters">
            <button type="button" class="messenger-filter active" data-filter="all">الكل</button>
            <button type="button" class="messenger-filter" data-filter="unread">غير مقروءة</button>
            <button type="button" class="messenger-filter" data-filter="read">مقروءة</button>
        </div>
        <div class="messenger-search">
            <i class="fa-solid fa-magnifying-glass"></i>
            <input type="search" id="threadSearch" placeholder="بحث أو #رقم المحادثة">
        </div>
        <div class="messenger-thread-list" id="threadList">
            <div class="messenger-skeleton"></div>
            <div class="messenger-skeleton"></div>
        </div>
    </aside>

    <section class="messenger-panel" id="messengerPanel">
        <div class="messenger-empty" id="messengerEmpty">
            <i class="fa-brands fa-facebook-messenger"></i>
            <h2><?= !empty($isAdminMessenger) ? 'مركز المحادثات' : 'محادثاتك' ?></h2>
            <p><?= !empty($isAdminMessenger) ? 'اختر محادثة لإدارة التواصل بين المستفسر والمعلن' : 'اختر محادثة من القائمة أو تواصل من صفحة العقار' ?></p>
        </div>

        <div class="messenger-room d-none" id="messengerRoom">
            <header class="messenger-room-head">
                <button type="button" class="btn btn-light btn-sm rounded-circle d-lg-none" id="messengerOpenList"><i class="fa-solid fa-arrow-right"></i></button>
                <img src="" alt="" class="messenger-room-avatar" id="roomAvatar">
                <div class="flex-grow-1 min-w-0">
                    <strong id="roomTitle">محادثة</strong>
                    <div class="small text-secondary text-truncate" id="roomSubtitle"></div>
                </div>
                <button type="button" class="btn btn-light btn-sm rounded-pill" id="messengerMinimize" title="تصغير"><i class="fa-solid fa-minus"></i></button>
            </header>
            <div class="messenger-context d-none" id="roomContext"></div>
            <div class="messenger-parties d-none" id="roomParties"></div>
            <div class="messenger-lane-tabs d-none" id="mediatedLaneTabs">
                <button type="button" class="messenger-lane-tab active" data-lane="0"><i class="fa-solid fa-user ms-1"></i> المستفسر</button>
                <button type="button" class="messenger-lane-tab" data-lane="1"><i class="fa-solid fa-store ms-1"></i> المعلن</button>
            </div>
            <div class="messenger-messages" id="messageList"></div>
            <input type="hidden" id="sendVisibility" value="customer_only">
            <form class="messenger-compose" id="messageForm">
                <label class="btn btn-light btn-sm rounded-circle mb-0" for="chatFileInput" title="مرفق"><i class="fa-solid fa-paperclip"></i></label>
                <input type="file" id="chatFileInput" class="d-none" accept="image/*,audio/*">
                <input type="text" id="messageInput" placeholder="اكتب رسالة..." autocomplete="off">
                <button type="submit" class="btn btn-primary rounded-circle"><i class="fa-solid fa-paper-plane"></i></button>
            </form>
        </div>
    </section>
</div>

<div class="messenger-fab d-none" id="messengerFab">
    <button type="button" class="btn btn-primary rounded-pill shadow" id="messengerFabOpen">
        <i class="fa-solid fa-comments ms-1"></i> المحادثات
    </button>
</div>
