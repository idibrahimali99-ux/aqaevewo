document.addEventListener('DOMContentLoaded', () => {
  const root = document.documentElement;
  const themeToggle = document.getElementById('themeToggle');
  const sidebar = document.getElementById('adminSidebar');
  const sidebarOpen = document.getElementById('sidebarOpen');
  const sidebarCollapse = document.getElementById('sidebarCollapse');
  const notificationsToggle = document.getElementById('notificationsToggle');
  const notificationsClose = document.getElementById('notificationsClose');
  const backdrop = document.getElementById('adminBackdrop');

  const savedTheme = localStorage.getItem('aqarTownTheme');
  if (savedTheme) root.setAttribute('data-bs-theme', savedTheme);
  if (localStorage.getItem('aqarTownSidebarCollapsed') === '1') {
    document.body.classList.add('admin-collapsed');
  }

  themeToggle?.addEventListener('click', () => {
    const next = root.getAttribute('data-bs-theme') === 'dark' ? 'light' : 'dark';
    root.setAttribute('data-bs-theme', next);
    localStorage.setItem('aqarTownTheme', next);
  });

  sidebarCollapse?.addEventListener('click', () => {
    document.body.classList.toggle('admin-collapsed');
    localStorage.setItem('aqarTownSidebarCollapsed', document.body.classList.contains('admin-collapsed') ? '1' : '0');
  });

  const closePanels = () => {
    document.body.classList.remove('admin-sidebar-open', 'admin-notifications-open');
  };

  sidebarOpen?.addEventListener('click', () => document.body.classList.add('admin-sidebar-open'));
  notificationsToggle?.addEventListener('click', () => document.body.classList.add('admin-notifications-open'));
  notificationsClose?.addEventListener('click', closePanels);
  backdrop?.addEventListener('click', closePanels);

  if (window.jQuery && document.querySelector('.datatable')) {
    window.jQuery('.datatable').DataTable({
      language: { url: 'https://cdn.datatables.net/plug-ins/1.13.8/i18n/ar.json' },
      pageLength: 15,
      responsive: true,
    });
  }

  if (typeof ApexCharts !== 'undefined' && document.querySelector('#overviewChart')) {
    new ApexCharts(document.querySelector('#overviewChart'), {
      chart: { type: 'area', height: 320, toolbar: { show: false }, fontFamily: 'Tajawal, sans-serif' },
      series: [{ name: 'نشاط', data: [12, 18, 14, 26, 22, 34, 28] }],
      colors: ['#F5B400'],
      stroke: { curve: 'smooth', width: 3 },
      fill: { type: 'gradient', gradient: { opacityFrom: 0.35, opacityTo: 0.05 } },
      dataLabels: { enabled: false },
      xaxis: { categories: ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'] },
    }).render();
  }
});
