document.addEventListener('change', (event) => {
  const target = event.target;
  if (!(target instanceof HTMLSelectElement)) return;
  if (target.name === 'account_kind') {
    document.body.dataset.accountKind = target.value;
  }
});
