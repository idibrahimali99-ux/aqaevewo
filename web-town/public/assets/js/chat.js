(() => {
  const app = document.getElementById('messengerApp');
  if (!app) return;

  const base = document.querySelector('meta[name="app-base"]')?.content || '';
  const csrf = document.querySelector('meta[name="csrf-token"]')?.content || '';
  const meId = document.body.dataset.userId || '';
  const meRole = document.body.dataset.userRole || '';
  const isAdmin = app.dataset.admin === '1';
  const apiBase = isAdmin ? '/admin/api/chat' : '/messages/api';

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

  const el = (id) => document.getElementById(id);
  const url = (path) => `${base}${path}`;

  const fetchJson = async (path, options = {}) => {
    const headers = { Accept: 'application/json', ...(options.headers || {}) };
    if (options.method && options.method !== 'GET') {
      headers['X-CSRF-Token'] = csrf;
      headers['Content-Type'] = 'application/json';
    }
    const res = await fetch(url(path), { ...options, headers });
    return res.json();
  };

  const escapeHtml = (s) => String(s).replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));

  const formatTime = (value) => {
    if (!value) return '';
    const d = new Date(String(value).replace(' ', 'T'));
    if (Number.isNaN(d.getTime())) return '';
    return d.toLocaleString('ar-IQ', { hour: '2-digit', minute: '2-digit', day: 'numeric', month: 'short' });
  };

  const threadTitle = (row) => {
    if (isAdmin) {
      const customer = (row.customer_display_name || row.customer_name || '').trim();
      const office = (row.office_display_name || row.office_name || '').trim();
      const pub = row.thread_public_no ? `#${row.thread_public_no}` : '';
      if (customer && office) return `${customer} ↔ ${office}${pub ? ' · ' + pub : ''}`;
      return customer || office || pub || 'محادثة';
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

  const useMediatedTabs = (meta) => {
    const type = String(meta.thread_type || '').toLowerCase();
    const customerId = String(meta.customer_user_id || '');
    const officeId = String(meta.office_user_id || '');
    return (type === 'mediated' || type === 'direct') && customerId && officeId;
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
    if (threadFilter === 'unread') return unread > 0;
    if (threadFilter === 'read') return unread === 0;
    return true;
  });

  const renderThreads = () => {
    const rows = filteredThreads();
    const threadList = el('threadList');
    if (!rows.length) {
      threadList.innerHTML = '<div class="text-center text-secondary py-5">لا توجد محادثات</div>';
      return;
    }
    threadList.innerHTML = rows.map((row) => {
      const id = row.id || '';
      const unread = Number(row.unread_count || 0);
      return `<button type="button" class="messenger-thread${id === activeThread ? ' active' : ''}" data-thread="${id}">
        <img src="${threadAvatar(row)}" alt="">
        <div class="messenger-thread-body">
          <strong>${escapeHtml(threadTitle(row))}</strong>
          <span>${escapeHtml(threadSubtitle(row))}</span>
        </div>
        <div class="messenger-thread-meta">
          <div>${formatTime(row.last_message_at || row.created_at)}</div>
          ${unread > 0 ? `<span class="messenger-unread">${unread > 99 ? '99+' : unread}</span>` : ''}
        </div>
      </button>`;
    }).join('');
    threadList.querySelectorAll('[data-thread]').forEach((btn) => {
      btn.addEventListener('click', () => openThread(btn.dataset.thread));
    });
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
      return `<audio controls preload="metadata" src="${media}"></audio>`;
    }
    return `<a href="${media}" target="_blank" rel="noopener"><img src="${media}" alt="مرفق"></a>`;
  };

  const visibilityLabel = (vis) => {
    if (vis === 'customer_only') return '→ للمستفسر';
    if (vis === 'office_only') return '→ للمعلن';
    return '';
  };

  const renderParties = (meta) => {
    const box = el('roomParties');
    const tabs = el('mediatedLaneTabs');
    const mediated = isAdmin && useMediatedTabs(meta);
    box.classList.toggle('d-none', !mediated);
    tabs.classList.toggle('d-none', !mediated);
    if (!mediated) {
      box.innerHTML = '';
      return;
    }
    const customer = (meta.customer_display_name || 'مستفسر').trim();
    const office = (meta.office_display_name || 'معلن').trim();
    const customerPhone = (meta.customer_phone || '').trim();
    const officePhone = (meta.office_phone || '').trim();
    box.innerHTML = `<div class="messenger-party-grid">
      <div class="messenger-party-card">
        <div class="small text-secondary">المستفسر</div>
        <strong>${escapeHtml(customer)}</strong>
        ${customerPhone ? `<div class="small">${escapeHtml(customerPhone)}</div>` : ''}
      </div>
      <div class="messenger-party-card">
        <div class="small text-secondary">المعلن</div>
        <strong>${escapeHtml(office)}</strong>
        ${officePhone ? `<div class="small">${escapeHtml(officePhone)}</div>` : ''}
      </div>
    </div>`;
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

  const renderMessages = () => {
    const items = visibleMessages();
    const messageList = el('messageList');
    messageList.innerHTML = items.map((msg) => {
      const mine = isMineMessage(msg);
      const body = (msg.body || msg.text || '').trim();
      const name = (msg.sender_display_name || msg.sender_full_name || '').trim();
      const label = (msg.sender_conversation_label || '').trim();
      let content = body ? `<div>${escapeHtml(body)}</div>` : '';
      content += renderMedia(msg);
      const vis = visibilityLabel(msg.visibility);
      return `<div class="messenger-bubble ${mine ? 'me' : 'them'}">
        ${name ? `<div class="messenger-sender">${escapeHtml(name)}${label ? `<small>${escapeHtml(label)}</small>` : ''}</div>` : ''}
        ${mine && vis ? `<div class="messenger-lane-inline">${escapeHtml(vis)}</div>` : ''}
        ${content || '<div>—</div>'}
        <div class="messenger-bubble-foot"><small>${formatTime(msg.created_at)}</small></div>
      </div>`;
    }).join('');
    messageList.scrollTop = messageList.scrollHeight;
  };

  const syncLaneUi = () => {
    const visibility = mediatedLaneTab === 0 ? 'customer_only' : 'office_only';
    const hidden = el('sendVisibility');
    if (hidden) hidden.value = visibility;
    el('mediatedLaneTabs')?.querySelectorAll('[data-lane]').forEach((btn) => {
      btn.classList.toggle('active', Number(btn.dataset.lane) === mediatedLaneTab);
    });
  };

  const applyPayload = (payload) => {
    currentThreadMeta = payload.thread || {};
    allMessages = payload.items || [];
    renderParties(currentThreadMeta);
    renderContext(payload);
    if (isAdmin && useMediatedTabs(currentThreadMeta)) {
      mediatedLaneTab = 0;
      syncLaneUi();
    }
    renderMessages();
  };

  const historyPath = () => (isAdmin ? `${base}/admin/chats` : window.location.pathname);

  const openThread = async (threadId) => {
    activeThread = threadId;
    app.dataset.activeThread = threadId;
    app.classList.add('room-open');
    el('messengerEmpty').classList.add('d-none');
    el('messengerRoom').classList.remove('d-none');
    currentThreadRow = threads.find((t) => t.id === threadId) || {};
    el('roomTitle').textContent = threadTitle(currentThreadRow);
    el('roomSubtitle').textContent = threadSubtitle(currentThreadRow);
    el('roomAvatar').src = threadAvatar(currentThreadRow);
    history.replaceState(null, '', `${historyPath()}?thread=${encodeURIComponent(threadId)}`);
    renderThreads();
    await loadMessages(true);
    if (pollMessages) clearInterval(pollMessages);
    pollMessages = setInterval(() => loadMessages(true), 2500);
  };

  const loadMessages = async (silent = false) => {
    if (!activeThread) return;
    const data = await fetchJson(`${apiBase}/${encodeURIComponent(activeThread)}`);
    if (!data.ok) {
      if (!silent) el('messageList').innerHTML = `<div class="alert alert-danger">${escapeHtml(data.error || 'تعذر تحميل الرسائل')}</div>`;
      return;
    }
    applyPayload(data);
    await loadThreads(true);
  };

  el('messageForm')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const input = el('messageInput');
    const body = input.value.trim();
    if (!body || !activeThread) return;
    input.value = '';
    const payload = { body };
    if (isAdmin) payload.visibility = el('sendVisibility')?.value || 'customer_only';
    await fetchJson(`${apiBase}/${encodeURIComponent(activeThread)}/send`, { method: 'POST', body: JSON.stringify(payload) });
    await loadMessages(true);
  });

  el('chatFileInput')?.addEventListener('change', async (e) => {
    const file = e.target.files?.[0];
    if (!file || !activeThread) return;
    const fd = new FormData();
    fd.append('file', file);
    fd.append('_csrf', csrf);
    if (isAdmin) fd.append('visibility', el('sendVisibility')?.value || 'customer_only');
    await fetch(url(`${apiBase}/${encodeURIComponent(activeThread)}/upload`), {
      method: 'POST', headers: { Accept: 'application/json', 'X-CSRF-Token': csrf }, body: fd,
    });
    e.target.value = '';
    await loadMessages(true);
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
      syncLaneUi();
      renderMessages();
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

  loadThreads();
  pollThreads = setInterval(() => loadThreads(true), 4000);
  if (activeThread) openThread(activeThread);
})();
