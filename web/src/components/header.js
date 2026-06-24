export function createHeader(container, store) {
  function render(state) {
    const age = state.generatedAt
      ? formatAge(new Date(state.generatedAt))
      : '—';
    const tzLabel = state.timezone === 'UTC' ? 'UTC' : 'Local';

    container.innerHTML = `
      <div class="header-left">
        <div class="header-logo">PS</div>
        <span class="header-title">PerfScale CI Schedule</span>
        <span class="header-subtitle">${state.totalJobs || 0} periodic jobs</span>
      </div>
      <div class="header-right">
        <span class="header-badge"><span class="dot"></span> Data: ${age}</span>
        <button class="tz-toggle" title="Toggle timezone">${tzLabel}</button>
      </div>
    `;

    container.querySelector('.tz-toggle').onclick = () => {
      store.set({ timezone: state.timezone === 'UTC' ? 'local' : 'UTC' });
    };
  }

  store.subscribe(render);
  render(store.get());
}

function formatAge(date) {
  const diffMs = Date.now() - date.getTime();
  const mins = Math.floor(diffMs / 60000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  return `${Math.floor(hrs / 24)}d ago`;
}
