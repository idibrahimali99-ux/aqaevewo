(() => {
  const app = document.getElementById('messengerApp');
  if (!app) return;

  const base = document.querySelector('meta[name="app-base"]')?.content || '';
  const csrf = document.querySelector('meta[name="csrf-token"]')?.content || '';
  const meId = document.body.dataset.userId || '';
  const meRole = document.body.dataset.userRole || '';
  const isAdmin = app.dataset.admin === '1';
  const apiBase = isAdmin ? '/admin/api/chat' : '/messages/api';
  const EMOJIS = ['😀', '😁', '😂', '😍', '🤩', '👍', '🙏', '🔥', '❤️', '👏', '👌', '🏠', '📍', '💰', '✅', '❌', '📞', '📷', '🎉', '🤝'];

  let activeThread = app.dataset.activeThread || '';
  let threads = [];
  let allMessages = [];
  let threadFilter = 'all';
  let mediatedLaneTab = 0;
  let currentThreadMeta = {};
  let currentThreadRow = {};
  let pollThreads = null;
  let pollMessages = null;
  let searchTimer = null;
  let stickToBottom = true;
  let lastMsgSig = '';
  let partiesRevealed = false;
  let mediaRecorder = null;
  let audioChunks = [];
  let recordStartedAt = 0;
  let recordTimer = null;
  let recordStream = null;

  const el = (id) => document.getElementById(id);
  const url = (path) => `${base}${path}`;

  const showToast = (text, danger = false) => {
    const box = el('messengerToast');
    if (!box) return;
    box.textContent = text;
    box.classList.toggle('is-danger', danger);
    box.classList.remove('d-none');
    clearTimeout(showToast._t);
    showToast._t = setTimeout(() => box.classList.add('d-none'), 2800);
  };

  const fetchJson = async (path, options = {}) => {
    const headers = { Accept: 'application/json', ...(options.headers || {}) };
    if (options.method && options.method !== 'GET') {
      headers['X-CSRF-Token'] = csrf;
      if (!(options.body instanceof FormData)) {
        headers['Content-Type'] = 'application/json';
      }
    }
    try {
      const res = await fetch(url(path), { credentials: 'same-origin', ...options, headers });
      const text = await res.text();
      let data = {};
      try {
        data = JSON.parse(text);
      } catch (_) {
        data = { ok: false, error: res.status === 401 ? 'انتهت الجلسة، سجّل الدخول من جديد' : 'استجابة غير صالحة من الخادم' };
      }
      if (res.status === 401) {
        data.ok = false;
        data.error = data.error || 'انتهت الجلسة';
      }
      return data;
    } catch (_) {
      return { ok: false, error: 'تعذر الاتصال، تحقق من الشبكة' };
    }
  };

  const escapeHtml = (s) => String(s).replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));

  const parseDate = (value) => {
    if (!value) return null;
    const d = new Date(String(value).replace(' ', 'T'));
    return Number.isNaN(d.getTime()) ? null : d;
  };

  const formatTime = (value) => {
    const d = parseDate(value);
    if (!d) return '';
    return d.toLocaleString('ar-IQ', { hour: '2-digit', minute: '2-digit' });
  };

  const formatDay = (value) => {
    const d = parseDate(value);
    if (!d) return '';
    const today = new Date();
    const yest = new Date();
    yest.setDate(today.getDate() - 1);
    const same = (a, b) => a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    if (same(d, today)) return 'اليوم';
    if (same(d, yest)) return 'أمس';
    return d.toLocaleDateString('ar-IQ', { weekday: 'long', day: 'numeric', month: 'long' });
  };

  const dayKey = (value) => {
    const d = parseDate(value);
    if (!d) return '';
    return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
  };

  const formatListTime = (value) => {
    const d = parseDate(value);
    if (!d) return '';
    const now = new Date();
    const sameDay = d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth() && d.getDate() === now.getDate();
    if (sameDay) return d.toLocaleTimeString('ar-IQ', { hour: '2-digit', minute: '2-digit' });
    return d.toLocaleDateString('ar-IQ', { day: 'numeric', month: 'short' });
  };

  const linkify = (text) => escapeHtml(text).replace(
    /(https?:\/\/[^\s<]+)/g,
    '<a href="$1" target="_blank" rel="noopener noreferrer">$1</a>',
  );

  const waLink = (phone) => {
    const digits = String(phone || '').replace(/\D/g, '');
    if (digits.length < 8) return '';
    let n = digits;
    if (n.startsWith('0')) n = `964${n.slice(1)}`;
    else if (!n.startsWith('964')) n = `964${n}`;
    return `https://wa.me/${n}`;
  };

  const threadTitle = (row, revealNames = false) => {
    if (isAdmin) {
      const customer = (row.customer_display_name || row.customer_name || '').trim();
      const office = (row.office_display_name || row.office_name || '').trim();
      const pub = row.thread_public_no ? `#${row.thread_public_no}` : '';
      const prop = (row.property_title || '').trim();
      if (revealNames && (customer || office)) {
        if (customer && office) return `${customer} ↔ ${office}${pub ? ' · ' + pub : ''}`;
        return customer || office || pub || 'محادثة';
      }
      if (prop && pub) return `${prop} · ${pub}`;
      return prop || pub || 'محادثة';
    }
    const prop = (row.property_title || '').trim();
    const peer = (row.admin_name || row.office_display_name || row.office_name || 'عقار تاون').trim();
    const first = (row.first_sender_name || '').trim();
    if (prop) return `${prop} · ${peer}`;
    if (first) return first;
    return peer || 'محادثة';
  };

  const threadSubtitle = (row) => (row.last_message_preview || row.property_title || '').trim() || 'بدون رسائل بعد';
  const threadAvatar = (row) => (row.property_thumb_url || '').trim() || `${base}/assets/images/placeholder-property.svg`;
  const threadType = (row) => String(row.thread_type || currentThreadMeta.thread_type || '').toLowerCase();

  const useMediatedTabs = (meta = currentThreadMeta) => {
    if (!isAdmin) return false;
    const cid = String(meta.customer_user_id || '');
    const oid = String(meta.office_user_id || '');
    return cid !== '' && oid !== '';
  };

  const msgCustomerTab = (msg, meta) => {
    const sid = String(msg.sender_user_id || '');
    const vis = String(msg.visibility || 'all');
    const cid = String(meta.customer_user_id || '');
    const oid = String(meta.office_user_id || '');
    if (sid === cid) return true;
    if (sid === oid) return false;
    if (vis === 'customer_only') return true;
    if (vis === 'office_only') return false;
    return vis === 'all';
  };

  const msgOfficeTab = (msg, meta) => {
    const sid = String(msg.sender_user_id || '');
    const vis = String(msg.visibility || 'all');
    const cid = String(meta.customer_user_id || '');
    const oid = String(meta.office_user_id || '');
    if (sid === oid) return true;
    if (sid === cid) return false;
    if (vis === 'office_only') return true;
    if (vis === 'customer_only') return false;
    return false;
  };

  const visibleMessages = () => {
    if (!isAdmin || !useMediatedTabs(currentThreadMeta)) return allMessages;
    return allMessages.filter((msg) => (
      mediatedLaneTab === 0 ? msgCustomerTab(msg, currentThreadMeta) : msgOfficeTab(msg, currentThreadMeta)
    ));
  };

  const filteredThreads = () => threads.filter((row) => {
    const unread = Number(row.unread_count || 0);
    const type = String(row.thread_type || '').toLowerCase();
    if (threadFilter === 'unread') return unread > 0;
    if (threadFilter === 'read') return unread === 0;
    if (threadFilter === 'mediated') return type === 'mediated';
    if (threadFilter === 'direct') return type === 'direct';
    return true;
  });

  const updateUnreadChrome = () => {
    const total = threads.reduce((sum, row) => sum + (Number(row.unread_count || 0) > 0 ? 1 : 0), 0);
    const label = el('threadCountLabel');
    if (label) {
      label.textContent = total > 0 ? `${total} غير مقروءة` : 'مرتبة حسب آخر نشاط';
    }
    const baseTitle = isAdmin ? 'محادثات الإدارة' : 'الرسائل';
    document.title = total > 0 ? `(${total}) ${baseTitle} | عقار تاون` : `${baseTitle} | عقار تاون`;
  };

  const renderThreads = () => {
    const rows = filteredThreads();
    const threadList = el('threadList');
    if (!rows.length) {
      threadList.innerHTML = '<div class="text-center text-secondary py-5">لا توجد محادثات</div>';
      updateUnreadChrome();
      return;
    }
    threadList.innerHTML = rows.map((row) => {
      const id = row.id || '';
      const unread = Number(row.unread_count || 0);
      const type = String(row.thread_type || '').toLowerCase();
      const typeBadge = type === 'direct'
        ? '<span class="messenger-type-badge is-direct">مباشر</span>'
        : (type === 'mediated' ? '<span class="messenger-type-badge is-mediated">بوساطة</span>' : '');
      return `<button type="button" class="messenger-thread${id === activeThread ? ' active' : ''}${unread > 0 ? ' is-unread' : ''}" data-thread="${id}">
        <img src="${threadAvatar(row)}" alt="">
        <div class="messenger-thread-body">
          <strong>${escapeHtml(threadTitle(row))}</strong>
          <span>${escapeHtml(threadSubtitle(row))}</span>
        </div>
        <div class="messenger-thread-meta">
          <div>${formatListTime(row.last_message_at || row.created_at)}</div>
          ${typeBadge}
          ${unread > 0 ? `<span class="messenger-unread">${unread > 99 ? '99+' : unread}</span>` : ''}
        </div>
      </button>`;
    }).join('');
    threadList.querySelectorAll('[data-thread]').forEach((btn) => {
      btn.addEventListener('click', () => openThread(btn.dataset.thread));
    });
    updateUnreadChrome();
  };

  const loadThreads = async (silent = false) => {
    const q = el('threadSearch')?.value?.trim() || '';
    const query = q ? `?q=${encodeURIComponent(q)}` : '';
    const data = await fetchJson(`${apiBase}/threads${query}`);
    if (!data.ok) {
      if (!silent) el('threadList').innerHTML = `<div class="alert alert-danger m-3">${escapeHtml(data.error || 'تعذر التحميل')}</div>`;
      return;
    }
    threads = data.items || [];
    renderThreads();
  };

  const isMineMessage = (msg) => {
    if (msg.mine === true) return true;
    if (String(msg.sender_user_id || '') === meId) return true;
    if (isAdmin) {
      const role = String(msg.sender_role || '').toLowerCase();
      return role === 'admin' || role === 'staff';
    }
    return false;
  };

  const renderMedia = (msg) => {
    const media = (msg.media_public_url || '').trim();
    if (!media) return '';
    const type = String(msg.media_type || '').toLowerCase();
    if (type === 'audio' || /\.(mp3|m4a|wav|ogg|webm)(\?|$)/i.test(media)) {
      return `<audio controls preload="metadata" src="${escapeHtml(media)}"></audio>`;
    }
    if (type === 'video' || /\.(mp4|webm|mov)(\?|$)/i.test(media)) {
      return `<video controls preload="metadata" src="${escapeHtml(media)}"></video>`;
    }
    return `<a href="${escapeHtml(media)}" class="messenger-image-link" data-full="${escapeHtml(media)}"><img src="${escapeHtml(media)}" alt="مرفق"></a>`;
  };

  const visibilityLabel = (vis) => {
    if (!isAdmin) return '';
    if (vis === 'customer_only') return 'للمستفسر فقط';
    if (vis === 'office_only') return 'للمعلن فقط';
    return '';
  };

  const syncPartyVisibility = () => {
    const btn = el('togglePartyInfo');
    const box = el('roomParties');
    const grid = el('partiesDetails');
    const mediated = isAdmin && useMediatedTabs(currentThreadMeta);
    if (btn) {
      btn.classList.toggle('d-none', !mediated);
      btn.innerHTML = partiesRevealed
        ? '<i class="fa-solid fa-eye-slash ms-1"></i> إخفاء البيانات'
        : '<i class="fa-solid fa-id-card ms-1"></i> إظهار البيانات';
    }
    box?.classList.toggle('d-none', !mediated);
    grid?.classList.toggle('d-none', !partiesRevealed);
    if (mediated) {
      const title = threadTitle({ ...currentThreadRow, ...currentThreadMeta }, partiesRevealed);
      if (title && el('roomTitle')) el('roomTitle').textContent = title;
    }
  };

  const renderParties = (meta) => {
    const box = el('roomParties');
    const tabs = el('mediatedLaneTabs');
    const mediated = isAdmin && useMediatedTabs(meta);
    box.classList.toggle('d-none', !mediated);
    tabs.classList.toggle('d-none', !mediated);
    el('togglePartyInfo')?.classList.toggle('d-none', !mediated);
    if (!mediated) {
      box.innerHTML = '';
      return;
    }
    const partyCard = (kind, label, name, phone, userId) => {
      const wa = waLink(phone);
      const profile = userId ? `${base}/admin/users?profile=${encodeURIComponent(userId)}` : '';
      return `<div class="messenger-party-card" data-party-card="${kind}">
        <div class="small text-secondary">${escapeHtml(label)}</div>
        <strong>${escapeHtml(name || '—')}</strong>
        ${phone ? `<div class="small mt-1" dir="ltr">${escapeHtml(phone)}</div>` : ''}
        <div class="messenger-party-links">
          ${phone ? `<a href="tel:${escapeHtml(phone)}" title="اتصال"><i class="fa-solid fa-phone"></i></a>` : ''}
          ${wa ? `<a href="${wa}" target="_blank" rel="noopener" title="واتساب"><i class="fa-brands fa-whatsapp"></i></a>` : ''}
          ${phone ? `<button type="button" data-copy-text="${escapeHtml(phone)}" title="نسخ الرقم"><i class="fa-regular fa-copy"></i></button>` : ''}
          ${profile ? `<a href="${profile}" title="ملف المستخدم"><i class="fa-solid fa-id-card"></i></a>` : ''}
        </div>
      </div>`;
    };
    box.innerHTML = `<div class="messenger-party-chips">
        <button type="button" class="messenger-party-chip" data-party="customer"><i class="fa-solid fa-user ms-1"></i> المستفسر</button>
        <button type="button" class="messenger-party-chip" data-party="office"><i class="fa-solid fa-store ms-1"></i> المعلن</button>
      </div>
      <div class="messenger-party-grid${partiesRevealed ? '' : ' d-none'}" id="partiesDetails">
      ${partyCard('customer', 'المستفسر', meta.customer_display_name, meta.customer_phone, meta.customer_user_id)}
      ${partyCard('office', 'المعلن', meta.office_display_name, meta.office_phone, meta.office_user_id)}
    </div>`;
    box.querySelectorAll('[data-party]').forEach((btn) => {
      btn.addEventListener('click', () => {
        partiesRevealed = true;
        const kind = btn.getAttribute('data-party');
        const gridEl = el('partiesDetails');
        gridEl?.classList.remove('d-none');
        gridEl?.querySelectorAll('[data-party-card]').forEach((card) => {
          card.classList.toggle('is-focus', card.getAttribute('data-party-card') === kind);
        });
        syncPartyVisibility();
      });
    });
    syncPartyVisibility();
  };

  const renderContext = (payload) => {
    const ctx = el('roomContext');
    const property = payload.property;
    const reel = payload.reel;
    if (property && property.title) {
      const pid = property.id || '';
      ctx.classList.remove('d-none');
      ctx.innerHTML = `<div class="messenger-context-card">
        <img src="${property.thumb_url || property.image_url || `${base}/assets/images/placeholder-property.svg`}" alt="">
        <div class="min-w-0"><strong>${escapeHtml(property.title)}</strong><div class="small text-secondary">${escapeHtml(property.governorate || '')}</div></div>
        ${pid ? `<a href="${base}/property/${pid}" class="btn btn-sm btn-light rounded-pill">عرض العقار</a>` : ''}
      </div>`;
      return;
    }
    if (reel && (reel.caption || reel.id)) {
      ctx.classList.remove('d-none');
      ctx.innerHTML = `<div class="messenger-context-card"><div class="messenger-context-reel"><i class="fa-solid fa-clapperboard"></i></div><div class="min-w-0"><strong>${escapeHtml(reel.caption || 'ريل')}</strong></div></div>`;
      return;
    }
    ctx.classList.add('d-none');
    ctx.innerHTML = '';
  };

  const renderMessages = (forceBottom = false) => {
    const items = visibleMessages();
    const sig = `${mediatedLaneTab}|${items.map((m) => m.id || m.created_at).join(',')}`;
    const grew = items.length > (renderMessages._len || 0);
    renderMessages._len = items.length;
    if (sig === lastMsgSig && !forceBottom) return;
    lastMsgSig = sig;

    const messageList = el('messageList');
    let lastDay = '';
    messageList.innerHTML = items.map((msg) => {
      const mine = isMineMessage(msg);
      const body = (msg.body || msg.text || '').trim();
      const name = (msg.sender_display_name || msg.sender_full_name || '').trim();
      const label = (msg.sender_conversation_label || '').trim();
      const vis = visibilityLabel(msg.visibility);
      const day = dayKey(msg.created_at);
      let html = '';
      if (day && day !== lastDay) {
        lastDay = day;
        html += `<div class="messenger-day-chip">${escapeHtml(formatDay(msg.created_at))}</div>`;
      }
      html += `<div class="messenger-bubble ${mine ? 'me' : 'them'}">
        ${name ? `<div class="messenger-sender">${escapeHtml(name)}${label ? `<small>${escapeHtml(label)}</small>` : ''}</div>` : ''}
        ${vis ? `<div class="messenger-lane-inline">${escapeHtml(vis)}</div>` : ''}
        ${body ? `<div>${linkify(body)}</div>` : ''}
        ${renderMedia(msg)}
        ${!body && !msg.media_public_url ? '<div>—</div>' : ''}
        <div class="messenger-bubble-foot"><small>${formatTime(msg.created_at)}</small></div>
      </div>`;
      return html;
    }).join('');

    messageList.querySelectorAll('.messenger-image-link').forEach((a) => {
      a.addEventListener('click', (e) => {
        e.preventDefault();
        openLightbox(a.dataset.full);
      });
    });

    if (forceBottom || stickToBottom) {
      messageList.scrollTop = messageList.scrollHeight;
      el('newMessagesChip')?.classList.add('d-none');
    } else if (grew) {
      el('newMessagesChip')?.classList.remove('d-none');
    }
  };

  const scrollMessagesTo = (where) => {
    const messageList = el('messageList');
    if (!messageList) return;
    messageList.scrollTo({
      top: where === 'top' ? 0 : messageList.scrollHeight,
      behavior: 'smooth',
    });
    if (where !== 'top') {
      stickToBottom = true;
      el('newMessagesChip')?.classList.add('d-none');
    }
  };

  const resizeMessageInput = () => {
    const input = el('messageInput');
    if (!input) return;
    input.style.height = 'auto';
    input.style.height = `${Math.min(input.scrollHeight, 132)}px`;
  };

  const syncLaneUi = () => {
    const hidden = el('sendVisibility');
    const mediated = useMediatedTabs(currentThreadMeta);
    if (hidden) {
      hidden.value = mediated
        ? (mediatedLaneTab === 0 ? 'customer_only' : 'office_only')
        : 'all';
    }
    el('mediatedLaneTabs')?.querySelectorAll('[data-lane]').forEach((btn) => {
      btn.classList.toggle('active', Number(btn.dataset.lane) === mediatedLaneTab);
    });
    const input = el('messageInput');
    const hint = el('composeHint');
    if (mediated && input) {
      input.placeholder = mediatedLaneTab === 0 ? 'اكتب للمستفسر...' : 'اكتب للمعلن...';
      if (hint) hint.textContent = mediatedLaneTab === 0 ? 'تظهر هذه الرسالة للمستفسر فقط' : 'تظهر هذه الرسالة للمعلن فقط';
    } else if (input) {
      input.placeholder = 'اكتب رسالتك هنا...';
      if (hint) hint.textContent = 'Enter للإرسال · Shift + Enter لسطر جديد · الصق صورة مباشرة';
    }
  };

  const applyPayload = (payload, firstOpen = false) => {
    currentThreadMeta = payload.thread || {};
    allMessages = payload.items || [];
    renderParties(currentThreadMeta);
    renderContext(payload);
    if (firstOpen && isAdmin && useMediatedTabs(currentThreadMeta)) {
      mediatedLaneTab = 0;
    }
    syncLaneUi();
    const pub = currentThreadMeta.thread_public_no || currentThreadRow.thread_public_no;
    const copyBtn = el('copyThreadNo');
    if (copyBtn) {
      copyBtn.classList.toggle('d-none', !pub);
      copyBtn.dataset.copyText = pub ? `#${pub}` : '';
    }
    const titleFromMeta = threadTitle({ ...currentThreadRow, ...currentThreadMeta }, partiesRevealed);
    if (titleFromMeta) el('roomTitle').textContent = titleFromMeta;
    renderMessages();
  };

  const historyPath = () => (isAdmin ? `${base}/admin/chats` : window.location.pathname);

  const openThread = async (threadId) => {
    activeThread = threadId;
    app.dataset.activeThread = threadId;
    app.classList.add('room-open');
    el('messengerEmpty').classList.add('d-none');
    el('messengerRoom').classList.remove('d-none');
    lastMsgSig = '';
    stickToBottom = true;
    partiesRevealed = false;
    currentThreadRow = threads.find((t) => t.id === threadId) || {};
    el('roomTitle').textContent = threadTitle(currentThreadRow);
    el('roomSubtitle').textContent = threadSubtitle(currentThreadRow);
    el('roomAvatar').src = threadAvatar(currentThreadRow);
    history.replaceState(null, '', `${historyPath()}?thread=${encodeURIComponent(threadId)}`);
    renderThreads();
    await loadMessages(false, true);
    if (pollMessages) clearInterval(pollMessages);
    pollMessages = setInterval(() => loadMessages(true), 2500);
    setTimeout(() => {
      resizeMessageInput();
      el('messageInput')?.focus();
    }, 80);
  };

  const loadMessages = async (silent = false, firstOpen = false) => {
    if (!activeThread) return;
    const data = await fetchJson(`${apiBase}/${encodeURIComponent(activeThread)}`);
    if (!data.ok) {
      if (!silent) el('messageList').innerHTML = `<div class="alert alert-danger">${escapeHtml(data.error || 'تعذر تحميل الرسائل')}</div>`;
      return;
    }
    applyPayload(data, firstOpen);
    await loadThreads(true);
  };

  const currentVisibility = () => (el('sendVisibility')?.value || 'all');

  const sendText = async (body) => {
    if (!body || !activeThread) return false;
    const payload = { body };
    const vis = currentVisibility();
    if (vis && vis !== 'all') payload.visibility = vis;
    const data = await fetchJson(`${apiBase}/${encodeURIComponent(activeThread)}/send`, {
      method: 'POST',
      body: JSON.stringify(payload),
    });
    if (!data.ok) {
      showToast(data.error || 'تعذر إرسال الرسالة', true);
      return false;
    }
    stickToBottom = true;
    await loadMessages(true);
    return true;
  };

  const uploadFile = async (file) => {
    if (!file || !activeThread) return;
    if (file.size <= 0) {
      showToast('الملف فارغ', true);
      return;
    }
    const fd = new FormData();
    fd.append('file', file);
    fd.append('_csrf', csrf);
    const vis = currentVisibility();
    if (vis && vis !== 'all') fd.append('visibility', vis);
    el('sendBtn') && (el('sendBtn').disabled = true);
    showToast('جاري رفع المرفق...');
    const data = await fetchJson(`${apiBase}/${encodeURIComponent(activeThread)}/upload`, {
      method: 'POST',
      body: fd,
    });
    if (el('sendBtn')) el('sendBtn').disabled = false;
    if (!data.ok) {
      showToast(data.error || 'فشل رفع الملف', true);
      return;
    }
    stickToBottom = true;
    await loadMessages(true);
  };

  el('messageForm')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const input = el('messageInput');
    const button = el('sendBtn');
    const body = input.value.trim();
    if (!body || !activeThread) return;
    input.value = '';
    resizeMessageInput();
    if (button) button.disabled = true;
    const ok = await sendText(body);
    if (!ok) {
      input.value = body;
      resizeMessageInput();
    }
    if (button) button.disabled = false;
    input.focus();
  });

  el('messageInput')?.addEventListener('input', resizeMessageInput);
  el('messageInput')?.addEventListener('keydown', (e) => {
    if (e.key !== 'Enter' || e.shiftKey) return;
    e.preventDefault();
    el('messageForm')?.requestSubmit();
  });
  el('messageInput')?.addEventListener('paste', (e) => {
    const item = [...(e.clipboardData?.items || [])].find((i) => i.type.startsWith('image/'));
    if (!item) return;
    e.preventDefault();
    const file = item.getAsFile();
    if (file) uploadFile(file);
  });

  el('chatFileInput')?.addEventListener('change', async (e) => {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (file) await uploadFile(file);
  });

  el('threadSearch')?.addEventListener('input', () => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => loadThreads(), 350);
  });

  el('threadFilters')?.querySelectorAll('[data-filter]').forEach((btn) => {
    btn.addEventListener('click', () => {
      threadFilter = btn.dataset.filter || 'all';
      el('threadFilters').querySelectorAll('[data-filter]').forEach((b) => b.classList.toggle('active', b === btn));
      renderThreads();
    });
  });

  el('mediatedLaneTabs')?.querySelectorAll('[data-lane]').forEach((btn) => {
    btn.addEventListener('click', () => {
      mediatedLaneTab = Number(btn.dataset.lane || 0);
      lastMsgSig = '';
      stickToBottom = true;
      syncLaneUi();
      renderMessages(true);
    });
  });

  el('messengerOpenList')?.addEventListener('click', () => app.classList.remove('room-open'));
  el('messengerCloseList')?.addEventListener('click', () => app.classList.remove('room-open'));
  el('messengerMinimize')?.addEventListener('click', () => {
    app.classList.toggle('is-minimized');
    el('messengerFab')?.classList.toggle('d-none', !app.classList.contains('is-minimized'));
  });
  el('messengerFabOpen')?.addEventListener('click', () => {
    app.classList.remove('is-minimized');
    el('messengerFab')?.classList.add('d-none');
  });
  el('scrollChatTop')?.addEventListener('click', () => scrollMessagesTo('top'));
  el('scrollChatBottom')?.addEventListener('click', () => scrollMessagesTo('bottom'));
  el('newMessagesChip')?.addEventListener('click', () => scrollMessagesTo('bottom'));

  el('messageList')?.addEventListener('scroll', () => {
    const list = el('messageList');
    const dist = list.scrollHeight - list.scrollTop - list.clientHeight;
    stickToBottom = dist < 72;
    if (stickToBottom) el('newMessagesChip')?.classList.add('d-none');
  });

  const openLightbox = (src) => {
    const box = el('imageLightbox');
    const img = el('lightboxImage');
    if (!box || !img || !src) return;
    img.src = src;
    box.classList.remove('d-none');
  };
  const closeLightbox = () => {
    el('imageLightbox')?.classList.add('d-none');
    const img = el('lightboxImage');
    if (img) img.src = '';
  };
  el('lightboxClose')?.addEventListener('click', closeLightbox);
  el('imageLightbox')?.addEventListener('click', (e) => {
    if (e.target.id === 'imageLightbox') closeLightbox();
  });
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      closeLightbox();
      el('emojiPanel')?.classList.add('d-none');
    }
  });

  const emojiPanel = el('emojiPanel');
  if (emojiPanel) {
    emojiPanel.innerHTML = EMOJIS.map((emo) => `<button type="button" class="messenger-emoji">${emo}</button>`).join('');
    emojiPanel.querySelectorAll('.messenger-emoji').forEach((btn) => {
      btn.addEventListener('click', () => {
        const input = el('messageInput');
        if (!input) return;
        const start = input.selectionStart || input.value.length;
        input.value = `${input.value.slice(0, start)}${btn.textContent}${input.value.slice(start)}`;
        resizeMessageInput();
        input.focus();
      });
    });
  }
  el('emojiToggle')?.addEventListener('click', () => {
    el('emojiPanel')?.classList.toggle('d-none');
  });

  const stopTracks = () => {
    recordStream?.getTracks().forEach((t) => t.stop());
    recordStream = null;
  };

  const stopRecording = (send) => {
    clearInterval(recordTimer);
    el('recordBar')?.classList.add('d-none');
    if (!mediaRecorder) return;
    mediaRecorder.onstop = async () => {
      stopTracks();
      if (send && audioChunks.length) {
        const blob = new Blob(audioChunks, { type: mediaRecorder.mimeType || 'audio/webm' });
        const file = new File([blob], `voice-${Date.now()}.webm`, { type: blob.type });
        await uploadFile(file);
      }
      mediaRecorder = null;
      audioChunks = [];
    };
    if (mediaRecorder.state !== 'inactive') mediaRecorder.stop();
  };

  el('voiceBtn')?.addEventListener('click', async () => {
    if (mediaRecorder) {
      stopRecording(true);
      return;
    }
    if (!navigator.mediaDevices?.getUserMedia) {
      showToast('المتصفح لا يدعم التسجيل الصوتي', true);
      return;
    }
    try {
      recordStream = await navigator.mediaDevices.getUserMedia({ audio: true });
      mediaRecorder = new MediaRecorder(recordStream);
      audioChunks = [];
      mediaRecorder.ondataavailable = (e) => {
        if (e.data.size) audioChunks.push(e.data);
      };
      mediaRecorder.start();
      recordStartedAt = Date.now();
      el('recordBar')?.classList.remove('d-none');
      el('recordTimer').textContent = '0:00';
      recordTimer = setInterval(() => {
        const sec = Math.floor((Date.now() - recordStartedAt) / 1000);
        el('recordTimer').textContent = `${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, '0')}`;
      }, 250);
    } catch (_) {
      showToast('يلزم السماح بالميكروفون لتسجيل الصوت', true);
    }
  });
  el('recordSend')?.addEventListener('click', () => stopRecording(true));
  el('recordCancel')?.addEventListener('click', () => stopRecording(false));

  const openSupport = async () => {
    const data = await fetchJson(`${isAdmin ? '/messages/api' : apiBase}/open`.replace('/admin/api/chat', '/messages/api'), {
      method: 'POST',
      body: JSON.stringify({ support: 1 }),
    });
    if (!data.ok || !data.thread_id) {
      showToast(data.error || 'تعذر فتح محادثة الدعم', true);
      return;
    }
    await loadThreads(true);
    openThread(data.thread_id);
  };
  el('openSupportChat')?.addEventListener('click', openSupport);
  el('emptySupportBtn')?.addEventListener('click', openSupport);

  el('togglePartyInfo')?.addEventListener('click', () => {
    partiesRevealed = !partiesRevealed;
    el('partiesDetails')?.classList.toggle('d-none', !partiesRevealed);
    syncPartyVisibility();
  });

  el('copyThreadNo')?.addEventListener('click', async () => {
    const text = el('copyThreadNo')?.dataset.copyText || '';
    if (!text) return;
    try {
      await navigator.clipboard.writeText(text);
      showToast(`تم نسخ ${text}`);
    } catch (_) {
      showToast('تعذر النسخ', true);
    }
  });

  document.addEventListener('click', async (e) => {
    const btn = e.target.closest('[data-copy-text]');
    if (!btn || btn.id === 'copyThreadNo') return;
    const text = btn.getAttribute('data-copy-text') || '';
    if (!text) return;
    e.preventDefault();
    try {
      await navigator.clipboard.writeText(text);
      showToast(`تم نسخ ${text}`);
    } catch (_) {}
  });

  const panel = el('messengerPanel');
  ['dragenter', 'dragover'].forEach((type) => {
    panel?.addEventListener(type, (e) => {
      e.preventDefault();
      el('dropOverlay')?.classList.remove('d-none');
    });
  });
  ['dragleave', 'drop'].forEach((type) => {
    panel?.addEventListener(type, (e) => {
      e.preventDefault();
      el('dropOverlay')?.classList.add('d-none');
    });
  });
  panel?.addEventListener('drop', (e) => {
    const file = e.dataTransfer?.files?.[0];
    if (file && file.type.startsWith('image/')) uploadFile(file);
  });

  loadThreads();
  pollThreads = setInterval(() => loadThreads(true), 4000);
  if (activeThread) openThread(activeThread);

  window.addEventListener('beforeunload', () => {
    if (pollThreads) clearInterval(pollThreads);
    if (pollMessages) clearInterval(pollMessages);
    stopTracks();
  });
})();
