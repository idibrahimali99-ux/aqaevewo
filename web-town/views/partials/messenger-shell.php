<?php /** @var string $activeThread */ ?>
<div class="messenger-shell<?= !empty($isAdminMessenger) ? ' messenger-shell-admin' : '' ?>"
     id="messengerApp"
     data-active-thread="<?= e($activeThread) ?>"
     data-admin="<?= !empty($isAdminMessenger) ? '1' : '0' ?>">
    <aside class="messenger-sidebar" id="messengerSidebar">
        <div class="messenger-sidebar-head">
            <div>
                <h1 class="h5 mb-0"><?= !empty($isAdminMessenger) ? 'محادثات الإدارة' : 'الرسائل' ?></h1>
                <small class="text-secondary" id="threadCountLabel">مرتبة حسب آخر نشاط</small>
            </div>
            <div class="d-flex gap-1">
                <?php if (empty($isAdminMessenger)): ?>
                    <button type="button" class="btn btn-light btn-sm rounded-circle" id="openSupportChat" title="دعم عقار تاون"><i class="fa-solid fa-headset"></i></button>
                <?php endif; ?>
                <button type="button" class="btn btn-light btn-sm rounded-circle d-lg-none" id="messengerCloseList" aria-label="إغلاق"><i class="fa-solid fa-xmark"></i></button>
            </div>
        </div>
        <div class="messenger-filters" id="threadFilters">
            <button type="button" class="messenger-filter active" data-filter="all">الكل</button>
            <button type="button" class="messenger-filter" data-filter="unread">غير مقروءة</button>
            <button type="button" class="messenger-filter" data-filter="read">مقروءة</button>
            <?php if (!empty($isAdminMessenger)): ?>
                <button type="button" class="messenger-filter" data-filter="mediated">بوساطة</button>
                <button type="button" class="messenger-filter" data-filter="direct">مباشر</button>
            <?php endif; ?>
        </div>
        <div class="messenger-search">
            <i class="fa-solid fa-magnifying-glass"></i>
            <input type="search" id="threadSearch" placeholder="بحث بالاسم أو #رقم المحادثة" autocomplete="off">
        </div>
        <div class="messenger-thread-list" id="threadList">
            <div class="messenger-skeleton"></div>
            <div class="messenger-skeleton"></div>
            <div class="messenger-skeleton"></div>
        </div>
    </aside>

    <section class="messenger-panel" id="messengerPanel">
        <div class="messenger-empty" id="messengerEmpty">
            <i class="fa-brands fa-facebook-messenger"></i>
            <h2><?= !empty($isAdminMessenger) ? 'مركز المحادثات' : 'محادثاتك' ?></h2>
            <p><?= !empty($isAdminMessenger) ? 'اختر محادثة لإدارة التواصل بين المستفسر والمعلن' : 'اختر محادثة من القائمة أو تواصل من صفحة العقار' ?></p>
            <?php if (empty($isAdminMessenger)): ?>
                <div class="d-flex flex-wrap justify-content-center gap-2 mt-2">
                    <a href="<?= e(url('/properties')) ?>" class="btn btn-light rounded-pill"><i class="fa-solid fa-house ms-1"></i> تصفح العقارات</a>
                    <button type="button" class="btn btn-primary rounded-pill" id="emptySupportBtn"><i class="fa-solid fa-headset ms-1"></i> محادثة الدعم</button>
                </div>
            <?php endif; ?>
        </div>

        <div class="messenger-room d-none" id="messengerRoom">
            <header class="messenger-room-head">
                <button type="button" class="btn btn-light btn-sm rounded-circle d-lg-none" id="messengerOpenList"><i class="fa-solid fa-arrow-right"></i></button>
                <img src="" alt="" class="messenger-room-avatar" id="roomAvatar">
                <div class="flex-grow-1 min-w-0">
                    <strong id="roomTitle">محادثة</strong>
                    <div class="small text-secondary text-truncate" id="roomSubtitle"></div>
                </div>
                <div class="messenger-room-actions">
                    <button type="button" class="btn btn-light btn-sm rounded-pill d-none" id="togglePartyInfo"><i class="fa-solid fa-id-card ms-1"></i> إظهار البيانات</button>
                    <button type="button" class="btn btn-light btn-sm rounded-pill d-none" id="copyThreadNo" title="نسخ رقم المحادثة"><i class="fa-solid fa-hashtag"></i></button>
                    <button type="button" class="btn btn-light btn-sm rounded-circle" id="messengerMinimize" title="تصغير"><i class="fa-solid fa-minus"></i></button>
                </div>
            </header>
            <div class="messenger-context d-none" id="roomContext"></div>
            <div class="messenger-parties d-none" id="roomParties"></div>
            <div class="messenger-lane-tabs d-none" id="mediatedLaneTabs">
                <button type="button" class="messenger-lane-tab active" data-lane="0"><i class="fa-solid fa-user ms-1"></i> المستفسر</button>
                <button type="button" class="messenger-lane-tab" data-lane="1"><i class="fa-solid fa-store ms-1"></i> المعلن</button>
            </div>
            <div class="messenger-messages" id="messageList"></div>
            <button type="button" class="messenger-new-chip d-none" id="newMessagesChip">رسائل جديدة</button>
            <div class="messenger-scroll-controls" aria-label="الانتقال داخل المحادثة">
                <button type="button" class="messenger-scroll-btn" id="scrollChatTop" title="أعلى المحادثة"><i class="fa-solid fa-arrow-up"></i></button>
                <button type="button" class="messenger-scroll-btn" id="scrollChatBottom" title="أسفل المحادثة"><i class="fa-solid fa-arrow-down"></i></button>
            </div>
            <div class="messenger-compose-wrap">
                <div class="messenger-emoji-panel d-none" id="emojiPanel"></div>
                <div class="messenger-record-bar d-none" id="recordBar">
                    <span class="messenger-record-dot"></span>
                    <strong id="recordTimer">0:00</strong>
                    <span>جاري التسجيل</span>
                    <button type="button" class="btn btn-light btn-sm rounded-pill" id="recordCancel">إلغاء</button>
                    <button type="button" class="btn btn-primary btn-sm rounded-pill" id="recordSend">إرسال</button>
                </div>
                <div class="messenger-attach-preview d-none" id="attachPreview"></div>
                <input type="hidden" id="sendVisibility" value="all">
                <form class="messenger-compose" id="messageForm" autocomplete="off">
                    <button type="button" class="messenger-tool-btn" id="emojiToggle" title="رموز"><i class="fa-regular fa-face-smile"></i></button>
                    <label class="messenger-attach-btn" for="chatFileInput" title="صورة أو ملف صوتي"><i class="fa-solid fa-paperclip"></i></label>
                    <input type="file" id="chatFileInput" class="d-none" accept="image/*,audio/*,video/mp4">
                    <div class="messenger-compose-field">
                        <textarea id="messageInput" rows="1" placeholder="اكتب رسالتك هنا..." aria-label="نص الرسالة"></textarea>
                        <small id="composeHint">Enter للإرسال · Shift + Enter لسطر جديد · الصق صورة مباشرة</small>
                    </div>
                    <button type="button" class="messenger-tool-btn" id="voiceBtn" title="رسالة صوتية"><i class="fa-solid fa-microphone"></i></button>
                    <button type="submit" class="messenger-send-btn" id="sendBtn">
                        <i class="fa-solid fa-paper-plane"></i>
                        <span>إرسال</span>
                    </button>
                </form>
            </div>
        </div>
    </section>
</div>

<div class="messenger-fab d-none" id="messengerFab">
    <button type="button" class="btn btn-primary rounded-pill shadow" id="messengerFabOpen">
        <i class="fa-solid fa-comments ms-1"></i> المحادثات
    </button>
</div>

<div class="messenger-toast d-none" id="messengerToast" role="status"></div>
<div class="messenger-lightbox d-none" id="imageLightbox" role="dialog" aria-modal="true">
    <button type="button" class="messenger-lightbox-close" id="lightboxClose" aria-label="إغلاق"><i class="fa-solid fa-xmark"></i></button>
    <img src="" alt="مرفق" id="lightboxImage">
</div>
<div class="messenger-drop-overlay d-none" id="dropOverlay">أفلت الصورة هنا لإرسالها</div>
