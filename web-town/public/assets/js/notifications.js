(() => {
  const base = document.querySelector('meta[name="app-base"]')?.content || '';
  const pollUrl = `${base}/notifications/api/poll`;
  const badge = document.getElementById('notificationCountBadge');
  const listEl = document.getElementById('notificationDropdownList');
  const msgLink = document.querySelector('.nav-icon-btn[href*="messages"], a[title="الرسائل"]');

  if (!badge && !listEl) return;

  const escapeHtml = (s) => String(s).replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));

  const purposeLabel = (v) => ({ sale: 'للبيع', rent: 'للإيجار' }[v] || v);
  const categoryLabel = (v) => ({
    house: 'بيت', apartment: 'شقة', villa: 'فيلا', land: 'أرض', shop: 'محل', compound: 'مجمع',
  }[v] || v);

  const itemUrl = (item) => {
    const payload = item.payload || {};
    const type = String(item.event_type || payload.type || '');
    const propertyId = String(payload.property_id || '').trim();
    const threadId = String(payload.thread_id || '').trim();
    const reelId = String(payload.reel_id || '').trim();
    if (threadId) return `${base}/messages?thread=${encodeURIComponent(threadId)}`;
    if (propertyId) return `${base}/property/${encodeURIComponent(propertyId)}`;
    if (reelId) return `${base}/reels?reel=${encodeURIComponent(reelId)}`;
    if (type.includes('property_request')) return `${base}/my-requests`;
    return `${base}/notifications`;
  };

  const totalCount = (counts) => {
    if (!counts || typeof counts !== 'object') return 0;
    return Object.entries(counts).reduce((sum, [, v]) => sum + Math.max(0, parseInt(v, 10) || 0), 0);
  };

  const renderItem = (item) => {
    const href = itemUrl(item);
    const unread = !item.read_at;
    const thumb = item.property?.thumb_url;
    const title = escapeHtml(item.title || 'إشعار');
    const body = escapeHtml(item.body || '');
    const pubNo = item.property?.property_public_no;
    return `<a class="notification-panel-item${unread ? ' unread' : ''}" href="${escapeHtml(href)}">
      ${thumb ? `<img src="${escapeHtml(thumb)}" alt="" class="notification-item-thumb">` : '<span class="notification-item-icon"><i class="fa-solid fa-bell"></i></span>'}
      <div class="min-w-0">
        <strong>${title}</strong>
        ${body ? `<p class="mb-0">${body}</p>` : ''}
        ${pubNo ? `<span class="badge text-bg-light border mt-1">#${escapeHtml(pubNo)}</span>` : ''}
      </div>
    </a>`;
  };

  const updateBadge = (count) => {
    if (!badge) return;
    if (count > 0) {
      badge.textContent = count > 99 ? '99+' : String(count);
      badge.classList.remove('d-none');
    } else {
      badge.classList.add('d-none');
    }
  };

  const updateMsgBadge = (chatUnread) => {
    if (!msgLink) return;
    let msgBadge = msgLink.querySelector('.notif-count-badge');
    if (chatUnread > 0) {
      if (!msgBadge) {
        msgBadge = document.createElement('span');
        msgBadge.className = 'notif-count-badge';
        msgLink.appendChild(msgBadge);
      }
      msgBadge.textContent = chatUnread > 99 ? '99+' : String(chatUnread);
    } else if (msgBadge) {
      msgBadge.remove();
    }
  };

  const poll = async () => {
    try {
      const res = await fetch(pollUrl, { credentials: 'same-origin', headers: { Accept: 'application/json' } });
      if (!res.ok) return;
      const data = await res.json();
      if (!data.ok) return;
      const counts = data.counts || {};
      updateBadge(totalCount(counts));
      updateMsgBadge(parseInt(counts.chat_unread, 10) || 0);
      if (!listEl) return;
      const items = Array.isArray(data.items) ? data.items : [];
      const chatUnread = parseInt(counts.chat_unread, 10) || 0;
      let html = '';
      if (chatUnread > 0) {
        html += `<a class="notification-panel-item unread" href="${base}/messages">
          <span class="notification-item-icon"><i class="fa-solid fa-comments"></i></span>
          <div><strong>محادثات غير مقروءة</strong><p class="mb-0">${chatUnread} رسالة</p></div>
          <span class="notif-count-badge ms-auto">${chatUnread > 99 ? '99+' : chatUnread}</span>
        </a>`;
      }
      if (items.length === 0 && chatUnread === 0) {
        html += '<div class="notification-panel-empty">لا توجد إشعارات جديدة</div>';
      } else {
        html += items.slice(0, 12).map(renderItem).join('');
      }
      listEl.innerHTML = html;
    } catch (_) { /* ignore */ }
  };

  poll();
  setInterval(poll, 45000);
})();
