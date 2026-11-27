/*
 * The theme: `data-theme` on the studio root holds the choice (`auto`, `light` or `dark`), and `data-bs-theme` on
 * <html> the mode it resolves to, which the map follows. The choice is kept in localStorage when the browser allows it.
 */
const KEY = 'stagemap-studio-theme';

function stored() {
  try {
    const value = window.localStorage.getItem(KEY);
    return value === 'light' || value === 'dark' ? value : 'auto';
  } catch {
    return 'auto';
  }
}

export function createTheme(root, tools) {
  const { signal } = tools;
  const media = window.matchMedia('(prefers-color-scheme: dark)');
  let choice = stored();

  const resolved = () => (choice === 'auto' ? (media.matches ? 'dark' : 'light') : choice);

  function apply() {
    const mode = resolved();
    root.dataset.theme = choice;
    document.documentElement.setAttribute('data-bs-theme', mode);
    for (const button of root.querySelectorAll('[data-sms-theme][role="switch"]')) {
      button.setAttribute('aria-checked', String(mode === 'dark'));
    }
    for (const word of root.querySelectorAll('[data-sms-mode]')) {
      if (word.dataset.smsMode === mode) word.dataset.smsOn = '';
      else delete word.dataset.smsOn;
    }
  }

  /* Switches to the other mode and keeps the choice. */
  function toggle() {
    choice = resolved() === 'dark' ? 'light' : 'dark';
    try {
      window.localStorage.setItem(KEY, choice);
    } catch {
      /* a browser that keeps nothing: the choice lasts for this page */
    }
    apply();
  }

  media.addEventListener('change', apply, { signal });
  apply();
  return { toggle };
}
