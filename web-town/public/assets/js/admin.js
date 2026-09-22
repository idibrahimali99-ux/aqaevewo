document.addEventListener('DOMContentLoaded', () => {
  const root = document.documentElement;
  const themeToggle = document.getElementById('themeToggle');
  const sidebar = document.getElementById('adminSidebar');
  const sidebarOpen = document.getElementById('sidebarOpen');
  const sidebarCollapse = document.getElementById('sidebarCollapse');
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
    document.body.classList.remove('admin-sidebar-open');
  };

  sidebarOpen?.addEventListener('click', () => document.body.classList.add('admin-sidebar-open'));
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

  const palette = document.getElementById('adminCommandPalette');
  const paletteInput = document.getElementById('adminCommandInput');
  const paletteResults = document.getElementById('adminCommandResults');
  const openPalette = () => {
    if (!palette) return;
    palette.classList.remove('d-none');
    paletteInput?.focus();
    paletteInput?.select();
  };
  const closePalette = () => palette?.classList.add('d-none');
  document.addEventListener('keydown', (e) => {
    if ((e.ctrlKey || e.metaKey) && (e.key === 'k' || e.key === 'K')) {
      e.preventDefault();
      openPalette();
    }
    if (e.key === 'Escape') closePalette();
  });
  document.getElementById('adminCommandOpen')?.addEventListener('click', openPalette);
  palette?.addEventListener('click', (e) => {
    if (e.target === palette) closePalette();
  });
  paletteInput?.addEventListener('input', () => {
    const q = paletteInput.value.trim();
    paletteResults?.querySelectorAll('[data-label]').forEach((a) => {
      a.classList.toggle('d-none', q !== '' && !(a.getAttribute('data-label') || '').includes(q));
    });
  });

  document.querySelectorAll('[data-live-filter]').forEach((input) => {
    const table = document.querySelector(input.getAttribute('data-live-filter') || '');
    if (!table) return;
    input.addEventListener('input', () => {
      const q = input.value.trim();
      table.querySelectorAll('tbody tr').forEach((row) => {
        row.style.display = q === '' || (row.textContent || '').includes(q) ? '' : 'none';
      });
    });
  });
});
