document.addEventListener('change', (event) => {
  const target = event.target;
  if (!(target instanceof HTMLSelectElement)) return;
  if (target.name === 'account_kind') {
    document.body.dataset.accountKind = target.value;
  }
});

document.addEventListener('DOMContentLoaded', () => {
  if (localStorage.getItem('webTownDashboardCollapsed') === '1') {
    document.body.classList.add('dashboard-collapsed');
  }
});

document.addEventListener('click', (event) => {
  const target = event.target;
  if (!(target instanceof Element)) return;

  if (target.closest('[data-dashboard-collapse]')) {
    document.body.classList.toggle('dashboard-collapsed');
    localStorage.setItem('webTownDashboardCollapsed', document.body.classList.contains('dashboard-collapsed') ? '1' : '0');
  }

  if (target.closest('[data-dashboard-drawer]')) {
    document.body.classList.add('dashboard-drawer-open');
  }

  if (target.closest('[data-dashboard-backdrop]') || target.closest('.admin-sidebar a')) {
    document.body.classList.remove('dashboard-drawer-open');
  }
});
