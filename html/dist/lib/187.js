/* 187Scripts — JS Utility Library v1.0 */

const S187 = (() => {

  /* ── NUI Bridge ── */
  const resourceName = () => {
    try { return GetParentResourceName(); } catch { return 'resource'; }
  };

  const post = (event, data = {}) =>
    fetch(`https://${resourceName()}/${event}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });

  /* ── Toasts ── */
  let toastContainer = null;

  const ensureContainer = () => {
    if (!toastContainer) {
      toastContainer = document.createElement('div');
      toastContainer.className = 'toast-container';
      document.body.appendChild(toastContainer);
    }
    return toastContainer;
  };

  const icons = { success: '✓', error: '✕', warning: '⚠', info: 'ℹ' };

  const notify = ({ title, message = '', type = 'info', duration = 4000 }) => {
    const container = ensureContainer();
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.innerHTML = `
      <span class="toast-icon">${icons[type] ?? 'ℹ'}</span>
      <div>
        <div class="toast-title">${title}</div>
        ${message ? `<div class="toast-message">${message}</div>` : ''}
      </div>
    `;
    container.appendChild(toast);
    setTimeout(() => {
      toast.style.animation = 'toastIn 0.2s ease reverse forwards';
      setTimeout(() => toast.remove(), 200);
    }, duration);
  };

  /* ── Panel show/hide ── */
  const show = (selector) => {
    const el = document.querySelector(selector);
    if (el) { el.style.display = ''; el.style.animation = 'panelIn 0.25s cubic-bezier(0.34, 1.56, 0.64, 1)'; }
  };

  const hide = (selector) => {
    const el = document.querySelector(selector);
    if (!el) return;
    el.style.animation = 'panelIn 0.2s ease reverse forwards';
    setTimeout(() => { el.style.display = 'none'; }, 200);
  };

  /* ── Progress bar ── */
  const setProgress = (selector, percent) => {
    const el = document.querySelector(selector);
    if (el) el.style.width = `${Math.min(100, Math.max(0, percent))}%`;
  };

  /* ── Tab system ── */
  const initTabs = (tabsSelector, contentSelector) => {
    document.querySelectorAll(tabsSelector).forEach(tab => {
      tab.addEventListener('click', () => {
        document.querySelectorAll(tabsSelector).forEach(t => t.classList.remove('active'));
        document.querySelectorAll(contentSelector).forEach(c => c.style.display = 'none');
        tab.classList.add('active');
        const target = document.querySelector(`[data-tab="${tab.dataset.target}"]`);
        if (target) target.style.display = '';
      });
    });
  };

  /* ── Format helpers ── */
  const money = (n) => `$${Number(n).toLocaleString('fr-FR')}`;
  const clamp = (v, min, max) => Math.min(max, Math.max(min, v));
  const lerp  = (a, b, t) => a + (b - a) * t;

  /* ── NUI message listener ── */
  const on = (action, handler) => {
    window.addEventListener('message', (e) => {
      if (e.data?.action === action) handler(e.data);
    });
  };

  /* ── Close on Escape ── */
  const onEscape = (callback) => {
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') callback();
    });
  };

  return { post, notify, show, hide, setProgress, initTabs, money, clamp, lerp, on, onEscape };
})();
