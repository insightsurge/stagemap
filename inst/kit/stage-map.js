// stagemap stage map 0.51.0, built from its source; do not edit.
(() => {
  const VERSION = '0.51.0';
  if (window.stagemap) {
    if (window.stagemap.version !== VERSION) {
      console.warn(
        `stagemap ${window.stagemap.version} is already on this page, so stagemap ${VERSION} was not loaded; visuals use ${window.stagemap.version}.`,
      );
    }
    return;
  }
  const ownD3 = window.d3;
  const datumOf = (el) => (ownD3 ?? window.d3).select(el).datum();
  const SVG_NS = 'http://www.w3.org/2000/svg';
  const TONES = ['teal', 'good', 'warn', 'bad', 'muted', 'orange', 'blue', 'violet', 'pink', 'gold', 'grey'];
  const STATUSES = ['done', 'running', 'waiting', 'failed', 'skipped'];
  const ICONS = Object.freeze({
    bell: '<path d="M10.268 21a2 2 0 0 0 3.464 0"/><path d="M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326"/>',
    calendar: '<path d="M8 2v3"/><path d="M16 2v3"/><rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18"/>',
    'chart-column': '<path d="M3 3v16a2 2 0 0 0 2 2h16"/><path d="M18 17V9"/><path d="M13 17V5"/><path d="M8 17v-3"/>',
    check: '<path d="M20 6 9 17l-5-5"/>',
    'chevron-down': '<path d="m6 9 6 6 6-6"/>',
    'chevron-left': '<path d="m15 18-6-6 6-6"/>',
    'chevron-right': '<path d="m9 18 6-6-6-6"/>',
    clock: '<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>',
    'file-text': '<path d="M6 22a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h8a2.4 2.4 0 0 1 1.704.706l3.588 3.588A2.4 2.4 0 0 1 20 8v12a2 2 0 0 1-2 2z"/><path d="M14 2v5a1 1 0 0 0 1 1h5"/><path d="M10 9H8"/><path d="M16 13H8"/><path d="M16 17H8"/>',
    flag: '<path d="M4 22V4a1 1 0 0 1 .4-.8A6 6 0 0 1 8 2c3 0 5 2 7.333 2q2 0 3.067-.8A1 1 0 0 1 20 4v10a1 1 0 0 1-.4.8A6 6 0 0 1 16 16c-3 0-5-2-8-2a6 6 0 0 0-4 1.528"/>',
    'flask-conical': '<path d="M14 2v6a2 2 0 0 0 .245.96l5.51 10.08A2 2 0 0 1 18 22H6a2 2 0 0 1-1.755-2.96l5.51-10.08A2 2 0 0 0 10 8V2"/><path d="M6.453 15h11.094"/><path d="M8.5 2h7"/>',
    'git-pull-request': '<circle cx="18" cy="18" r="3"/><circle cx="6" cy="6" r="3"/><path d="M13 6h3a2 2 0 0 1 2 2v7"/><line x1="6" x2="6" y1="9" y2="21"/>',
    hourglass: '<path d="M5 22h14"/><path d="M5 2h14"/><path d="M17 22v-4.172a2 2 0 0 0-.586-1.414L12 12l-4.414 4.414A2 2 0 0 0 7 17.828V22"/><path d="M7 2v4.172a2 2 0 0 0 .586 1.414L12 12l4.414-4.414A2 2 0 0 0 17 6.172V2"/>',
    house: '<path d="M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8"/><path d="M3 10a2 2 0 0 1 .709-1.528l7-6a2 2 0 0 1 2.582 0l7 6A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>',
    info: '<circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/>',
    'layout-grid': '<rect width="7" height="7" x="3" y="3" rx="1"/><rect width="7" height="7" x="14" y="3" rx="1"/><rect width="7" height="7" x="14" y="14" rx="1"/><rect width="7" height="7" x="3" y="14" rx="1"/>',
    'list-checks': '<path d="M13 5h8"/><path d="M13 12h8"/><path d="M13 19h8"/><path d="m3 17 2 2 4-4"/><path d="m3 7 2 2 4-4"/>',
    lock: '<rect width="18" height="11" x="3" y="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>',
    map: '<path d="M14.106 5.553a2 2 0 0 0 1.788 0l3.659-1.83A1 1 0 0 1 21 4.619v12.764a1 1 0 0 1-.553.894l-4.553 2.277a2 2 0 0 1-1.788 0l-4.212-2.106a2 2 0 0 0-1.788 0l-3.659 1.83A1 1 0 0 1 3 19.381V6.618a1 1 0 0 1 .553-.894l4.553-2.277a2 2 0 0 1 1.788 0z"/><path d="M15 5.764v15"/><path d="M9 3.236v15"/>',
    'octagon-alert': '<path d="M12 16h.01"/><path d="M12 8v4"/><path d="M15.312 2a2 2 0 0 1 1.414.586l4.688 4.688A2 2 0 0 1 22 8.688v6.624a2 2 0 0 1-.586 1.414l-4.688 4.688a2 2 0 0 1-1.414.586H8.688a2 2 0 0 1-1.414-.586l-4.688-4.688A2 2 0 0 1 2 15.312V8.688a2 2 0 0 1 .586-1.414l4.688-4.688A2 2 0 0 1 8.688 2z"/>',
    'panel-left': '<rect width="18" height="18" x="3" y="3" rx="2"/><path d="M9 3v18"/>',
    'panel-right': '<rect width="18" height="18" x="3" y="3" rx="2"/><path d="M15 3v18"/>',
    settings: '<path d="M9.671 4.136a2.34 2.34 0 0 1 4.659 0 2.34 2.34 0 0 0 3.319 1.915 2.34 2.34 0 0 1 2.33 4.033 2.34 2.34 0 0 0 0 3.831 2.34 2.34 0 0 1-2.33 4.033 2.34 2.34 0 0 0-3.319 1.915 2.34 2.34 0 0 1-4.659 0 2.34 2.34 0 0 0-3.32-1.915 2.34 2.34 0 0 1-2.33-4.033 2.34 2.34 0 0 0 0-3.831A2.34 2.34 0 0 1 6.35 6.051a2.34 2.34 0 0 0 3.319-1.915"/><circle cx="12" cy="12" r="3"/>',
    table: '<path d="M12 3v18"/><rect width="18" height="18" x="3" y="3" rx="2"/><path d="M3 9h18"/><path d="M3 15h18"/>',
    'triangle-alert': '<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3"/><path d="M12 9v4"/><path d="M12 17h.01"/>',
    users: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><path d="M16 3.128a4 4 0 0 1 0 7.744"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><circle cx="9" cy="7" r="4"/>',
    x: '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
  });
  const instances = new WeakMap();
  const placeOwners = new WeakMap();
  const registry = new Map();
  const pluginRegistry = new Map();
  const warned = new Set();
  let serial = 0;
  const ZERO_WAIT = 1000;

  const listeners = new WeakMap();
  const joined = new Set();
  const parked = new Set();
  const listening = new WeakSet();

  function toEach(doc, hear) {
    for (const ref of [...parked]) {
      const entry = ref.deref();
      if (!entry) parked.delete(ref);
      else if (entry.root.isConnected) {
        parked.delete(ref);
        join(entry);
      }
    }
    for (const entry of [...joined]) {
      if (!entry.root.isConnected) {
        joined.delete(entry);
        if (entry.free) park(entry);
      } else if (entry.root.ownerDocument === doc) hear(entry);
    }
  }

  function park(entry) {
    entry.ref ??= typeof WeakRef === 'function' ? new WeakRef(entry) : { deref: () => entry };
    parked.add(entry.ref);
    listen(entry.root.ownerDocument);
  }

  function join(entry) {
    joined.add(entry);
    listen(entry.root.ownerDocument);
  }

  function listen(doc) {
    if (listening.has(doc)) return;
    listening.add(doc);
    doc.addEventListener('report:tab', () => toEach(doc, (one) => one.tab()));
    doc.addEventListener('click', (e) => {
      toEach(doc, (one) => {
        for (const fn of [...one.clicks]) {
          try {
            fn(e);
          } catch (err) {
            console.warn('stagemap: a click handler threw and was skipped.', err);
          }
        }
      });
    });
  }

  function onOutside(root, fn) {
    const hear = (e) => {
      if (!e.target.isConnected) return;
      const other = e.target.closest?.('dialog');
      if ((other && other !== root.closest('dialog')) || e.target.closest?.('[data-stagemap-keep]')) return;
      fn(e);
    };
    const clicks = listeners.get(root)?.clicks;
    const doc = root.ownerDocument;
    if (clicks) clicks.add(hear);
    else doc.addEventListener('click', hear);
    return () => (clicks ? clicks.delete(hear) : doc.removeEventListener('click', hear));
  }

  function readData(root) {
    const block = [...root.children].find((n) => n.matches('script[type="application/json"]'));
    if (!block) throw new Error('it has no data block (<script type="application/json">)');
    try {
      return JSON.parse(block.textContent);
    } catch (e) {
      throw new Error(`its data block is not valid JSON (${e.message})`);
    }
  }

  function problemsOf(visual, data) {
    if (data === null || typeof data !== 'object' || Array.isArray(data)) return ['the data must be a JSON object'];
    if (!visual.validate) return [];
    const found = visual.validate(data);
    return (Array.isArray(found) ? found : [found]).filter(Boolean).map(String);
  }

  const isVisual = (v) => v !== null && typeof v === 'object' && typeof v.draw === 'function';
  const codeOf = (fn) => String(fn).replace(/\s+/g, ' ');

  function define(name, visual) {
    if (typeof name !== 'string' || !name) throw new TypeError('stagemap.define: the first argument must be a name');
    if (!isVisual(visual)) throw new TypeError('stagemap.define: the second argument needs a draw(ctx) function');
    const kept = registry.get(name);
    if (!kept) {
      registry.set(name, visual);
      lookForDefined(name);
      if (waiting.delete(name)) for (const watcher of watchers.values()) watcher.rescan();
      return visual;
    }
    const same = (a, b) => codeOf(a) === codeOf(b);
    if (
      kept !== visual &&
      !warned.has(name) &&
      !(same(kept.draw, visual.draw) && same(kept.validate, visual.validate))
    ) {
      warned.add(name);
      console.warn(`stagemap: "${name}" is defined twice with different code; the first definition is kept by name.`);
    }
    return kept;
  }

  function plugin(visualName, definition) {
    if (typeof visualName !== 'string' || !visualName) {
      throw new TypeError("stagemap.plugin: the first argument must be a visual's name");
    }
    if (!isObject(definition) || typeof definition.name !== 'string' || !definition.name) {
      throw new TypeError('stagemap.plugin: the second argument needs a name');
    }
    if (!pluginRegistry.has(visualName)) pluginRegistry.set(visualName, new Map());
    const own = pluginRegistry.get(visualName);
    const kept = own.get(definition.name);
    if (!kept) {
      own.set(definition.name, definition);
      return definition;
    }
    const code = (p) => JSON.stringify(p, (_, v) => (typeof v === 'function' ? codeOf(v) : v));
    const key = `${visualName}/${definition.name}`;
    if (kept !== definition && !warned.has(key) && code(kept) !== code(definition)) {
      warned.add(key);
      console.warn(`stagemap: plugin "${key}" is registered twice with different code; the first one is kept.`);
    }
    return kept;
  }

  const plugins = (visualName) => [...(pluginRegistry.get(visualName)?.values() ?? [])];

  function mount(root, nameOrVisual, data, options = {}) {
    if (root?.nodeType !== 1) throw new TypeError("stagemap.mount: the first argument must be the visual's root");
    let visual = nameOrVisual;
    if (typeof nameOrVisual === 'string') {
      visual = registry.get(nameOrVisual);
      if (!visual) {
        const known = [...registry.keys()].join(', ') || 'none';
        throw new TypeError(`stagemap.mount: no visual is defined as "${nameOrVisual}" (defined: ${known})`);
      }
    } else if (!isVisual(nameOrVisual)) {
      throw new TypeError('stagemap.mount: the second argument must be a defined name or an object with draw(ctx)');
    }
    instances.get(root)?.destroy();
    const own = Array.isArray(visual.roles) ? visual.roles : [];
    const name = root.dataset.stagemapVisual || (typeof nameOrVisual === 'string' ? nameOrVisual : '');
    const part = name || [...registry].find(([, v]) => v === visual)?.[0] || null;
    const lookOn = typeof visual.lookOn === 'string' ? visual.lookOn : null;
    const look = (given = options) => applyLook(root, given || {}, own, root.dataset.stagemapVisual || name, lookOn);
    return createView(root, visual, data, look, part);
  }

  const AUTO = '[data-stagemap-visual][data-stagemap-auto]';
  const waiting = new Set();
  const watchers = new Map();

  function undefinedName(name, doc) {
    const first = !waiting.has(name);
    waiting.add(name);
    if (!first || warned.has(`auto/${name}`)) return;
    const say = (more) => {
      if (registry.has(name) || warned.has(`auto/${name}`)) return;
      warned.add(`auto/${name}`);
      console.warn(`stagemap.mountAll: no visual is defined as "${name}", so its root was left as it is. ${more}`);
    };
    if (!watchers.has(doc)) {
      say('Load its script first, or call stagemap.observe() to mount it when the script loads.');
      return;
    }
    const later = () =>
      setTimeout(() => say('Its script may have failed to load, or the name may be misspelt.'), ZERO_WAIT);
    const win = doc.defaultView;
    if (doc.readyState === 'complete' || !win) later();
    else win.addEventListener('load', later, { once: true });
  }

  const autoRoots = (scope) => {
    const found = scope.nodeType === 1 && scope.matches(AUTO) ? [scope] : [];
    return found.concat([...scope.querySelectorAll(AUTO)]);
  };

  function mountAll(scope = document) {
    if (![1, 9, 11].includes(scope?.nodeType)) {
      throw new TypeError('stagemap.mountAll: the scope must be an element, a document or a fragment');
    }
    const views = [];
    for (const root of autoRoots(scope)) {
      let view = instances.get(root);
      if (!view) {
        const name = root.getAttribute('data-stagemap-visual');
        if (!registry.has(name)) {
          undefinedName(name, root.ownerDocument);
          continue;
        }
        try {
          view = mount(root, name);
        } catch (e) {
          console.warn(`stagemap.mountAll: ${name} could not be mounted.`, e);
          continue;
        }
      }
      views.push(view);
    }
    return views;
  }

  function watch(doc) {
    const added = new Set();
    const gone = new Set();
    let queued = false;
    let live = true;
    let observer = null;
    const flush = () => {
      queued = false;
      if (!live) return;
      const leaving = [...gone];
      gone.clear();
      for (const root of leaving) if (!root.isConnected) instances.get(root)?.destroy();
      const arriving = [...added];
      added.clear();
      for (const node of arriving) if (node.isConnected) mountAll(node);
    };
    const queue = () => {
      if (queued) return;
      queued = true;
      queueMicrotask(flush);
    };
    const hear = (records) => {
      for (const record of records) {
        for (const n of record.removedNodes) {
          if (n.nodeType === 1) for (const root of autoRoots(n)) if (instances.has(root)) gone.add(root);
        }
        for (const n of record.addedNodes) if (n.nodeType === 1) added.add(n);
      }
      if (added.size || gone.size) queue();
    };
    const begin = () => {
      if (!live) return;
      mountAll(doc);
      observer = new MutationObserver(hear);
      observer.observe(doc, { childList: true, subtree: true });
    };
    return {
      users: 0,
      start() {
        if (doc.readyState === 'loading') doc.addEventListener('DOMContentLoaded', begin, { once: true });
        else begin();
      },
      rescan() {
        if (!observer) return;
        added.add(doc.documentElement);
        queue();
      },
      stop() {
        live = false;
        observer?.disconnect();
        doc.removeEventListener('DOMContentLoaded', begin);
      },
    };
  }

  function observe(target = document) {
    const doc = target?.nodeType === 9 ? target : target?.ownerDocument;
    if (!doc) throw new TypeError('stagemap.observe: the argument must be a document or an element in one');
    let watcher = watchers.get(doc);
    if (!watcher) {
      watcher = watch(doc);
      watchers.set(doc, watcher);
      watcher.start();
    }
    watcher.users++;
    let stopped = false;
    return () => {
      if (stopped) return;
      stopped = true;
      watcher.users--;
      if (watcher.users || watchers.get(doc) !== watcher) return;
      watcher.stop();
      watchers.delete(doc);
    };
  }

  const MODE_ROLES = [
    'page',
    'panel',
    'panel-soft',
    'card',
    'sidebar',
    'drawer',
    'popup',
    'backdrop',
    'ink',
    'muted',
    'line',
    'line-strong',
    'accent',
    'accent-soft',
    'accent-ink',
    'accent-line',
    'on-accent',
    'good',
    'good-soft',
    'warn',
    'warn-soft',
    'bad',
    'bad-soft',
    'mark-muted',
    'focus',
    'cat-1',
    'cat-2',
    'cat-3',
    'cat-4',
    'cat-5',
    'cat-6',
    'cat-7',
    'cat-8',
    'seq-lo',
    'seq-hi',
    'div-lo',
    'div-mid',
    'div-hi',
    'shadow-1',
    'shadow-2',
    'shadow-3',
  ];
  const BASE_ROLES = [
    'space-1',
    'space-2',
    'space-3',
    'space-4',
    'space-5',
    'space-6',
    'radius-s',
    'radius-m',
    'radius-l',
    'radius-pill',
    'line-width',
    'focus-width',
  ];
  const TYPE_ROLES = [
    'text-label',
    'text-caption',
    'text-small',
    'text-body',
    'text-sub',
    'text-heading',
    'text-value',
    'text-title',
  ];
  const PALETTE_ROLES = [
    'accent',
    'accent-soft',
    'accent-ink',
    'accent-line',
    'on-accent',
    'focus',
    ...MODE_ROLES.filter((r) => /^(cat|seq|div)-/.test(r)),
  ];
  const LEADERS = {
    'accent-soft': (p) => p.accent && `color-mix(in srgb, ${p.accent} 16%, var(--stagemap-panel))`,
    'accent-ink': (p) => p.accent,
    'accent-line': (p) => p.accent,
    focus: (p) => p.accent,
    'cat-1': (p) => p.accent,
    'seq-hi': (p) => p.accent,
    'seq-lo': (p) => p['accent-soft'],
  };
  const CHART_LEADERS = {
    'cat-1': 'accent',
    'seq-lo': 'accent-soft',
    'seq-hi': 'accent',
    'div-mid': 'panel-soft',
    'accent-ink': 'accent',
    'accent-line': 'accent',
  };
  const NAME = /^[a-z][a-z0-9-]*$/;
  const COLOUR = /^(#[0-9a-fA-F]{3,8}|(rgb|rgba|hsl|hsla|oklch|color-mix)\(.*\))$/;

  function applyLook(root, options, own, visualName, lookOn = null) {
    const done = [];
    const target = (lookOn && root.querySelector(lookOn)) || root;
    const set = (attr, value) => {
      const before = root.getAttribute(attr);
      root.setAttribute(attr, value);
      done.push(() => (before === null ? root.removeAttribute(attr) : root.setAttribute(attr, before)));
    };
    const { theme, palette } = options;
    if (options.look !== undefined && options.look !== null) done.push(rootLook(target, options.look, own, visualName));
    if (typeof theme === 'string') {
      if (NAME.test(theme)) set('data-stagemap-theme', theme);
      else console.warn(`stagemap.mount: theme "${theme}" is not a theme name; the visual keeps the page's theme.`);
    } else if (isObject(theme)) {
      const name = themeStyle(theme, root.ownerDocument);
      if (name) set('data-stagemap-theme', name);
    } else if (theme !== undefined && theme !== null) {
      console.warn(
        "stagemap.mount: theme must be a theme's name or a theme object; the visual keeps the page's theme.",
      );
    }
    if (typeof palette === 'string' && Object.hasOwn(PALETTES, palette)) {
      done.push(rootLook(target, palette, own, visualName));
    } else if (typeof palette === 'string') {
      if (NAME.test(palette)) {
        if (!themeOnPage(palette, root.ownerDocument, 'data-stagemap-palette'))
          console.warn(
            `stagemap.mount: no palette "${palette}" on the page yet (ready-made: ${oneOf(Object.keys(PALETTES))}; a theme's palette needs its CSS on the page).`,
          );
        set('data-stagemap-palette', palette);
      } else
        console.warn(`stagemap.mount: palette "${palette}" is not a theme name; the visual keeps the page's colours.`);
    } else if (isObject(palette)) {
      const given = {};
      for (const [written, value] of Object.entries(palette)) {
        const role = roleName(written);
        if (!PALETTE_ROLES.includes(role) && !own.includes(role)) {
          const roles = [...PALETTE_ROLES, ...own].join(', ');
          console.warn(
            `stagemap.mount: "${role}" is not a palette role or one of this visual's (${roles}); it is left out.`,
          );
        } else if (!PALETTE_ROLES.includes(role) && !visualName) {
          console.warn(
            `stagemap.mount: "${role}" is a visual's own role, but this root names no visual (data-stagemap-visual); it is left out.`,
          );
        } else if (safeColour(value)) {
          given[role] = value.trim();
        } else if (value !== null) {
          console.warn(`stagemap.mount: palette ${role} "${value}" is not a colour; it is left out.`);
        }
      }
      for (const [role, leader] of Object.entries(LEADERS)) {
        if (!(role in given) && leader(given)) given[role] = leader(given);
      }
      if (own.includes('active-ink')) {
        const pages = pageColours(target);
        for (const mode of ['light', 'dark']) checkChosen(given, given, mode, pages, own, 'mount palette');
      }
      for (const [role, value] of Object.entries(given)) {
        const prop = own.includes(role) ? `--stagemap-${visualName}-${role}` : `--stagemap-${role}`;
        const before = target.style.getPropertyValue(prop);
        target.style.setProperty(prop, value);
        done.push(() => (before ? target.style.setProperty(prop, before) : target.style.removeProperty(prop)));
      }
    } else if (palette !== undefined && palette !== null) {
      console.warn(
        "stagemap.mount: palette must be a theme's name or an object of roles; the visual keeps the page's colours.",
      );
    }
    return () => {
      for (const f of done.reverse()) f();
    };
  }

  const PALETTES = Object.freeze({
    teal: { light: { accent: '#0a7675', sidebar: '#eef6f5' }, dark: { accent: '#4cc3bf', sidebar: '#16292b' } },
    indigo: { light: { accent: '#3e4fc1', sidebar: '#eff1fb' }, dark: { accent: '#8b9cf6', sidebar: '#1b1f33' } },
    violet: { light: { accent: '#8a3aa8', sidebar: '#f8eefb' }, dark: { accent: '#d9a0ee', sidebar: '#2a1b30' } },
    crimson: { light: { accent: '#b8284f', sidebar: '#fbeff2' }, dark: { accent: '#f2809f', sidebar: '#2e1a20' } },
    amber: { light: { accent: '#94560a', sidebar: '#fbf4e8' }, dark: { accent: '#f2b54b', sidebar: '#2b2216' } },
    slate: { light: { accent: '#3f5168', sidebar: '#f0f3f6' }, dark: { accent: '#a3b5cc', sidebar: '#1c232c' } },
  });
  const LOOK_KEYS = [
    'palette',
    'seeds',
    'light',
    'dark',
    'mode',
    'css',
    'fonts',
    'base',
    'font_scale',
    'decor',
    'parts',
  ];
  const SEED_NAMES = ['accent', 'background', 'foreground'];
  const SEED_PATTERN =
    /^(#[0-9a-fA-F]{3}|#[0-9a-fA-F]{6}|rgb\(\s*(?:25[0-5]|2[0-4]\d|1\d\d|\d{1,2})\s*,\s*(?:25[0-5]|2[0-4]\d|1\d\d|\d{1,2})\s*,\s*(?:25[0-5]|2[0-4]\d|1\d\d|\d{1,2})\s*\)|var\(\s*--[A-Za-z0-9_-]+\s*(,\s*(#[0-9a-fA-F]{3}|#[0-9a-fA-F]{6}|rgb\(\s*(?:25[0-5]|2[0-4]\d|1\d\d|\d{1,2})\s*,\s*(?:25[0-5]|2[0-4]\d|1\d\d|\d{1,2})\s*,\s*(?:25[0-5]|2[0-4]\d|1\d\d|\d{1,2})\s*\)))?\))$/;
  const SEED_PER_MODE = ['background', 'foreground'];
  const CHECK_KINDS = ['text', 'mark', 'chart'];
  const CHECK_SOURCES = ['derived', 'persona', 'pinned', 'host'];
  const LOOK_EVENT_KEYS = ['font_scale', 'accent', 'background', 'foreground'];
  const DECOR = Object.freeze({
    divider: ['line', 'rule'],
    texture: ['hatch'],
    callout: ['bar', 'margin', 'fill', 'boxed'],
    bold: ['type', 'colour', 'structure'],
  });
  const lookWarned = new Set();
  const FONT_ROLES = ['body', 'display', 'mono', 'title'];
  const FONT_FALLBACK = {
    body: '"Helvetica Neue", Arial, sans-serif',
    display: '"Helvetica Neue", Arial, sans-serif',
    mono: 'ui-monospace, Menlo, monospace',
    title: '"Helvetica Neue", Arial, sans-serif',
  };
  const roleName = (role) => String(role).trim().replace(/_/g, '-');
  const unsafeCss = (t) => /[;{}<>\\]|\/\*/.test(t);
  const safeShadow = (v) => {
    if (typeof v !== 'string') return false;
    const t = v.trim();
    if (!t || unsafeCss(t)) return false;
    if (t === 'none') return true;
    if (globalThis.CSS?.supports) return CSS.supports('box-shadow', t);
    return /\d/.test(t);
  };
  const fontValue = (v, role) => {
    const family =
      typeof v === 'string' ? v.trim() : isObject(v) && typeof v.family === 'string' ? v.family.trim() : '';
    const fallback = isObject(v) && typeof v.fallback === 'string' ? v.fallback.trim() : FONT_FALLBACK[role];
    const value = /^var\(--[A-Za-z0-9_-]+\)$/.test(family)
      ? `${family.slice(0, -1)}, ${fallback})`
      : `"${family}", ${fallback}`;
    if (
      !family ||
      !fallback ||
      /["'`]/.test(family) ||
      /[`]/.test(fallback) ||
      (fallback.match(/"/g) || []).length % 2 === 1 ||
      (fallback.match(/'/g) || []).length % 2 === 1 ||
      [...(family + fallback)].some((c) => c.charCodeAt(0) < 32 || c.charCodeAt(0) === 127) ||
      unsafeCss(family) ||
      unsafeCss(fallback)
    )
      return null;
    if (globalThis.CSS?.supports && !CSS.supports('font-family', value)) return null;
    if ((value.match(/\(/g) || []).length !== (value.match(/\)/g) || []).length) return null;
    return value;
  };
  const MODES = ['auto', 'light', 'dark', 'host'];
  const LIFT = /^(accent|accent-line|focus|good|warn|bad|cat-\d+|seq-hi|div-(lo|hi))$/;
  const WORDS = /^(ink|muted|on-accent|.*-ink)$/;

  const roleVar = () => new RegExp(`^${VAR_PATTERN}$`);
  function spacingRoleValue(v) {
    const onGrid = (n) => Number.isFinite(n) && n >= 0 && n % 2 === 0;
    if (typeof v === 'number') return onGrid(v) ? `${v}px` : null;
    if (typeof v !== 'string') return null;
    const text = v.trim();
    const px = /^(\d+(?:\.\d+)?)px$/.exec(text);
    if (px) return onGrid(Number(px[1])) ? text : null;
    const host = roleVar().exec(text);
    if (!host) return null;
    if (host[1] === undefined) return text;
    const fallback = /^(\d+(?:\.\d+)?)px$/.exec(host[1]);
    return fallback && onGrid(Number(fallback[1])) ? text : null;
  }
  function textRoleValue(role, v) {
    const spec = TEXT_ROLES[role];
    if (spec.values) {
      if (typeof v !== 'string') return null;
      const word = v.trim();
      if (spec.values.includes(word)) return spec.css[word];
      const host = roleVar().exec(word);
      if (!host) return null;
      if (host[1] === undefined) return word;
      return spec.values.includes(host[1]) ? `var(${/--[A-Za-z0-9_-]+/.exec(word)[0]}, ${spec.css[host[1]]})` : null;
    }
    if (typeof v === 'string' && roleVar().test(v.trim())) return v.trim();
    const m = typeof v === 'number' ? [null, String(v)] : /^(-?\d*\.?\d+)(em)?$/.exec(String(v).trim());
    if (!m || (m[2] && spec.unit !== 'em')) return null;
    const n = Number(m[1]);
    if (!Number.isFinite(n) || n < spec.min || n > spec.max || (spec.step && n % spec.step !== 0)) return null;
    return spec.unit ? `${n}${spec.unit}` : String(n);
  }
  const textSizeCss = (roles) =>
    roles
      .map((r) => `--stagemap-${r}: max(${FONT_SCALE.floor}px, calc(var(--stagemap-${r}-base) * var(--stagemap-font-scale)));`)
      .join(' ');
  function fontScaleValue(v) {
    const numeric = typeof v === 'string' && /^\s*-?\d*\.?\d+\s*$/.test(v);
    const n = typeof v === 'number' ? v : numeric ? Number(v) : Number.NaN;
    if (!Number.isFinite(n)) return null;
    const scale = Math.min(FONT_SCALE.max, Math.max(FONT_SCALE.min, n));
    return scale === n ? { scale } : { scale, from: n };
  }
  function phoneCss(values, selectors) {
    const lines = [];
    for (const role of PHONE_ROLES) {
      const regular = values[role];
      const compact = values[`${role}-compact`];
      if (regular !== undefined) lines.push(`--stagemap-${role}: min(${regular}, var(--stagemap-${role}-compact));`);
      else if (compact !== undefined) lines.push(`--stagemap-${role}: var(--stagemap-${role}-compact);`);
    }
    return lines.length
      ? `@media (max-width: ${PHONE_WIDTH}px) { ${selectors.join(', ')} { ${lines.join(' ')} } }\n`
      : '';
  }
  const colourCache = new Map();
  let colourCanvas = null;
  function parseColour(text) {
    if (typeof text !== 'string') return null;
    const t = text.trim();
    if (!t || t.includes('var(')) return null;
    if (colourCache.has(t)) return colourCache.get(t);
    let out = null;
    const h6 = /^#([0-9a-f]{3,4}|[0-9a-f]{6}|[0-9a-f]{8})$/i.exec(t);
    const rgbm = h6
      ? null
      : /^rgba?\(\s*([\d.]+)(%?)[\s,]+([\d.]+)(%?)[\s,]+([\d.]+)(%?)\s*(?:[,/]\s*([\d.]+)(%?))?\s*\)$/i.exec(t);
    if (h6) {
      let h = h6[1];
      if (h.length <= 4) h = [...h].map((c) => c + c).join('');
      out = {
        rgb: [0, 2, 4].map((k) => parseInt(h.slice(k, k + 2), 16) / 255),
        alpha: h.length === 8 ? parseInt(h.slice(6), 16) / 255 : 1,
      };
    } else if (rgbm) {
      const m = rgbm;
      const ch = (v, pc) => Math.min(1, Number(v) / (pc ? 100 : 255));
      const a = m[7] === undefined ? 1 : Math.min(1, Number(m[7]) / (m[8] ? 100 : 1));
      out = { rgb: [ch(m[1], m[2]), ch(m[3], m[4]), ch(m[5], m[6])], alpha: a };
    } else if (typeof document !== 'undefined' && safeColour(t)) {
      try {
        colourCanvas ??= document.createElement('canvas').getContext('2d', { willReadFrequently: true });
        if (colourCanvas) {
          colourCanvas.canvas.width = colourCanvas.canvas.height = 1;
          colourCanvas.clearRect(0, 0, 1, 1);
          colourCanvas.fillStyle = '#000';
          colourCanvas.fillStyle = t;
          colourCanvas.fillRect(0, 0, 1, 1);
          const [r, g, b, a] = colourCanvas.getImageData(0, 0, 1, 1).data;
          out = a ? { rgb: [r, g, b].map((v) => v / 255), alpha: a / 255 } : null;
        }
      } catch {
        out = null;
      }
    }
    colourCache.set(t, out);
    return out;
  }
  const toLinear = (c) => (c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4);
  const toGamma = (c) => (c <= 0.0031308 ? 12.92 * c : 1.055 * c ** (1 / 2.4) - 0.055);
  const luminance = (rgb) => {
    const [r, g, b] = rgb.map(toLinear);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  };
  const contrast = (a, b) => {
    const [x, y] = [luminance(a), luminance(b)].sort((p, q) => q - p);
    return (x + 0.05) / (y + 0.05);
  };
  function toOklch(rgb) {
    const [r, g, b] = rgb.map(toLinear);
    const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    const L = 0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s;
    const A = 1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s;
    const B = 0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s;
    return [L, Math.hypot(A, B), Math.atan2(B, A)];
  }
  function fromOklch([L, C, H]) {
    const A = C * Math.cos(H);
    const B = C * Math.sin(H);
    const l = (L + 0.3963377774 * A + 0.2158037573 * B) ** 3;
    const m = (L - 0.1055613458 * A - 0.0638541728 * B) ** 3;
    const s = (L - 0.0894841775 * A - 1.291485548 * B) ** 3;
    return [
      4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
      -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
      -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s,
    ].map(toGamma);
  }
  function inGamut([L, C, H]) {
    for (let c = C; c >= 0; c -= 0.005) {
      const rgb = fromOklch([L, c, H]);
      if (rgb.every((v) => v >= -0.0005 && v <= 1.0005)) return rgb.map((v) => Math.min(1, Math.max(0, v)));
    }
    return fromOklch([L, 0, H]).map((v) => Math.min(1, Math.max(0, v)));
  }
  const hex = (rgb) =>
    `#${rgb
      .map((v) =>
        Math.round(v * 255)
          .toString(16)
          .padStart(2, '0'),
      )
      .join('')}`;
  function fitColour(rgb, page, need = 3) {
    if (contrast(rgb, page) >= need) return rgb;
    const [L, C, H] = toOklch(rgb);
    const up = luminance(page) < 0.2;
    for (let step = 1; step <= 60; step++) {
      const next = inGamut([Math.min(0.98, Math.max(0.02, L + (up ? 1 : -1) * step * 0.01)), C, H]);
      if (contrast(next, page) >= need) return next;
    }
    return rgb;
  }
  const wordsOn = (rgb, darkInk = [0.078, 0.149, 0.165]) =>
    contrast([1, 1, 1], rgb) >= contrast(darkInk, rgb) ? '#ffffff' : hex(darkInk);

  const leftOut = (v) =>
    v === null ||
    v === undefined ||
    (typeof v === 'string' && v.trim() === '') ||
    (Array.isArray(v) && v.length === 0) ||
    (isObject(v) && Object.keys(v).length === 0);
  const safeColour = (v) => {
    if (typeof v !== 'string') return false;
    const t = v.trim();
    if (!t || /[;{}<>\\]|\/\*/.test(t)) return false;
    if (globalThis.CSS?.supports) return CSS.supports('color', t);
    return COLOUR.test(t);
  };
  const knownThemes = new Map();
  function themeOnPage(name, doc = document, attr = 'data-stagemap-theme') {
    const key = `${attr} ${name}`;
    if (knownThemes.has(key)) return knownThemes.get(key);
    let found = attr === 'data-stagemap-theme' && Boolean(doc.querySelector(`style[data-stagemap-theme-css="${name}"]`));
    if (!found) {
      for (const sheet of doc.styleSheets) {
        let rules;
        try {
          rules = sheet.cssRules;
        } catch {
          continue;
        }
        if ([...rules].some((r) => r.cssText.includes(`[${attr}="${name}"]`))) {
          found = true;
          break;
        }
      }
    }
    if (found) knownThemes.set(key, true);
    return found;
  }

  function readLook(look, own, where, { visual = null, doc = document } = {}) {
    const out = {
      theme: null,
      palette: null,
      light: {},
      dark: {},
      css: {},
      base: {},
      mode: null,
      given: { light: {}, dark: {} },
      both: {},
      seeds: null,
    };
    if (leftOut(look)) return out;
    const note = (text) => console.warn(`stagemap ${where}: ${text}`);
    const roleOk = (role) => {
      if (own.includes(role) && !visual) {
        note(`"${role}" is a part's own colour, but this element names no part (data-stagemap-visual); it is left out.`);
        return false;
      }
      if (PALETTE_ROLES.includes(role) || MODE_ROLES.includes(role) || own.includes(role)) return true;
      note(`"${role}" is not a colour role (${lookRoles(own)}); it is left out.`);
      return false;
    };
    const colours = (map, into, label) => {
      if (leftOut(map)) return;
      if (!isObject(map)) {
        note(`${label} must be an object of colour roles; it is left out.`);
        return;
      }
      for (const [given, value] of Object.entries(map)) {
        const role = roleName(given);
        if (leftOut(value) || !roleOk(role)) continue;
        if (/^shadow-\d$/.test(role)) {
          if (safeShadow(value)) into[role] = value.trim();
          else
            note(
              `${label}.${given} ${quoted(value)} is not a shadow ("0 2px 8px rgba(0, 0, 0, 0.12)" or "none"); it is left out.`,
            );
        } else if (safeColour(value)) into[role] = value.trim();
        else note(`${label}.${given} ${quoted(value)} is not a colour; it is left out.`);
      }
    };
    let full;
    let both = false;
    if (typeof look === 'string') {
      const name = look.trim();
      if (Object.hasOwn(PALETTES, name)) full = { palette: name };
      else if (NAME.test(name)) {
        if (!themeOnPage(name, doc))
          note(
            `no theme "${name}" on the page yet (ready-made palettes: ${oneOf(Object.keys(PALETTES))}; a theme needs its CSS on the page).`,
          );
        out.theme = name;
        return out;
      } else {
        note(`${quoted(name)} is not a palette's or a theme's name; it is left out.`);
        return out;
      }
    } else if (isObject(look) && !Object.keys(look).some((k) => LOOK_KEYS.includes(k))) {
      full = { light: look };
      both = true;
    } else if (isObject(look)) {
      full = look;
    } else {
      note(
        'a look is a palette or theme name, an object of colour roles, or { palette, seeds, light, dark, mode, css, fonts, base, font_scale }; it is left out.',
      );
      return out;
    }
    for (const k of Object.keys(full)) {
      if (k === 'parts' && !leftOut(full.parts) && where !== 'look' && where !== 'root look')
        note('"parts" belongs to the page look (stagemap.look); a part\'s own look leaves it out.');
      else if (k === 'decor' && !leftOut(full.decor) && where !== 'look' && where !== 'root look')
        note('"decor" is for the page\'s look; a part\'s own look leaves it out.');
      else if (!LOOK_KEYS.includes(k)) note(`"${k}" is not part of a look (${oneOf(LOOK_KEYS)}); it is left out.`);
    }
    if (!leftOut(full.palette)) {
      if (typeof full.palette === 'string' && Object.hasOwn(PALETTES, full.palette.trim())) {
        out.palette = full.palette.trim();
        const p = PALETTES[out.palette];
        Object.assign(out.light, p.light);
        Object.assign(out.dark, p.dark);
      } else note(`no palette ${quoted(full.palette)} (${oneOf(Object.keys(PALETTES))}); it is left out.`);
    }
    if (!leftOut(full.seeds)) out.seeds = checkSeeds(full.seeds, note);
    if (both) colours(full.light, out.both, 'look');
    else {
      colours(full.light, out.given.light, 'light');
      colours(full.dark, out.given.dark, 'dark');
    }
    if (!leftOut(full.mode)) {
      if (MODES.includes(full.mode)) out.mode = full.mode;
      else note(`mode must be one of ${oneOf(MODES)}, not ${quoted(full.mode)}; it is left out.`);
    }
    if (!leftOut(full.css)) {
      if (!isObject(full.css)) note('css must be an object: role -> a CSS variable name ("--brand-blue").');
      else
        for (const [given, v] of Object.entries(full.css)) {
          const role = roleName(given);
          if (leftOut(v) || !roleOk(role)) continue;
          if (typeof v === 'string' && /^--[A-Za-z0-9_-]+$/.test(v.trim())) out.css[role] = v.trim();
          else
            note(
              `css.${role} must be a CSS variable's name, such as "--brand-blue", not ${quoted(v)}; it is left out.`,
            );
        }
    }
    if (!leftOut(full.fonts)) {
      if (!isObject(full.fonts))
        note(`fonts must be an object: ${oneOf(FONT_ROLES)} -> a family's name or { family, fallback }.`);
      else
        for (const [role, v] of Object.entries(full.fonts)) {
          if (leftOut(v)) continue;
          if (!FONT_ROLES.includes(role))
            note(`fonts.${role} is not a font role (${oneOf(FONT_ROLES)}); it is left out.`);
          else if (fontValue(v, role)) out.base[`font-${role}`] = fontValue(v, role);
          else
            note(
              `fonts.${role} must be a family's name or { family, fallback }, without quotes, not ${quoted(v)}; it is left out.`,
            );
        }
    }
    if (!leftOut(full.base)) {
      const roles = [...BASE_ROLES, ...TYPE_ROLES, ...SPACING_ROLES, ...Object.keys(TEXT_ROLES)];
      if (!isObject(full.base)) note(`base must be an object of sizes: ${oneOf(roles)}.`);
      else
        for (const [given, v] of Object.entries(full.base)) {
          const role = roleName(given);
          if (leftOut(v)) continue;
          if (!roles.includes(role)) note(`base.${given} is not a size role (${oneOf(roles)}); it is left out.`);
          else if (TEXT_ROLES[role]) {
            const text = textRoleValue(role, v);
            if (text !== null) out.base[role] = text;
            else
              note(
                TEXT_ROLES[role].values
                  ? `base.${given} must be ${oneOf(TEXT_ROLES[role].values)}, or a host variable "var(--x)" (a fallback is one of those words), not ${quoted(v)}; it is left out.`
                  : `base.${given} must be a number from ${TEXT_ROLES[role].min} to ${TEXT_ROLES[role].max}${TEXT_ROLES[role].unit ? ` (in ${TEXT_ROLES[role].unit})` : ''}, or a host variable "var(--x)", not ${quoted(v)}; it is left out.`,
              );
          } else if (SPACING_ROLES.includes(role)) {
            const px = spacingRoleValue(v);
            if (px !== null) out.base[role] = px;
            else
              note(
                `base.${given} must be a whole number of 2 pixels (16), a px length ("16px") or a host variable ("var(--x)" or "var(--x, 16px)"), not ${quoted(v)}; it is left out.`,
              );
          } else if (cssLength(v) !== null) out.base[role] = cssLength(v);
          else
            note(
              `base.${given} must be a number of pixels (12) or a length ("30vh", "50%", "0.75rem", "0", "var(--x)", no calc() and no spaces), not ${quoted(v)}; it is left out.`,
            );
        }
    }
    if (!leftOut(full.font_scale)) {
      const got = fontScaleValue(full.font_scale);
      if (!got)
        note(
          `font_scale must be a number from ${FONT_SCALE.min} to ${FONT_SCALE.max}, not ${quoted(full.font_scale)}; it is left out.`,
        );
      else {
        if (got.from !== undefined)
          note(`font_scale ${got.from} is outside ${FONT_SCALE.min} to ${FONT_SCALE.max}; ${got.scale} is used.`);
        out.base['font-scale'] = String(got.scale);
      }
    }
    return out;
  }
  const lookRoles = (own) => oneOf([...PALETTE_ROLES, ...MODE_ROLES.filter((r) => !PALETTE_ROLES.includes(r)), ...own]);

  const pageCache = new Map();
  function pageColours(at) {
    const doc = at.ownerDocument;
    const theme = at.closest?.('[data-stagemap-theme]')?.getAttribute('data-stagemap-theme') ?? '';
    const rootLook = at.closest?.('[data-stagemap-root-look]')?.getAttribute('data-stagemap-root-look') ?? '';
    const key = `${theme}|${rootLook}`;
    if (pageCache.has(key)) return pageCache.get(key);
    const read = (mode) => {
      const probe = doc.createElement('span');
      probe.dataset.stagemapProbe = '';
      probe.setAttribute('data-stagemap-mode', mode);
      probe.hidden = true;
      at.append(probe);
      const css = getComputedStyle(probe);
      const values = {};
      for (const r of MODE_ROLES) values[r] = css.getPropertyValue(`--stagemap-${r}`).trim();
      probe.remove();
      return {
        page: parseColour(values.page)?.rgb ?? (mode === 'dark' ? [0.055, 0.09, 0.098] : [0.96, 0.97, 0.97]),
        ink: parseColour(values.ink)?.rgb ?? parseColour(mode === 'dark' ? '#e3eeee' : '#14262a').rgb,
        values,
      };
    };
    const found = { light: read('light'), dark: read('dark') };
    pageCache.set(key, found);
    return found;
  }

  const mix = (a, b, share) => a.map((v, i) => v * share + b[i] * (1 - share));
  function fitBoth(rgb, page, need = 4.5) {
    const ok = (c) =>
      contrast(c, page) >= need && Math.max(contrast([1, 1, 1], c), contrast([0.078, 0.149, 0.165], c)) >= need;
    if (ok(rgb)) return rgb;
    const [L, C, H] = toOklch(rgb);
    const up = luminance(page) < 0.2;
    for (let step = 1; step <= 80; step++) {
      const next = inGamut([Math.min(0.98, Math.max(0.02, L + (up ? 1 : -1) * step * 0.01)), C, H]);
      if (ok(next)) return next;
    }
    return fitColour(rgb, page, need);
  }

  function finishLook(read, at, own, where, host = null, report = null) {
    const pages = pageColours(at);
    const seeded = read.seeds ? lookDerive(read, at, where) : null;
    if (report) {
      report.seeds = seeded ? seeded.shown : null;
      report.seedState = seeded?.seedState ?? null;
    }
    const checkPages = host
      ? { ...pages, [host.mode]: { ...pages[host.mode], page: host.rgb, host: true } }
      : pages;
    const final = {};
    const showing = host
      ? [host.mode]
      : read.mode === 'light' || read.mode === 'dark'
        ? [read.mode]
        : ['light', 'dark'];
    for (const mode of ['light', 'dark']) {
      const v = { ...read.base, ...read[mode], ...(seeded?.roles[mode] ?? {}) };
      const other = mode === 'light' ? 'dark' : 'light';
      for (const [role, value] of Object.entries(read.both)) {
        const c = LIFT.test(role) && mode === 'dark' ? parseColour(value) : null;
        v[role] = c && c.alpha === 1 ? hex(fitColour(c.rgb, pages[mode].page)) : value;
      }
      Object.assign(v, read.given[mode]);
      if (
        !read.given[mode].accent &&
        !read.both.accent &&
        !seeded?.shown[mode].accent &&
        !('accent' in (seeded?.roles[mode] ?? {})) &&
        read.given[other].accent
      ) {
        const c = parseColour(read.given[other].accent);
        const pageRgb = parseColour(v.page)?.rgb ?? pages[mode].page;
        if (c) v.accent = hex(fitBoth(c.rgb, pageRgb));
      }
      for (const [role, name] of Object.entries(read.css)) {
        const before = v[role] ?? pages[mode].values[role];
        v[role] = before ? `var(${name}, ${before})` : `var(${name})`;
      }
      const sidebar = v.sidebar ?? pages[mode].values.sidebar;
      if (!('accent-soft' in v) && v.accent && sidebar && !read.css.accent) {
        const a = parseColour(v.accent);
        const t = parseColour(sidebar);
        if (a && t) v['accent-soft'] = hex(mix(a.rgb, t.rgb, colourRules().pairs.mixes.soft_fill.share[mode]));
      }
      for (const [role, leader] of Object.entries(LEADERS)) if (!(role in v) && leader(v)) v[role] = leader(v);
      if (v.accent && !('on-accent' in v)) {
        const c = parseColour(read.css.accent ? resolveVar(at, read.css.accent) : v.accent);
        const lightInk = parseColour(final.light?.ink ?? v.ink)?.rgb ?? pages.light.ink;
        if (c) v['on-accent'] = wordsOn(c.rgb, lightInk ?? undefined);
      }
      if (showing.includes(mode)) {
        checkLook(v, read, mode, checkPages, own, where);
        checkChosen(v, { ...read.both, ...read.given[mode] }, mode, checkPages, own, where);
      }
      final[mode] = v;
    }
    return final;
  }
  const resolveVar = (at, name) => getComputedStyle(at).getPropertyValue(name).trim() || null;
  function checkLook(v, read, mode, pages, own, where) {
    const chosen = { ...read.both, ...read.given[mode], ...(v['on-accent'] ? { 'on-accent': v['on-accent'] } : {}) };
    for (const role of Object.keys(chosen)) {
      if (!(LIFT.test(role) || WORDS.test(role))) continue;
      const need = WORDS.test(role) ? 4.5 : 3;
      const fill =
        role === 'on-accent' ? 'accent' : role.endsWith('-ink') && role !== 'accent-ink' ? role.slice(0, -4) : null;
      const under = fill && v[fill] ? v[fill] : own.length && v.surface && WORDS.test(role) ? v.surface : null;
      const fg = parseColour(v[role]);
      const bgParsed = under ? parseColour(under) : { rgb: pages[mode].page, alpha: 1 };
      const key = `${where} ${mode} ${role} ${v[role]} ${pages[mode].host ? hex(pages[mode].page) : ''}`;
      if (!fg || !bgParsed) {
        if (!lookWarned.has(`${key} ?`)) {
          lookWarned.add(`${key} ?`);
          console.info(`stagemap ${where}: ${role} ${v[role]} in ${mode} mode can't be checked for contrast here.`);
        }
        continue;
      }
      const bg = bgParsed.alpha < 1 ? mix(bgParsed.rgb, pages[mode].page, bgParsed.alpha) : bgParsed.rgb;
      const shown = fg.alpha < 1 ? mix(fg.rgb, bg, fg.alpha) : fg.rgb;
      const has = contrast(shown, bg);
      if (has < need && !lookWarned.has(key)) {
        lookWarned.add(key);
        console.warn(
          `stagemap ${where}: ${role} ${v[role]} has ${has.toFixed(1)}:1 contrast in ${mode} mode against ${under ? (fill ?? 'surface') : pages[mode].host ? `the host's background ${hex(pages[mode].page)}` : 'the page'} (at least ${need}:1 is readable); it is kept.`,
        );
      }
    }
  }

  const CHOSEN_ROLES = ['active', 'active-ink', 'mark', 'surface', 'ink'];
  function checkChosen(v, given, mode, pages, own, where) {
    if (!['active', 'active-ink', 'mark'].every((r) => own.includes(r))) return;
    if (!CHOSEN_ROLES.some((r) => r in given)) return;
    const page = pages[mode];
    const pick = (...options) => options.map((o) => parseColour(o)).find(Boolean) ?? null;
    const words = pick(v['active-ink'], v.ink, page.values.ink);
    const fill = pick(v.active, v['accent-soft'], page.values['accent-soft']);
    const bar = pick(v.mark, v['accent-ink'], page.values['accent-ink'], v.accent, page.values.accent);
    const surface = pick(v.surface, v.sidebar, page.values.sidebar);
    const surfaceEnd = pick(v['surface-end']) ?? surface;
    if (!words || !fill || !bar || !surface) return;
    const onPage = (c) => (c.alpha < 1 ? mix(c.rgb, page.page, c.alpha) : c.rgb);
    const ground = onPage(surface);
    const endGround = onPage(surfaceEnd);
    const fillRgb = fill.alpha < 1 ? mix(fill.rgb, ground, fill.alpha) : fill.rgb;
    const wordsRgb = words.alpha < 1 ? mix(words.rgb, fillRgb, words.alpha) : words.rgb;
    const barRgb = bar.alpha < 1 ? mix(bar.rgb, fillRgb, bar.alpha) : bar.rgb;
    const checks = [
      ['words', wordsRgb, fillRgb, 4.5, 'its fill'],
      ['bar', barRgb, fillRgb, 3, 'its fill'],
      ['bar', barRgb, ground, 3, 'the surface'],
    ];
    if (endGround.some((c, i) => c !== ground[i])) checks.push(['bar', barRgb, endGround, 3, "the surface's end"]);
    for (const [what, fg, bg, need, on] of checks) {
      const has = contrast(fg, bg);
      if (has >= need) continue;
      const key = `${where} ${mode} chosen ${what} ${hex(fg)} on ${hex(bg)}`;
      if (lookWarned.has(key)) continue;
      lookWarned.add(key);
      console.warn(
        `stagemap ${where}: the chosen item's ${what} ${hex(fg)} has ${has.toFixed(1)}:1 contrast in ${mode} mode against ${on} ${hex(bg)} (at least ${need}:1 is readable); it is kept.`,
      );
    }
  }

  function lookCss(scope, final, partOf) {
    const prop = (role) => {
      const part = partOf(role);
      return part ? `--stagemap-${part}-${role}` : `--stagemap-${role}`;
    };
    const decl = (v) => {
      const sized = TYPE_ROLES.filter((r) => ('font-scale' in v ? true : r in v));
      const lines = Object.entries(v).map(([r, c]) =>
        TYPE_ROLES.includes(r) ? `--stagemap-${r}-base: ${c};` : `${prop(r)}: ${c};`,
      );
      return [...lines, textSizeCss(sized)].filter(Boolean).join(' ');
    };
    const m = (mode) => `[data-stagemap-mode="${mode}"]`;
    const around = (mode) => {
      const others = ['light', 'dark', 'auto'].filter((o) => o !== mode).map((o) => `${m(mode)} ${m(o)} *`);
      return `${m(mode)} ${scope}:where(:not(${others.join(', ')})), ${scope} ${m(mode)}`;
    };
    const L = decl(final.light);
    const D = decl(final.dark);
    if (!L && !D) return '';
    const phone = phoneCss(final.light, [
      scope,
      around('dark'),
      around('auto'),
      around('light'),
      `${scope}${m('light')}`,
      `${scope}${m('dark')}`,
      `${scope}${m('auto')}`,
    ]);
    return (
      `${scope} { ${L} }\n` +
      `@media screen { ${around('dark')} { ${D} } }\n` +
      `@media screen and (prefers-color-scheme: dark) { ${around('auto')} { ${D} } }\n` +
      `${around('light')} { ${L} }\n` +
      `${scope}${m('light')} { ${L} }\n` +
      `@media screen { ${scope}${m('dark')} { ${D} } }\n` +
      `@media screen and (prefers-color-scheme: dark) { ${scope}${m('auto')} { ${D} } }\n` +
      phone
    );
  }
  const hasColours = (read) =>
    [read.light, read.dark, read.both, read.given.light, read.given.dark, read.css, read.base, read.seeds ?? {}].some(
      (o) => Object.keys(o).length,
    );
  const warnCssNames = (read, at, where) => {
    for (const [role, name] of Object.entries(read.css)) {
      if (!resolveVar(at, name))
        console.warn(
          `stagemap ${where}: css.${role} names ${name}, which this page doesn't set (yet); the colour it replaces stays until it does.`,
        );
    }
  };

  const HOST_ATTRS = ['class', 'style', 'data-bs-theme'];
  const upFrom = (el) => el.parentElement ?? el.parentNode?.host ?? null;
  function hostBackground(root) {
    const view = root.ownerDocument?.defaultView;
    const layers = [];
    let under = [1, 1, 1];
    for (let el = upFrom(root); el && view; el = upFrom(el)) {
      const c = parseColour(view.getComputedStyle(el).backgroundColor);
      if (!c || c.alpha <= 0) continue;
      if (c.alpha >= 1) {
        under = c.rgb;
        break;
      }
      layers.push(c);
    }
    for (const c of layers.reverse()) under = mix(c.rgb, under, c.alpha);
    return under;
  }
  const adoptedWatchers = new WeakMap();
  const ADOPTED_MUTATORS = new Set(['push', 'pop', 'shift', 'unshift', 'splice', 'reverse', 'sort']);
  function watchAdopted(target, onChange) {
    if (!target || !('adoptedStyleSheets' in target)) return () => {};
    let entry = adoptedWatchers.get(target);
    if (!entry) {
      let desc = null;
      for (let p = Object.getPrototypeOf(target); p && !desc; p = Object.getPrototypeOf(p))
        desc = Object.getOwnPropertyDescriptor(p, 'adoptedStyleSheets');
      if (!desc?.get || !desc?.set) return () => {};
      const cbs = new Set();
      const notify = () => {
        for (const fn of [...cbs]) fn();
      };
      let cachedTarget = null;
      let cachedProxy = null;
      try {
        Object.defineProperty(target, 'adoptedStyleSheets', {
          configurable: true,
          enumerable: desc.enumerable,
          get() {
            const arr = desc.get.call(this);
            if (arr !== cachedTarget) {
              cachedTarget = arr;
              cachedProxy = new Proxy(arr, {
                get(t, prop) {
                  const v = Reflect.get(t, prop, t);
                  if (typeof v === 'function') {
                    if (ADOPTED_MUTATORS.has(prop)) {
                      return (...args) => {
                        const r = Reflect.apply(v, t, args);
                        notify();
                        return r;
                      };
                    }
                    return v.bind(t);
                  }
                  return v;
                },
                set(t, prop, value) {
                  const r = Reflect.set(t, prop, value);
                  notify();
                  return r;
                },
              });
            }
            return cachedProxy;
          },
          set(val) {
            desc.set.call(this, val);
            notify();
          },
        });
      } catch {
        return () => {};
      }
      entry = { cbs };
      adoptedWatchers.set(target, entry);
    }
    entry.cbs.add(onChange);
    return () => {
      entry.cbs.delete(onChange);
      if (entry.cbs.size === 0 && adoptedWatchers.get(target) === entry) {
        adoptedWatchers.delete(target);
        try {
          delete target.adoptedStyleSheets;
        } catch {
        }
      }
    };
  }

  function watchHost(at, onSignal, { includeSelf = false } = {}) {
    const doc = at.ownerDocument;
    const view = doc?.defaultView;
    if (!view) return { stop() {}, flush() {} };
    let stopped = false;
    let queued = false;
    const offs = [];
    const run = () => {
      queued = false;
      if (stopped) return;
      onSignal();
    };
    const again = () => {
      if (stopped || queued) return;
      queued = true;
      if (typeof view.requestAnimationFrame === 'function') view.requestAnimationFrame(run);
      else queueMicrotask(run);
    };
    const listen = (target, type, fn, options) => {
      target.addEventListener(type, fn, options);
      offs.push(() => target.removeEventListener(type, fn, options));
    };
    let chain = null;
    const chainEnded = [];
    const ended = (e) => {
      if (
        e.target === e.currentTarget &&
        (e.propertyName === 'background-color' || (includeSelf && e.propertyName === 'color'))
      )
        again();
    };
    const unarm = () => {
      chain?.disconnect();
      for (const el of chainEnded.splice(0)) el.removeEventListener('transitionend', ended);
    };
    const arm = () => {
      unarm();
      chain = new view.MutationObserver(again);
      const targets = new Set();
      if (includeSelf && (at === doc.documentElement || at === doc.body)) {
        if (doc.body) targets.add(doc.body);
        if (doc.documentElement) targets.add(doc.documentElement);
      } else {
        for (let el = includeSelf ? at : upFrom(at); el; el = upFrom(el)) targets.add(el);
      }
      for (const el of targets) {
        chain.observe(el, { attributes: true, attributeFilter: HOST_ATTRS });
        el.addEventListener('transitionend', ended);
        chainEnded.push(el);
      }
    };
    offs.push(unarm);
    arm();
    if (!at.isConnected) {
      const joined = new view.MutationObserver(() => {
        if (!at.isConnected) return;
        joined.disconnect();
        arm();
        again();
      });
      joined.observe(doc, { childList: true, subtree: true });
      offs.push(() => joined.disconnect());
    }
    const ours = (n) => [...n.attributes].some((a) => a.name.startsWith('data-stagemap-'));
    const checkSheetNode = (n) => {
      if (n.nodeType !== 1 || ours(n)) return;
      const link = n.localName === 'link' && /\bstylesheet\b/i.test(n.rel ?? '');
      if (link && n.isConnected) {
        listen(n, 'load', again, { once: true });
        listen(n, 'error', again, { once: true });
      }
      if (link || n.localName === 'style') {
        again();
        return;
      }
      if (n.childElementCount && n.querySelectorAll) {
        for (const sub of n.querySelectorAll('style, link[rel~="stylesheet" i]')) checkSheetNode(sub);
      }
    };
    const sheets = new view.MutationObserver((records) => {
      for (const r of records) for (const n of [...r.addedNodes, ...r.removedNodes]) checkSheetNode(n);
    });
    let observedBody = false;
    const observeSheets = () => {
      if (doc.head) sheets.observe(doc.head, { childList: true });
      if (doc.body && !observedBody) {
        sheets.observe(doc.body, { childList: true, subtree: true });
        observedBody = true;
      }
    };
    observeSheets();
    offs.push(() => sheets.disconnect());
    offs.push(watchAdopted(doc, again));
    const rootNode = at.getRootNode?.();
    if (rootNode && rootNode !== doc) offs.push(watchAdopted(rootNode, again));
    if (typeof view.matchMedia === 'function') {
      const mq = view.matchMedia('(prefers-color-scheme: dark)');
      const onMedia = () => again();
      if (typeof mq.addEventListener === 'function') {
        mq.addEventListener('change', onMedia);
        offs.push(() => mq.removeEventListener('change', onMedia));
      } else if (typeof mq.addListener === 'function') {
        mq.addListener(onMedia);
        offs.push(() => mq.removeListener(onMedia));
      }
    }
    if (doc.readyState !== 'complete')
      listen(
        view,
        'load',
        () => {
          arm();
          observeSheets();
          again();
        },
        { once: true },
      );
    return {
      stop() {
        stopped = true;
        for (const off of offs.splice(0)) off();
      },
      flush() {
        chain?.takeRecords();
        sheets?.takeRecords();
      },
    };
  }

  function hostLook(root) {
    let themeInks = null;
    const out = {
      now: null,
      checks: [],
      pick(read) {
        const rgb = hostBackground(root);
        if (!themeInks) {
          const pages = pageColours(root);
          themeInks = { light: pages.light.ink, dark: pages.dark.ink };
        }
        const ink = (mode) => {
          const css = read.css.ink ? parseColour(resolveVar(root, read.css.ink) ?? '') : null;
          const given = parseColour(read.given[mode].ink ?? read.both.ink ?? '');
          return css?.rgb ?? given?.rgb ?? themeInks[mode];
        };
        const better = (light, dark) => contrast(dark, rgb) - contrast(light, rgb);
        const by = better(ink('light'), ink('dark'));
        const mode = (Math.abs(by) > 1e-6 ? by : better(themeInks.light, themeInks.dark)) > 0 ? 'dark' : 'light';
        out.now = { mode, rgb, key: `${mode} ${hex(rgb)}` };
        return out.now;
      },
    };
    return out;
  }

  let pageLook = null;
  let pageLookDoc = null;
  const pageLookStops = new WeakMap();
  function restoreLookTheme(html) {
    if (html.dataset.stagemapLookTheme === undefined) return;
    const was = html.dataset.stagemapLookTheme;
    if (was) html.setAttribute('data-stagemap-theme', was);
    else html.removeAttribute('data-stagemap-theme');
    delete html.dataset.stagemapLookTheme;
  }
  const ROOT_ATTR = 'data-stagemap-root-look';
  const OUTSIDE_ROOTS = `:where(:not([${ROOT_ATTR}], [${ROOT_ATTR}] *))`;
  function look(given, { doc = document, root = null } = {}) {
    if (root !== null && root !== undefined) {
      if (root?.nodeType !== 1) {
        console.warn("stagemap.look: root must be an element (the page's root); the look is left out.");
        return false;
      }
      return lookOnRoot(given, root);
    }
    if (given === undefined) return pageLook === null ? null : JSON.parse(JSON.stringify(pageLook));
    if (!(given === null || typeof given === 'string' || isObject(given))) {
      console.warn(
        'stagemap.look: give a palette or theme name, an object of colour roles, or { palette, seeds, light, dark, mode, css, fonts, base, font_scale, parts }; the page keeps its look.',
      );
      return false;
    }
    const html = doc.documentElement;
    modeStart(html);
    seedLookSeen(html, readBuiltLook(doc)?.shown);
    pageLookStops.get(doc)?.();
    pageLookStops.delete(doc);
    restoreLookTheme(html);
    let css = '';
    let theme = null;
    let mode = null;
    let keepBuilt = false;
    let page = null;
    const pagePartReads = [];
    const report = {};
    const buildPageCss = (at, rep, keepBuiltNow) => {
      let outCss = '';
      if (keepBuiltNow) {
        const rest = restOfBuiltLook(page);
        if (hasColours(rest)) {
          warnCssNames(rest, html, 'look');
          outCss += lookCss(':root', finishLook(rest, at, [], 'look'), () => null);
        }
      } else if (hasColours(page)) {
        warnCssNames(page, html, 'look');
        outCss += lookCss(':root', finishLook(page, at, [], 'look', null, rep), () => null);
      }
      for (const p of pagePartReads) {
        outCss += lookCss(p.scope, finishLook(p.read, at, p.own, `look parts.${p.name}`), (r) =>
          p.own.includes(r) ? p.name : null,
        );
      }
      return outCss;
    };
    if (given !== null && !leftOut(given)) {
      let pageOnly = given;
      if (isObject(given) && ('parts' in given || 'decor' in given)) {
        pageOnly = { ...given };
        delete pageOnly.parts;
        delete pageOnly.decor;
      }
      page = readLook(pageOnly, [], 'look', { doc });
      if (page.mode === 'host') {
        if (!lookWarned.has('look: host without a root')) {
          lookWarned.add('look: host without a root');
          console.info(
            'stagemap.look: mode "host" needs a root (stagemap.look(look, { root })); on the whole page it acts as "auto".',
          );
        }
        page.mode = 'auto';
      }
      theme = page.theme;
      mode = page.mode;
      pageCache.clear();
      const built = page.seeds ? matchBuiltLook(doc, html, page) : null;
      if (built) {
        keepBuilt = true;
        report.seeds = built.shown;
        report.seedState = built.seedState ?? null;
      }
      const parts = isObject(given) ? given.parts : null;
      if (!leftOut(parts)) {
        if (!isObject(parts)) console.warn('stagemap.look: parts must be an object: part name -> look.');
        else
          for (const [written, partLook] of Object.entries(parts)) {
            const name = roleName(written);
            if (!NAME.test(name)) {
              console.warn(`stagemap.look: parts.${quoted(name)} is not a part's name; it is left out.`);
              continue;
            }
            const def = registry.get(name);
            if (!def) continue;
            const own = Array.isArray(def.roles) ? def.roles : [];
            const read = readLook(partLook, own, `look parts.${name}`, { visual: name, doc });
            if (!hasColours(read)) continue;
            const on = typeof def.lookOn === 'string' ? ` ${def.lookOn}` : '';
            const scope = `[data-stagemap-visual="${name}"][data-stagemap-visual]${on}${OUTSIDE_ROOTS}`;
            pagePartReads.push({ name, own, read, scope });
          }
      }
      css = buildPageCss(doc.body ?? html, report, keepBuilt);
    }
    doc.querySelector('style[data-stagemap-look-page]')?.remove();
    if (!keepBuilt) doc.querySelector('style[data-stagemap-look-built]')?.remove();
    restoreLookTheme(html);
    if (html.dataset.stagemapLookMode !== undefined) {
      if (html.getAttribute('data-stagemap-mode') === html.dataset.stagemapLookMode) {
        const was = html.dataset.stagemapLookModeWas;
        if (was) html.setAttribute('data-stagemap-mode', was);
        else html.removeAttribute('data-stagemap-mode');
      }
      delete html.dataset.stagemapLookMode;
      delete html.dataset.stagemapLookModeWas;
    }
    pageCache.clear();
    if (given === null || leftOut(given)) {
      pageLook = null;
      modeEnd(html);
      settleLook(html, null, 'host');
      return true;
    }
    pageLook = JSON.parse(JSON.stringify(given));
    pageLookDoc = doc;
    if (theme) {
      html.dataset.stagemapLookTheme = html.getAttribute('data-stagemap-theme') ?? '';
      html.setAttribute('data-stagemap-theme', theme);
    }
    const current = html.getAttribute('data-stagemap-mode');
    if (mode && mode !== 'auto' && (current === null || current === 'auto')) {
      html.dataset.stagemapLookModeWas = current ?? '';
      html.setAttribute('data-stagemap-mode', mode);
      html.dataset.stagemapLookMode = mode;
    } else if (mode && mode !== 'auto') {
      console.info(`stagemap.look: the page is already ${current} (the reader's choice), so mode "${mode}" waits.`);
    }
    if (css) {
      const style = doc.createElement('style');
      style.dataset.stagemapLookPage = '';
      style.textContent = css;
      doc.head.append(style);
    }
    const watchVars = hasVarSeeds(page) || pagePartReads.some((p) => hasVarSeeds(p.read));
    if (watchVars) {
      const initState = pagePartReads.some((p) => hasVarSeeds(p.read)) ? null : report.seedState;
      const tracker = makeSeedTracker(doc.body ?? html, page, pagePartReads, initState);
      const watcher = watchHost(
        doc.body ?? html,
        () => {
          const at = doc.body ?? html;
          if (!tracker.changed(at)) return;
          pageCache.clear();
          doc.querySelector('style[data-stagemap-look-built]')?.remove();
          const nextReport = {};
          const nextCss = buildPageCss(at, nextReport, false);
          let style = doc.querySelector('style[data-stagemap-look-page]');
          if (nextCss) {
            if (!style) {
              style = doc.createElement('style');
              style.dataset.stagemapLookPage = '';
              doc.head.append(style);
            }
            style.textContent = nextCss;
          } else {
            style?.remove();
          }
          pageCache.clear();
          settleLook(html, nextReport.seeds ?? null, 'host', page?.base['font-scale'] ?? null);
          watcher.flush();
        },
        { includeSelf: true },
      );
      pageLookStops.set(doc, watcher.stop);
    }
    modeEnd(html);
    settleLook(html, report.seeds ?? null, 'host', page?.base['font-scale'] ?? null);
    return true;
  }
  const names = (given, name) =>
    isObject(given) && isObject(given.parts) && Object.keys(given.parts).some((k) => roleName(k) === name);
  const lookForDefined = (name) => {
    if (pageLook && names(pageLook, name)) look(pageLook, { doc: pageLookDoc ?? document });
    for (const ref of [...rootRefs]) {
      const root = ref.deref();
      const held = root && rootLooks.get(root);
      if (!held) rootRefs.delete(ref);
      else if (names(held.given, name)) lookOnRoot(held.given, root, held.token);
    }
  };

  const rootLooks = new WeakMap();
  const rootRefs = new Set();
  const weakRef = (el) => (typeof WeakRef === 'function' ? new WeakRef(el) : { deref: () => el });
  let rootSerial = 0;
  function lookOnRoot(given, root, token = Symbol('root look')) {
    const held = rootLooks.get(root);
    if (given === undefined) return held ? JSON.parse(JSON.stringify(held.given)) : null;
    if (!(given === null || typeof given === 'string' || isObject(given))) {
      console.warn(
        'stagemap.look: give a palette or theme name, an object of colour roles, or { palette, seeds, light, dark, mode, css, fonts, base, font_scale, parts }; the root keeps its look.',
      );
      return false;
    }
    modeStart(root);
    held?.undo(true);
    if (given === null || leftOut(given)) {
      modeEnd(root);
      settleLook(root, null, 'host');
      return true;
    }
    const doc = root.ownerDocument;
    const id = `r${++rootSerial}`;
    const undo = [];
    const before = (attr) => {
      const was = root.getAttribute(attr);
      undo.push(() => (was === null ? root.removeAttribute(attr) : root.setAttribute(attr, was)));
    };
    before(ROOT_ATTR);
    root.setAttribute(ROOT_ATTR, id);
    if (isObject(given) && 'decor' in given) {
      const decor = given.decor;
      before('data-stagemap-decor');
      if (decor === null || (isObject(decor) && Object.keys(decor).length === 0)) {
        root.removeAttribute('data-stagemap-decor');
      } else if (!isObject(decor)) {
        const id = 'root-look: decor-not-object';
        if (!lookWarned.has(id)) {
          lookWarned.add(id);
          console.warn(
            'stagemap root look: decor must be an object ({ callout: "margin", divider: "rule" }); it is left out.',
          );
        }
        root.removeAttribute('data-stagemap-decor');
      } else {
        const valid = {};
        for (const [k, v] of Object.entries(decor)) {
          if (!Object.hasOwn(DECOR, k)) {
            const id = `root-look: decor-key-${k}`;
            if (!lookWarned.has(id)) {
              lookWarned.add(id);
              console.warn(
                `stagemap root look: "${k}" is not a decor key (${oneOf(Object.keys(DECOR))}); it is left out.`,
              );
            }
          } else if (v === null) {
          } else if (!DECOR[k].includes(v)) {
            const id = `root-look: decor-value-${k}-${v}`;
            if (!lookWarned.has(id)) {
              lookWarned.add(id);
              console.warn(
                `stagemap root look: decor.${k} must be one of ${oneOf(DECOR[k])}, not ${quoted(v)}; it is left out.`,
              );
            }
          } else {
            valid[k] = v;
          }
        }
        const words = Object.keys(valid)
          .sort()
          .map((k) => `${k}-${valid[k]}`);
        if (words.length) {
          root.setAttribute('data-stagemap-decor', words.join(' '));
        } else {
          root.removeAttribute('data-stagemap-decor');
        }
      }
    }
    let rootOnly = given;
    if (isObject(given) && ('parts' in given || 'decor' in given)) {
      rootOnly = { ...given };
      delete rootOnly.parts;
      delete rootOnly.decor;
    }
    const read = readLook(rootOnly, [], 'root look', { doc });
    if (read.theme) {
      before('data-stagemap-theme');
      root.setAttribute('data-stagemap-theme', read.theme);
    }
    pageCache.clear();
    const host = read.mode === 'host' ? hostLook(root) : null;
    if (read.mode) {
      before('data-stagemap-mode');
      if (host) hostModeRoots.add(root);
      root.setAttribute('data-stagemap-mode', host ? host.pick(read).mode : read.mode);
    }
    const R = `[${ROOT_ATTR}="${id}"]`;
    const partReads = [];
    const parts = isObject(given) ? given.parts : null;
    if (!leftOut(parts)) {
      if (!isObject(parts)) console.warn('stagemap.look: parts must be an object: part name -> look.');
      else
        for (const [written, partLook] of Object.entries(parts)) {
          const name = roleName(written);
          if (!NAME.test(name)) {
            console.warn(`stagemap.look: parts.${quoted(name)} is not a part's name; it is left out.`);
            continue;
          }
          const def = registry.get(name);
          if (!def) continue;
          const own = Array.isArray(def.roles) ? def.roles : [];
          const partRead = readLook(partLook, own, `root look parts.${name}`, { visual: name, doc });
          if (!hasColours(partRead)) continue;
          const on = typeof def.lookOn === 'string' ? ` ${def.lookOn}` : '';
          partReads.push({ name, own, read: partRead, on });
        }
    }
    const buildRootCss = (hostNow, rep) => {
      let outCss = '';
      if (hasColours(read)) {
        warnCssNames(read, root, 'root look');
        outCss += lookCss(
          `${R}[${ROOT_ATTR}][${ROOT_ATTR}]`,
          finishLook(read, root, [], 'root look', hostNow, rep),
          () => null,
        );
      }
      for (const p of partReads) {
        const final = finishLook(p.read, root, p.own, `root look parts.${p.name}`, hostNow);
        const partOf = (r) => (p.own.includes(r) ? p.name : null);
        const part = `[data-stagemap-visual="${p.name}"][data-stagemap-visual]`;
        outCss += lookCss(`${part}:where(${R} *)${p.on}`, final, partOf);
        outCss += lookCss(`${part}${R}[${ROOT_ATTR}][${ROOT_ATTR}]${p.on}`, final, partOf);
      }
      return outCss;
    };
    const report = {};
    const css = buildRootCss(host?.now, report);
    if (host) {
      if (hasColours(read)) host.checks.push((now) => finishLook(read, root, [], 'root look', now));
      for (const p of partReads)
        host.checks.push((now) => finishLook(p.read, root, p.own, `root look parts.${p.name}`, now));
    }
    if (css) {
      const style = doc.createElement('style');
      style.dataset.stagemapRootLookCss = id;
      style.textContent = css;
      root.append(style);
    }
    undo.push(() => {
      for (const old of root.querySelectorAll(':scope > style[data-stagemap-root-look-css]')) old.remove();
    });
    const watchVars = hasVarSeeds(read) || partReads.some((p) => hasVarSeeds(p.read));
    if (host || watchVars) {
      const initState = partReads.some((p) => hasVarSeeds(p.read)) ? null : report.seedState;
      const tracker = watchVars ? makeSeedTracker(root, read, partReads, initState) : null;
      const watcher = watchHost(
        root,
        () => {
          let modeChanged = false;
          let hostNow = host?.now ?? null;
          if (host) {
            const was = host.now?.key;
            hostNow = host.pick(read);
            if (hostNow.key !== was) {
              modeChanged = true;
              root.setAttribute('data-stagemap-mode', hostNow.mode);
              settleMode(root, 'host');
            }
          }
          let seedsChanged = false;
          if (tracker?.changed(root)) {
            seedsChanged = true;
            pageCache.clear();
            const nextReport = {};
            const nextCss = buildRootCss(hostNow, nextReport);
            let style = root.querySelector(':scope > style[data-stagemap-root-look-css]');
            if (nextCss) {
              if (!style) {
                style = doc.createElement('style');
                style.dataset.stagemapRootLookCss = id;
                root.append(style);
              }
              style.textContent = nextCss;
            } else {
              style?.remove();
            }
            pageCache.clear();
            settleLook(root, nextReport.seeds ?? null, 'host', read.base['font-scale'] ?? null);
          }
          if (modeChanged && !seedsChanged && host) {
            for (const check of host.checks) check(hostNow);
          }
          watcher.flush();
        },
        { includeSelf: watchVars },
      );
      undo.push(watcher.stop);
    }
    pageCache.clear();
    let done = false;
    const record = {
      given: JSON.parse(JSON.stringify(given)),
      token,
      undo(keepMode = false) {
        if (done) return;
        done = true;
        hostModeRoots.delete(root);
        for (const f of undo.reverse()) f();
        if (rootLooks.get(root) === record) rootLooks.delete(root);
        rootRefs.delete(record.ref);
        pageCache.clear();
        if (!keepMode) {
          modeEnd(root);
          settleLook(root, null, 'host');
        }
      },
    };
    record.ref = weakRef(root);
    rootLooks.set(root, record);
    rootRefs.add(record.ref);
    modeEnd(root);
    settleLook(root, report.seeds ?? null, 'host', read.base['font-scale'] ?? null);
    return () => {
      if (rootLooks.get(root)?.token === token) rootLooks.get(root).undo();
    };
  }

  let lookSerial = 0;
  function rootLook(root, given, own, visualName) {
    const read = readLook(given, own, 'mount look', { visual: visualName || null, doc: root.ownerDocument });
    const undo = [];
    if (read.theme) {
      const before = root.getAttribute('data-stagemap-theme');
      root.setAttribute('data-stagemap-theme', read.theme);
      undo.push(() =>
        before === null ? root.removeAttribute('data-stagemap-theme') : root.setAttribute('data-stagemap-theme', before),
      );
    }
    const host = read.mode === 'host' ? hostLook(root) : null;
    host?.pick(read);
    const doc = root.ownerDocument;
    let mountId = null;
    let mountScope = null;
    const mountReport = {};
    if (hasColours(read)) {
      mountId = `l${++lookSerial}`;
      root.setAttribute('data-stagemap-look', mountId);
      const style = doc.createElement('style');
      style.dataset.stagemapLookCss = mountId;
      mountScope = `[data-stagemap-look="${mountId}"][data-stagemap-look][data-stagemap-look]`;
      warnCssNames(read, root, 'mount look');
      style.textContent = lookCss(mountScope, finishLook(read, root, own, 'mount look', host?.now, mountReport), (r) =>
        own.includes(r) && visualName ? visualName : null,
      );
      host?.checks.push((now) => finishLook(read, root, own, 'mount look', now));
      doc.head.append(style);
      undo.push(() => {
        doc.querySelector(`style[data-stagemap-look-css="${mountId}"]`)?.remove();
        root.removeAttribute('data-stagemap-look');
      });
    }
    if (read.mode) {
      const before = root.getAttribute('data-stagemap-mode');
      root.setAttribute('data-stagemap-mode', host ? host.now.mode : read.mode);
      undo.push(() =>
        before === null ? root.removeAttribute('data-stagemap-mode') : root.setAttribute('data-stagemap-mode', before),
      );
    }
    const watchVars = hasVarSeeds(read);
    if (host || watchVars) {
      const tracker = watchVars ? makeSeedTracker(root, read, [], mountReport.seedState) : null;
      const watcher = watchHost(
        root,
        () => {
          let modeChanged = false;
          let hostNow = host?.now ?? null;
          if (host) {
            const was = host.now?.key;
            hostNow = host.pick(read);
            if (hostNow.key !== was) {
              modeChanged = true;
              root.setAttribute('data-stagemap-mode', hostNow.mode);
            }
          }
          let seedsChanged = false;
          if (tracker && mountId && mountScope && tracker.changed(root)) {
            seedsChanged = true;
            pageCache.clear();
            const style = doc.querySelector(`style[data-stagemap-look-css="${mountId}"]`);
            if (style)
              style.textContent = lookCss(mountScope, finishLook(read, root, own, 'mount look', hostNow), (r) =>
                own.includes(r) && visualName ? visualName : null,
              );
            pageCache.clear();
          }
          if (modeChanged && !seedsChanged && host) {
            for (const check of host.checks) check(hostNow);
          }
          watcher.flush();
        },
        { includeSelf: watchVars },
      );
      undo.push(watcher.stop);
    }
    return () => {
      for (const f of undo.reverse()) f();
    };
  }

  function themeStyle(theme, doc = document) {
    const name = theme.name;
    const complete = (block, roles) => isObject(block) && roles.every((r) => typeof block[r] === 'string');
    const REQUIRED = MODE_ROLES.filter((r) => !(r in CHART_LEADERS));
    if (
      ![1, 2].includes(theme.stagemap_theme) ||
      typeof name !== 'string' ||
      !NAME.test(name) ||
      !complete(theme.base, BASE_ROLES) ||
      !complete(theme.light, REQUIRED) ||
      !complete(theme.dark, REQUIRED) ||
      !isObject(theme.fonts) ||
      !['display', 'body', 'mono'].every((r) => complete(theme.fonts[r], ['family', 'fallback']))
    ) {
      console.warn(
        "stagemap.mount: the theme object is not a complete theme (themes/README.md); the visual keeps the page's theme.",
      );
      return null;
    }
    if (typeof name === 'string' && Object.hasOwn(PALETTES, name)) {
      console.warn(
        `stagemap.mount: "${name}" is a ready-made palette's name; give the theme another name. The visual keeps the page's theme.`,
      );
      return null;
    }
    if (doc.querySelector(`style[data-stagemap-theme-css="${name}"]`)) return name;
    const decl = (block, roles) => roles.map((r) => `--stagemap-${r}: ${block[r] ?? block[CHART_LEADERS[r]]};`).join(' ');
    const own = (mode) =>
      Object.entries(isObject(theme.visuals) ? theme.visuals : {})
        .flatMap(([v, modes]) =>
          Object.entries(isObject(modes?.[mode]) ? modes[mode] : {}).map(([r, c]) => `--stagemap-${v}-${r}: ${c};`),
        )
        .join(' ');
    const fonts = ['display', 'body', 'mono', ...(complete(theme.fonts.title, ['family', 'fallback']) ? ['title'] : [])]
      .map((r) => `--stagemap-font-${r}: "${theme.fonts[r].family}", ${theme.fonts[r].fallback};`)
      .join(' ');
    const sizes = TYPE_ROLES.filter((r) => typeof theme.base[r] === 'string');
    const bases = sizes.map((r) => `--stagemap-${r}-base: ${theme.base[r]};`).join(' ');
    const scale = theme.font_scale === undefined ? null : fontScaleValue(theme.font_scale);
    if (theme.font_scale !== undefined && !scale)
      console.warn(
        `stagemap.mount: the theme's font_scale must be a number from ${FONT_SCALE.min} to ${FONT_SCALE.max}; it is left out.`,
      );
    const scaled = scale ? `--stagemap-font-scale: ${scale.scale}; ${textSizeCss(TYPE_ROLES)}` : textSizeCss(sizes);
    const light = `${decl(theme.base, BASE_ROLES)} ${bases} ${scaled} ${fonts} ${decl(theme.light, MODE_ROLES)} ${own('light')}`;
    const dark = `${decl(theme.dark, MODE_ROLES)} ${own('dark')} color-scheme: dark;`;
    const a = `[data-stagemap-theme="${name}"]`;
    const m = (mode) => `[data-stagemap-mode="${mode}"]`;
    const forms = (mode) => {
      const others = ['light', 'dark', 'auto'].filter((o) => o !== mode).map((o) => `${m(mode)} ${m(o)} *`);
      return `${a}${m(mode)}, ${m(mode)} ${a}:where(:not(${others.join(', ')})), ${a} ${m(mode)}`;
    };
    const style = doc.createElement('style');
    style.dataset.stagemapThemeCss = name;
    style.textContent =
      `${a} { ${light} }\n` +
      `@media screen { ${forms('dark')} { ${dark} } }\n` +
      `@media screen and (prefers-color-scheme: dark) { ${forms('auto')} { ${dark} } }\n` +
      `${forms('light')} { ${decl(theme.light, MODE_ROLES)} ${own('light')} color-scheme: light; }\n`;
    doc.head.append(style);
    return name;
  }

  let trailOn = false;
  let trailSeq = 0;
  let currentCause;
  let currentStartedBy;
  function trail(on) {
    if (on === undefined) return trailOn;
    if (on === null) on = false;
    if (typeof on !== 'boolean') throw new TypeError('stagemap.trail: give true or false');
    trailOn = on;
    return trailOn;
  }
  const trailing = (doc) => trailOn || Boolean(doc?.documentElement?.hasAttribute('data-stagemap-trail'));
  function stamp(detail, doc = document) {
    const said = { ...detail };
    if (trailing(doc)) Object.assign(said, { at: new Date().toISOString(), seq: ++trailSeq, via: said.via ?? null });
    else delete said.via;
    if (currentCause !== undefined && !('cause' in said)) said.cause = currentCause;
    if (currentStartedBy !== undefined && !('started_by' in said)) said.started_by = currentStartedBy;
    return said;
  }

  function parseCause(info, part) {
    if (info === undefined || info === null) return undefined;
    if (!isObject(info)) {
      const key = `${part || 'visual'}/cause-shape`;
      if (!warned.has(key)) {
        warned.add(key);
        console.warn(`stagemap: ${part || 'a visual'} send() info must be an object with { cause }; ignored.`);
      }
      return undefined;
    }
    if (!('cause' in info) || info.cause === undefined || info.cause === null) return undefined;
    const raw = info.cause;
    if (typeof raw === 'string') {
      if (raw.trim().length > 0) return raw;
      const key = `${part || 'visual'}/cause-blank`;
      if (!warned.has(key)) {
        warned.add(key);
        console.warn(`stagemap: ${part || 'a visual'} send() cause cannot be blank; ignored.`);
      }
      return undefined;
    }
    if (typeof raw === 'number' && Number.isFinite(raw)) {
      return String(raw);
    }
    const key = `${part || 'visual'}/cause-invalid`;
    if (!warned.has(key)) {
      warned.add(key);
      console.warn(
        `stagemap: ${part || 'a visual'} send() cause must be a non-blank string or a finite number; ignored.`,
      );
    }
    return undefined;
  }

  const STARTED_BY_VALUES = new Set(['reader', 'host', 'data']);
  function parseStartedBy(info, part) {
    if (info === undefined || info === null || !isObject(info)) return undefined;
    if (!('started_by' in info) || info.started_by === undefined || info.started_by === null) return undefined;
    const raw = info.started_by;
    if (STARTED_BY_VALUES.has(raw)) return raw;
    if (typeof raw === 'string' && raw.trim().length === 0) {
      const key = `${part || 'visual'}/started_by-blank`;
      if (!warned.has(key)) {
        warned.add(key);
        console.warn(`stagemap: ${part || 'a visual'} send() started_by cannot be blank; ignored.`);
      }
      return undefined;
    }
    const key = `${part || 'visual'}/started_by-invalid`;
    if (!warned.has(key)) {
      warned.add(key);
      console.warn(`stagemap: ${part || 'a visual'} send() started_by must be 'reader', 'host' or 'data'; ignored.`);
    }
    return undefined;
  }

  function runAll(fns) {
    for (const fn of fns.splice(0)) {
      try {
        fn();
      } catch (e) {
        console.warn('stagemap: a cleanup threw and was skipped.', e);
      }
    }
  }

  const FALLBACK = '[data-stagemap-fallback]';
  const dropFallback = (root) => {
    for (const n of [...root.children]) if (n.matches(FALLBACK)) n.remove();
  };

  function isBare(root) {
    return ![...root.childNodes].some((n) =>
      n.nodeType === 1 ? !n.matches(`style, script, ${FALLBACK}`) : n.nodeType === 3 && n.textContent.trim(),
    );
  }

  function writeSkeleton(root, skeleton, part) {
    const later = isObject(skeleton) && typeof skeleton.html === 'function';
    if (!isObject(skeleton) || (typeof skeleton.html !== 'string' && !later) || !isBare(root)) return false;
    root.classList.add(
      ...String(skeleton.class ?? '')
        .split(/\s+/)
        .filter(Boolean),
    );
    root.setAttribute('data-stagemap-visual', part ?? '');
    if (later) return true;
    root.insertAdjacentHTML('afterbegin', skeleton.html);
    ownPlaces(root);
    return false;
  }

  function ownPlaces(root) {
    for (const place of root.querySelectorAll('[data-stagemap-slot]'))
      if (!placeOwners.has(place)) placeOwners.set(place, root);
  }

  function createView(root, visual, given, look, part) {
    const id = ++serial;
    let unlook;
    const teardown = [() => unlook()];
    const undraw = [];
    const saved = {
      className: root.getAttribute('class'),
      visual: root.getAttribute('data-stagemap-visual'),
      children: [...root.childNodes].map((n) => n.cloneNode(true)),
    };
    const skeletonLater = writeSkeleton(root, visual.skeleton, part);
    unlook = look();
    const commands = Array.isArray(visual.commands) ? visual.commands : [];
    const handlers = new Map();
    const held = [];
    const entry = { root, tab: null, clicks: new Set(), free: visual.widthFree === true };
    listeners.set(root, entry);
    let data;
    let problems = [];
    let hidOwn = false;
    let width = 0;
    let height = 0;
    let ready = false;
    let zeroTimer = 0;
    let zeroSaid = false;
    let stale = true;
    let draws = 0;
    let frame = 0;
    let drawing = false;
    let alive = true;
    let started = false;
    const widthFree = visual.widthFree === true;
    if (widthFree && visual.fill === true && !warned.has(`${part}/fill`)) {
      warned.add(`${part}/fill`);
      console.warn(
        `stagemap: ${part || 'a visual'} says both widthFree and fill; widthFree wins, so it does not draw again when its height changes.`,
      );
    }

    const load = (value) => {
      try {
        data = value === undefined ? readData(root) : value;
        problems = problemsOf(visual, data);
      } catch (e) {
        problems = [e.message];
      }
      stale = true;
    };

    let tearingDown = false;
    const emit = (type, detail) => {
      if (!alive && !tearingDown) return;
      const said = { ...detail, part, name: root.dataset.stagemapName ?? null };
      const stamped = stamp(said, root.ownerDocument);
      root.dispatchEvent(new CustomEvent(type, { bubbles: true, cancelable: type === 'stagemap:need', detail: stamped }));
    };

    const kept = {};
    const owns = (el) => {
      const hit = el.closest('[data-stagemap-visual]');
      return !hit || hit === root || !root.contains(hit);
    };
    const ctx = () => ({
      root,
      data,
      width,
      height,
      first: draws === 0,
      state: kept,
      select: (selector) => [...root.querySelectorAll(selector)].find(owns) ?? null,
      uid: (name) => `${name}-${id}`,
      cleanup: (fn) => undraw.push(fn),
      destroyed: (fn) => teardown.push(fn),
      outside: (fn) => undraw.push(onOutside(root, fn)),
      redraw: () => view.resize(),
      emit,
      handle(command, fn) {
        if (!commands.includes(command) && !warned.has(`${part}/${command}`)) {
          warned.add(`${part}/${command}`);
          console.warn(
            `stagemap: ${part || 'a visual'} handles "${command}", which its "commands" list leaves out, so send() answers false.`,
          );
        }
        handlers.set(command, fn);
      },
    });

    const run = (command, value, cause, startedBy) => {
      const fn = handlers.get(command);
      if (!fn) return false;
      const prevCause = currentCause;
      const prevStartedBy = currentStartedBy;
      currentCause = cause;
      currentStartedBy = startedBy;
      try {
        return fn(value) ?? true;
      } catch (e) {
        console.warn(`stagemap: ${part || 'a visual'} could not run "${command}".`, e);
        return false;
      } finally {
        currentCause = prevCause;
        currentStartedBy = prevStartedBy;
      }
    };

    const watchWidth = () => {
      if (zeroSaid || zeroTimer) return;
      zeroTimer = setTimeout(() => {
        zeroTimer = 0;
        if (!alive || !stale || root.clientWidth || !root.isConnected || !root.getClientRects().length) return;
        zeroSaid = true;
        console.warn(
          `stagemap: ${part || 'a visual'} is on the page with no width yet; it draws once its root has a width. If it stays blank, give its root a width: it must not be inline, and its parent must have one.`,
        );
      }, ZERO_WAIT);
    };

    const takeDown = () => {
      tearingDown = true;
      try {
        runAll(undraw);
        runAll(teardown);
      } finally {
        tearingDown = false;
      }
      root.replaceChildren(...saved.children);
      if (saved.className === null) root.removeAttribute('class');
      else root.setAttribute('class', saved.className);
      if (saved.visual === null) root.removeAttribute('data-stagemap-visual');
      else root.setAttribute('data-stagemap-visual', saved.visual);
    };

    const render = () => {
      if (drawing) {
        stale = true;
        schedule();
        return;
      }
      if (frame) cancelAnimationFrame(frame);
      frame = 0;
      if (!alive || !started) return;
      if (root.isConnected) join(entry);
      else if (widthFree) park(entry);
      if (typeof visual.empty === 'function') {
        let none = false;
        try {
          none = !problems.length && Boolean(visual.empty(data));
        } catch (e) {
          console.warn(`stagemap: ${root.dataset.stagemapVisual || 'a visual'}'s empty() threw; it draws.`, e);
        }
        if (none) {
          if (!root.hidden) {
            root.hidden = true;
            hidOwn = true;
          }
          runAll(undraw);
          handlers.clear();
          ready = false;
          stale = true;
          return;
        }
        if (hidOwn) {
          root.hidden = false;
          hidOwn = false;
        }
      }
      const w = Math.round(root.clientWidth);
      const h = Math.round(root.clientHeight);
      if (widthFree) {
        if (!stale) return;
      } else {
        if (!w && stale) watchWidth();
        if (!w || (w === width && !stale && !(visual.fill === true && h !== height))) return;
      }
      width = w;
      height = h;
      stale = false;
      ready = false;
      drawing = true;
      runAll(undraw);
      handlers.clear();
      if (!draws) dropFallback(root);
      if (problems.length) {
        showError(root, problems);
      } else {
        clearError(root);
        root.classList.toggle('sm-enter', draws === 0);
        try {
          applyMotionOptions(root, data);
          applyTooltipOptions(root, data);
          visual.draw(ctx());
          draws++;
          ready = true;
        } catch (e) {
          showError(root, [`the drawing stopped: ${e.message}`]);
          console.warn(`stagemap: ${root.dataset.stagemapVisual || 'a visual'} could not be drawn.`, e);
        }
      }
      drawing = false;
      if (!alive) {
        takeDown();
        return;
      }
      while (alive && ready && !stale && held.length) run(...held.shift());
    };

    const schedule = () => {
      if (alive && !frame) frame = requestAnimationFrame(render);
    };

    const start = () => {
      if (!alive) return;
      started = true;
      const observer = widthFree ? null : new ResizeObserver(schedule);
      observer?.observe(root);
      teardown.push(() => {
        if (hidOwn) root.hidden = false;
        observer?.disconnect();
        joined.delete(entry);
        if (entry.ref) parked.delete(entry.ref);
        clearTimeout(zeroTimer);
      });
      render();
    };

    entry.tab = schedule;
    load(given);
    if (skeletonLater && !problems.length) {
      try {
        root.insertAdjacentHTML('afterbegin', String(visual.skeleton.html(data) ?? ''));
        ownPlaces(root);
      } catch (e) {
        console.warn(`stagemap: ${part || 'a visual'}'s skeleton threw; it starts with none.`, e);
      }
    }

    const view = Object.freeze({
      root,
      update(next, options) {
        if (alive) {
          const looks = options !== undefined && options !== null;
          if (looks) {
            unlook();
            unlook = look(options);
            stale = true;
          }
          const fresh = next !== undefined || !looks;
          if (fresh) load(next);
          render();
          if (fresh && !problems.length) emit('stagemap:data', {});
        }
        return view;
      },
      resize() {
        if (alive) {
          stale = true;
          render();
        }
        return view;
      },
      send(command, value, info) {
        if (!alive || !commands.includes(command)) return false;
        const cause = parseCause(info, part);
        const startedBy = parseStartedBy(info, part);
        if (!ready || stale || held.length) {
          held.push([command, value, cause, startedBy]);
          return null;
        }
        return run(command, value, cause, startedBy);
      },
      data: () => (data === undefined ? null : JSON.parse(JSON.stringify(data))),
      destroy() {
        if (!alive) return;
        alive = false;
        if (frame) cancelAnimationFrame(frame);
        if (instances.get(root) === view) instances.delete(root);
        if (!drawing) takeDown();
      },
    });
    instances.set(root, view);
    const doc = root.ownerDocument;
    if (doc.readyState === 'loading') {
      doc.addEventListener('DOMContentLoaded', start, { once: true });
      teardown.push(() => doc.removeEventListener('DOMContentLoaded', start));
    } else {
      start();
    }
    return view;
  }

  function showError(root, problems) {
    root.classList.add('sm-has-error');
    let box = root.querySelector(':scope > .sm-error');
    if (!box) {
      box = document.createElement('div');
      box.className = 'sm-error';
      root.prepend(box);
    }
    const head = document.createElement('b');
    head.textContent = 'This visual could not be drawn: ';
    const list = document.createElement('ul');
    for (const p of problems.slice(0, 5)) list.append(Object.assign(document.createElement('li'), { textContent: p }));
    if (problems.length > 5) {
      list.append(Object.assign(document.createElement('li'), { textContent: `and ${problems.length - 5} more` }));
    }
    box.replaceChildren(head, list);
  }

  function clearError(root) {
    root.classList.remove('sm-has-error');
    root.querySelector(':scope > .sm-error')?.remove();
  }

  const reducedMotion = () => matchMedia('(prefers-reduced-motion: reduce)').matches || pageMotionScale() === 0;

  function onTheme(fn) {
    const listener = (e) => fn(e.detail);
    document.addEventListener('report:theme', listener);
    return () => document.removeEventListener('report:theme', listener);
  }

  const toneClass = (tone) => `sm-t-${TONES.includes(tone) ? tone : 'muted'}`;
  const statusClass = (status) => `sm-s-${STATUSES.includes(status) ? status : 'skipped'}`;

  function markerPath(shape, r) {
    switch (shape) {
      case 'diamond':
        return `M0,${-r * 1.25}L${r * 1.25},0L0,${r * 1.25}L${-r * 1.25},0Z`;
      case 'square':
        return `M${-r},${-r}H${r}V${r}H${-r}Z`;
      case 'triangle':
        return `M0,${-r * 1.2}L${r * 1.15},${r * 0.9}H${-r * 1.15}Z`;
      default:
        return `M${-r},0a${r},${r} 0 1,0 ${2 * r},0a${r},${r} 0 1,0 ${-2 * r},0Z`;
    }
  }

  function legendItem(list, { shape, line, tone, label }) {
    const li = document.createElement('li');
    li.className = toneClass(tone);
    const svg = document.createElementNS(SVG_NS, 'svg');
    svg.setAttribute('viewBox', '-8 -8 16 16');
    svg.setAttribute('aria-hidden', 'true');
    const path = document.createElementNS(SVG_NS, 'path');
    if (line) {
      path.setAttribute('d', 'M-7,0H7');
      path.setAttribute('class', `sm-line sm-${line}`);
    } else {
      path.setAttribute('d', markerPath(shape || 'circle', 4.5));
      path.setAttribute('class', 'sm-mark sm-solid');
    }
    svg.append(path);
    li.append(svg, document.createTextNode(label));
    list.append(li);
    return li;
  }

  function icon(name, { label } = {}) {
    const added = ADDED_ICONS.get(name);
    if (!Object.hasOwn(ICONS, name) && !added) {
      console.warn(`stagemap.ui.icon: no icon "${name}" (icons: ${iconNames().join(', ')})${iconHint(name)}`);
      return null;
    }
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    for (const [k, v] of Object.entries({
      viewBox: '0 0 24 24',
      fill: 'none',
      stroke: 'currentColor',
      'stroke-width': '2',
      'stroke-linecap': 'round',
      'stroke-linejoin': 'round',
      class: 'sm-icon',
      ...added?.attrs,
    })) {
      svg.setAttribute(k, v);
    }
    if (added) svg.append(...added.nodes.map((n) => n.cloneNode(true)));
    else svg.innerHTML = ICONS[name];
    if (label) {
      svg.setAttribute('role', 'img');
      svg.setAttribute('aria-label', label);
    } else {
      svg.setAttribute('aria-hidden', 'true');
    }
    return svg;
  }

  function chip(text, { tone, status, hollow = false, icon: name } = {}) {
    const span = document.createElement('span');
    span.className = `sm-chip ${status ? statusClass(status) : toneClass(tone)}${hollow ? ' sm-hollow' : ''}`;
    span.textContent = text;
    const mark = name ? icon(name) : null;
    if (mark) {
      span.classList.add('sm-chip-icon');
      span.prepend(mark);
    }
    return span;
  }

  const BUTTON_VARIANTS = ['solid', 'outline', 'plain'];
  const BUTTON_SIZES = ['s', 'm', 'l'];
  let buttonSerial = 0;
  let warnedButton = false;
  function button(spec = {}, el) {
    const { label, icon: name, tone, variant, size, icon_only: iconOnly, disabled, reason, busy } = spec;
    const b = el ?? document.createElement('button');
    b.type = 'button';
    for (const c of [...b.classList]) if (c.startsWith('sm-btn-') || c.startsWith('sm-t-')) b.classList.remove(c);
    b.classList.add(
      'sm-btn',
      'sm-btn-ui',
      `sm-btn-${BUTTON_VARIANTS.includes(variant) ? variant : 'outline'}`,
      `sm-btn-${BUTTON_SIZES.includes(size) ? size : 'm'}`,
      toneClass(TONES.includes(tone) ? tone : 'teal'),
    );
    b.classList.toggle('sm-btn-tone', TONES.includes(tone));
    const words = Object.assign(document.createElement('span'), {
      className: 'sm-btn-label',
      textContent: label ?? '',
    });
    b.classList.toggle('sm-btn-busy', Boolean(busy));
    b.classList.toggle('sm-btn-off', Boolean(disabled));
    const mark = busy ? spinner() : name ? icon(name) : null;
    b.classList.toggle('sm-btn-icon', Boolean(iconOnly) && Boolean(mark));
    b.replaceChildren(...(mark ? [mark, words] : [words]));
    if (iconOnly && mark) {
      words.classList.add('sm-sr');
      b.title = String(label ?? '');
    } else b.removeAttribute('title');
    if (disabled && !reason && !warnedButton) {
      warnedButton = true;
      console.warn('stagemap.ui.button: a disabled button needs a reason, as words: the reader is told why');
    }
    if (busy) b.setAttribute('aria-busy', 'true');
    else b.removeAttribute('aria-busy');
    if (disabled && reason) {
      b.setAttribute('aria-disabled', 'true');
      b.dataset.reason = reason;
      const why = Object.assign(document.createElement('span'), {
        className: 'sm-sr sm-btn-why',
        id: b.dataset.whyId || `sm-btn-why-${++buttonSerial}`,
        textContent: reason,
      });
      why.setAttribute('aria-hidden', 'true');
      b.dataset.whyId = why.id;
      b.setAttribute('aria-describedby', why.id);
      b.append(why);
    } else {
      if (disabled || busy) b.setAttribute('aria-disabled', 'true');
      else b.removeAttribute('aria-disabled');
      b.removeAttribute('data-reason');
      b.removeAttribute('aria-describedby');
    }
    buttonStatus(b, busy ? String(label ?? '') : null);
    return b;
  }

  function spinner() {
    const box = Object.assign(document.createElement('span'), { className: 'sm-btn-spin' });
    box.setAttribute('aria-hidden', 'true');
    const ring = Object.assign(document.createElement('span'), { className: 'sm-btn-ring' });
    const still = icon('hourglass');
    still?.classList.add('sm-btn-still');
    box.append(ring, ...(still ? [still] : []));
    return box;
  }

  const buttonSaid = new WeakMap();
  function buttonStatus(b, words) {
    let status = b.nextElementSibling?.classList.contains('sm-btn-status') ? b.nextElementSibling : null;
    if (!status && b.parentNode) {
      status = Object.assign(document.createElement('span'), { className: 'sm-sr sm-btn-status' });
      status.setAttribute('role', 'status');
      status.setAttribute('aria-live', 'polite');
      b.after(status);
      if (words !== null) buttonSaid.set(b, words);
    }
    if (!status) return;
    if (words === null) {
      buttonSaid.delete(b);
      status.textContent = '';
    } else if (buttonSaid.get(b) !== words) {
      buttonSaid.set(b, words);
      status.textContent = words;
    }
  }

  function pauseButton(ctx, host) {
    if (reducedMotion() || host.querySelector('.sm-pause')) return;
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'sm-btn sm-pause';
    button.setAttribute('aria-pressed', 'false');
    button.textContent = 'Pause animation';
    button.addEventListener('click', () => {
      const paused = ctx.root.classList.toggle('sm-paused');
      button.setAttribute('aria-pressed', String(paused));
      button.textContent = paused ? 'Play animation' : 'Pause animation';
    });
    host.append(button);
  }

  function reveal(box, el) {
    const spot = el.getBoundingClientRect();
    const view = box.getBoundingClientRect();
    const style = getComputedStyle(box);
    const left = view.left + (Number.parseFloat(style.scrollPaddingLeft) || 0);
    const right = view.right - (Number.parseFloat(style.scrollPaddingRight) || 0);
    if (spot.right > right) box.scrollLeft += Math.min(spot.right - right, spot.left - left);
    else if (spot.left < left) box.scrollLeft -= left - spot.left;
  }

  function scrollBox(ctx, box, key = 'picture') {
    if (!ctx.state.scroll) ctx.state.scroll = {};
    const place = ctx.state.scroll;
    box.scrollLeft = place[key] || 0;
    const focused = document.activeElement;
    if (focused && focused !== box && box.contains(focused)) {
      reveal(box, focused);
      place[key] = box.scrollLeft;
    }
    const mark = () => {
      const more = box.scrollWidth - box.clientWidth;
      const rtl = getComputedStyle(box).direction === 'rtl';
      const gone = Math.abs(box.scrollLeft);
      const before = gone > 1;
      const after = more > 1 && gone < more - 1;
      box.classList.toggle('sm-more-left', rtl ? after : before);
      box.classList.toggle('sm-more-right', rtl ? before : after);
    };
    const scrolled = () => {
      place[key] = box.scrollLeft;
      mark();
    };
    box.addEventListener('scroll', scrolled, { passive: true });
    ctx.cleanup(() => box.removeEventListener('scroll', scrolled));
    mark();
  }

  function travel(el, d, { animate = true, duration = 0.9, delay = 0 } = {}) {
    el.style.offsetPath = `path("${d}")`;
    el.style.setProperty('--dur', `${duration}s`);
    el.style.setProperty('--delay', `${delay}s`);
    el.classList.add('sm-rest');
    el.classList.toggle('sm-hop', animate && !reducedMotion());
    return el;
  }

  function player(
    ctx,
    {
      controls,
      caption,
      list,
      steps,
      onStep,
      intro = 'Press Play to start, or choose a step in the list to jump there.',
      interval = 2800,
      motion = true,
    },
  ) {
    if (!ctx.state.player) ctx.state.player = { i: -1, playing: false };
    const place = ctx.state.player;
    const last = steps.length - 1;
    place.i = Math.min(place.i, last);
    let timer = 0;
    const make = (tag, props) => Object.assign(document.createElement(tag), props);
    const button = (key, text, label) => {
      const b = make('button', { type: 'button', className: 'sm-btn', textContent: text });
      b.dataset.k = key;
      if (label) b.setAttribute('aria-label', label);
      return b;
    };
    const play = button('play', 'Play');
    const back = button('back', 'Back', 'Back one step');
    const next = button('next', 'Next', 'Next step');
    const reset = button('reset', 'Reset', 'Back to the start');
    const count = make('span', { className: 'sm-count', textContent: `${steps.length} step${last ? 's' : ''}` });
    controls.classList.add('sm-player');
    controls.replaceChildren(play, back, next, reset, count);
    caption.classList.add('sm-caption');
    caption.setAttribute('aria-live', 'polite');
    list.classList.add('sm-steps');
    const items = steps.map((s, i) => {
      const b = make('button', { type: 'button' });
      b.dataset.k = `step-${i}`;
      b.append(
        make('span', { className: 'sm-step-n', textContent: String(i + 1) }),
        make('span', { className: 'sm-step-t', textContent: s.title }),
      );
      if (s.text) {
        const x = make('span', { className: 'sm-step-x' });
        b.append(x);
        markdown(x, s.text, { inline: true, field: 'steps.text', id: s.id ?? null });
      }
      const li = make('li');
      li.append(b);
      return li;
    });
    list.replaceChildren(...items);

    const write = () => {
      const s = steps[place.i];
      caption.replaceChildren(
        make('span', { className: 'sm-cap-k', textContent: s ? `Step ${place.i + 1} of ${steps.length}` : 'Start' }),
        s
          ? make('b', { textContent: s.title })
          : markdown(make('b', {}), intro, { inline: true, field: 'options.intro' }),
        ...(s?.text
          ? [markdown(make('div', { className: 'sm-cap-text' }), s.text, { field: 'steps.text', id: s.id ?? null })]
          : []),
      );
      play.textContent = place.playing ? 'Pause' : 'Play';
      play.classList.toggle('sm-playing', place.playing);
      back.setAttribute('aria-disabled', String(place.i < 0));
      next.setAttribute('aria-disabled', String(place.i >= last));
      reset.setAttribute('aria-disabled', String(place.i < 0 && !place.playing));
      items.forEach((li, i) => {
        li.classList.toggle('sm-done', i < place.i);
        li.classList.toggle('sm-now', i === place.i);
        if (i === place.i) li.firstChild.setAttribute('aria-current', 'step');
        else li.firstChild.removeAttribute('aria-current');
      });
    };
    const go = (i, moving = true) => {
      place.i = Math.max(-1, Math.min(last, i));
      write();
      onStep(place.i, { animate: moving && motion && !reducedMotion(), again: !moving });
    };
    const schedule = () => {
      clearTimeout(timer);
      timer = place.playing ? setTimeout(tick, interval) : 0;
    };
    const stop = () => {
      place.playing = false;
      schedule();
      write();
    };
    function tick() {
      if (place.i >= last) stop();
      else {
        go(place.i + 1);
        if (place.i >= last) stop();
        else schedule();
      }
    }
    play.addEventListener('click', () => {
      if (place.playing) {
        stop();
        return;
      }
      place.playing = true;
      go(place.i >= last ? 0 : place.i + 1);
      if (place.i >= last) stop();
      else schedule();
    });
    const step = (to) => () => {
      const i = Math.max(-1, Math.min(last, to()));
      const was = place.playing;
      place.playing = false;
      schedule();
      if (i === place.i) {
        if (was) write();
        return;
      }
      go(i);
    };
    const toBack = step(() => (place.i < 0 ? -1 : place.i - 1));
    const toNext = step(() => place.i + 1);
    const toStart = step(() => -1);
    back.addEventListener('click', toBack);
    next.addEventListener('click', toNext);
    reset.addEventListener('click', toStart);
    for (const [i, li] of items.entries()) {
      const toStep = step(() => i);
      li.firstChild.addEventListener('click', toStep);
    }

    ctx.cleanup(() => {
      clearTimeout(timer);
      const focused = [...controls.children, ...items.map((li) => li.firstChild)].find(
        (el) => el === document.activeElement,
      );
      place.focus = focused?.dataset.k;
    });
    go(place.i, false);
    schedule();
    const all = [...controls.children, ...items.map((li) => li.firstChild)];
    const refocus = all.find((el) => el.dataset.k === place.focus);
    place.focus = undefined;
    refocus?.focus({ preventScroll: true });
    return { go };
  }

  const HOLD_MAX = 240;
  const ARROWS = { ArrowRight: ['x', 1], ArrowLeft: ['x', -1], ArrowDown: ['y', 1], ArrowUp: ['y', -1] };
  const LINED_UP = 0.25;
  const SAME_STEP = 16;

  function beside(marks, i, key) {
    const [axis, dir] = ARROWS[key];
    const cross = axis === 'x' ? 'y' : 'x';
    const boxes = marks.map((el) => {
      const r = el.getBoundingClientRect();
      return { x: [r.left, r.right], y: [r.top, r.bottom] };
    });
    const middle = ([a, b]) => (a + b) / 2;
    const size = ([a, b]) => b - a;
    const overlap = ([a, b], [c, d]) => Math.min(b, d) - Math.max(a, c);
    const from = boxes[i];
    let best = -1;
    let bestRank = null;
    boxes.forEach((box, j) => {
      const ahead = (middle(box[axis]) - middle(from[axis])) * dir;
      const lined = overlap(from[cross], box[cross]) > LINED_UP * Math.min(size(from[cross]), size(box[cross]));
      if (j === i || ahead <= 0 || (overlap(from[axis], box[axis]) > 1 && !lined)) return;
      const rank = [lined ? 0 : 1, Math.round(ahead / SAME_STEP), Math.abs(middle(box[cross]) - middle(from[cross]))];
      const order = bestRank && (rank[0] - bestRank[0] || rank[1] - bestRank[1] || rank[2] - bestRank[2]);
      if (!bestRank || order < 0) {
        best = j;
        bestRank = rank;
      }
    });
    if (best >= 0) return best;
    const oneLine = Math.max(...boxes.map((b) => b[axis][0])) < Math.min(...boxes.map((b) => b[axis][1]));
    return oneLine ? Math.min(marks.length - 1, Math.max(0, i + dir)) : i;
  }

  function ids(selection) {
    if (!isObject(selection)) return [];
    const given = selection.ids ?? selection.id ?? null;
    if (given === null) return [];
    return (Array.isArray(given) ? given : [given]).filter((x) => x !== null && x !== undefined).map(String);
  }

  const kpisOf = (f) => (f.kpis || []).filter(([, value]) => value !== null && value !== undefined);

  function record(box, f, idle = '', at = {}) {
    box.replaceChildren();
    const look = f?.status ? statusClass(f.status) : f?.tone ? toneClass(f.tone) : '';
    box.className = `sm-detail ${look}`.trim();
    if (!f) {
      box.append(Object.assign(document.createElement('p'), { textContent: idle }));
      return;
    }
    if (f.kicker) {
      box.append(
        Object.assign(document.createElement('span'), { className: 'sm-label sm-d-kicker', textContent: f.kicker }),
      );
    }
    const head = document.createElement('div');
    head.className = 'sm-d-head';
    head.append(Object.assign(document.createElement('span'), { className: 'sm-d-title', textContent: f.title }));
    if (f.meta) {
      head.append(Object.assign(document.createElement('span'), { className: 'sm-d-meta', textContent: f.meta }));
    }
    box.append(head);
    if (f.text) {
      const text = Object.assign(document.createElement('div'), { className: 'sm-d-text' });
      box.append(markdown(text, f.text, { field: at.field ?? null, id: at.id ?? null }));
    }
    const kpis = kpisOf(f);
    if (kpis.length) {
      const row = document.createElement('div');
      row.className = 'sm-d-kpis';
      for (const [label, value] of kpis) {
        const span = document.createElement('span');
        span.append(Object.assign(document.createElement('em'), { textContent: label }), String(value));
        row.append(span);
      }
      box.append(row);
    }
  }

  function move(parent, node, before = null) {
    if (parent.moveBefore && parent.isConnected && node.isConnected) {
      try {
        parent.moveBefore(node, before);
        return node;
      } catch {
      }
    }
    return parent.insertBefore(node, before);
  }

  function detail(
    ctx,
    items,
    fill,
    idle = 'Hover or tap a mark for details, or use Tab and the arrow keys.',
    { onShow, onPin, key, many = false, disabled = null, field = null, outside = true } = {},
  ) {
    const panel = ctx.select('.sm-detail');
    const marks = items.nodes();
    const why = marks.map((el) => {
      const reason = disabled?.(datumOf(el));
      return typeof reason === 'string' && reason.trim() ? reason.trim() : null;
    });
    const off = (i) => why[i] !== null;
    const facts = marks.map((el, i) => {
      const f = fill(datumOf(el));
      return off(i)
        ? { ...f, text: [f.text, `Not available: ${markdown.escape(why[i])}`].filter(Boolean).join('\n\n') }
        : f;
    });
    const ids = key ? marks.map((el) => String(key(datumOf(el)))) : null;
    const place = ctx.state;
    const leadBefore = place.detailLead ?? null;
    let current = -1;
    let pinned = [];
    const lead = () => (pinned.length ? pinned[pinned.length - 1] : -1);
    let byPointer = false;

    const atOf = (i) => ({
      field: typeof field === 'function' ? field(datumOf(marks[i])) : field,
      id: ids ? ids[i] : null,
    });
    const write = (f, box = panel, at = {}) => record(box, f, idle, at);
    const writeShown = (i) => {
      write(facts[i], panel, atOf(i));
      if (pinned.length > 1 && pinned.includes(i))
        panel.append(
          Object.assign(document.createElement('p'), {
            className: 'sm-d-picked',
            textContent: `${pinned.length} picked`,
          }),
        );
    };
    const markPinned = () => {
      marks.forEach((el, j) => {
        el.setAttribute('aria-pressed', String(pinned.includes(j)));
        if (many) el.classList.toggle('sm-picked', pinned.length > 1 && pinned.includes(j));
      });
    };
    let heldWidth = 0;
    const hold = () => {
      const width = panel.getBoundingClientRect().width;
      if (!width || width === heldWidth) return;
      heldWidth = width;
      const probe = panel.cloneNode(false);
      probe.style.cssText = `position:absolute;visibility:hidden;width:${width}px`;
      probe.setAttribute('aria-hidden', 'true');
      panel.after(probe);
      let tallest = 0;
      for (const [i, f] of [null, ...facts].entries()) {
        write(f, probe, i ? atOf(i - 1) : {});
        tallest = Math.max(tallest, probe.getBoundingClientRect().height);
      }
      probe.remove();
      panel.style.minHeight = `${Math.min(Math.ceil(tallest), HOLD_MAX)}px`;
    };
    const show = (i) => {
      current = i;
      ctx.root.classList.add('sm-dim');
      const kept = many && pinned.length > 1 ? pinned : [];
      marks.forEach((el, j) => {
        el.classList.toggle('sm-on', j === i);
        el.classList.toggle('sm-off', j !== i && !kept.includes(j));
      });
      writeShown(i);
      onShow?.(datumOf(marks[i]));
    };
    const clear = () => {
      current = -1;
      ctx.root.classList.remove('sm-dim');
      for (const el of marks) el.classList.remove('sm-on', 'sm-off');
      write(null);
      onShow?.(null);
    };
    const settle = () => {
      const focused = marks.indexOf(document.activeElement);
      if (pinned.length) show(lead());
      else if (focused >= 0 && !byPointer) show(focused);
      else clear();
    };
    let from = leadBefore;
    const announce = (by, via = null) => {
      const i = lead();
      const hosts = by === 'data' && place.hostBy;
      place.detailLead = ids && i >= 0 ? ids[i] : null;
      onPin?.(i >= 0 ? datumOf(marks[i]) : null, {
        by: hosts ? 'host' : by,
        via: hosts ? 'command' : via,
        from,
        details: i >= 0 ? facts[i] : null,
        ids: ids ? pinned.map((j) => ids[j]) : [],
      });
      from = place.detailLead;
    };
    const unpin = (by = 'reader', via = null) => {
      const had = pinned.length > 0;
      pinned = [];
      markPinned();
      clear();
      if (had) announce(by, via);
    };
    const pinAll = (list, by, via = null) => {
      if (!list.length) return unpin(by, via);
      if (list.length === pinned.length && list.every((j, k) => j === pinned[k])) return;
      pinned = list;
      markPinned();
      show(lead());
      announce(by, via);
    };
    const toggle = (i, adding, via) => {
      if (off(i)) return;
      if (many && adding) pinAll(pinned.includes(i) ? pinned.filter((j) => j !== i) : [...pinned, i], 'reader', via);
      else if (pinned.length === 1 && pinned[0] === i) unpin('reader', via);
      else pinAll([i], 'reader', via);
    };
    const clickVia = (e) => (e.detail === 0 ? 'key' : 'click');
    const pin = (id) => {
      const wanted = Array.isArray(id) ? id : id === null || id === undefined ? [] : [id];
      if (!wanted.length) {
        if (pinned.length) unpin('host', 'command');
        return true;
      }
      if (!many && wanted.length > 1) return false;
      const found = wanted.map((x) => (ids ? ids.indexOf(String(x)) : -1));
      if (found.some((i) => i < 0 || off(i))) return false;
      pinAll([...new Set(found.reverse())].reverse(), 'host', 'command');
      return true;
    };
    const adds = (e) => e.shiftKey || e.ctrlKey || e.metaKey;
    const focusMark = (i, options) => {
      marks.forEach((el, j) => {
        el.tabIndex = j === i ? 0 : -1;
      });
      marks[i].focus(options);
    };
    const spoken = (f) =>
      [f.kicker, f.title, f.meta, markdown.plain(f.text), ...kpisOf(f).map(([label, value]) => `${label} ${value}`)]
        .filter(Boolean)
        .join('. ');

    marks.forEach((el, i) => {
      el.tabIndex = i === 0 ? 0 : -1;
      el.setAttribute('role', 'button');
      el.setAttribute('aria-label', spoken(facts[i]));
      if (off(i)) el.setAttribute('aria-disabled', 'true');
      el.addEventListener('mouseenter', () => show(i));
      el.addEventListener('mouseleave', settle);
      el.addEventListener('pointerdown', () => {
        byPointer = true;
      });
      el.addEventListener('focus', () => show(i));
      el.addEventListener('blur', (e) => {
        if (marks.includes(e.relatedTarget)) return;
        settle();
        byPointer = false;
      });
      el.addEventListener('click', (e) => {
        if (many && adds(e)) document.getSelection()?.removeAllRanges();
        toggle(i, adds(e), clickVia(e));
      });
      el.addEventListener('keydown', (e) => {
        const last = marks.length - 1;
        let to = null;
        if (ARROWS[e.key]) to = beside(marks, i, e.key);
        else if (e.key === 'Home') to = 0;
        else if (e.key === 'End') to = last;
        else if (e.key === 'Escape') {
          if (e.isComposing || e.keyCode === 229) return;
          if (current >= 0 || pinned.length) {
            e.preventDefault();
            e.stopPropagation();
          }
          unpin('reader', 'key');
          return;
        } else if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          toggle(i, adds(e), 'key');
          return;
        }
        if (to === null) return;
        e.preventDefault();
        focusMark(to);
      });
    });

    const keyed = (e) => {
      if (marks.some((el) => el.contains(e.target))) byPointer = false;
    };
    ctx.root.addEventListener('keydown', keyed, true);

    const stopHearing = onOutside(ctx.root, (e) => {
      if (!pinned.length || marks.some((el) => el.contains(e.target)) || panel.contains(e.target)) return;
      if (outside === false && !ctx.root.contains(e.target)) return;
      unpin('reader', clickVia(e));
    });
    let live = true;
    const watcher = new ResizeObserver(() => requestAnimationFrame(() => live && hold()));
    watcher.observe(panel);
    if (document.fonts?.status !== 'loaded') {
      document.fonts?.ready.then(() => {
        if (!live) return;
        heldWidth = 0;
        hold();
      });
    }
    ctx.cleanup(() => {
      live = false;
      watcher.disconnect();
      stopHearing();
      ctx.root.removeEventListener('keydown', keyed, true);
      const focused = marks.indexOf(document.activeElement);
      place.detail = { focused, pinned, showing: current, byPointer };
      if (ids) place.detail.ids = { focused: ids[focused], pinned: pinned.map((j) => ids[j]), showing: ids[current] };
    });

    hold();
    clear();
    const back = place.detail;
    place.detail = undefined;
    if (back && marks.length) {
      const last = marks.length - 1;
      const valid = (i) => (i >= 0 ? Math.min(i, last) : -1);
      const found = (which) => (back.ids && ids ? ids.indexOf(back.ids[which]) : valid(back[which]));
      byPointer = back.byPointer;
      pinned =
        back.ids && ids
          ? back.ids.pinned.map((id) => ids.indexOf(id)).filter((j) => j >= 0 && !off(j))
          : [...new Set(back.pinned.map(valid))].filter((j) => j >= 0 && !off(j));
      markPinned();
      const focused = found('focused') >= 0 ? found('focused') : valid(back.focused);
      if (focused >= 0) focusMark(focused, { preventScroll: true });
      const showing = found('showing');
      if (showing >= 0 && (pinned.includes(showing) || !off(showing))) show(showing);
      else if (pinned.length) show(lead());
      else if (focused >= 0) clear();
    } else markPinned();
    if (back?.ids && back.ids.pinned.length !== pinned.length) announce('data');
    place.hostBy = undefined;
    return {
      clear: (via = 'key') => unpin('reader', via),
      showing: () => current >= 0,
      pin,
      pinned: () =>
        pinned.length
          ? { id: ids ? ids[lead()] : null, details: facts[lead()], ids: ids ? pinned.map((j) => ids[j]) : [] }
          : null,
    };
  }

  function detailGone(ctx, onPin) {
    const place = ctx.state;
    const held = place.detail?.ids?.pinned?.length > 0;
    if (held) {
      const hosts = Boolean(place.hostBy);
      onPin({
        by: hosts ? 'host' : 'data',
        via: hosts ? 'command' : null,
        from: place.detailLead ?? null,
        details: null,
        ids: [],
      });
    }
    place.detail = undefined;
    place.detailLead = null;
    place.hostBy = undefined;
    return held;
  }

  const HOVER_WAIT = 100;
  function hover(ctx, items, which) {
    ctx.state.hover ??= { said: null, want: null, timer: 0, last: Number.NEGATIVE_INFINITY };
    const place = ctx.state.hover;
    const emit = ctx.emit;
    const key = (v) => `${v.kind}\u0000${v.id}`;
    const send = () => {
      place.timer = 0;
      place.last = performance.now();
      if (!place.want || (place.said && key(place.said) === key(place.want))) return;
      place.said = place.want;
      emit('stagemap:hover', { ...place.want });
    };
    const want = (v) => {
      place.want = v;
      if (place.timer) return;
      const wait = v.id === null ? HOVER_WAIT : Math.max(0, place.last + HOVER_WAIT - performance.now());
      place.timer = setTimeout(send, wait);
    };
    const pointer = (e) => e.pointerType !== 'touch';
    for (const el of items.nodes()) {
      const at = which(datumOf(el));
      if (!at) continue;
      const here = { kind: at.kind, id: at.id === null || at.id === undefined ? null : String(at.id) };
      el.addEventListener('pointerenter', (e) => pointer(e) && want(here));
      el.addEventListener('pointerleave', (e) => {
        if (pointer(e) && place.want && key(place.want) === key(here)) want({ kind: here.kind, id: null });
      });
    }
  }

  function paragraphs(text) {
    if (text === null || text === undefined) return [];
    const words = String(text)
      .replace(/\r\n?/g, '\n')
      .replace(/\n\s*$/, '');
    if (!words) return [];
    if (!words.includes('\n')) return [Object.assign(document.createElement('p'), { textContent: words })];
    const out = [];
    let rows = null;
    for (const line of words.split('\n')) {
      const item = /^\s*- (.*)$/.exec(line);
      if (item) {
        if (!rows) {
          rows = document.createElement('ul');
          out.push(rows);
        }
        rows.append(Object.assign(document.createElement('li'), { textContent: item[1] }));
      } else if (line.trim()) {
        rows = null;
        out.push(Object.assign(document.createElement('p'), { textContent: line }));
      }
    }
    return out;
  }

  function slotWords(slot, text, name, how = {}) {
    const own = [...slot.children].find((c) => c.classList.contains(name)) ?? null;
    const hosts = [...slot.childNodes].some(
      (n) => n !== own && (n.nodeType === 1 || (n.nodeType === 3 && n.textContent.trim())),
    );
    if (hosts || !hasText(text)) {
      own?.remove();
      return null;
    }
    const box = own ?? Object.assign(document.createElement('div'), { className: name });
    markdown(box, text, how);
    if (!own) slot.append(box);
    return box;
  }

  let sanitiser = null;
  function setSanitizer(fn) {
    if (fn !== null && typeof fn !== 'function')
      throw new TypeError('stagemap.setSanitizer: give a function, or null to remove it');
    sanitiser = fn;
  }
  function html(el, text) {
    if (text === null || text === undefined) {
      el.replaceChildren();
      return;
    }
    try {
      if (!sanitiser) {
        el.innerHTML = String(text);
        return;
      }
      const clean = sanitiser(String(text));
      if (typeof clean === 'string') el.innerHTML = clean;
      else if ([1, 3, 11].includes(clean?.nodeType)) el.replaceChildren(clean);
      else {
        console.warn(
          'stagemap: the sanitiser gave back neither text nor an element, text or fragment node; nothing was inserted.',
        );
        el.replaceChildren();
      }
    } catch (e) {
      console.warn(
        `stagemap: ${sanitiser ? 'the sanitiser threw' : 'the HTML could not be inserted'}; nothing was inserted.`,
        e,
      );
      el.replaceChildren();
    }
  }

  const isTime = (s) => typeof s === 'string' && /^([01]\d|2[0-3]):[0-5]\d$/.test(s);
  const minutes = (hhmm) => {
    const [h, m] = hhmm.split(':').map(Number);
    return h * 60 + m;
  };
  const hhmm = (mins) => {
    if (!Number.isFinite(mins)) return '--:--';
    const m = ((Math.round(mins) % 1440) + 1440) % 1440;
    return `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;
  };

  const num = (value) => (Number.isFinite(value) ? Number(value.toPrecision(12)) : value);

  function decimalParts(abs) {
    if (abs === 0) return { digits: '0', dot: 1 };
    const m = /^(\d+)(?:\.(\d+))?(?:[eE]([+-]?\d+))?$/.exec(String(abs));
    const raw = `${m[1]}${m[2] ?? ''}`;
    let dot = m[1].length + (m[3] ? Number(m[3]) : 0);
    let i = 0;
    while (i < raw.length && raw[i] === '0') i++;
    if (i === raw.length) return { digits: '0', dot: 1 };
    dot -= i;
    return { digits: raw.slice(i), dot };
  }

  function roundDecimalEven(digits, dot, places) {
    if (digits === '0') return { digits: '0', dot: 1 };
    const keepLen = dot + places;
    if (keepLen < 0) return { digits: '0', dot: 1 };
    if (keepLen >= digits.length) return { digits, dot };
    const first = digits[keepLen];
    const restNonZero = /[^0]/.test(digits.slice(keepLen + 1));
    const lastKept = keepLen === 0 ? 0 : Number(digits[keepLen - 1]);
    const roundUp = first > '5' || (first === '5' && (restNonZero || lastKept % 2 === 1));
    if (!roundUp) return keepLen === 0 ? { digits: '0', dot: 1 } : { digits: digits.slice(0, keepLen), dot };
    if (keepLen === 0) return { digits: '1', dot: 1 - places };
    const out = digits.slice(0, keepLen).split('');
    for (let i = out.length - 1; i >= 0; i--) {
      if (out[i] !== '9') {
        out[i] = String(Number(out[i]) + 1);
        return { digits: out.join(''), dot };
      }
      out[i] = '0';
    }
    return { digits: `1${out.join('')}`, dot: dot + 1 };
  }

  function formatDecimalParts(digits, dot, fixedDigits) {
    if (fixedDigits !== null) {
      if (digits === '0') return fixedDigits > 0 ? `0.${'0'.repeat(fixedDigits)}` : '0';
      let intPart = '0';
      let fracPart = '';
      if (dot <= 0) {
        fracPart = `${'0'.repeat(-dot)}${digits}`;
      } else if (dot >= digits.length) {
        intPart = `${digits}${'0'.repeat(dot - digits.length)}`;
      } else {
        intPart = digits.slice(0, dot);
        fracPart = digits.slice(dot);
      }
      if (fixedDigits === 0) return intPart;
      return `${intPart}.${fracPart.padEnd(fixedDigits, '0')}`;
    }
    const trimmed = digits.replace(/0+$/, '');
    if (!trimmed) return '0';
    if (dot < -5 || dot > 21) {
      const exp = dot - 1;
      const mant = trimmed.length > 1 ? `${trimmed[0]}.${trimmed.slice(1)}` : trimmed;
      return `${mant}e${exp >= 0 ? `+${exp}` : exp}`;
    }
    if (dot <= 0) return `0.${'0'.repeat(-dot)}${trimmed}`;
    if (dot >= trimmed.length) return `${trimmed}${'0'.repeat(dot - trimmed.length)}`;
    return `${trimmed.slice(0, dot)}.${trimmed.slice(dot)}`;
  }

  const DOUBLE_BUF = new ArrayBuffer(8);
  const DOUBLE_VIEW = new DataView(DOUBLE_BUF);

  function roundDoubleExactBigInt(abs, places) {
    if (abs === 0) return { digits: '0', dot: 1 };
    DOUBLE_VIEW.setFloat64(0, abs, false);
    const hi = DOUBLE_VIEW.getUint32(0, false);
    const lo = DOUBLE_VIEW.getUint32(4, false);
    const expBits = (hi >>> 20) & 0x7ff;
    const mant = (BigInt(hi & 0xfffff) << 32n) | BigInt(lo);
    const m = expBits === 0 ? mant : mant | (1n << 52n);
    const e = expBits === 0 ? -1074 : expBits - 1075;
    const shift = e + places;
    const numScaled = m * 5n ** BigInt(places);
    let q;
    if (shift >= 0) {
      q = numScaled << BigInt(shift);
    } else {
      const den = 1n << BigInt(-shift);
      q = numScaled / den;
      const twiceR = (numScaled % den) << 1n;
      if (twiceR > den || (twiceR === den && (q & 1n) === 1n)) q += 1n;
    }
    if (q === 0n) return { digits: '0', dot: 1 };
    const s = q.toString();
    return { digits: s, dot: s.length - places };
  }

  const FORMAT_NUMBER_KEYS = ['digits', 'percent'];
  function format_number(value, options) {
    let digits = null;
    let percent = false;
    if (given(options)) {
      if (!isObject(options)) {
        const id = 'format_number|options';
        if (!noted.has(id)) {
          noted.add(id);
          console.warn(`stagemap: format_number options must be an object, got ${kindOf(options)}.`);
        }
      } else {
        for (const [key, val] of Object.entries(options)) {
          if (!FORMAT_NUMBER_KEYS.includes(key)) {
            const id = `format_number|${key}`;
            if (!noted.has(id)) {
              noted.add(id);
              console.warn(
                `stagemap: format_number does not take ${quoted(key)}; it takes ${oneOf(FORMAT_NUMBER_KEYS)}${didYouMean(key, FORMAT_NUMBER_KEYS)}`,
              );
            }
          } else if (key === 'digits' && given(val)) {
            if (Number.isInteger(val) && val >= 0 && val <= 100) digits = val;
            else {
              const id = `format_number|digits|${String(val)}`;
              if (!noted.has(id)) {
                noted.add(id);
                const got = quoted(val);
                console.warn(`stagemap: format_number "digits" must be an integer from 0 to 100, got ${got}.`);
              }
            }
          } else if (key === 'percent' && given(val)) {
            if (typeof val === 'boolean') percent = val;
            else {
              const id = `format_number|percent|${String(val)}`;
              if (!noted.has(id)) {
                noted.add(id);
                console.warn(`stagemap: format_number "percent" must be true or false, got ${quoted(val)}.`);
              }
            }
          }
        }
      }
    }
    if (typeof value !== 'number' || !Number.isFinite(value)) return '';
    const neg = value < 0;
    const abs = Math.abs(value);
    let rounded;
    if (digits === null) {
      rounded = decimalParts(Number(abs.toPrecision(15)));
    } else {
      const places = digits + (percent ? 2 : 0);
      if (abs < 1e21 && places <= 40) {
        const exact = decimalParts(abs.toFixed(100));
        rounded = roundDecimalEven(exact.digits, exact.dot, places);
      } else {
        rounded = roundDoubleExactBigInt(abs, places);
      }
    }
    const shiftedDot = rounded.digits === '0' ? 1 : rounded.dot + (percent ? 2 : 0);
    const body = formatDecimalParts(rounded.digits, shiftedDot, digits);
    const isZero = /^0(?:\.0+)?$/.test(body);
    return `${neg && !isZero ? '-' : ''}${body}${percent ? '%' : ''}`;
  }

  const isObject = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);
  const list = (value) => (Array.isArray(value) ? value : []);
  const asRows = (value) => (Array.isArray(value) ? value : isObject(value) ? [value] : []);
  const given = (value) => value !== null && value !== undefined;
  const hasText = (value) => typeof value === 'string' && value.trim() !== '';
  const isScalar = (value) => hasText(value) || Number.isFinite(value);

  const oneOf = (values) => values.map((v) => JSON.stringify(v)).join(', ');
  const quoted = (v) => {
    if (typeof v === 'string') return `"${v.length > 40 ? `${v.slice(0, 39)}…` : v}"`;
    return JSON.stringify(v) ?? typeof v;
  };
  const kindOf = (v) => {
    if (Array.isArray(v)) return 'a list';
    if (v === null) return 'null';
    return { object: 'an object', string: 'text', number: 'a number', boolean: 'true or false' }[typeof v] || 'a value';
  };
  function closest(word, known, most = 2) {
    const far = (a, b) => {
      let row = Array.from({ length: b.length + 1 }, (_, j) => j);
      for (let i = 1; i <= a.length; i++) {
        const next = [i];
        for (let j = 1; j <= b.length; j++)
          next[j] = Math.min(row[j] + 1, next[j - 1] + 1, row[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
        row = next;
      }
      return row[b.length];
    };
    let best = null;
    let distance = most + 1;
    for (const k of known) {
      const d = far(String(word).toLowerCase(), String(k).toLowerCase());
      if (d < distance) [best, distance] = [k, d];
    }
    return best;
  }
  const didYouMean = (word, known) => {
    const near = closest(word, known);
    return near === null ? '' : `; did you mean ${quoted(near)}?`;
  };

  const LENGTH_RULE = /^(0|(\d+(\.\d+)?|\.\d+)(px|rem|em|vh|vw|%))$|^var\(--[A-Za-z0-9_-]+\)$/;
  function cssLength(value) {
    if (typeof value === 'number') return Number.isFinite(value) && value >= 0 ? `${value}px` : null;
    if (typeof value !== 'string') return null;
    return LENGTH_RULE.test(value) ? value : null;
  }
  const NEAREST = Object.freeze({ cutoff: 0.6, max: 1 });
  function nearest(word, known) {
    if (typeof word !== 'string' || word === '' || !known || typeof known[Symbol.iterator] !== 'function') return [];
    const far = (a, b) => {
      let row = Array.from({ length: b.length + 1 }, (_, j) => j);
      for (let i = 1; i <= a.length; i++) {
        const next = [i];
        for (let j = 1; j <= b.length; j++)
          next[j] = Math.min(row[j] + 1, next[j - 1] + 1, row[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
        row = next;
      }
      return row[b.length];
    };
    return [...known]
      .map(String)
      .sort()
      .map((k) => [1 - far(word, k) / Math.max(word.length, k.length), k])
      .filter(([ratio]) => ratio >= NEAREST.cutoff)
      .sort((x, y) => y[0] - x[0])
      .slice(0, NEAREST.max)
      .map(([, k]) => k);
  }
  const iconHint = (name) => {
    const [near] = nearest(name, iconNames());
    return near === undefined ? '' : `; did you mean ${quoted(near)}?`;
  };

  const noted = new Set();
  function checkOptions(options, rules, who = 'a part', where = '"options"') {
    if (!given(options)) return [];
    if (!isObject(options)) return [`${where} must be an object`];
    const problems = [];
    const known = Object.keys(rules);
    for (const [key, value] of Object.entries(options)) {
      if (!Object.hasOwn(rules, key)) {
        const id = `${who}|${where}|${key}`;
        if (!noted.has(id)) {
          noted.add(id);
          console.warn(
            `stagemap: ${who}'s ${where} has ${quoted(key)}, which it doesn't take; ${known.length ? `it takes ${oneOf(known)}${didYouMean(key, known)}` : 'it takes no options'}`,
          );
        }
        continue;
      }
      if (!given(value)) continue;
      const problem = rules[key](value, key);
      if (problem) problems.push(problem);
    }
    return problems;
  }

  function wrap(text, max) {
    const lines = [];
    let line = '';
    for (const word of String(text).split(/\s+/).filter(Boolean)) {
      if (line && `${line} ${word}`.length > max) {
        lines.push(line);
        line = word;
      } else {
        line = line ? `${line} ${word}` : word;
      }
    }
    if (line) lines.push(line);
    return lines;
  }

  function placeFlags(items, { levels = 6, pole = 3, gap = 5, bounds = [0, Number.POSITIVE_INFINITY] } = {}) {
    const span = (it, flip) => (flip ? [it.x - it.w, it.x + pole] : [it.x - pole, it.x + it.w]);
    const fits = (it, flip) => {
      const [a, b] = span(it, flip);
      return a >= bounds[0] && b <= bounds[1];
    };
    const free = (taken, lo, hi) => taken.every(([a, b]) => hi + gap <= a || lo - gap >= b);

    const attempt = (order, firstTurn) => {
      const taken = { '-1': Array.from({ length: levels }, () => []), 1: Array.from({ length: levels }, () => []) };
      const out = new Map();
      let clashes = 0;
      let turn = firstTurn;
      for (const it of order) {
        const sides = turn++ % 2 === 0 ? [-1, 1] : [1, -1];
        const flips = [it.flip, !it.flip].filter((f) => fits(it, f));
        if (!flips.length) flips.push(it.flip);
        const top = it.priority ? 1 : levels;
        let spot = null;
        for (let level = 1; level <= top && !spot; level++) {
          for (const side of sides) {
            const clear = taken[side].slice(0, level - 1).every((l) => free(l, it.x - pole, it.x + pole));
            const flip = clear ? flips.find((f) => free(taken[side][level - 1], ...span(it, f))) : undefined;
            if (flip !== undefined) {
              spot = { side, level, flip };
              break;
            }
          }
        }
        if (!spot) {
          clashes++;
          spot = { side: sides[0], level: top, flip: flips[0] };
        }
        out.set(it, spot);
        taken[spot.side][spot.level - 1].push(span(it, spot.flip));
        const poleTo = it.priority ? levels : spot.level - 1;
        for (let l = it.priority ? 2 : 1; l <= poleTo; l++) taken[spot.side][l - 1].push([it.x - pole, it.x + pole]);
      }
      return { out, clashes, cost: clashes * 1000 + [...out.values()].reduce((n, v) => n + v.level, 0) };
    };

    const first = items.filter((i) => i.priority);
    const rest = items.filter((i) => !i.priority);
    const orders = [[...first, ...rest], [...first, ...[...rest].reverse()], items, [...items].reverse()];
    let best = null;
    for (const order of orders) {
      for (const turn of [0, 1]) {
        const r = attempt(order, turn);
        if (!best || r.cost < best.cost) best = r;
      }
    }
    for (const [it, spot] of best.out) Object.assign(it, spot);
    return best.clashes;
  }

  function machine({ initial, states, on, name = 'machine' } = {}) {
    if (!isObject(states) || !Object.hasOwn(states, initial)) {
      throw new TypeError(`stagemap.machine: give "states" and an "initial" state among them`);
    }
    for (const [s, steps] of Object.entries(states)) {
      for (const [step, to] of Object.entries(steps ?? {})) {
        if (!Object.hasOwn(states, to))
          throw new TypeError(`stagemap.machine: step "${step}" from "${s}" leads to "${to}", which is not a state`);
      }
    }
    let state = initial;
    const can = (step) => Object.hasOwn(states[state] ?? {}, step);
    const send = (step, info = {}) => {
      if (!can(step)) {
        console.warn(`stagemap ${name}: "${step}" is not a step from "${state}" (${stepsFrom(states[state])})`);
        return false;
      }
      const to = states[state][step];
      if (to === state) return null;
      const from = state;
      state = to;
      on?.({ ...info, from, to, step });
      return true;
    };
    return Object.freeze({
      get state() {
        return state;
      },
      can,
      send,
    });
  }
  const stepsFrom = (steps) => {
    const names = Object.keys(steps ?? {});
    return names.length ? `steps from here: ${oneOf(names)}` : 'no steps from here';
  };

  function hostStore() {
    const hidden = new Map();
    const reason = new Map();
    const badge = new Map();
    const busy = new Map();
    const label = new Map();
    const maps = [hidden, reason, badge];
    return {
      hidden,
      reason,
      badge,
      busy,
      label,
      keepOnly(ids) {
        const keep = new Set(ids);
        for (const m of [...maps, busy, label]) for (const id of [...m.keys()]) if (!keep.has(id)) m.delete(id);
      },
      rows(order) {
        return order
          .filter((id) => maps.some((m) => m.has(id)))
          .map((id) => ({
            id,
            hidden: hidden.has(id) ? hidden.get(id) : null,
            disabled: reason.has(id) ? reason.get(id) !== null : null,
            reason: reason.get(id) ?? null,
            badge: badge.has(id) ? badge.get(id) : null,
            badge_set: badge.has(id) ? true : null,
          }));
      },
    };
  }

  function collection(rows, { name = 'items', noun = 'item', keep = null } = {}) {
    const given_ = asRows(rows);
    const problems = [];
    const items = [];
    const byId = new Map();
    given_.forEach((row, i) => {
      const at = `${noun} ${i + 1} (in "${name}")`;
      if (!isObject(row)) {
        problems.push(`${at} must be an object`);
        return;
      }
      if (!isScalar(row.id)) {
        problems.push(`${at}: "id" is required, as text or a number`);
        return;
      }
      const id = String(row.id);
      if (byId.has(id)) {
        problems.push(`${at}: "id" ${quoted(id)} is used twice; ids must be unique`);
        return;
      }
      const words = (v) => (hasText(v) ? v : Number.isFinite(v) ? String(v) : null);
      const disabled = row.disabled === true;
      const item = {
        ...row,
        id,
        label: words(row.label),
        parent: isScalar(row.parent) ? String(row.parent) : null,
        group: words(row.group),
        hidden: row.hidden === true,
        disabled,
        reason: disabled && hasText(row.reason) ? row.reason : null,
      };
      byId.set(id, item);
      items.push(item);
    });
    const at = (item) =>
      `${noun} ${given_.findIndex((r) => isObject(r) && isScalar(r.id) && String(r.id) === item.id) + 1} (in "${name}")`;
    for (const item of items) {
      if (item.parent === null) continue;
      if (item.parent === item.id) {
        problems.push(`${at(item)}: "parent" is the item's own id (${quoted(item.id)}); name another item`);
        item.parent = null;
      } else if (!byId.has(item.parent)) {
        problems.push(`${at(item)}: "parent" is ${quoted(item.parent)}, which is not the id of any item`);
        item.parent = null;
      }
    }
    const safe = new Set();
    for (const item of items) {
      const chain = [item.id];
      const seen = new Set(chain);
      for (let up = item.parent; up !== null && !safe.has(up); up = byId.get(up).parent) {
        if (seen.has(up)) {
          const loop = [...chain.slice(chain.indexOf(up)), up];
          const start = byId.get(up);
          problems.push(
            `${at(start)}: "parent" makes a loop (${loop.map(quoted).join(' under ')}); an item cannot sit under itself`,
          );
          start.parent = null;
          break;
        }
        chain.push(up);
        seen.add(up);
      }
      for (const id of chain) safe.add(id);
    }
    const kids = new Map([[null, []]]);
    for (const item of items) {
      if (!kids.has(item.parent)) kids.set(item.parent, []);
      kids.get(item.parent).push(item);
    }
    const item = (id) => (isScalar(id) ? (byId.get(String(id)) ?? null) : null);
    const path = (id) => {
      const out = [];
      for (let t = item(id); t; t = t.parent === null ? null : byId.get(t.parent)) out.unshift(t.id);
      return out;
    };
    const changed = isObject(keep) && keep.host ? keep.host : hostStore();
    changed.keepOnly(items.map((t) => t.id));
    const hidden = (id) => {
      const t = item(id);
      return t ? (changed.hidden.has(t.id) ? changed.hidden.get(t.id) : t.hidden) : false;
    };
    const reason = (id) => {
      const t = item(id);
      if (!t) return null;
      return changed.reason.has(t.id) ? changed.reason.get(t.id) : t.disabled ? (t.reason ?? '') : null;
    };
    const badge = (id) => {
      const t = item(id);
      if (!t) return null;
      return changed.badge.has(t.id) ? changed.badge.get(t.id) : isScalar(t.badge) ? t.badge : null;
    };
    const wordsOrNull = (v) => (hasText(v) ? v : Number.isFinite(v) ? String(v) : null);
    const busy = (id) => {
      const t = item(id);
      if (!t) return false;
      return changed.busy.has(t.id) ? changed.busy.get(t.id) !== false : t.busy === true;
    };
    const busyLabel = (id) => {
      const t = item(id);
      if (!t || !busy(id)) return null;
      const set = changed.busy.get(t.id);
      return typeof set === 'string' ? set : wordsOrNull(t.busy_label);
    };
    const label = (id) => {
      const t = item(id);
      if (!t) return null;
      return changed.label.has(t.id) ? changed.label.get(t.id) : wordsOrNull(t.label);
    };
    const visible = (id) => {
      const p = path(id);
      return p.length > 0 && p.every((x) => !hidden(x));
    };
    const putBusy = (id, value) => {
      const t = item(id);
      if (!t) return false;
      const before = `${busy(t.id)}\u0000${busyLabel(t.id)}`;
      changed.busy.set(t.id, value);
      return before === `${busy(t.id)}\u0000${busyLabel(t.id)}` ? null : true;
    };
    const put = (map, id, value, now) => {
      const t = item(id);
      if (!t) return false;
      const before = now(t.id);
      map.set(t.id, value);
      return before === value ? null : true;
    };
    return Object.freeze({
      items: Object.freeze(items),
      problems: Object.freeze(problems),
      item,
      children: (id = null) => [...(kids.get(id === null ? null : String(id)) ?? [])],
      shown: (id = null) => (kids.get(id === null ? null : String(id)) ?? []).filter((t) => !hidden(t.id)),
      roots: () => [...kids.get(null)],
      path,
      depth: (id) => path(id).length,
      hidden,
      reason,
      badge,
      visible,
      open: (id) => visible(id) && reason(id) === null,
      show: (id) => put(changed.hidden, id, false, hidden),
      hide: (id) => put(changed.hidden, id, true, hidden),
      disable: (id, why) => (hasText(why) ? put(changed.reason, id, why, reason) : false),
      enable: (id) => put(changed.reason, id, null, reason),
      busy,
      busyLabel,
      setBusy: (id, words = null) =>
        words === null || words === undefined || typeof words === 'string' || Number.isFinite(words)
          ? putBusy(id, wordsOrNull(words) ?? true)
          : false,
      clearBusy: (id) => putBusy(id, false),
      label,
      setLabel: (id, words = null) => {
        const t = item(id);
        if (!t) return false;
        if (words !== null && words !== undefined && typeof words !== 'string' && !Number.isFinite(words)) return false;
        const before = label(t.id);
        const next = wordsOrNull(words);
        if (next === null) changed.label.delete(t.id);
        else changed.label.set(t.id, next);
        return before === label(t.id) ? null : true;
      },
      setBadge: (id, value) => (value === null || isScalar(value) ? put(changed.badge, id, value, badge) : false),
      changes: () => changed.rows(items.map((t) => t.id)),
      host: changed,
    });
  }

  function selection({ choosable = () => true, on, value = null, fallback = null, multiple = false } = {}) {
    const text = (v) => (isScalar(v) ? String(v) : null);
    const listOf = (v) => {
      const out = [...new Set((Array.isArray(v) ? v : [v]).map(text).filter((x) => x !== null))];
      return multiple ? out : out.slice(-1);
    };
    let picked = multiple ? listOf(value) : isScalar(value) ? [String(value)] : [];
    const lead = () => picked.at(-1) ?? null;
    const change = (next, info) => {
      if (next.length === picked.length && next.every((x, i) => x === picked[i])) return null;
      const from = lead();
      const added = next.filter((x) => !picked.includes(x));
      const removed = picked.filter((x) => !next.includes(x));
      picked = next;
      const to = lead();
      on?.(multiple ? { ...info, from, to, values: [...picked], added, removed } : { ...info, from, to });
      return true;
    };
    return Object.freeze({
      get value() {
        return lead();
      },
      get values() {
        return [...picked];
      },
      select(id, info = {}) {
        if (!isScalar(id)) return id === null ? change([], info) : false;
        const to = String(id);
        if (!picked.includes(to) && !choosable(to)) return false;
        return change(multiple ? [...picked.filter((x) => x !== to), to] : [to], info);
      },
      toggle(id, info = {}) {
        if (!isScalar(id)) return false;
        const to = String(id);
        if (picked.includes(to))
          return change(
            picked.filter((x) => x !== to),
            info,
          );
        if (!choosable(to)) return false;
        return change(multiple ? [...picked, to] : [to], info);
      },
      set(ids, info = {}) {
        const given_ = ids === null || ids === undefined ? [] : Array.isArray(ids) ? ids : [ids];
        if (!given_.every(isScalar)) return false;
        const next = [...new Set(given_.map(String))];
        if (!multiple && next.length > 1) return false;
        if (next.some((x) => !picked.includes(x) && !choosable(x))) return false;
        return change(next, info);
      },
      clear: (info = {}) => change([], info),
      recheck(info = {}) {
        if (picked.every(choosable)) return null;
        if (multiple) return change(picked.filter(choosable), info);
        const next = fallback ? fallback() : null;
        return change(isScalar(next) && choosable(String(next)) ? [String(next)] : [], info);
      },
      quiet(id) {
        picked = listOf(id);
      },
    });
  }

  function disclosure({ open = false, on, name = 'disclosure' } = {}) {
    const m = machine({
      name,
      initial: open ? 'open' : 'closed',
      states: {
        closed: { open: 'open', close: 'closed', toggle: 'open' },
        open: { open: 'open', close: 'closed', toggle: 'closed' },
      },
      on: (c) => {
        if (!c.quiet) on?.({ ...c, from: c.from === 'open', to: c.to === 'open' });
      },
    });
    return Object.freeze({
      get value() {
        return m.state === 'open';
      },
      open: (info) => m.send('open', info),
      close: (info) => m.send('close', info),
      toggle: (info) => m.send('toggle', info),
      set: (value, info) => m.send(value ? 'open' : 'close', info),
      quiet(value) {
        if (Boolean(value) !== (m.state === 'open')) m.send(value ? 'open' : 'close', { quiet: true });
      },
    });
  }

  const stacks = new WeakMap();
  function layerStack(doc = document) {
    const at = doc?.nodeType === 9 ? doc : document;
    if (!stacks.has(at)) {
      const list = [];
      stacks.set(
        at,
        Object.freeze({
          push(layer) {
            if (!list.includes(layer)) list.push(layer);
            return list.indexOf(layer);
          },
          remove(layer) {
            const i = list.indexOf(layer);
            if (i >= 0) list.splice(i, 1);
            return i;
          },
          index: (layer) => list.indexOf(layer),
          get layers() {
            return [...list];
          },
          close(layer, info = {}) {
            if (!list.includes(layer)) return false;
            for (const above of list.slice(list.indexOf(layer) + 1).reverse()) {
              if (list.includes(above)) above.close({ ...info, reason: 'below' });
            }
            layer.close(info);
            return true;
          },
        }),
      );
    }
    return stacks.get(at);
  }

  function hostItems(ctx, rowsOf) {
    if (!ctx.state.hostItems) ctx.state.hostItems = hostStore();
    const mine = ctx.state.hostItems;
    const rows = () => {
      const list = asRows(rowsOf()).filter((r) => isObject(r) && isScalar(r.id));
      mine.keepOnly(list.map((r) => String(r.id)));
      return list;
    };
    const find = (id) => rows().find((r) => String(r.id) === String(id));
    const view = (r) => {
      const id = String(r.id);
      const hidden = mine.hidden.has(id) ? mine.hidden.get(id) : r.hidden === true;
      const reason = mine.reason.has(id)
        ? mine.reason.get(id)
        : r.disabled === true && hasText(r.reason)
          ? r.reason
          : null;
      const disabled = mine.reason.has(id) ? reason !== null : r.disabled === true;
      return { hidden, disabled, reason: disabled ? (reason ?? 'Not available') : null };
    };
    const apply = (list) => {
      rows();
      return asRows(list).map((r) => (isObject(r) && isScalar(r.id) ? { ...r, ...view(r) } : r));
    };
    const idOf = (value) => {
      if (isScalar(value)) return String(value);
      if (!isObject(value)) return undefined;
      const all = ids(value);
      return all.length === 1 ? all[0] : undefined;
    };
    const change = (value, set) => {
      const id = idOf(value);
      const row = id === undefined ? undefined : find(id);
      if (!row) {
        console.warn(`stagemap: no item with the id ${JSON.stringify(value) ?? String(value)} to change.`);
        return false;
      }
      const before = JSON.stringify(view(row));
      set(String(row.id));
      if (JSON.stringify(view(row)) !== before) {
        ctx.state.hostBy = true;
        ctx.redraw();
      }
      return true;
    };
    return {
      apply,
      state: () => {
        const list = rows();
        return {
          hidden: list.filter((r) => view(r).hidden).map((r) => String(r.id)),
          disabled: list.filter((r) => view(r).disabled).map((r) => String(r.id)),
          host_changes: mine.rows(list.map((r) => String(r.id))),
        };
      },
      hide: (value) => change(value, (id) => mine.hidden.set(id, true)),
      show: (value) => change(value, (id) => mine.hidden.set(id, false)),
      enable: (value) => change(value, (id) => mine.reason.set(id, null)),
      disable(value) {
        const reason = isObject(value) ? value.reason : null;
        if (!hasText(reason)) {
          console.warn('stagemap: "disable" needs a "reason", as text: the reader is told why');
          return false;
        }
        return change(value, (id) => mine.reason.set(id, reason));
      },
    };
  }
  const ADDED_ICONS = new Map();
  const ICON_NAME = /^[a-z0-9]+(-[a-z0-9]+)*$/;
  const ICON_ATTRS = ['viewBox', 'fill', 'stroke', 'stroke-width', 'stroke-linecap', 'stroke-linejoin'];
  const ICON_SHAPES = new Set(['g', 'path', 'circle', 'ellipse', 'line', 'polyline', 'polygon', 'rect']);
  const ICON_SHAPE_ATTRS = new Set([
    'd',
    'cx',
    'cy',
    'r',
    'rx',
    'ry',
    'x',
    'y',
    'x1',
    'y1',
    'x2',
    'y2',
    'width',
    'height',
    'points',
    'transform',
    'fill',
    'fill-rule',
    'fill-opacity',
    'clip-rule',
    'stroke',
    'stroke-width',
    'stroke-linecap',
    'stroke-linejoin',
    'stroke-opacity',
    'stroke-miterlimit',
    'opacity',
  ]);
  const safeIconValue = (v) => !/url\s*\(|:|expression|[<>]/i.test(v);
  const iconCopy = (src) => {
    const name = src.localName;
    if (src.namespaceURI !== SVG_NS || !ICON_SHAPES.has(name)) return null;
    const out = document.createElementNS(SVG_NS, name);
    for (const a of src.attributes) {
      if (!a.namespaceURI && ICON_SHAPE_ATTRS.has(a.name) && safeIconValue(a.value)) out.setAttribute(a.name, a.value);
    }
    for (const kid of src.children) {
      const copy = iconCopy(kid);
      if (copy) out.append(copy);
    }
    return out;
  };
  function addIcon(name, svg) {
    if (typeof name !== 'string' || !ICON_NAME.test(name)) {
      console.warn(`stagemap.addIcon: the name must be lower-case words joined with "-", not ${quoted(name)}`);
      return false;
    }
    if (Object.hasOwn(ICONS, name) || ADDED_ICONS.has(name)) {
      console.warn(`stagemap.addIcon: an icon named "${name}" is already there`);
      return false;
    }
    const doc = typeof svg === 'string' ? new DOMParser().parseFromString(svg.trim(), 'image/svg+xml') : null;
    const el = doc?.documentElement;
    if (!el || el.localName !== 'svg' || el.namespaceURI !== SVG_NS || doc.getElementsByTagName('parsererror').length) {
      console.warn(`stagemap.addIcon: "${name}" needs one <svg> element as text, with xmlns="${SVG_NS}"`);
      return false;
    }
    const nodes = [...el.children].map(iconCopy).filter(Boolean);
    if (!nodes.length) {
      console.warn(
        `stagemap.addIcon: "${name}" has no shapes (path, circle, ellipse, line, polyline, polygon, rect, g)`,
      );
      return false;
    }
    const attrs = {};
    for (const a of ICON_ATTRS) {
      const v = el.getAttribute(a) ?? (a === 'viewBox' ? el.getAttribute('viewbox') : null);
      if (v !== null && safeIconValue(v)) attrs[a] = v;
    }
    if (attrs.fill && attrs.fill !== 'none' && !attrs.stroke) attrs.stroke = 'none';
    ADDED_ICONS.set(name, { nodes, attrs });
    return true;
  }
  const iconNames = () => Object.freeze([...Object.keys(ICONS), ...ADDED_ICONS.keys()]);

  const MD_ESCAPABLE = '!"#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~';
  const MD_LINK_PREFIXES = ['http://', 'https://', 'mailto:'];
  const MD_LINK_BLANK = ['http://', 'https://'];
  const MD_LINK_SCHEMES = ['http', 'https', 'mailto'];
  const MD_LINK_REL = 'noopener noreferrer';
  const MD_NOTE_EXCLUDED = ' \t\\`*[]^';
  const MD_NOTE_ATTRIBUTE = 'data-sm-note';
  const MD_BULLET = /^[-*+] /;
  const MD_ORDERED = /^([0-9]{1,9})\. /;
  const MD_PICKABLE =
    'button, [role="button"], [role="option"], [role="tab"], [role="menuitem"], [role="tooltip"], .sm-item';
  const mdSpace = (c) => c === ' ' || c === '\t';
  const mdTrim = (t) => t.replace(/^[ \t]+|[ \t]+$/g, '');
  const mdLower = (t) => t.replace(/[A-Z]/g, (c) => String.fromCharCode(c.charCodeAt(0) + 32));
  const mdStarts = (t, prefixes) => prefixes.some((p) => mdLower(t).startsWith(p));

  function mdBlocks(text) {
    const out = [];
    let para = null;
    let items = null;
    let blank = false;
    const endPara = () => {
      if (para) out.push(['p', para.join(' ')]);
      para = null;
    };
    const endList = () => {
      if (items) out.push([items[0], items[1], items[2].map((i) => i.join(' '))]);
      items = null;
    };
    for (const line of text.split(/\r\n|\r|\n/)) {
      if (!mdTrim(line)) {
        endPara();
        blank = true;
        continue;
      }
      const bullet = MD_BULLET.exec(line);
      const ordered = bullet ? null : MD_ORDERED.exec(line);
      if (bullet || ordered) {
        endPara();
        const kind = bullet ? 'ul' : 'ol';
        if (items && items[0] !== kind) endList();
        if (!items) items = [kind, ordered ? Number(ordered[1]) : 1, []];
        const words = mdTrim(line.slice((bullet ?? ordered)[0].length));
        items[2].push(words ? [words] : []);
      } else if (items && !blank) items[2][items[2].length - 1].push(mdTrim(line));
      else {
        endList();
        para = [...(para ?? []), mdTrim(line)];
      }
      blank = false;
    }
    endPara();
    endList();
    return out;
  }

  function mdEscaped(s) {
    const out = new Array(s.length).fill(false);
    for (let i = 0; i < s.length; ) {
      if (s[i] === '\\' && i + 1 < s.length && MD_ESCAPABLE.includes(s[i + 1])) {
        out[i + 1] = true;
        i += 2;
      } else i += 1;
    }
    return out;
  }

  function mdNext(s, escaped, char, inCode) {
    const next = new Array(s.length + 1).fill(-1);
    for (let i = s.length - 1; i >= 0; i -= 1) next[i] = s[i] === char && !escaped[i] && !inCode[i] ? i : next[i + 1];
    return next;
  }

  function mdRuns(s) {
    const runs = new Map();
    for (let i = 0; i < s.length; ) {
      if (s[i] !== '`') {
        i += 1;
        continue;
      }
      let j = i;
      while (j < s.length && s[j] === '`') j += 1;
      if (!runs.has(j - i)) runs.set(j - i, []);
      runs.get(j - i).push(i);
      i = j;
    }
    return runs;
  }

  function mdCodeMask(s, runs) {
    const inCode = new Array(s.length).fill(false);
    const pointer = new Map();
    for (let i = 0; i < s.length; ) {
      if (s[i] === '\\' && i + 1 < s.length && MD_ESCAPABLE.includes(s[i + 1])) i += 2;
      else if (s[i] === '`') {
        let j = i;
        while (j < s.length && s[j] === '`') j += 1;
        const starts = runs.get(j - i) ?? [];
        let p = pointer.get(j - i) ?? 0;
        while (p < starts.length && starts[p] < j) p += 1;
        pointer.set(j - i, p);
        if (p < starts.length) {
          const end = starts[p] + (j - i);
          inCode.fill(true, i, end);
          i = end;
        } else i = j;
      } else i += 1;
    }
    return inCode;
  }

  const mdCode = (raw) =>
    raw.length >= 2 && raw[0] === ' ' && raw.at(-1) === ' ' && /[^ ]/.test(raw) ? raw.slice(1, -1) : raw;

  function mdUnescape(raw) {
    let out = '';
    for (let i = 0; i < raw.length; ) {
      if (raw[i] === '\\' && i + 1 < raw.length && MD_ESCAPABLE.includes(raw[i + 1])) {
        out += raw[i + 1];
        i += 2;
      } else out += raw[i++];
    }
    return out;
  }

  function mdNoteEnd(s, i) {
    if (s[i + 1] !== '^') return -1;
    let j = i + 2;
    while (j < s.length && !MD_NOTE_EXCLUDED.includes(s[j])) j += 1;
    return j > i + 2 && s[j] === ']' ? j : -1;
  }

  function mdInline(s, links = true, notes = true) {
    const tokens = [];
    let buf = '';
    const escaped = mdEscaped(s);
    const runs = mdRuns(s);
    const inCode = links ? mdCodeMask(s, runs) : null;
    const closeBracket = links ? mdNext(s, escaped, ']', inCode) : null;
    const closeParen = links ? mdNext(s, escaped, ')', inCode) : null;
    const pointer = new Map();
    const flush = () => {
      if (buf) tokens.push(['text', buf]);
      buf = '';
    };
    const linkAt = (i) => {
      const j = closeBracket[i + 1];
      if (j === -1 || j + 1 >= s.length || s[j + 1] !== '(') return null;
      const k = closeParen[j + 2];
      if (k === -1) return null;
      const raw = s.slice(j + 2, k);
      return raw && !/[ \t]/.test(raw) ? [j, k] : null;
    };
    const n = s.length;
    for (let i = 0; i < n; ) {
      const c = s[i];
      if (c === '\\' && i + 1 < n && MD_ESCAPABLE.includes(s[i + 1])) {
        buf += s[i + 1];
        i += 2;
      } else if (c === '`') {
        let j = i;
        while (j < n && s[j] === '`') j += 1;
        const starts = runs.get(j - i) ?? [];
        let p = pointer.get(j - i) ?? 0;
        while (p < starts.length && starts[p] < j) p += 1;
        pointer.set(j - i, p);
        if (p < starts.length) {
          flush();
          tokens.push(['code', mdCode(s.slice(j, starts[p]))]);
          i = starts[p] + (j - i);
        } else {
          buf += s.slice(i, j);
          i = j;
        }
      } else if (c === '[' && links && notes && mdNoteEnd(s, i) !== -1) {
        const end = mdNoteEnd(s, i);
        flush();
        tokens.push(['note', s.slice(i + 2, end)]);
        i = end + 1;
      } else if (c === '[' && links && !(i > 0 && s[i - 1] === '!' && !escaped[i - 1]) && linkAt(i)) {
        const [j, k] = linkAt(i);
        const raw = s.slice(j + 2, k);
        flush();
        tokens.push(['link', mdUnescape(raw), mdInline(s.slice(i + 1, j), false), mdStarts(raw, MD_LINK_PREFIXES)]);
        i = k + 1;
      } else if (c === '*') {
        let j = i;
        while (j < n && s[j] === '*') j += 1;
        if (j - i > 3) buf += s.slice(i, j);
        else {
          flush();
          tokens.push({ count: j - i, canOpen: j < n && !mdSpace(s[j]), canClose: i > 0 && !mdSpace(s[i - 1]) });
        }
        i = j;
      } else {
        buf += c;
        i += 1;
      }
    }
    flush();
    return mdEmphasis(tokens);
  }

  function mdJoin(pieces) {
    const joined = [];
    for (const p of pieces) {
      if (p[0] === 'text' && joined.at(-1)?.[0] === 'text')
        joined[joined.length - 1] = ['text', joined.at(-1)[1] + p[1]];
      else if (p[0] !== 'text' || p[1]) joined.push(p);
    }
    return joined;
  }

  function mdEmphasis(tokens) {
    const stack = [];
    const tops = { em: [], strong: [] };
    const close = (kind) => {
      const pos = tops[kind].at(-1);
      for (const mark of stack.slice(pos + 1)) {
        mark[1] = 'text';
        tops[mark[0]].pop();
      }
      stack.length = pos + 1;
      stack.pop()[1] = 'closed';
      tops[kind].pop();
    };
    for (const tok of tokens) {
      if (Array.isArray(tok)) continue;
      const closed = [];
      if (tok.canClose) {
        const wants =
          tok.count === 3
            ? ['em', 'strong'].filter((k) => tops[k].length).sort((a, b) => tops[b].at(-1) - tops[a].at(-1))
            : [tok.count === 1 ? 'em' : 'strong'];
        for (const kind of wants) {
          if (tops[kind].length) {
            close(kind);
            closed.push(kind);
          }
        }
      }
      if (closed.length) {
        const used = closed.reduce((sum, k) => sum + (k === 'strong' ? 2 : 1), 0);
        tok.pieces = [
          ...closed.map((k) => ['close', k]),
          ...(tok.count > used ? [['text', '*'.repeat(tok.count - used)]] : []),
        ];
      } else if (tok.canOpen) {
        tok.opened = { 1: ['em'], 2: ['strong'], 3: ['em', 'strong'] }[tok.count].map((kind) => {
          const mark = [kind, 'open'];
          stack.push(mark);
          tops[kind].push(stack.length - 1);
          return mark;
        });
      } else tok.pieces = [['text', '*'.repeat(tok.count)]];
    }
    for (const mark of stack) mark[1] = 'text';
    const out = [];
    for (const tok of tokens) {
      if (Array.isArray(tok)) out.push(tok);
      else if (tok.opened)
        for (const [kind, state] of tok.opened)
          out.push(state === 'closed' ? ['open', kind] : ['text', kind === 'strong' ? '**' : '*']);
      else out.push(...tok.pieces);
    }
    return mdJoin(out);
  }

  const mdPlain = (pieces) =>
    pieces.map((p) => (p[0] === 'text' || p[0] === 'code' ? p[1] : p[0] === 'link' ? mdPlain(p[2]) : '')).join('');

  function mdLink(href, at) {
    const a = document.createElement('a');
    a.setAttribute('href', href);
    a.setAttribute('rel', MD_LINK_REL);
    if (mdStarts(href, MD_LINK_BLANK)) a.setAttribute('target', '_blank');
    a.addEventListener('click', (e) => {
      e.stopPropagation();
      const root = a.closest('[data-stagemap-visual]');
      const detail = stamp(
        {
          href,
          by: 'reader',
          field: at.field,
          id: at.id,
          part: root?.dataset.stagemapVisual ?? null,
          name: root?.dataset.stagemapName ?? null,
        },
        a.ownerDocument,
      );
      (root ?? a).dispatchEvent(new CustomEvent('stagemap:link', { bubbles: true, detail }));
    });
    return a;
  }

  function mdScheme(href, words, at) {
    const found = /^([a-z][a-z0-9]*):/.exec(mdLower(href));
    if (!found || MD_LINK_SCHEMES.includes(found[1])) return null;
    if (!at.schemes || !Object.hasOwn(at.schemes, found[1]) || typeof at.schemes[found[1]] !== 'function') return null;
    try {
      const node = at.schemes[found[1]]({
        href,
        rest: href.slice(found[1].length + 1),
        words,
        field: at.field,
        id: at.id,
      });
      return node instanceof Node ? node : null;
    } catch {
      return null;
    }
  }

  function mdNodes(pieces, at) {
    const out = [];
    const open = [];
    const into = () => open.at(-1) ?? null;
    const add = (node) => (into() ? into().append(node) : out.push(node));
    for (const p of pieces) {
      if (p[0] === 'text') add(document.createTextNode(p[1]));
      else if (p[0] === 'code') add(Object.assign(document.createElement('code'), { textContent: p[1] }));
      else if (p[0] === 'open') {
        const el = document.createElement(p[1]);
        add(el);
        open.push(el);
      } else if (p[0] === 'close') open.pop();
      else if (p[0] === 'note') {
        const span = document.createElement('span');
        span.setAttribute(MD_NOTE_ATTRIBUTE, p[1]);
        span.textContent = `[^${p[1]}]`;
        add(span);
      } else if (p[3] && !at.words) {
        const a = mdLink(p[1], at);
        a.append(...mdNodes(p[2], at));
        add(a);
      } else {
        const words = mdNodes(p[2], at);
        const drawn = p[3] || at.words ? null : mdScheme(p[1], words, at);
        for (const node of drawn ? [drawn] : words) add(node);
      }
    }
    return out;
  }

  function markdown(el, text, { inline = false, field = null, id = null, notes = true, schemes = null } = {}) {
    const at = {
      field: field ?? null,
      id: id === null || id === undefined ? null : String(id),
      words: Boolean(el.closest?.(MD_PICKABLE)),
      schemes: schemes !== null && typeof schemes === 'object' ? schemes : null,
    };
    const read = notes !== false;
    el.classList.toggle('sm-md', !inline);
    el.classList.toggle('sm-md-inline', !!inline);
    if (text === null || text === undefined) {
      el.replaceChildren();
      return el;
    }
    const parts = mdBlocks(String(text));
    if (inline) {
      const pieces = [];
      for (const b of parts) {
        const marker = (i) => (b[0] === 'ul' ? '-' : `${b[1] + i}.`);
        const lines = b[0] === 'p' ? [b[1]] : b[2].map((item, i) => `${marker(i)} ${item}`.replace(/ +$/, ''));
        for (const line of lines) {
          if (pieces.length) pieces.push(['text', ' ']);
          for (const piece of mdInline(line, true, read)) pieces.push(piece);
        }
      }
      el.replaceChildren(...mdNodes(mdJoin(pieces), at));
      return el;
    }
    const nodes = parts.map((b) => {
      if (b[0] === 'p') {
        const p = document.createElement('p');
        p.append(...mdNodes(mdInline(b[1], true, read), at));
        return p;
      }
      const list = document.createElement(b[0]);
      if (b[0] === 'ol' && b[1] !== 1) list.setAttribute('start', String(b[1]));
      for (const item of b[2]) {
        const li = document.createElement('li');
        li.append(...mdNodes(mdInline(item, true, read), at));
        list.append(li);
      }
      return list;
    });
    el.replaceChildren(...nodes);
    return el;
  }

  const MD_MARKS = ['\\', '`', '*', '[', ']'];
  markdown.escape = (text) => {
    if (text === null || text === undefined) return '';
    let out = String(text).replace(/\s*[\r\n]\s*/g, ' ');
    out = Array.from(out, (c) => (MD_MARKS.includes(c) ? `\\${c}` : c)).join('');
    const ordered = MD_ORDERED.exec(out);
    if (ordered) return `${ordered[1]}\\${out.slice(ordered[1].length)}`;
    return MD_BULLET.test(out) ? `\\${out}` : out;
  };

  markdown.plain = (text, { notes = true } = {}) => {
    if (text === null || text === undefined) return '';
    const words = [];
    for (const b of mdBlocks(String(text))) {
      if (b[0] === 'p') words.push(mdPlain(mdInline(b[1], true, notes !== false)));
      else for (const item of b[2]) words.push(mdPlain(mdInline(item, true, notes !== false)));
    }
    return words.join(' ');
  };
  Object.freeze(markdown);
  const MOTION_SPEEDS = ['off', 'fast', 'normal', 'slow'];
  const MOTION_TYPES = ['smooth', 'snappy', 'spring', 'fade'];
  const MOTION_NUMBER_TO_SCALE = (n) => n;
  const MOTION_MAX = 5;
  const reducedQuery = () => matchMedia('(prefers-reduced-motion: reduce)');

  const motionToken = (el, name) => getComputedStyle(el).getPropertyValue(name).trim();
  const motionNumber = (el, name, fallback) => {
    const n = Number.parseFloat(motionToken(el, name));
    return Number.isFinite(n) ? n : fallback;
  };
  const motionScale = (el = document.documentElement) => motionNumber(el, '--stagemap-motion-scale', 1);

  let pageScale = null;
  function pageMotionScale() {
    if (pageScale === null) {
      pageScale = motionScale();
      Promise.resolve().then(() => {
        pageScale = null;
      });
    }
    return pageScale;
  }

  function motion(settings, root) {
    const el = root ?? document.documentElement;
    if (settings !== undefined && settings !== null) {
      if (!isObject(settings)) console.warn('stagemap.motion: give { speed, type } (or nothing to read the setting).');
      else {
        if ('speed' in settings) setMotionSpeed(el, settings.speed);
        if ('type' in settings) setMotionType(el, settings.type);
      }
    }
    const attr = el.getAttribute('data-stagemap-motion-speed');
    const speed =
      attr !== null && attr !== '' && Number.isFinite(Number(attr))
        ? Number(attr)
        : motionToken(el, '--stagemap-motion-speed') || 'normal';
    return {
      speed,
      type: motionToken(el, '--stagemap-motion-type') || 'smooth',
      scale: motionScale(el),
      reduced: reducedQuery().matches,
    };
  }
  function setMotionSpeed(el, value) {
    el.style.removeProperty('--stagemap-motion-scale');
    if (value === null) {
      el.removeAttribute('data-stagemap-motion-speed');
      return;
    }
    if (MOTION_SPEEDS.includes(value)) {
      el.setAttribute('data-stagemap-motion-speed', value);
      return;
    }
    const n = typeof value === 'string' && value.trim() !== '' ? Number(value) : value;
    if (typeof n !== 'number' || !Number.isFinite(n) || n < 0) {
      console.warn(
        `stagemap.motion: speed must be ${MOTION_SPEEDS.map((s) => `"${s}"`).join(', ')} or a number from 0 to ${MOTION_MAX}; kept the old value.`,
      );
      return;
    }
    const kept = Math.min(n, MOTION_MAX);
    if (kept !== n) console.warn(`stagemap.motion: speed ${n} is above ${MOTION_MAX}; using ${MOTION_MAX}.`);
    if (kept === 0) {
      el.setAttribute('data-stagemap-motion-speed', 'off');
      return;
    }
    el.setAttribute('data-stagemap-motion-speed', String(kept));
    el.style.setProperty('--stagemap-motion-scale', String(MOTION_NUMBER_TO_SCALE(kept)));
    el.style.setProperty('--stagemap-motion-play', 'running');
  }
  function setMotionType(el, value) {
    if (value === null) el.removeAttribute('data-stagemap-motion-type');
    else if (MOTION_TYPES.includes(value)) el.setAttribute('data-stagemap-motion-type', value);
    else
      console.warn(
        `stagemap.motion: type must be ${MOTION_TYPES.map((s) => `"${s}"`).join(', ')}; kept the old value.`,
      );
  }

  const motionRules = Object.freeze({
    motion_speed: (v) =>
      MOTION_SPEEDS.includes(v) ||
      ((typeof v === 'string' ? v.trim() !== '' : typeof v === 'number') &&
        Number.isFinite(Number(v)) &&
        Number(v) >= 0 &&
        Number(v) <= MOTION_MAX)
        ? ''
        : `"options.motion_speed" must be ${MOTION_SPEEDS.join(', ')} or a number from 0 to ${MOTION_MAX}`,
    motion_type: (v) =>
      MOTION_TYPES.includes(v) ? '' : `"options.motion_type" must be one of ${MOTION_TYPES.join(', ')}`,
  });
  const motionOwn = new WeakMap();
  function applyMotionOptions(root, data) {
    const options = isObject(data) && isObject(data.options) ? data.options : null;
    const had = motionOwn.get(root);
    if (!options && !had) return;
    const now = new Set();
    for (const [key, name] of [
      ['motion_speed', 'speed'],
      ['motion_type', 'type'],
    ]) {
      const value = options?.[key];
      if (given(value)) {
        now.add(name);
        if (motionRules[key](value) === '') motion({ [name]: value }, root);
      } else if (had?.has(name)) motion({ [name]: null }, root);
    }
    motionOwn.set(root, now);
  }

  const livePresence = new Set();
  function presence(
    el,
    {
      open = false,
      axis = 'fade',
      side = 'left',
      rise = 6,
      distance = 16,
      scale = 1,
      inner = null,
      show,
      hide,
      shown: isShown,
      backdrop = false,
      exit = 'ghost',
    } = {},
  ) {
    let target = Boolean(open);
    let running = [];
    let primed = null;
    let current = null;
    const phase = machine({
      name: 'presence',
      initial: 'idle',
      states: {
        idle: { enter: 'entering', leave: 'leaving', settle: 'idle' },
        entering: { enter: 'entering', leave: 'leaving', settle: 'idle' },
        leaving: { enter: 'entering', leave: 'leaving', settle: 'idle' },
      },
      on: ({ to }) =>
        to === 'entering' ? el.setAttribute('data-presence', 'entering') : el.removeAttribute('data-presence'),
    });
    const progressOf = (a) => Math.min(1, Math.max(0, a?.effect?.getComputedTiming().progress ?? 1));
    const custom = typeof show === 'function' && typeof hide === 'function';
    const shown = () => (typeof isShown === 'function' ? isShown() : custom ? el.open === true : !el.hidden);
    const apply = (isOpen) => {
      if (!custom) el.hidden = !isOpen;
      else if (isOpen && !shown()) show();
      else if (!isOpen && shown()) hide();
    };
    if (!custom) el.hidden = !target;

    const clear = () => {
      current = null;
      primed?.ghost.remove();
      primed?.scrim?.remove();
      primed = null;
      for (const r of running) {
        livePresence.delete(r);
        r.cancel?.();
        r.ghost?.remove();
      }
      running = [];
    };
    const axisOf = () => (typeof axis === 'function' ? axis() : axis);
    const frames = (node) => {
      const kind = axisOf();
      const travel = motionNumber(el, '--stagemap-motion-travel', 1);
      const size = motionNumber(el, '--stagemap-motion-size', 1);
      const away = { opacity: 0 };
      const rest = { opacity: 1 };
      if (kind === 'fade') {
        const parts = [];
        if (rise * travel) parts.push(`translateY(${rise * travel}px)`);
        if (scale !== 1 && travel) parts.push(`scale(${1 - (1 - scale) * travel})`);
        away.transform = parts.length ? parts.join(' ') : 'none';
        rest.transform = 'none';
      } else if (kind === 'slide') {
        const d = distance * travel;
        away.transform =
          {
            left: `translateX(${-d}px)`,
            right: `translateX(${d}px)`,
            top: `translateY(${-d}px)`,
            bottom: `translateY(${d}px)`,
          }[typeof side === 'function' ? side() : side] ?? 'none';
        rest.transform = 'none';
      } else if (kind === 'none') {
        away.opacity = 1;
        away.transform = 'none';
        rest.transform = 'none';
      } else if (size) {
        const prop = kind === 'inline' ? 'width' : 'height';
        away[prop] = '0px';
        away.boxSizing = 'border-box';
        rest.boxSizing = 'border-box';
        rest[prop] = `${kind === 'inline' ? node.getBoundingClientRect().width : node.scrollHeight}px`;
        if (kind === 'inline') {
          away.flexBasis = '0px';
          rest.flexBasis = rest.width;
        } else {
          const style = getComputedStyle(node);
          away.paddingTop = '0px';
          away.paddingBottom = '0px';
          rest.paddingTop = style.paddingTop;
          rest.paddingBottom = style.paddingBottom;
        }
      }
      return [away, rest];
    };
    const timing = (exiting) => ({
      duration:
        motionNumber(el, '--stagemap-motion-base-m', 200) * motionScale(el) * motionNumber(el, '--stagemap-motion-factor', 1),
      easing: motionToken(el, exiting ? '--stagemap-motion-ease-exit' : '--stagemap-motion-ease') || 'ease-out',
    });
    const play = (node, exiting, from = 0) => {
      const kind = axisOf();
      const [away, rest] = frames(node);
      const edge = kind === 'block' || kind === 'inline' ? node.style.overflow : null;
      if (edge !== null) node.style.overflow = 'hidden';
      const t = timing(exiting);
      const a = node.animate(exiting ? [rest, away] : [away, rest], t);
      if (from > 0) a.currentTime = from * t.duration;
      const done = () => {
        if (edge !== null) node.style.overflow = edge;
      };
      a.finished.then(
        () => {
          done();
          livePresence.delete(a);
          if (a.ghost) a.ghost.remove();
          if (current?.a === a) {
            current = null;
            phase.send('settle');
          }
        },
        () => done(),
      );
      livePresence.add(a);
      running.push(a);
      current = { a, exiting };
      phase.send(exiting ? 'leave' : 'enter');
      return a;
    };
    const inside = (node) => (inner ? node.querySelector(inner) : node) ?? node;
    const canMove = () => motionScale(el) > 0 && typeof el.animate === 'function' && el.isConnected;

    const leaver = () => {
      const rect = el.getBoundingClientRect();
      let ghost;
      if (custom && el.localName === 'dialog') {
        ghost = document.createElement('div');
        for (const attr of el.attributes) ghost.setAttribute(attr.name, attr.value);
        for (const child of el.childNodes) ghost.append(child.cloneNode(true));
      } else ghost = el.cloneNode(true);
      ghost.removeAttribute('id');
      for (const x of ghost.querySelectorAll('[id]')) x.removeAttribute('id');
      for (const x of [ghost, ...ghost.querySelectorAll('[data-stagemap-auto], [data-stagemap-visual]')]) {
        x.removeAttribute('data-stagemap-auto');
        x.removeAttribute('data-stagemap-visual');
      }
      for (const x of ghost.querySelectorAll('input, select, textarea, button')) {
        x.removeAttribute('name');
        x.removeAttribute('form');
      }
      const media = 'iframe, video, audio, object, embed';
      const live = [...el.querySelectorAll(media)];
      [...ghost.querySelectorAll(media)].forEach((x, i) => {
        const box = document.createElement('div');
        const r = live[i]?.getBoundingClientRect();
        if (r) Object.assign(box.style, { width: `${r.width}px`, height: `${r.height}px` });
        x.replaceWith(box);
      });
      ghost.setAttribute('data-stagemap-copy', '');
      ghost.setAttribute('aria-hidden', 'true');
      ghost.setAttribute('inert', '');
      ghost.removeAttribute('hidden');
      ghost.style.pointerEvents = 'none';
      let scrim = null;
      if (custom) {
        ghost.setAttribute('open', '');
        Object.assign(ghost.style, {
          position: 'fixed',
          margin: '0',
          inset: 'auto',
          left: `${rect.left}px`,
          top: `${rect.top}px`,
          width: `${rect.width}px`,
          height: `${rect.height}px`,
          zIndex: '2147483000',
        });
        if (backdrop) {
          const colour = getComputedStyle(el, '::backdrop').backgroundColor;
          scrim = document.createElement('div');
          Object.assign(scrim.style, {
            position: 'fixed',
            inset: '0',
            background: colour,
            pointerEvents: 'none',
            zIndex: '2147482999',
          });
          scrim.setAttribute('aria-hidden', 'true');
        }
      }
      (custom ? (el.getRootNode() === document ? el.parentElement : document.body) : el.parentElement)?.insertBefore(
        ghost,
        custom ? null : el.nextSibling,
      );
      if (scrim) ghost.before(scrim);
      return { ghost, scrim };
    };

    const set = (value) => {
      const next = Boolean(value);
      if (next === target) return;
      target = next;
      const wasShown = shown();
      const carry = current && current.exiting === next ? 1 - progressOf(current.a) : 0;
      if (next) {
        clear();
        apply(true);
        if (!canMove()) {
          phase.send('settle');
          return;
        }
        play(inside(el), false, carry);
        if (backdrop) {
          try {
            const b = el.animate([{ opacity: 0 }, { opacity: 1 }], { ...timing(false), pseudoElement: '::backdrop' });
            running.push(b);
          } catch {
          }
        }
        return;
      }
      const copy = primed ?? (exit === 'ghost' && wasShown && canMove() ? leaver() : null);
      primed = null;
      clear();
      apply(false);
      if (!copy) {
        phase.send('settle');
        return;
      }
      copy.ghost.setAttribute('data-presence', 'leaving');
      const a = play(inside(copy.ghost), true, carry);
      a.ghost = copy.ghost;
      if (copy.scrim) {
        const b = copy.scrim.animate([{ opacity: 1 }, { opacity: 0 }], timing(true));
        b.finished.then(
          () => copy.scrim.remove(),
          () => copy.scrim.remove(),
        );
        running.push({ cancel: () => copy.scrim.remove(), ghost: null });
      }
    };
    return Object.freeze({
      get open() {
        return target;
      },
      set,
      prime() {
        if (!primed && target && exit === 'ghost' && shown() && canMove()) primed = leaver();
      },
      get phase() {
        return phase.state;
      },
      quiet(value) {
        target = Boolean(value);
        clear();
        apply(target);
        phase.send('settle');
      },
      enter() {
        if (!target || axisOf() === 'none' || !canMove()) return;
        clear();
        play(inside(el), false, 0);
      },
      destroy() {
        clear();
        apply(target);
        phase.send('settle');
      },
    });
  }

  if (typeof matchMedia === 'function') {
    reducedQuery().addEventListener?.('change', (e) => {
      if (!e.matches) return;
      for (const a of [...livePresence]) {
        try {
          a.finish();
        } catch {
          a.cancel();
        }
      }
    });
  }
  const MODE_ATTR = 'data-stagemap-mode';
  const modeState = new WeakMap();
  const modeRefs = new Set();
  const modeRefd = new WeakSet();
  const hostModeRoots = new WeakSet();
  const darkQueries = new WeakMap();
  let modeObserver = null;

  const modeSource = (el) => el.closest(`[${MODE_ATTR}]`) ?? el.ownerDocument.documentElement;
  const settingOf = (el) => {
    const src = modeSource(el);
    if (hostModeRoots.has(src)) return 'host';
    const value = src.getAttribute(MODE_ATTR);
    return value === 'dark' || value === 'auto' ? value : 'light';
  };
  const shownOf = (el) => {
    const src = modeSource(el);
    const setting = settingOf(src);
    if (setting === 'auto')
      return src.ownerDocument.defaultView?.matchMedia?.('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    return setting === 'dark' || (setting === 'host' && src.getAttribute(MODE_ATTR) === 'dark') ? 'dark' : 'light';
  };

  function settleMode(el, by) {
    const was = modeState.get(el);
    if (!was) return false;
    const now = { mode: shownOf(el), setting: settingOf(el) };
    modeState.set(el, now);
    if (was.mode === now.mode) return false;
    const detail = {
      mode: now.mode,
      from: was.mode,
      setting: now.setting,
      by,
      scope: el === el.ownerDocument.documentElement ? 'page' : 'root',
    };
    el.dispatchEvent(new CustomEvent('stagemap:mode', { bubbles: true, detail: stamp(detail, el.ownerDocument) }));
    return true;
  }
  const liveScopes = () => {
    const live = [];
    for (const ref of [...modeRefs]) {
      const el = ref.deref();
      if (!el) modeRefs.delete(ref);
      else if (modeState.has(el)) live.push(el);
    }
    return live;
  };
  function modeStart(el) {
    if (modeState.has(el)) return;
    modeState.set(el, { mode: shownOf(el), setting: settingOf(el) });
    if (!modeRefd.has(el)) {
      modeRefd.add(el);
      liveScopes();
      modeRefs.add(weakRef(el));
    }
    const view = el.ownerDocument.defaultView;
    modeObserver ??= new MutationObserver((records) => {
      for (const target of new Set(records.map((r) => r.target))) {
        if (target.ownerDocument.documentElement !== target && !target.hasAttribute(MODE_ATTR)) modeEnd(target);
        else settleMode(target, 'host');
      }
    });
    modeObserver.observe(el, { attributes: true, attributeFilter: [MODE_ATTR] });
    if (view?.matchMedia && !darkQueries.has(view)) {
      const query = view.matchMedia('(prefers-color-scheme: dark)');
      darkQueries.set(view, query);
      query.addEventListener('change', () => {
        for (const el of liveScopes()) {
          if (settingOf(el) !== 'auto') continue;
          if (el.isConnected) settleMode(el, 'system');
          else modeState.set(el, { mode: shownOf(el), setting: settingOf(el) });
        }
      });
    }
  }
  function modeEnd(el) {
    settleMode(el, 'host');
    if (el !== el.ownerDocument.documentElement && !el.hasAttribute(MODE_ATTR)) {
      modeState.delete(el);
      hostModeRoots.delete(el);
    }
  }
  document.addEventListener('report:theme', () => {
    const html = document.documentElement;
    const was = modeState.get(html);
    if (was) settleMode(html, settingOf(html) !== was.setting ? 'reader' : 'system');
  });
  modeStart(document.documentElement);

  function mode(root) {
    if (root !== undefined && root !== null && root?.nodeType !== 1) {
      console.warn('stagemap.mode: root must be an element (or left out for the page); nothing is read.');
      return null;
    }
    const el = modeSource(root ?? document.documentElement);
    return {
      mode: shownOf(el),
      setting: settingOf(el),
      scope: el === el.ownerDocument.documentElement ? 'page' : 'root',
    };
  }
  const COLOUR_RULES = {"rules":1,"numeric":{"channel":{"scale":255,"half":0.5},"srgb":{"to_linear_below":0.04045,"to_linear_slope":12.92,"offset":0.055,"gamma":2.4,"from_linear_below":0.0031308},"luminance":[0.2126,0.7152,0.0722],"flare":0.05,"oklab":{"rgb_to_lms":[[0.4122214708,0.5363325363,0.0514459929],[0.2119034982,0.6806995451,0.1073969566],[0.0883024619,0.2817188376,0.6299787005]],"lms_to_lab":[[0.2104542553,0.793617785,-0.0040720468],[1.9779984951,-2.428592205,0.4505937099],[0.0259040371,0.7827717662,-0.808675766]],"lab_to_lms":[[1,0.3963377774,0.2158037573],[1,-0.1055613458,-0.0638541728],[1,-0.0894841775,-1.291485548]],"lms_to_rgb":[[4.0767416621,-3.3077115913,0.2309699292],[-1.2684380046,2.6097574011,-0.3413193965],[-0.0041960863,-0.7034186147,1.707614701]]},"machado":{"protan":[[0.152286,1.052583,-0.204868],[0.114503,0.786281,0.099216],[-0.003882,-0.048116,1.051998]],"deutan":[[0.367322,0.860646,-0.227968],[0.280085,0.672501,0.047413],[-0.01182,0.04294,0.968881]]},"l_step":0.005,"halvings":16,"hueless_chroma":0.0005,"ratio_cut":1e-09,"ratio_scale":100,"distance_scale":100,"search_ends":{"lighter":"#ffffff","darker":"#000000"},"notes":"A channel is floor(v * 255 + 0.5) after v is held to 0..1. The lightness search moves in l_step and tests the rounded hex. A colour is brought into sRGB by `halvings` halvings of chroma. A colour under hueless_chroma has chroma 0 and hue 0. A shown ratio is floor(r * 100 + ratio_cut) / 100; a pair passes when r >= need on the uncut ratio."},"guards":{"grey_accent":{"chroma_under":0.03},"surface_room":{"light":{"lightness_at_least":0.79},"dark":{"lightness_at_most":0.4}},"surface_chroma_most":0.04,"status_angle":20,"chart":{"band":{"light":[0.43,0.77],"dark":[0.48,0.67]},"apart_normal":15,"apart_colour_blind":8,"chroma_least":0.1,"apart_slots":2,"companion":{"hue":250,"chroma":0.13,"band_share":0.5}}},"colour_defaults":{"about":"The stand-in persona's own settings for the rules (section 3 of the API note: a persona's surface steps and tints). Each is a number or { light, dark }. A persona's own `colour` block, once themes have one, replaces them by name. They were measured on the default theme: seeding its own page, ink and accent gives back its surfaces within a step or two.","panel_step":{"light":0.023,"dark":0.044},"panel_chroma":{"light":1.0,"dark":1.3},"soft_step":{"light":-0.014,"dark":0.083},"soft_chroma":{"light":2.0,"dark":1.6},"line_step":{"light":-0.075,"dark":0.13},"line_chroma":{"light":3.0,"dark":1.5},"line_strong_step":{"light":-0.125,"dark":0.2},"line_strong_chroma":{"light":4.0,"dark":1.9},"muted_step":{"light":0.25,"dark":-0.195},"mark_muted_step":{"light":0.337,"dark":-0.227},"chart_led_by_accent":true},"pairs":{"sets":{"surface":["page","panel","panel-soft","card","sidebar","drawer","popup"],"chart_surface":["panel","card"],"tone":["good","warn","bad"],"series":["cat-1","cat-2","cat-3","cat-4","cat-5","cat-6","cat-7","cat-8"],"word_colour":["accent-ink","good","warn","bad","muted","cat-1","cat-2","cat-3","cat-4","cat-5","cat-6","cat-7","cat-8"]},"mixes":{"word":{"colour":"$role","with":"ink","share":0.7},"chip_soft":{"colour":"$role","with":"panel","share":0.16,"label":"its soft fill"},"solid_rest":{"colour":"accent","with":"ink","share":0.92,"label":"the button at rest"},"solid_hover":{"colour":"accent","with":"ink","share":0.68,"token":"button-solid-hover-bg","label":"the button on hover"},"soft_fill":{"colour":"$role","with":"panel","share":{"light":0.16,"dark":0.24}}},"groups":{"text":{"need":4.5,"kind":"text","rows":[{"role":["ink","muted","accent-ink"],"on":"@surface"},{"role":"accent-ink","on":"accent-soft"},{"role":"@tone","on":"$role-soft"}]},"label":{"need":4.5,"kind":"text","rows":[{"role":"on-accent","on":"accent"},{"role":"on-accent","on_mix":"solid_rest"}]},"label_hover":{"need":4.5,"kind":"text","rows":[{"role":"on-accent","on_mix":"solid_hover"}]},"words":{"need":4.5,"kind":"text","waivable":"words","rows":[{"role":"@word_colour","mix":"word","on":"@surface"},{"role":"@word_colour","mix":"word","on_mix":"chip_soft"}]},"marks":{"need":3,"kind":"mark","rows":[{"role":["focus","accent-line","mark-muted"],"on":"@surface"},{"role":"@tone","on":"@chart_surface"}]},"fill_mark":{"need":3,"kind":"mark","report":false,"rows":[{"role":"accent","on":"@surface"}]},"chart":{"need":3,"kind":"chart","rows":[{"role":"@series","on":"@chart_surface"}]},"chosen":{"need":4.5,"kind":"text","part":"the sidebar's chosen item","rows":[{"role":"ink","on":"accent-soft","part_role":"words"},{"role":"accent-ink","on":["accent-soft","sidebar"],"need":3,"kind":"mark","part_role":"bar"}]}}},"roles":[{"role":"page","family":"background","from":{"seed":"background"}},{"role":"panel","family":"background","from":{"seed":"background"},"set":{"L":{"add":{"setting":"panel_step"}},"C":{"mul":{"setting":"panel_chroma"}}}},{"role":"panel-soft","family":"background","from":{"seed":"background"},"set":{"L":{"add":{"setting":"soft_step"}},"C":{"mul":{"setting":"soft_chroma"}}}},{"role":"card","family":"background","pick":["panel"]},{"role":"sidebar","family":"background","pick":["panel-soft"]},{"role":"drawer","family":"background","pick":["panel"]},{"role":"popup","family":"background","pick":{"light":["panel"],"dark":["panel-soft"]}},{"role":"div-mid","family":"chart","pick":["panel-soft"],"follows":["background"]},{"role":"line","family":"background","from":{"seed":"background"},"set":{"L":{"add":{"setting":"line_step"}},"C":{"mul":{"setting":"line_chroma"}}}},{"role":"line-strong","family":"background","from":{"seed":"background"},"set":{"L":{"add":{"setting":"line_strong_step"}},"C":{"mul":{"setting":"line_strong_chroma"}}}},{"role":"ink","family":"foreground","from":{"seed":"foreground"},"ensure":["text"],"settle":["chosen"],"rule":"text_shifted"},{"role":"muted","family":"foreground","from":"ink","set":{"L":{"add":{"setting":"muted_step"}}},"ensure":["text","words"],"rule":"text_shifted"},{"role":"mark-muted","family":"foreground","from":"ink","set":{"L":{"add":{"setting":"mark_muted_step"}}},"ensure":["marks"],"rule":"text_shifted"},{"role":"backdrop","family":"background","follows":["background","foreground"],"rgba":{"light":"ink","dark":"#000000"}},{"role":"shadow-1","family":"background","follows":["background","foreground"],"rgba":{"light":"ink","dark":"#000000"}},{"role":"shadow-2","family":"background","follows":["background","foreground"],"rgba":{"light":"ink","dark":"#000000"}},{"role":"shadow-3","family":"background","follows":["background","foreground"],"rgba":{"light":"ink","dark":"#000000"}},{"role":"accent","family":"accent","from":{"seed":"accent"},"ensure":{"light":["label"],"dark":["fill_mark","label"]},"rule":{"light":"fill_stepped","dark":"fill_lifted"}},{"role":"accent-soft","family":"accent","from":"accent","mix":"soft_fill","follows":["accent","background"]},{"role":"accent-ink","family":"accent","from":{"seed":"accent"},"ensure":["text","words"],"rule":"text_shifted"},{"role":"accent-line","family":"accent","pick":["accent","accent-ink"],"ensure":["marks"],"rule":"fill_edged"},{"role":"focus","family":"accent","pick":["accent","accent-ink"],"ensure":["marks"]},{"role":"on-accent","family":"accent","pick":["#ffffff","light.ink","#000000"],"ensure":["label","label_hover"],"rule":"label_picked","turn":{"role":"button-solid-hover-bg","ensure":["label_hover"],"rule":"hover_turned"}},{"role":"cat-1","family":"chart","from":{"seed":"accent"},"follows":["accent"],"band":true,"when":"chart_led_by_accent","ensure":["chart","words"],"rule":"series_refit"},{"role":"seq-hi","family":"chart","pick":["cat-1"],"follows":["accent"]},{"role":"seq-lo","family":"chart","pick":["accent-soft"],"follows":["accent","background"]},{"role":"good","family":"status","ensure":["text","marks","words"],"rule":"tone_refit"},{"role":"warn","family":"status","ensure":["text","marks","words"],"rule":"tone_refit"},{"role":"bad","family":"status","ensure":["text","marks","words"],"rule":"tone_refit"},{"role":"good-soft","family":"status","from":"good","mix":"soft_fill","follows":["background"]},{"role":"warn-soft","family":"status","from":"warn","mix":"soft_fill","follows":["background"]},{"role":"bad-soft","family":"status","from":"bad","mix":"soft_fill","follows":["background"]},{"role":"cat-2","family":"chart","ensure":["chart","words"],"rule":"series_refit"},{"role":"cat-3","family":"chart","ensure":["chart","words"],"rule":"series_refit"},{"role":"cat-4","family":"chart","ensure":["chart","words"],"rule":"series_refit"},{"role":"cat-5","family":"chart","ensure":["chart","words"],"rule":"series_refit"},{"role":"cat-6","family":"chart","ensure":["chart","words"],"rule":"series_refit"},{"role":"cat-7","family":"chart","ensure":["chart","words"],"rule":"series_refit"},{"role":"cat-8","family":"chart","ensure":["chart","words"],"rule":"series_refit"},{"role":"div-lo","family":"chart","pick":["cat-3"],"follows":["accent","background"]},{"role":"div-hi","family":"chart","pick":["cat-2"],"follows":["accent","background"]}],"procedures":{"about":"Steps that are code in every runtime, not row data. Each names the change rule it records, and its numbers live here or in guards.","seeds":{"unset":"seed_unset","one_colour":"other_mode","foreground_reference":{"light":"#ffffff","dark":"#000000"}},"background":{"moved":"background_moved"},"ink":{"settle_passes":4},"hover":{"step":0.08,"dark_label_below":0.179,"dark_label_direction":1,"light_label_direction":-1},"series":{"companion":"series_companion","skipped":"series_skipped","accent_near_tone":"near_status"},"followers":{"accent-ink":"accent","accent-line":"accent"}},"change_rules":{"text_shifted":{"what":"a text colour went darker (light) or lighter (dark) at the same hue until it held its floor","note":"{role} moved from {asked} to {got} to reach its floor on the surfaces it sits on."},"fill_edged":{"what":"the typed accent stays on fills; where it is too faint against a surface, accent-line takes the text colour","note":"The accent fill {asked} is too faint against a surface, so its edge takes {got}."},"fill_lifted":{"what":"an accent too dark for the dark page was lifted there","note":"The accent {asked} was lifted to {got} so that it stays visible on the dark surfaces and carries a readable label."},"fill_stepped":{"what":"a light-mode accent fill moved a few steps so that a label reads on both the fill and the resting button","note":"The accent {asked} moved to {got} so that a label reads on both the fill and the resting button."},"label_picked":{"what":"on-accent is white, then the page ink, then black: the first that holds its floor on the fill, at rest and on hover","note":"The words on the accent are {got}, the first candidate that reads on the fill and the button."},"hover_turned":{"what":"the solid button's hover fill stepped away from the label, because the usual darker hover would not hold its floor","note":"The button's usual hover {asked} would not hold the text floor under the label, so the hover fill is {got}."},"series_companion":{"what":"a grey accent: chart series 2 took a companion hue, not a second grey","note":"The accent is grey, so {role} takes the companion hue {got} instead of a second grey."},"series_skipped":{"what":"a persona's chart colour sat too close to the accent-led cat-1 and moved back; the next one took its slot","note":"Chart colour {asked} sat too close to the lead chart colour, so {role} now holds {got}."},"near_status":{"what":"the accent's hue sits near a status hue: nothing moved; noted, because status is told by shape and word","note":"The accent's hue ({hue}) is near {tone} ({tone_hue}); nothing moved, because status is told by shape and word."},"wash_words":{"what":"words on a soft fill use the ink or the tone's word mix, never the muted ink step; no colour moves for it","note":"Words on a soft fill use the ink or the tone's word mix, never the muted ink step."},"tone_refit":{"what":"a status tone moved in lightness to hold its floor on the surfaces it sits on","note":"{role} moved from {asked} to {got} to hold its floor on these surfaces."},"series_refit":{"what":"a chart colour moved in lightness to hold its floor on the surfaces it sits on","note":"{role} moved from {asked} to {got} to hold its floor on these surfaces."},"background_moved":{"what":"a background was moved to the nearest lightness at which every surface of the mode leaves room for text","note":"The background {asked} left no room for text in the {mode} mode, so the page uses {got}."},"other_mode":{"what":"a background or foreground given as one colour belongs to the mode its lightness suits; the other mode keeps the persona's lightness and takes the seed's hue","note":"The {seed} was given as one colour, so the {mode} mode keeps the persona's lightness and takes its hue: {got}."},"seed_unset":{"what":"a host variable the page does not define, with no fallback: the persona's own seed is used","note":"The host variable {asked} has no fallback, so the persona's own {seed} {got} is used."},"seed_flattened":{"what":"a host variable's colour had alpha and was laid over the colour behind (the kit reads a host page; Python never does)","note":"The host variable {asked} had alpha, so it was laid over the colour behind it and is {got}."}}};
  const colourRules = () => COLOUR_RULES;
  let colourEngine = null;
  const engineOf = () => {
    colourEngine ??= makeColourEngine(colourRules());
    return colourEngine;
  };

  function makeColourEngine(RULES) {
    const NUM = RULES.numeric;
    const GUARDS = RULES.guards;
    const PAIRS = RULES.pairs;
    const PROC = RULES.procedures;
    const MODE_NAMES = ['light', 'dark'];
    const SURFACES = PAIRS.sets.surface;
    const ROWS = Object.fromEntries(RULES.roles.map((r) => [r.role, r]));
    const own = (o, k) => Object.hasOwn(o, k);

    const srgbIn = (c) => {
      const s = NUM.srgb;
      return c <= s.to_linear_below ? c / s.to_linear_slope : ((c + s.offset) / (1 + s.offset)) ** s.gamma;
    };
    const srgbOut = (c) => {
      const s = NUM.srgb;
      return c <= s.from_linear_below ? s.to_linear_slope * c : (1 + s.offset) * c ** (1 / s.gamma) - s.offset;
    };
    const byte = (h, i) => Number.parseInt(h.slice(i, i + 2), 16);
    const lin = (h) => [1, 3, 5].map((i) => srgbIn(byte(h, i) / NUM.channel.scale));
    const channel = (v) => Math.floor(Math.min(1, Math.max(0, v)) * NUM.channel.scale + NUM.channel.half);
    const toHex = (rgb) => `#${rgb.map((v) => channel(v).toString(16).padStart(2, '0')).join('')}`;
    const luminanceOf = (h) => {
      const c = lin(h);
      let sum = 0;
      for (let i = 0; i < 3; i++) sum += NUM.luminance[i] * c[i];
      return sum;
    };
    const contrastOf = (a, b) => {
      const [hi, lo] = [luminanceOf(a), luminanceOf(b)].sort((p, q) => q - p);
      return (hi + NUM.flare) / (lo + NUM.flare);
    };
    const cut = (r) => Math.floor(r * NUM.ratio_scale + NUM.ratio_cut) / NUM.ratio_scale;
    const mixHex = (a, b, share) =>
      toHex(
        [1, 3, 5].map((i) => (byte(a, i) / NUM.channel.scale) * share + (byte(b, i) / NUM.channel.scale) * (1 - share)),
      );
    const matrix = (m, v) => m.map((row) => row[0] * v[0] + row[1] * v[1] + row[2] * v[2]);
    const cubeRoot = (x) => (x < 0 ? -1 : 1) * Math.abs(x) ** (1 / 3);
    const oklab = (rgb) => matrix(NUM.oklab.lms_to_lab, matrix(NUM.oklab.rgb_to_lms, rgb).map(cubeRoot));
    const oklch = (h) => {
      const [L, a, b] = oklab(lin(h));
      const C = Math.hypot(a, b);
      if (C < NUM.hueless_chroma) return [L, 0, 0];
      const deg = Math.atan2(b, a) * (180 / Math.PI);
      return [L, C, ((deg % 360) + 360) % 360];
    };
    const linRgb = (L, C, H) => {
      const rad = H * (Math.PI / 180);
      const lms = matrix(NUM.oklab.lab_to_lms, [L, C * Math.cos(rad), C * Math.sin(rad)]).map((x) => x ** 3);
      return matrix(NUM.oklab.lms_to_rgb, lms);
    };
    const inside = (v) => v.every((x) => x >= 0 && x <= 1);
    const fromLch = (L0, C, H) => {
      const L = Math.min(1, Math.max(0, L0));
      let v = linRgb(L, C, H);
      if (!inside(v)) {
        let lo = 0;
        let hi = C;
        for (let i = 0; i < NUM.halvings; i++) {
          const mid = (lo + hi) / 2;
          if (inside(linRgb(L, mid, H))) lo = mid;
          else hi = mid;
        }
        v = linRgb(L, lo, H);
      }
      return toHex(v.map((x) => srgbOut(Math.min(1, Math.max(0, x)))));
    };
    const seen = (h, kind) => {
      let rgb = lin(h);
      if (kind) rgb = matrix(NUM.machado[kind], rgb).map((x) => Math.max(0, Math.min(1, x)));
      return oklab(rgb);
    };
    const delta = (a, b, kind) => {
      const p = seen(a, kind);
      const q = seen(b, kind);
      return NUM.distance_scale * Math.sqrt((p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 + (p[2] - q[2]) ** 2);
    };
    const hueGap = (a, b) => {
      const d = Math.abs(a - b) % 360;
      return Math.min(d, 360 - d);
    };
    const search = (start, ok, up) => {
      if (ok(start)) return start;
      const [L, C, H] = oklch(start);
      for (let k = 1; ; k++) {
        const Lk = L + (up ? 1 : -1) * k * NUM.l_step;
        if (Lk > 1 || Lk < 0) return NUM.search_ends[up ? 'lighter' : 'darker'];
        const h = fromLch(Lk, C, H);
        if (ok(h)) return h;
      }
    };

    const expand = (spec) => {
      if (Array.isArray(spec)) return [...spec];
      if (typeof spec === 'string' && spec.startsWith('@')) return [...PAIRS.sets[spec.slice(1)]];
      return [spec];
    };
    const perMode = (spec, mode) =>
      isObject(spec) && Object.keys(spec).every((k) => MODE_NAMES.includes(k)) ? spec[mode] : spec;
    const mixOf = (name, role, v, mode) => {
      const spec = PAIRS.mixes[name];
      if (spec.token && own(v, spec.token)) return v[spec.token];
      const colour = spec.colour === '$role' ? role : spec.colour;
      return mixHex(v[colour], v[spec.with], perMode(spec.share, mode));
    };
    const pairRows = (groups = null) => {
      const out = [];
      for (const [group, g] of Object.entries(PAIRS.groups)) {
        if (groups && !groups.includes(group)) continue;
        for (const row of g.rows) {
          for (const role of expand(row.role)) {
            const spec = row.on_mix ? PAIRS.mixes[row.on_mix] : null;
            const ons = row.on ? expand(row.on) : [spec.colour === '$role' ? role : spec.colour];
            for (const on of ons) {
              out.push({
                group,
                role,
                mix: row.mix ?? null,
                on_mix: row.on_mix ?? null,
                on: on.replace('$role', role),
                label: spec ? spec.label : null,
                need: row.need ?? g.need,
                kind: row.kind ?? g.kind,
                report: g.report ?? true,
                part: g.part ?? null,
                part_role: row.part_role ?? null,
              });
            }
          }
        }
      }
      return out;
    };
    const evaluate = (row, v, mode) =>
      contrastOf(
        row.mix ? mixOf(row.mix, row.role, v, mode) : v[row.role],
        row.on_mix ? mixOf(row.on_mix, row.role, v, mode) : v[row.on],
      );
    const withFollowers = (v) => {
      const out = { ...v };
      for (const [role, leader] of Object.entries(PROC.followers)) if (!own(out, role)) out[role] = out[leader];
      return out;
    };
    const checksOf = (v, mode, source) => {
      const out = [];
      for (const row of pairRows()) {
        if (!row.report) continue;
        const r = evaluate(row, v, mode);
        out.push({
          role: row.role,
          on: row.on,
          label: row.label,
          mode,
          ratio: cut(r),
          need: row.need,
          kind: row.kind,
          pass: r >= row.need,
          source: source?.[row.role] ?? 'persona',
        });
      }
      return out;
    };

    const parseColour = (text) => {
      const t = text.trim().toLowerCase();
      if (t.startsWith('#') && (t.length === 4 || t.length === 7) && /^[0-9a-f]+$/.test(t.slice(1)))
        return t.length === 7 ? t : `#${[...t.slice(1)].map((c) => c + c).join('')}`;
      if (t.startsWith('rgb(') && t.endsWith(')')) {
        const parts = t
          .slice(4, -1)
          .replaceAll('/', ',')
          .split(',')
          .map((p) => p.trim());
        if (parts.length === 3 && parts.every((p) => /^\d+$/.test(p) && Number(p) <= NUM.channel.scale))
          return `#${parts.map((p) => Number(p).toString(16).padStart(2, '0')).join('')}`;
      }
      throw new Error(
        `a colour must be a hex such as #0b7c7b or rgb(11, 124, 123), without alpha; got ${quoted(text)}`,
      );
    };
    const readSeed = (value, name) => {
      if (value === null || value === undefined || value === '') return [null, false];
      if (typeof value !== 'string')
        throw new Error(
          `seeds.${name} must be written as text, a hex such as #0b7c7b or rgb(11, 124, 123); got ${quoted(value)}`,
        );
      if (value.trim().toLowerCase().startsWith('var(')) {
        const inner = value.trim().slice(4, -1);
        const comma = inner.indexOf(',');
        const fallback = comma >= 0 ? inner.slice(comma + 1).trim() : '';
        return [fallback ? readSeed(fallback, name)[0] : null, true];
      }
      return [parseColour(value), false];
    };

    const setting = (name, persona, mode) => {
      const block = isObject(persona.colour) ? persona.colour : {};
      return perMode(own(block, name) ? block[name] : RULES.colour_defaults[name], mode);
    };
    const number = (spec, persona, mode) =>
      isObject(spec) && 'setting' in spec ? setting(spec.setting, persona, mode) : spec;
    const applySet = (row, base, persona, mode) => {
      let [L, C, H] = oklch(base);
      for (const key of ['L', 'C']) {
        const spec = row.set[key];
        if (spec === undefined) continue;
        const now = key === 'L' ? L : C;
        const value = 'add' in spec ? now + number(spec.add, persona, mode) : now * number(spec.mul, persona, mode);
        if (key === 'L') L = value;
        else C = value;
      }
      if (row.family === 'background') C = Math.min(C, GUARDS.surface_chroma_most);
      return fromLch(L, C, H);
    };
    const restain = (text, rgb) => {
      if (text.split('rgba(').length !== 2 || !text.trimEnd().endsWith(')')) return null;
      const head = text.slice(0, text.indexOf('rgba('));
      const tail = text.slice(text.indexOf('rgba(') + 5);
      const alpha = tail.slice(tail.lastIndexOf(',') + 1);
      return `${head}rgba(${byte(rgb, 1)}, ${byte(rgb, 3)}, ${byte(rgb, 5)},${alpha}`;
    };

    const surfaceOf = (page, mode, persona) => {
      const out = {};
      for (const name of SURFACES) {
        const row = ROWS[name];
        if (!row) continue;
        const pick = 'pick' in row ? perMode(row.pick, mode) : null;
        out[name] = pick ? out[pick[0]] : 'set' in row ? applySet(row, page, persona, mode) : page;
      }
      return out;
    };
    const roomOf = (mode, persona) => {
      const g = GUARDS.surface_room[mode];
      const steps = [...Object.values(surfaceOf(fromLch(0.5, 0, 0), mode, persona)).map((c) => oklch(c)[0] - 0.5), 0];
      return mode === 'light' ? g.lightness_at_least - Math.min(...steps) : g.lightness_at_most - Math.max(...steps);
    };
    const insideRoom = (page, mode, persona) => {
      const g = GUARDS.surface_room[mode];
      const lights = Object.values(surfaceOf(page, mode, persona)).map((c) => oklch(c)[0]);
      return mode === 'light'
        ? Math.min(...lights) >= g.lightness_at_least
        : Math.max(...lights) <= g.lightness_at_most;
    };
    const limitPage = (hexcolour, mode, persona) => {
      if (insideRoom(hexcolour, mode, persona)) return [hexcolour, false];
      const [, C, H] = oklch(hexcolour);
      const start = fromLch(roomOf(mode, persona), C, H);
      return [search(start, (h) => insideRoom(h, mode, persona), mode === 'light'), true];
    };
    const modeOfBackground = (hexcolour, persona) => {
      const L = oklch(hexcolour)[0];
      const dist = {};
      for (const m of MODE_NAMES)
        dist[m] = m === 'light' ? Math.max(0, roomOf(m, persona) - L) : Math.max(0, L - roomOf(m, persona));
      return dist.light <= dist.dark ? 'light' : 'dark';
    };
    const modeOfForeground = (hexcolour) => {
      const ref = PROC.seeds.foreground_reference;
      const light = contrastOf(hexcolour, ref.light);
      const dark = contrastOf(hexcolour, ref.dark);
      return dark > light ? 'dark' : 'light';
    };
    const otherModeSeed = (seed, personaColour) => {
      const [, C, H] = oklch(seed);
      if (C === 0) return null;
      const [pL, pC] = oklch(personaColour);
      return fromLch(pL, pC, H);
    };
    const fill = (text, fields) => text.replace(/\{(\w+)\}/g, (_, k) => String(fields[k]));

    class Run {
      constructor(persona, seeds, pinned, hostInfo = null) {
        this.persona = persona;
        this.changes = [];
        this.pinned = pinned || {};
        this.unread = [];
        this.seedsOut = {};
        this.v = {};
        this.origin = {};
        this.derived = {};
        this.hostDerived = {};
        for (const m of MODE_NAMES) {
          this.v[m] = { ...persona[m] };
          this.origin[m] = { ...this.v[m] };
          this.derived[m] = new Set();
          this.hostDerived[m] = new Set();
        }
        this.askedAccent = {};
        this.inkOverride = {};
        this.seed = { accent: null, background: { light: null, dark: null }, foreground: { light: null, dark: null } };
        this.hostSeed = {
          accent: false,
          background: { light: false, dark: false },
          foreground: { light: false, dark: false },
        };
        this.rowsByGroup = {};
        for (const g of Object.keys(PAIRS.groups)) this.rowsByGroup[g] = pairRows([g]);
        this.readSeeds(seeds, hostInfo);
      }

      note(rule, role, mode, asked, got, fields = {}) {
        const text = fill(RULES.change_rules[rule].note, { role, mode, asked, got, ...fields });
        this.changes.push({ role, mode, asked, got, rule, note: text });
      }

      readOne(name, value) {
        const [hexed, unread] = readSeed(value, name);
        if (unread) this.unread.push(name);
        if (value !== null && value !== undefined && value !== '' && hexed === null) {
          for (const m of MODE_NAMES) {
            const leader = { accent: this.v[m].accent, background: this.v[m].page, foreground: this.v[m].ink }[name];
            this.note(PROC.seeds.unset, name, m, value.trim(), leader, { seed: name });
          }
        }
        return hexed;
      }

      readSeeds(given, hostInfo = null) {
        const seeds = given || {};
        const hostFlags = hostInfo?.host || {};
        const flattened = hostInfo?.flattened || [];
        const noteFlat = (role, mode) => {
          for (const item of flattened)
            if (item.role === role && (item.mode === null || item.mode === mode))
              this.note('seed_flattened', role, mode, item.asked, item.got, { seed: role });
        };
        for (const name of Object.keys(seeds))
          if (!['accent', 'background', 'foreground'].includes(name))
            throw new Error(`unknown seed "${name}"; the seeds are accent, background and foreground`);
        this.seed.accent = this.readOne('accent', seeds.accent);
        this.seedsOut.accent = this.seed.accent;
        if (this.seed.accent !== null && hostFlags.accent) {
          this.hostSeed.accent = true;
          for (const m of MODE_NAMES) noteFlat('accent', m);
        }
        for (const [name, leader] of [
          ['background', 'page'],
          ['foreground', 'ink'],
        ]) {
          const value = seeds[name];
          if (isObject(value)) {
            if (Object.keys(value).some((k) => !MODE_NAMES.includes(k)))
              throw new Error(`seeds.${name} holds light and dark only`);
            for (const m of MODE_NAMES)
              if (value[m] !== null && value[m] !== undefined) {
                this.seed[name][m] = this.readOne(name, value[m]);
                if (this.seed[name][m] !== null && hostFlags[name]?.[m]) {
                  this.hostSeed[name][m] = true;
                  noteFlat(name, m);
                }
              }
            this.seedsOut[name] = { light: this.seed[name].light, dark: this.seed[name].dark };
            continue;
          }
          const hexed = this.readOne(name, value);
          this.seedsOut[name] = hexed;
          if (hexed === null) continue;
          const mine = name === 'background' ? modeOfBackground(hexed, this.persona) : modeOfForeground(hexed);
          const other = mine === 'light' ? 'dark' : 'light';
          this.seed[name][mine] = hexed;
          if (hostFlags[name]) {
            this.hostSeed[name][mine] = true;
            noteFlat(name, mine);
          }
          const tinted = otherModeSeed(hexed, this.v[other][leader]);
          if (tinted) {
            this.seed[name][other] = tinted;
            if (hostFlags[name]) this.hostSeed[name][other] = true;
            this.note(PROC.seeds.one_colour, leader, other, hexed, tinted, { seed: name });
          }
        }
        for (const m of MODE_NAMES) this.askedAccent[m] = this.seed.accent || this.v[m].accent;
      }

      activeSeeds(mode) {
        return {
          accent: this.seed.accent !== null,
          background: this.seed.background[mode] !== null,
          foreground: this.seed.foreground[mode] !== null,
        };
      }

      isHostRow(row, mode) {
        const families = row.follows ?? [row.family];
        return families.some((f) =>
          f === 'accent'
            ? this.hostSeed.accent
            : f === 'background' || f === 'foreground'
              ? this.hostSeed[f][mode]
              : false,
        );
      }

      active(row, mode) {
        if ('when' in row && !RULES.colour_defaults[row.when]) return false;
        const act = this.activeSeeds(mode);
        return (row.follows ?? [row.family]).some((f) => f in act && act[f]);
      }

      start(row, mode, page) {
        const src = row.from;
        if (!this.active(row, mode) && own(this.origin[mode], row.role)) return this.v[mode][row.role];
        if (isObject(src)) {
          const got =
            src.seed === 'accent'
              ? this.askedAccent[mode]
              : src.seed === 'background'
                ? page
                : this.seed.foreground[mode];
          return got || this.v[mode][row.role];
        }
        return src ? this.v[mode][src] : this.v[mode][row.role];
      }

      candidates(row, mode) {
        const v = this.v[mode];
        return perMode(row.pick, mode).map((c) =>
          c === 'light.ink' ? this.v.light.ink : c.startsWith('#') ? c : v[c],
        );
      }

      moved(rule, role, mode, asked, got, fields, fromHost = false) {
        if (asked !== got) {
          this.note(rule, role, mode, asked, got, fields);
          this.derived[mode].add(role);
          if (fromHost) this.hostDerived[mode].add(role);
        }
      }

      holds(role, trial, env, mode, groups) {
        const e = { ...env, [role]: trial };
        for (const dep of RULES.roles) {
          if (dep.mix && dep.from === role && (this.active(dep, mode) || trial !== this.origin[mode][role]))
            e[dep.role] = mixOf(dep.mix, role, e, mode);
        }
        for (const g of groups) {
          const rows = this.rowsByGroup[g];
          if (rows.some((r) => r.role === role && evaluate(r, e, mode) < r.need)) return false;
          const others = new Set(rows.filter((r) => r.role !== role && r.on === role).map((r) => r.role));
          for (const other of others) {
            const pick = ROWS[other] && 'pick' in ROWS[other] ? ROWS[other] : null;
            const mine = rows.filter((r) => r.role === other);
            if (
              pick &&
              !this.candidates(pick, mode).some((c) =>
                mine.every((r) => evaluate(r, { ...e, [other]: c }, mode) >= r.need),
              )
            )
              return false;
          }
        }
        return true;
      }

      ensure(row, mode, start) {
        const groups = perMode(row.ensure, mode);
        return search(start, (h) => this.holds(row.role, h, this.v[mode], mode, groups), mode === 'dark');
      }

      runMode(mode) {
        const mark = this.changes.length;
        const ink = ROWS.ink;
        for (let pass = 0; pass < PROC.ink.settle_passes; pass++) {
          this.changes.length = mark;
          for (const k of Object.keys(this.v[mode])) delete this.v[mode][k];
          Object.assign(this.v[mode], this.origin[mode]);
          this.derived[mode].clear();
          this.hostDerived[mode].clear();
          this.deriveOnce(mode);
          const v = this.v[mode];
          const groups = [...ink.ensure, ...ink.settle];
          if (this.holds('ink', v.ink, v, mode, groups)) return;
          this.inkOverride[mode] = search(v.ink, (h) => this.holds('ink', h, v, mode, groups), mode === 'dark');
        }
      }

      deriveOnce(mode) {
        const v = this.v[mode];
        let page = this.seed.background[mode];
        if (page) {
          const [got, was] = limitPage(page, mode, this.persona);
          if (was) this.note(PROC.background.moved, 'page', mode, page, got);
          page = got;
        }
        let paletteDone = false;
        const lead = this.lead();
        for (const row of RULES.roles) {
          const role = row.role;
          if ('rgba' in row) this.rowRgba(row, mode);
          else if ('pick' in row && !('ensure' in row)) {
            if (this.active(row, mode)) {
              v[role] = this.candidates(row, mode)[0];
              this.derived[mode].add(role);
              if (this.isHostRow(row, mode)) this.hostDerived[mode].add(role);
            }
          } else if ('pick' in row) this.rowPick(row, mode);
          else if ('mix' in row) {
            if (this.active(row, mode) || v[row.from] !== this.origin[mode][row.from]) {
              v[role] = mixOf(row.mix, row.from, v, mode);
              this.derived[mode].add(role);
              if (this.isHostRow(row, mode) || this.hostDerived[mode].has(row.from)) this.hostDerived[mode].add(role);
            }
          } else if (row.family === 'chart' && 'ensure' in row && role !== lead.role) {
            if (!paletteDone) {
              this.palette(mode);
              paletteDone = true;
            }
          } else {
            this.rowSet(row, mode, page);
            if (role === lead.role) this.nearStatus(mode);
          }
        }
      }

      lead() {
        return RULES.roles.find((r) => r.family === 'chart' && 'ensure' in r);
      }

      rowSet(row, mode, page) {
        const role = row.role;
        const v = this.v[mode];
        let base = this.start(row, mode, page);
        let asked = base;
        if (role === 'ink' && mode in this.inkOverride) base = this.inkOverride[mode];
        const fromHost = this.isHostRow(row, mode);
        if (this.active(row, mode)) {
          this.derived[mode].add(role);
          if (fromHost) this.hostDerived[mode].add(role);
          if ('set' in row) {
            base = applySet(row, base, this.persona, mode);
            asked = base;
          }
        }
        if (row.band && this.active(row, mode)) {
          const [lo, hi] = GUARDS.chart.band[mode];
          const [L, C, H] = oklch(base);
          base = fromLch(Math.min(hi, Math.max(lo, L)), C, H);
        }
        let got;
        if ('ensure' in row) {
          v[role] = base;
          got = this.ensure(row, mode, base);
        } else got = base;
        v[role] = got;
        const movedFromHost =
          fromHost ||
          ((row.family === 'status' || row.family === 'chart' || row.family === 'foreground') &&
            this.hostSeed.background[mode]);
        if ('rule' in row) this.moved(perMode(row.rule, mode), role, mode, asked, got, undefined, movedFromHost);
      }

      rowPick(row, mode) {
        const role = row.role;
        const v = this.v[mode];
        const fresh = !own(this.origin[mode], role);
        const active = this.active(row, mode) || fresh;
        const groups = perMode(row.ensure, mode);
        const cands = this.candidates(row, mode);
        const asked = active ? cands[0] : v[role];
        if (!active && this.holds(role, v[role], v, mode, groups)) return;
        let got = cands.find((c) => this.holds(role, c, v, mode, groups));
        if (got === undefined && row.turn) got = this.turn(row, row.turn, cands, mode);
        else if (got === undefined) got = cands[cands.length - 1];
        v[role] = got;
        const fromHost = this.isHostRow(row, mode);
        if (active) {
          this.derived[mode].add(role);
          if (fromHost) this.hostDerived[mode].add(role);
        }
        if ('rule' in row)
          this.moved(row.rule, role, mode, asked, got, undefined, fromHost || this.hostSeed.background[mode]);
      }

      turn(row, turn, cands, mode) {
        const v = this.v[mode];
        const hover = PROC.hover;
        const rest = perMode(row.ensure, mode).filter((g) => !turn.ensure.includes(g));
        const label = cands.find((c) => this.holds(row.role, c, v, mode, rest));
        const usual = mixOf('solid_hover', 'accent', v, mode);
        const darkLabel = luminanceOf(label) < hover.dark_label_below;
        const direction = darkLabel ? hover.dark_label_direction : hover.light_label_direction;
        const [L, C, H] = oklch(v.accent);
        const env = { ...v, [row.role]: label };
        const turned = search(
          fromLch(L + direction * hover.step, C, H),
          (h) =>
            turn.ensure.every((g) =>
              this.rowsByGroup[g].every((r) => evaluate(r, { ...env, [turn.role]: h }, mode) >= r.need),
            ),
          direction > 0,
        );
        v[turn.role] = turned;
        this.note(turn.rule, turn.role, mode, usual, turned);
        this.derived[mode].add(turn.role);
        if (this.hostSeed.accent || this.hostSeed.background[mode]) this.hostDerived[mode].add(turn.role);
        return label;
      }

      rowRgba(row, mode) {
        if (!this.active(row, mode)) return;
        const rgb = row.rgba[mode];
        const text = restain(this.origin[mode][row.role], rgb === 'ink' ? this.v[mode].ink : rgb);
        if (text === null) return;
        this.v[mode][row.role] = text;
        this.derived[mode].add(row.role);
        if (this.isHostRow(row, mode)) this.hostDerived[mode].add(row.role);
      }

      palette(mode) {
        const v = this.v[mode];
        const lead = this.lead();
        const slots = RULES.roles.filter((r) => r.family === 'chart' && 'ensure' in r && r !== lead);
        const names = slots.map((r) => r.role);
        const led = this.active(lead, mode);
        const grey = led && oklch(this.askedAccent[mode])[1] < GUARDS.grey_accent.chroma_under;
        if (led) {
          const [lo, hi] = GUARDS.chart.band[mode];
          const c1 = v[lead.role];
          const chart = GUARDS.chart;
          const pool = names.map((n) => this.origin[mode][n]);
          const kept = [];
          if (grey) {
            let comp = fromLch(
              lo + (hi - lo) * chart.companion.band_share,
              chart.companion.chroma,
              chart.companion.hue,
            );
            comp = this.ensure(slots[0], mode, comp);
            kept.push(comp);
            this.note(PROC.series.companion, names[0], mode, this.origin[mode][names[0]], comp);
            this.derived[mode].add(names[0]);
            if (this.hostSeed.accent) this.hostDerived[mode].add(names[0]);
          }
          const apart = (a, b) =>
            delta(a, b) >= chart.apart_normal &&
            Math.min(...Object.keys(NUM.machado).map((k) => delta(a, b, k))) >= chart.apart_colour_blind;
          const back = [];
          for (const c of [...pool]) {
            if (kept.length >= chart.apart_slots) break;
            pool.splice(pool.indexOf(c), 1);
            if (apart(c, c1) && kept.every((k) => apart(c, k))) kept.push(c);
            else back.push(c);
          }
          const order = [...kept, ...pool, ...back];
          order.slice(0, names.length).forEach((c, i) => {
            v[names[i]] = c;
            if (own(this.origin[mode], names[i]) && c !== this.origin[mode][names[i]]) {
              this.derived[mode].add(names[i]);
              if (this.hostSeed.accent) this.hostDerived[mode].add(names[i]);
            }
          });
          for (const c of back) {
            const slot = names[names.map((n) => this.origin[mode][n]).indexOf(c)];
            this.note(PROC.series.skipped, slot, mode, c, v[slot]);
          }
        }
        for (const row of slots) {
          const start = v[row.role];
          const got = this.ensure(row, mode, start);
          v[row.role] = got;
          this.moved(
            row.rule,
            row.role,
            mode,
            start,
            got,
            undefined,
            this.hostSeed.background[mode] || (led && this.hostSeed.accent),
          );
        }
      }

      nearStatus(mode) {
        if (!this.active(this.lead(), mode)) return;
        const asked = this.askedAccent[mode];
        const hue = oklch(asked)[2];
        if (oklch(asked)[1] < GUARDS.grey_accent.chroma_under) return;
        for (const tone of PAIRS.sets.tone) {
          const th = oklch(this.origin[mode][tone])[2];
          if (hueGap(hue, th) < GUARDS.status_angle)
            this.note(PROC.series.accent_near_tone, 'accent', mode, asked, asked, {
              hue: hue.toFixed(0),
              tone,
              tone_hue: th.toFixed(0),
            });
        }
      }
    }

    function deriveFull(persona, seeds = null, pinned = null, hostInfo = null) {
      const run = new Run(persona, seeds, pinned, hostInfo);
      const seeded =
        run.seed.accent !== null ||
        ['background', 'foreground'].some((n) => MODE_NAMES.some((m) => run.seed[n][m] !== null));
      if (seeded) for (const m of MODE_NAMES) run.runMode(m);
      const out = {
        persona: persona.name ?? null,
        rules: RULES.rules,
        seeds: run.seedsOut,
        unread: [...new Set(run.unread)].sort(),
      };
      const sources = {};
      for (const m of MODE_NAMES) {
        const pinnedHere = run.pinned[m] || {};
        let v = seeded ? run.v[m] : { ...run.v[m] };
        Object.assign(v, pinnedHere);
        if (own(pinnedHere, 'accent'))
          for (const role of Object.keys(PROC.followers)) if (!own(pinnedHere, role)) v[role] = pinnedHere.accent;
        if (!seeded) v = withFollowers(v);
        out[m] = Object.fromEntries(Object.entries(v).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0)));
        sources[m] = {};
        for (const role of Object.keys(v))
          sources[m][role] = own(pinnedHere, role)
            ? 'pinned'
            : run.hostDerived[m].has(role)
              ? 'host'
              : run.derived[m].has(role)
                ? 'derived'
                : 'persona';
      }
      out.checks = MODE_NAMES.flatMap((m) => checksOf(out[m], m, sources[m]));
      out.changes = run.changes;
      const shown = {
        light: {
          accent: run.seed.accent,
          background: run.seed.background.light,
          foreground: run.seed.foreground.light,
        },
        dark: { accent: run.seed.accent, background: run.seed.background.dark, foreground: run.seed.foreground.dark },
      };
      return { out, shown };
    }
    const derive = (persona, seeds, pinned, hostInfo) => deriveFull(persona, seeds, pinned, hostInfo).out;
    const accentFollowers = RULES.roles
      .filter(
        (r) =>
          (r.family === 'accent' && r.role !== 'accent') ||
          (r.follows ?? []).join() === 'accent' ||
          (Array.isArray(r.pick) && r.pick.includes('accent-soft')),
      )
      .flatMap((r) => [r.role, ...(r.turn ? [r.turn.role] : [])]);
    return { derive, deriveFull, parseSeed: readSeed, cut, accentFollowers, toHex };
  }

  function splitVarSeed(value) {
    if (typeof value !== 'string') return null;
    const t = value.trim();
    if (!/^var\(/i.test(t) || !t.endsWith(')')) return null;
    const inner = t.slice(4, -1);
    const comma = inner.indexOf(',');
    const varName = (comma >= 0 ? inner.slice(0, comma) : inner).trim();
    const fallback = comma >= 0 ? inner.slice(comma + 1).trim() : '';
    return { varName, fallback: fallback || null, raw: t };
  }

  function hasVarSeeds(read) {
    if (!read?.seeds) return false;
    for (const value of Object.values(read.seeds)) {
      if (typeof value === 'string' && splitVarSeed(value)) return true;
      if (isObject(value) && Object.values(value).some((v) => typeof v === 'string' && splitVarSeed(v))) return true;
    }
    return false;
  }

  function checkSeeds(seeds, note) {
    if (leftOut(seeds)) return null;
    if (!isObject(seeds)) {
      note(`seeds must be an object: ${oneOf(SEED_NAMES)} -> a colour; it is left out.`);
      return null;
    }
    const engine = engineOf();
    const out = {};
    const colour = (value, label) => {
      if (leftOut(value)) return undefined;
      try {
        if (typeof value !== 'string' || !SEED_PATTERN.test(value.trim()))
          throw new Error(
            'must be a hex such as #0b7c7b, rgb(11, 124, 123) without alpha, or a host variable such as var(--brand, #0b7c7b)',
          );
        const v = splitVarSeed(value);
        if (v && v.varName.startsWith('--stagemap-')) {
          note(`${label} points at stagemap token ${v.varName}; it is left out.`);
          return undefined;
        }
        engine.parseSeed(value, label);
        return value.trim();
      } catch (e) {
        note(`${label}: ${e.message}; it is left out.`);
        return undefined;
      }
    };
    for (const [name, value] of Object.entries(seeds)) {
      if (leftOut(value)) continue;
      if (!SEED_NAMES.includes(name)) {
        note(`seeds.${name} is not a seed (${oneOf(SEED_NAMES)}); it is left out.`);
      } else if (isObject(value)) {
        if (name === 'accent') {
          note('seeds.accent is one colour for both modes (its dark twin is worked out); it is left out.');
          continue;
        }
        const both = {};
        for (const [mode, c] of Object.entries(value)) {
          if (mode !== 'light' && mode !== 'dark')
            note(`seeds.${name}.${mode} is not a mode (light, dark); it is left out.`);
          else both[mode] = colour(c, `seeds.${name}.${mode}`);
        }
        const kept = Object.fromEntries(Object.entries(both).filter(([, c]) => c !== undefined));
        if (Object.keys(kept).length) out[name] = kept;
      } else {
        const c = colour(value, `seeds.${name}`);
        if (c !== undefined) out[name] = c;
      }
    }
    return Object.keys(out).length ? out : null;
  }

  function pointsAtstagemap(at, varName) {
    if (varName.startsWith('--stagemap-')) return varName;
    const doc = at?.ownerDocument;
    const view = doc?.defaultView;
    const matchesEl = (el, sel) => {
      try {
        return Boolean(sel && el.matches?.(sel));
      } catch {
        return false;
      }
    };
    const isstagemapSheet = (sheet) => {
      const node = sheet.ownerNode;
      return Boolean(node?.attributes && [...node.attributes].some((a) => a.name.startsWith('data-stagemap-')));
    };
    const walkRules = (rules, el, prop, found) => {
      for (const rule of rules) {
        if (rule.type === 1) {
          const val = rule.style?.getPropertyValue(prop).trim();
          if (val && matchesEl(el, rule.selectorText)) found.raw = val;
          if (rule.cssRules?.length) walkRules(rule.cssRules, el, prop, found);
        } else if (rule.type === 4) {
          if (view?.matchMedia?.(rule.conditionText).matches) walkRules(rule.cssRules, el, prop, found);
        } else if (rule.type === 12) {
          if (view?.CSS?.supports?.(rule.conditionText)) walkRules(rule.cssRules, el, prop, found);
        } else if (rule.cssRules?.length) {
          walkRules(rule.cssRules, el, prop, found);
        }
      }
    };
    const rawDeclared = (prop) => {
      for (let el = at; el; el = upFrom(el)) {
        const inline = el.style?.getPropertyValue(prop).trim();
        if (inline) return inline;
        if (!doc) continue;
        const found = { raw: '' };
        const sheets = [...doc.styleSheets, ...(doc.adoptedStyleSheets ?? [])];
        const rootNode = at?.getRootNode?.();
        if (rootNode && rootNode !== doc && rootNode.adoptedStyleSheets) sheets.push(...rootNode.adoptedStyleSheets);
        for (const sheet of sheets) {
          if (sheet.disabled || isstagemapSheet(sheet)) continue;
          let rules;
          try {
            rules = sheet.cssRules;
          } catch {
            continue;
          }
          walkRules(rules, el, prop, found);
        }
        if (found.raw) return found.raw;
      }
      return '';
    };
    const visited = new Set([varName]);
    const queue = [varName];
    while (queue.length) {
      const prop = queue.shift();
      const raw = rawDeclared(prop);
      if (!raw) continue;
      for (const m of raw.matchAll(/var\(\s*(--[A-Za-z0-9_-]+)/g)) {
        const ref = m[1];
        if (ref.startsWith('--stagemap-')) return ref;
        if (!visited.has(ref)) {
          visited.add(ref);
          queue.push(ref);
        }
      }
    }
    return null;
  }

  function probeHostVar(at, varName) {
    const doc = at?.ownerDocument;
    const view = doc?.defaultView;
    if (!view || !at.isConnected) return { state: 'undefined' };
    const wrap = doc.createElement('span');
    wrap.dataset.stagemapProbe = '';
    wrap.hidden = true;
    wrap.style.color = 'rgb(1, 2, 3)';
    const sp = doc.createElement('span');
    sp.style.color = `var(${varName})`;
    wrap.append(sp);
    at.append(wrap);
    try {
      const cs = view.getComputedStyle(sp);
      const raw = cs.getPropertyValue(varName).trim();
      if (!raw) return { state: 'undefined' };
      const col = cs.color;
      if (col === 'rgb(1, 2, 3)') {
        wrap.style.color = 'rgb(4, 5, 6)';
        if (cs.color === 'rgb(4, 5, 6)') return { state: 'invalid', raw };
      }
      return { state: 'defined', col, raw };
    } finally {
      wrap.remove();
    }
  }

  function resolveHostSeeds(seeds, at, where, { quiet = false } = {}) {
    const engine = engineOf();
    const out = {};
    const host = { accent: false, background: {}, foreground: {} };
    const flattened = [];
    const warnings = [];
    const sig = { connected: Boolean(at?.isConnected), entries: {} };
    let anyFromHost = false;
    let anyRefused = false;
    const warn = (text) => {
      warnings.push(text);
      if (!quiet) console.warn(`stagemap ${where}: ${text}`);
    };
    const resolveOne = (name, modeKey, value) => {
      const label = modeKey ? `seeds.${name}.${modeKey}` : `seeds.${name}`;
      const sigKey = modeKey ? `${name}.${modeKey}` : name;
      const v = splitVarSeed(value);
      if (!v) {
        sig.entries[sigKey] = `lit:${value}`;
        return { value, fromHost: false };
      }
      const stagemapRef = pointsAtstagemap(at, v.varName);
      if (stagemapRef) {
        anyRefused = true;
        sig.entries[sigKey] = `refused:${stagemapRef}:${v.raw}`;
        warn(`${label} (${v.varName}) points at stagemap token ${stagemapRef}; it is left out.`);
        return { value: v.raw, fromHost: false };
      }
      const probed = probeHostVar(at, v.varName);
      if (probed.state === 'undefined') {
        sig.entries[sigKey] = `var:${v.raw}`;
        return { value: v.raw, fromHost: false };
      }
      if (probed.state === 'invalid') {
        anyRefused = true;
        sig.entries[sigKey] = `invalid:${probed.raw}:${v.raw}`;
        warn(`${label} (${v.varName} = ${quoted(probed.raw)}) is not a colour; it is left out.`);
        return { value: v.raw, fromHost: false };
      }
      const parsed = parseColour(probed.col);
      if (!parsed || parsed.alpha <= 0) {
        sig.entries[sigKey] = `clear:${v.raw}`;
        return { value: v.raw, fromHost: false };
      }
      let gotHex;
      if (parsed.alpha < 1) {
        const flatRgb = mix(parsed.rgb, hostBackground(at), parsed.alpha);
        gotHex = engine.toHex(flatRgb);
        flattened.push({ role: name, mode: modeKey, asked: v.raw, got: gotHex });
      } else {
        gotHex = engine.toHex(parsed.rgb);
      }
      anyFromHost = true;
      sig.entries[sigKey] = `host:${gotHex}`;
      return { value: gotHex, fromHost: true };
    };

    for (const [name, value] of Object.entries(seeds || {})) {
      if (isObject(value)) {
        const both = {};
        for (const [m, c] of Object.entries(value)) {
          const got = resolveOne(name, m, c);
          if (got.value !== undefined) both[m] = got.value;
          if (got.fromHost) host[name][m] = true;
        }
        if (Object.keys(both).length) out[name] = both;
      } else {
        const got = resolveOne(name, null, value);
        if (got.value !== undefined) out[name] = got.value;
        if (got.fromHost) host[name] = true;
      }
    }
    return {
      seeds: out,
      hostInfo: { host, flattened },
      anyFromHost,
      anyRefused,
      hasAlpha: flattened.length > 0,
      warnings,
      signature: stableJson(sig),
    };
  }

  function watchedVarNames(read, partReads = []) {
    const names = new Set();
    const collect = (seeds) => {
      if (!seeds) return;
      for (const value of Object.values(seeds)) {
        if (typeof value === 'string') {
          const v = splitVarSeed(value);
          if (v) names.add(v.varName);
        } else if (isObject(value)) {
          for (const sub of Object.values(value)) {
            const v = splitVarSeed(sub);
            if (v) names.add(v.varName);
          }
        }
      }
    };
    collect(read?.seeds);
    for (const p of partReads) collect(p.read?.seeds);
    return [...names].sort();
  }

  function seedSignature(at, read, partReads = []) {
    const parts = [];
    let hasAlpha = false;
    if (hasVarSeeds(read)) {
      const r = resolveHostSeeds(read.seeds, at, 'look', { quiet: true });
      parts.push(`main:${r.signature}`);
      if (r.hasAlpha) hasAlpha = true;
    }
    for (const p of partReads)
      if (hasVarSeeds(p.read)) {
        const r = resolveHostSeeds(p.read.seeds, at, 'look', { quiet: true });
        parts.push(`part:${p.name}:${r.signature}`);
        if (r.hasAlpha) hasAlpha = true;
      }
    return { sig: parts.join('|'), hasAlpha };
  }

  function makeSeedTracker(at, read, partReads = [], initial = null) {
    const names = watchedVarNames(read, partReads);
    let hasAlpha = Boolean(initial?.hasAlpha);
    const rawKey = (el) => {
      const view = el?.ownerDocument?.defaultView;
      if (!view || !el.isConnected) return 'disconnected';
      const cs = view.getComputedStyle(el);
      const vals = names.map((n) => cs.getPropertyValue(n).trim()).join('\0');
      return hasAlpha ? `${vals}\0bg:${hex(hostBackground(el))}` : vals;
    };
    let prevSig = initial?.sig ?? null;
    if (prevSig === null) {
      const init = seedSignature(at, read, partReads);
      prevSig = init.sig;
      hasAlpha = init.hasAlpha;
    }
    let prevRaw = rawKey(at);
    return {
      changed(el) {
        const nextRaw = rawKey(el);
        if (nextRaw === prevRaw) return false;
        prevRaw = nextRaw;
        const next = seedSignature(el, read, partReads);
        hasAlpha = next.hasAlpha;
        if (next.sig === prevSig) return false;
        prevSig = next.sig;
        return true;
      },
    };
  }

  const FOLLOWER_ROLES = ['accent-ink', 'accent-line'];
  function ownLookSheets(at) {
    const doc = at.ownerDocument;
    const found =
      at === doc.body || at === doc.documentElement
        ? [...doc.querySelectorAll('style[data-stagemap-look-page], style[data-stagemap-look-built]')]
        : [...at.querySelectorAll(':scope > style[data-stagemap-root-look-css]')];
    const mount = at.getAttribute?.('data-stagemap-look');
    if (mount) found.push(...doc.querySelectorAll(`style[data-stagemap-look-css="${mount}"]`));
    return found.map((style) => style.sheet).filter(Boolean);
  }
  function applyPalette(persona, read) {
    const softShare = colourRules().pairs.mixes.soft_fill.share;
    const lightInk = parseColour(persona.light.ink)?.rgb;
    for (const mode of ['light', 'dark']) {
      const entries = Object.entries(read[mode]);
      if (!entries.length) continue;
      const v = persona[mode];
      for (const [role, value] of entries) {
        const c = parseColour(value);
        if (c && c.alpha === 1 && role in v) v[role] = hex(c.rgb);
      }
      if (!read.palette) continue;
      const accent = parseColour(v.accent);
      const sidebar = parseColour(v.sidebar);
      if (!accent) continue;
      if (sidebar) v['accent-soft'] = hex(mix(accent.rgb, sidebar.rgb, softShare[mode]));
      for (const follower of ['focus', 'cat-1', 'seq-hi']) v[follower] = v.accent;
      if (v['accent-soft']) v['seq-lo'] = v['accent-soft'];
      v['on-accent'] = wordsOn(accent.rgb, lightInk);
    }
  }

  function applyAccentFollowers(roles, pinned, hasAccentSeed, { skipCssAccent = false } = {}) {
    if (skipCssAccent) return;
    const softShare = colourRules().pairs.mixes.soft_fill.share;
    const lightInk = parseColour(roles.light.ink)?.rgb;
    for (const mode of ['light', 'dark']) {
      const other = mode === 'light' ? 'dark' : 'light';
      const v = roles[mode];
      const pin = pinned[mode];
      const otherPin = pinned[other];
      const autoAccent = !hasAccentSeed && !('accent' in pin) && 'accent' in otherPin;
      if (autoAccent) {
        const a = parseColour(otherPin.accent);
        const p = parseColour(v.page);
        if (a && p) v.accent = hex(fitBoth(a.rgb, p.rgb));
      }
      if ('accent' in pin || autoAccent) {
        for (const follower of ['accent-ink', 'accent-line', 'focus', 'cat-1', 'seq-hi'])
          if (!(follower in pin)) v[follower] = v.accent;
        if (!('accent-soft' in pin)) {
          const a = parseColour(v.accent);
          const s = parseColour(v.sidebar);
          if (a && s) v['accent-soft'] = hex(mix(a.rgb, s.rgb, softShare[mode]));
        }
        if (!('seq-lo' in pin) && v['accent-soft']) v['seq-lo'] = v['accent-soft'];
        if (!('on-accent' in pin)) {
          const a = parseColour(v.accent);
          if (a) v['on-accent'] = wordsOn(a.rgb, lightInk);
        }
        if ('button-solid-hover-bg' in v && !('button-solid-hover-bg' in pin)) delete v['button-solid-hover-bg'];
      }
    }
  }

  function personaAt(at, read, where) {
    const doc = at.ownerDocument;
    const hold = doc.createElement('style');
    hold.dataset.stagemapLookHold = '';
    hold.textContent = '*, *::before, *::after { transition: none !important; }';
    doc.head.append(hold);
    const off = ownLookSheets(at).filter((sheet) => !sheet.disabled);
    for (const sheet of off) sheet.disabled = true;
    const base = { name: null, light: {}, dark: {} };
    let missing = null;
    try {
      for (const mode of ['light', 'dark']) {
        const probe = doc.createElement('span');
        probe.dataset.stagemapProbe = '';
        probe.setAttribute('data-stagemap-mode', mode);
        probe.hidden = true;
        at.append(probe);
        const css = getComputedStyle(probe);
        for (const role of MODE_ROLES) {
          if (FOLLOWER_ROLES.includes(role)) continue;
          const text = css.getPropertyValue(`--stagemap-${role}`).trim();
          if (role === 'backdrop' || /^shadow-\d$/.test(role)) {
            if (text) base[mode][role] = text;
            else missing ??= role;
            continue;
          }
          const c = parseColour(text);
          if (c && c.alpha === 1) base[mode][role] = hex(c.rgb);
          else missing ??= role;
        }
        probe.remove();
      }
    } finally {
      for (const sheet of off) sheet.disabled = false;
      getComputedStyle(at).getPropertyValue('--stagemap-accent');
      hold.remove();
    }
    if (missing) {
      console.warn(
        `stagemap ${where}: seeds need the theme's colours (kit/tokens.css) on the page, and --stagemap-${missing} is not an opaque colour here; the seeds are left out.`,
      );
      return null;
    }
    const persona = { name: null, light: { ...base.light }, dark: { ...base.dark } };
    applyPalette(persona, read);
    return { base, persona };
  }

  function pinnedColours(read) {
    const pinned = { light: {}, dark: {} };
    for (const mode of ['light', 'dark']) {
      const pins = { ...read.both, ...read.given[mode] };
      for (const [role, value] of Object.entries(pins)) {
        const c = parseColour(value);
        if (c && c.alpha === 1 && MODE_ROLES.includes(role) && !/^shadow-\d$/.test(role) && role !== 'backdrop')
          pinned[mode][role] = hex(c.rgb);
      }
    }
    return pinned;
  }

  function stableJson(value) {
    if (isObject(value)) {
      const sorted = {};
      for (const k of Object.keys(value).sort()) sorted[k] = value[k];
      return `{${Object.keys(sorted)
        .map((k) => `${JSON.stringify(k)}:${stableJson(sorted[k])}`)
        .join(',')}}`;
    }
    return JSON.stringify(value);
  }

  function readBuiltLook(doc) {
    const raw = doc.querySelector('style[data-stagemap-look-built]')?.getAttribute('data-stagemap-look-built');
    if (!raw) return null;
    try {
      const parsed = JSON.parse(raw);
      return isObject(parsed) ? parsed : null;
    } catch {
      return null;
    }
  }

  function matchBuiltLook(doc, html, read) {
    const built = readBuiltLook(doc);
    if (!built || !read.seeds || 'accent' in read.css) return null;
    if (built.rules !== colourRules().rules) return null;
    if (built.theme !== (html.getAttribute('data-stagemap-theme') || 'default')) return null;
    if ((built.palette ?? null) !== (read.palette ?? null)) return null;
    if (stableJson(built.seeds) !== stableJson(read.seeds)) return null;
    if (stableJson(built.pinned) !== stableJson(pinnedColours(read))) return null;
    if (!(isObject(built.shown) && isObject(built.shown.light) && isObject(built.shown.dark))) return null;
    if (hasVarSeeds(read) || (Array.isArray(built.unread) && built.unread.length > 0)) {
      const probed = resolveHostSeeds(read.seeds, doc.body ?? html, 'look', { quiet: true });
      if (probed.anyFromHost) return null;
      for (const text of probed.warnings) console.warn(`stagemap look: ${text}`);
      return { ...built, seedState: { sig: `main:${probed.signature}`, hasAlpha: probed.hasAlpha } };
    }
    return built;
  }

  function restOfBuiltLook(read) {
    const pinned = pinnedColours(read);
    const keep = (map, mode) =>
      Object.fromEntries(Object.entries(map).filter(([r]) => !Object.hasOwn(pinned[mode], r)));
    return {
      theme: read.theme,
      palette: null,
      light: {},
      dark: {},
      css: read.css,
      base: read.base,
      mode: read.mode,
      given: { light: keep(read.given.light, 'light'), dark: keep(read.given.dark, 'dark') },
      both: Object.fromEntries(
        Object.entries(read.both).filter(([r]) => !Object.hasOwn(pinned.light, r) && !Object.hasOwn(pinned.dark, r)),
      ),
      seeds: null,
    };
  }

  function lookDerive(read, at, where) {
    const readPersona = personaAt(at, read, where);
    if (!readPersona) return null;
    const { base, persona } = readPersona;
    const pinned = pinnedColours(read);
    const resolved = read.seeds ? resolveHostSeeds(read.seeds, at, where) : null;
    let full;
    try {
      full = engineOf().deriveFull(persona, resolved ? resolved.seeds : {}, pinned, resolved?.hostInfo ?? null);
    } catch (e) {
      console.warn(`stagemap ${where}: ${e.message}; the seeds are left out.`);
      return null;
    }
    const skipCssAccent = 'accent' in read.css;
    applyAccentFollowers(full.out, pinned, Boolean(full.shown.light.accent), { skipCssAccent });
    const roles = { light: {}, dark: {} };
    const followers = engineOf().accentFollowers;
    for (const mode of ['light', 'dark']) {
      const nonOpaqueAccent =
        skipCssAccent || (!('accent' in pinned[mode]) && Boolean(read.both.accent || read.given[mode].accent));
      for (const [role, value] of Object.entries(full.out[mode])) {
        if (role in pinned[mode] || role in read.css) continue;
        if (nonOpaqueAccent && followers.includes(role)) continue;
        if (base[mode][role] !== value || role in read[mode]) roles[mode][role] = value;
      }
    }
    const seedState = resolved ? { sig: `main:${resolved.signature}`, hasAlpha: resolved.hasAlpha } : null;
    return { roles, seedState, ...full };
  }

  function derive(given, root) {
    if (root !== undefined && root !== null && root?.nodeType !== 1) {
      console.warn('stagemap.derive: root must be an element (or left out for the page); nothing is derived.');
      return null;
    }
    let at = root ?? document.body ?? document.documentElement;
    let wanted = given;
    if (wanted === null || wanted === undefined) {
      const scope = at.closest?.(`[${ROOT_ATTR}]`);
      const held = scope && rootLooks.get(scope)?.given;
      if (held) at = scope;
      else at = at.ownerDocument.body ?? at.ownerDocument.documentElement;
      wanted = held ?? pageLook;
    }
    if (!(wanted === null || wanted === undefined || typeof wanted === 'string' || isObject(wanted))) {
      console.warn(
        'stagemap.derive: give a look (a palette or theme name, or an object), or null; nothing is derived.',
      );
      return null;
    }
    let only = wanted;
    if (isObject(wanted) && ('parts' in wanted || 'decor' in wanted)) {
      only = { ...wanted };
      delete only.parts;
      delete only.decor;
    }
    const read = readLook(only ?? null, [], 'derive', { doc: at.ownerDocument });
    const got = lookDerive(read, at, 'derive');
    if (!got) return null;
    const say = (list) => list.map(({ label, ...rest }) => rest);
    return {
      persona: null,
      rules: got.out.rules,
      setting: read.mode ?? settingOf(modeSource(at)),
      seeds: got.out.seeds,
      unread: got.out.unread,
      light: got.out.light,
      dark: got.out.dark,
      font_scale: Number(read.base['font-scale'] ?? FONT_SCALE.default),
      density: null,
      checks: say(got.out.checks),
      changes: got.out.changes,
    };
  }

  const lookSeen = new WeakMap();
  const NO_SEEDS = Object.freeze({ font_scale: null, accent: null, background: null, foreground: null });
  const shownKeys = (shown, mode) =>
    shown
      ? {
          font_scale: null,
          accent: shown[mode]?.accent ?? null,
          background: shown[mode]?.background ?? null,
          foreground: shown[mode]?.foreground ?? null,
        }
      : NO_SEEDS;
  function seedLookSeen(el, shown) {
    if (!lookSeen.has(el) && isObject(shown?.light) && isObject(shown?.dark))
      lookSeen.set(el, shownKeys(shown, shownOf(el)));
  }
  function settleLook(el, next, by, scale = null) {
    const mode = shownOf(el);
    const was = lookSeen.get(el) ?? NO_SEEDS;
    const now = { ...shownKeys(next, mode), font_scale: scale };
    if (next || scale !== null) lookSeen.set(el, now);
    else lookSeen.delete(el);
    if (el.ownerDocument.readyState !== 'complete') return;
    const page = el === el.ownerDocument.documentElement;
    for (const key of LOOK_EVENT_KEYS) {
      const before = was[key];
      const after = now[key];
      if (before === after) continue;
      const detail = { key, value: after, from: before, by, scope: page ? 'page' : 'root' };
      el.dispatchEvent(new CustomEvent('stagemap:look', { bubbles: true, detail: stamp(detail, el.ownerDocument) }));
    }
  }
  const SPACING_ROLES = ["inset-x","inset-y","inset-cell","gap-s","gap-m","gap-l","row-height","inset-x-compact","inset-y-compact","inset-cell-compact","gap-m-compact","gap-l-compact","row-height-compact"];
  const PHONE_ROLES = ["inset-x","gap-m","gap-l"];
  const PHONE_WIDTH = 520;
  const FONT_SCALE = {"min":0.85,"max":1.5,"default":1,"floor":12};
  const VAR_PATTERN = "var\\(\\s*--[A-Za-z0-9_-]+\\s*(?:,\\s*((?:[^()]|\\([^()]*\\))*?)\\s*)?\\)";
  const TEXT_ROLES = {"lineheight-body":{"setting":"lineheight","unit":null,"min":1,"max":2,"step":null},"lineheight-row":{"setting":"lineheight","unit":null,"min":1,"max":2,"step":null},"lineheight-heading":{"setting":"lineheight","unit":null,"min":1,"max":2,"step":null},"lineheight-figures":{"setting":"lineheight","unit":null,"min":1,"max":2,"step":null},"weight-body":{"setting":"weight","unit":null,"min":100,"max":900,"step":1},"weight-label":{"setting":"weight","unit":null,"min":100,"max":900,"step":1},"weight-heading":{"setting":"weight","unit":null,"min":100,"max":900,"step":1},"weight-figures":{"setting":"weight","unit":null,"min":100,"max":900,"step":1},"weight-strong":{"setting":"weight","unit":null,"min":100,"max":900,"step":1},"letterspacing-heading":{"setting":"letterspacing","unit":"em","min":-0.05,"max":0.05,"step":null},"letterspacing-figures":{"setting":"letterspacing","unit":"em","min":-0.05,"max":0.05,"step":null},"letterspacing-label":{"setting":"letterspacing","unit":"em","min":-0.05,"max":0.15,"step":null},"case-label":{"setting":"case","unit":null,"min":null,"max":null,"step":null,"values":["upper","none"],"css":{"upper":"uppercase","none":"none"}}};
  function applyTooltipOptions() {}

  window.stagemap = Object.freeze({
    version: VERSION,
    define,
    plugin,
    plugins,
    mount,
    mountAll,
    observe,
    visuals: () => [...registry.keys()],
    instance: (root) => instances.get(root),
    owner: (place) => placeOwners.get(place) ?? null,
    reducedMotion,
    motion,
    onTheme,
    setSanitizer,
    trail,
    tones: Object.freeze([...TONES]),
    statuses: Object.freeze([...STATUSES]),
    get icons() {
      return iconNames();
    },
    look,
    derive,
    mode,
    palettes: Object.freeze(Object.keys(PALETTES)),
    addIcon,
    machine,
    markdown,
    ui: Object.freeze({
      toneClass,
      statusClass,
      markerPath,
      legendItem,
      chip,
      button,
      icon,
      pauseButton,
      detail,
      detailGone,
      hover,
      record,
      move,
      collection,
      selection,
      disclosure,
      stack: layerStack,
      presence,
      hostItems,
      hostStore,
      paragraphs,
      slotWords,
      html,
      scrollBox,
      reveal,
      travel,
      player,
    }),
    util: Object.freeze({
      stamp,
      isTime,
      minutes,
      hhmm,
      num,
      format_number,
      isObject,
      list,
      rows: asRows,
      contrast: (a, b) => {
        const x = parseColour(a);
        const y = parseColour(b);
        return x && y ? engineOf().cut(contrast(x.rgb, y.rgb)) : null;
      },
      wrap,
      placeFlags,
      oneOf,
      quoted,
      kindOf,
      closest,
      didYouMean,
      nearest,
      iconHint,
      ids,
      given,
      hasText,
      isScalar,
      checkOptions,
      cssLength,
      motionRules,
    }),
  });
})();
    (() => {
      const { ui, util } = stagemap;
      const { oneOf, closest, quoted: show, kindOf: kind, didYouMean: hint } = util;

      const SKELETON = `
  <div class="sm-head">
    <div>
      <h3 class="sm-title v-sm-title"></h3>
      <p class="sm-sub v-sm-sub"></p>
    </div>
    <div class="v-sm-variants sm-player" role="group" aria-label="Variant"></div>
    <div class="v-sm-tools"></div>
  </div>
  <p class="sm-sr v-sm-summary"></p>
  <ul class="sm-legend v-sm-legend" aria-label="Legend"></ul>
  <div class="v-sm-caption"></div>
  <div class="v-sm-notes"></div>
  <div class="v-sm-body">
    <div class="v-sm-main">
      <div class="v-sm-frame">
        <div class="v-sm-lanes"></div>
        <div class="sm-scroll v-sm-picture"></div>
      </div>
      <div class="sm-detail"></div>
    </div>
    <section class="v-sm-panel" aria-label="What happens at this stage">
      <div class="v-sm-say" aria-live="polite">
        <p class="sm-label v-sm-kicker"></p>
        <h4 class="v-sm-ptitle"></h4>
        <div class="v-sm-ptext"></div>
      </div>
      <figure class="v-sm-file">
        <figcaption class="sm-label v-sm-fname"></figcaption>
        <p class="sm-sr v-sm-fnote"></p>
        <pre class="v-sm-code" tabindex="0"><code></code></pre>
      </figure>
    </section>
  </div>
  <ol class="v-sm-steps" aria-label="Steps"></ol>
  <div class="v-sm-zones"></div>
  <div class="v-sm-tiles"></div>
`;

      const LAYOUTS = ['grid', 'levels', 'dates'];
      const LINES = ['solid', 'dashed', 'dotted', 'dashdot'];
      const ENDS = ['arrow', 'ring', 'none'];
      const STEP_PANEL = ['file', 'code', 'highlight'];
      const LISTS = {
        stages: { min: 1, required: ['id', 'label'], optional: ['kicker', 'text', 'date', 'flag', 'tone', ...STEP_PANEL] },
        lanes: { min: 1, required: ['id', 'label'], optional: ['tone', 'text'] },
        nodes: {
          min: 1,
          required: ['id', 'label', 'stage', 'lane'],
          optional: ['sub', 'status', 'tone', 'text', 'zone', 'milestone', 'variants', 'hidden', 'disabled', 'reason'],
        },
        links: { min: 0, required: ['from', 'to'], optional: ['kind', 'label', 'step', 'variants'] },
        kinds: { min: 0, required: ['id', 'label'], optional: ['line', 'end', 'tone', 'quiet'] },
        statuses: { min: 0, required: ['id'], optional: ['label', 'tone', 'icon'] },
        zones: { min: 0, required: ['id', 'label'], optional: ['text', 'note', 'tone'] },
        steps: { min: 0, required: ['id', 'label'], optional: ['kicker', 'text', 'stage', ...STEP_PANEL] },
        changes: { min: 0, required: ['step', 'card'], optional: ['status', 'stage', 'hidden'], blank: true },
        variants: { min: 0, required: ['id', 'label'], optional: [] },
      };
      const OPTIONS = ['layout', 'title', 'sub', 'intro', 'label', 'motion', 'target', 'variant', 'statuses', 'legend', 'summary', 'hosted', 'cell_columns', 'bundle_links', 'dismiss', 'highlight'];
      const DISMISS = ['any', 'no_outside'];
      const REGIONS = ['title', 'details', 'stage', 'steps', 'zones'];
      const JOINS = {
        nodes: { stage: 'stages', lane: 'lanes', zone: 'zones' },
        links: { from: 'nodes', to: 'nodes', kind: 'kinds', step: 'steps' },
        steps: { stage: 'stages' },
        changes: { step: 'steps', card: 'nodes', stage: 'stages' },
      };
      const MANY = { nodes: { variants: 'variants' }, links: { variants: 'variants' } };
      const LINE_LIST = /^\s*\d+(\s*-\s*\d+)?(\s*,\s*\d+(\s*-\s*\d+)?)*\s*$/;
      const isDate = (v) =>
        typeof v === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(v) && !Number.isNaN(Date.parse(`${v}T00:00:00Z`)) &&
        new Date(`${v}T00:00:00Z`).toISOString().startsWith(v);
      const RULES = {
        status: [(v) => stagemap.statuses.includes(v), `one of ${oneOf(stagemap.statuses)}`],
        tone: [(v) => stagemap.tones.includes(v), `one of ${oneOf(stagemap.tones)}`],
        line: [(v) => LINES.includes(v), `one of ${oneOf(LINES)}`],
        end: [(v) => ENDS.includes(v), `one of ${oneOf(ENDS)}`],
        milestone: [(v) => typeof v === 'boolean', 'true or false'],
        hidden: [(v) => typeof v === 'boolean', 'true or false'],
        disabled: [(v) => typeof v === 'boolean', 'true or false'],
        quiet: [(v) => typeof v === 'boolean', 'true or false'],
        date: [isDate, 'a date written YYYY-MM-DD'],
        highlight: [(v) => typeof v === 'string' && LINE_LIST.test(v), 'line numbers such as "3, 5-7"'],
      };
      const TEXT = [(v) => typeof v === 'string', 'text'];
      const ID = [(v) => typeof v === 'string' && v.trim() !== '', 'text that is not empty, or a number'];

      const typo = (key, known) => closest(key, known, String(key).length <= 4 ? 1 : 2);
      const unused = (where, what, key, known) =>
        `${where} has ${what} ${show(key)}; did you mean ${show(typo(key, known))}? It is not used.`;
      const several = (text) =>
        String(text)
          .split(',')
          .map((s) => s.trim())
          .filter(Boolean);
      const given = (row, key) => row[key] !== undefined && row[key] !== null;
      const filled = (spec, row, key) => given(row, key) && !((spec.blank || key === 'quiet') && typeof row[key] === 'string' && row[key].trim() === '');
      const regions = (value) => [value].flat().filter((r) => r !== undefined && r !== null);
      const TRACE = ['ids', 'links'];
      const TRACE_LINK = ['from', 'to', 'kind'];
      const listOf = (v) => (v === undefined || v === null ? [] : Array.isArray(v) ? v : [v]);
      const idText = (v) => (typeof v === 'number' && Number.isFinite(v) ? String(v) : v);
      function readHighlight(value, cards, links) {
        const none = { ids: [], links: [] };
        const no = (problem) => ({ ...none, problem: `"highlight" ${problem}` });
        if (value === undefined || value === null) return none;
        if (!util.isObject(value)) return no(`must be an object with "ids" and, if wanted, "links", not ${show(value)}`);
        for (const key of Object.keys(value)) {
          if (!TRACE.includes(key)) return no(`takes ${oneOf(TRACE)}, not ${show(key)}${hint(key, TRACE)}`);
        }
        const ids = listOf(value.ids).filter((x) => x !== null).map(idText);
        const bad = ids.find((x) => !ID[0](x));
        if (bad !== undefined) return no(`"ids" must be card ids (text or numbers), not ${show(bad)}`);
        const gone = ids.find((x) => !cards.includes(x));
        if (gone !== undefined) return no(`"ids" names ${show(gone)}, which is not an id in "nodes"${hint(gone, cards)}`);
        if (!ids.length) return none;
        const out = [];
        for (const row of listOf(value.links)) {
          if (!util.isObject(row)) return no(`"links" must be rows with "from", "to" and, if wanted, "kind", not ${show(row)}`);
          const odd = Object.keys(row).find((k) => !TRACE_LINK.includes(k));
          if (odd !== undefined) return no(`"links" rows take ${oneOf(TRACE_LINK)}, not ${show(odd)}${hint(odd, TRACE_LINK)}`);
          const [from, to] = [idText(row.from), idText(row.to)];
          const kind = row.kind === undefined || row.kind === null ? null : idText(row.kind);
          if (!ID[0](from) || !ID[0](to) || (kind !== null && !ID[0](kind)))
            return no(`"links" rows need "from" and "to" as card ids (and "kind", when given, as a kind id), not ${show(row)}`);
          const away = [from, to].find((x) => !ids.includes(x));
          if (away !== undefined) return no(`"links" names ${show(away)}, which is not one of its "ids"`);
          if (!links.some((l) => l.from === from && l.to === to && (kind === null || l.kind === kind)))
            return no(`"links": there is no link from ${show(from)} to ${show(to)}${kind === null ? '' : ` of the kind ${show(kind)}`}`);
          out.push({ from, to, kind });
        }
        return { ids: [...new Set(ids)], links: out };
      }
      const traceable = (d) => ({
        cards: listOf(d.nodes).filter(util.isObject).map((n) => idText(n.id)),
        links: listOf(d.links)
          .filter(util.isObject)
          .map((l) => ({ from: idText(l.from), to: idText(l.to), kind: l.kind === undefined || l.kind === null ? null : idText(l.kind) })),
      });

      const MIN_COLUMNS = 1;
      const MAX_COLUMNS = 6;
      function columnsOf(v) {
        if (v === undefined || v === null) return 1;
        const word = typeof v === 'string' ? v.trim() : v;
        if (word === '') return 1;
        if (word === 'auto') return 'auto';
        const k = typeof word === 'string' && /^\d+$/.test(word) ? Number(word) : word;
        return Number.isInteger(k) && k >= MIN_COLUMNS && k <= MAX_COLUMNS ? k : null;
      }

      function normalise(d) {
        if (!util.isObject(d)) return d;
        const out = { ...d };
        const text = (row, key) => {
          if (typeof row[key] === 'number' && Number.isFinite(row[key])) row[key] = String(row[key]);
        };
        for (const name of Object.keys(LISTS)) {
          if (d[name] === undefined || d[name] === null) continue;
          const rows = util.isObject(d[name]) ? [d[name]] : d[name];
          if (!Array.isArray(rows)) continue;
          out[name] = rows.map((row) => {
            if (!util.isObject(row)) return row;
            const copy = { ...row };
            for (const key of ['id', 'status', ...Object.keys(JOINS[name] || {}), ...Object.keys(MANY[name] || {})]) text(copy, key);
            return copy;
          });
        }
        if (util.isObject(d.options)) {
          out.options = { ...d.options };
          text(out.options, 'target');
          text(out.options, 'variant');
        }
        return out;
      }

      function check(d) {
        const p = [];
        const notes = new Map();
        const note = (key, text) => notes.set(key, text);
        const done = () => ({ problems: p, notes: [...notes.values()] });
        const { isObject } = util;
        if (!isObject(d)) {
          p.push(`the data must be an object with "options", "stages", "lanes" and "nodes", not ${kind(d)}`);
          return done();
        }
        for (const key of Object.keys(d)) {
          const top = ['options', ...Object.keys(LISTS)];
          if (!top.includes(key) && typo(key, top)) note(`|${key}`, unused('The data', 'a field', key, top));
        }

        const allowedStatuses = [...stagemap.statuses];
        for (const s of util.rows(d.statuses)) {
          const id = isObject(s) && s.id !== undefined && s.id !== null ? String(s.id) : '';
          if (id.trim() !== '' && !allowedStatuses.includes(id)) allowedStatuses.push(id);
        }
        const statusRule = [(v) => allowedStatuses.includes(v), `one of ${oneOf(allowedStatuses)}`];
        const ids = {};
        const rows = {};
        for (const [name, spec] of Object.entries(LISTS)) {
          const value = d[name];
          rows[name] = [];
          if (value === undefined || value === null) {
            if (spec.min) p.push(`"${name}" is missing; it must be a list of rows with ${oneOf(spec.required)}`);
            continue;
          }
          if (!Array.isArray(value)) {
            p.push(`"${name}" must be a list of rows (records), not ${kind(value)}`);
            continue;
          }
          if (value.length < spec.min) p.push(`"${name}" must have at least ${spec.min} row`);
          const seen = new Set();
          let whole = true;
          const known = [...spec.required, ...spec.optional];
          value.forEach((row, i) => {
            const at = `"${name}" row ${i + 1}`;
            if (!isObject(row)) {
              p.push(`${at} must be an object with ${oneOf(spec.required)}, not ${show(row)}`);
              whole = false;
              return;
            }
            rows[name].push([row, i + 1]);
            for (const key of Object.keys(row)) {
              if (!known.includes(key) && typo(key, known)) note(`${name}|${key}`, unused(`"${name}"`, 'a column', key, known));
            }
            for (const key of spec.required) {
              if (!given(row, key)) {
                p.push(`${at}: "${key}" is missing`);
                continue;
              }
              const [ok, what] = key === 'status' ? statusRule : (key === 'id' || JOINS[name]?.[key] ? ID : RULES[key] || TEXT);
              if (!ok(row[key])) p.push(`${at}: "${key}" must be ${what}, not ${show(row[key])}`);
            }
            for (const key of spec.optional.filter((k) => filled(spec, row, k))) {
              const [ok, what] = key === 'status' ? statusRule : (JOINS[name]?.[key] ? ID : RULES[key] || TEXT);
              if (!ok(row[key])) p.push(`${at}: "${key}" must be ${what}, not ${show(row[key])}`);
            }
            if (spec.required.includes('id') && !ID[0](row.id)) whole = false;
            else if (typeof row.id === 'string') {
              if (seen.has(row.id)) p.push(`${at}: the id ${show(row.id)} is used twice in "${name}"`);
              seen.add(row.id);
            }
          });
          if (whole) ids[name] = seen;
        }

        const changed = new Map();
        for (const [row, n] of rows.changes) {
          if (!ID[0](row.step) || !ID[0](row.card)) continue;
          const key = JSON.stringify([row.step, row.card]);
          if (changed.has(key))
            p.push(`"changes" row ${n}: the card ${show(row.card)} is changed twice at the step ${show(row.step)} (rows ${changed.get(key)} and ${n})`);
          else changed.set(key, n);
        }

        const absent = new Map();
        const joins = (name, key, value, target, at) => {
          if (!ids[target] || typeof value !== 'string') return;
          if (!ids[target].has(value))
            p.push(`${at}: "${key}" is ${show(value)}, which is not an id in "${target}"${hint(value, ids[target])}`);
        };
        const check = (name, row, n, key, target, values) => {
          if (d[target] === undefined || d[target] === null) {
            const k = `${name}|${key}`;
            if (!absent.has(k)) absent.set(k, [name, key, target, 0]);
            absent.get(k)[3]++;
            return;
          }
          const at = `"${name}" row ${n}${typeof row.id === 'string' ? ` (${show(row.id)})` : ''}`;
          for (const one of values) joins(name, key, one, target, at);
        };
        for (const [name, fields] of Object.entries(JOINS)) {
          for (const [row, n] of rows[name]) {
            for (const [key, target] of Object.entries(fields)) {
              if (filled(LISTS[name], row, key)) check(name, row, n, key, target, [row[key]]);
            }
          }
        }
        for (const [name, fields] of Object.entries(MANY)) {
          for (const [row, n] of rows[name]) {
            for (const [key, target] of Object.entries(fields)) {
              if (given(row, key) && typeof row[key] === 'string') check(name, row, n, key, target, several(row[key]));
            }
          }
        }
        for (const [name, key, target, count] of absent.values()) {
          if (LISTS[target].min) continue;
          const which = count === 1 ? '1 row gives' : `${count} rows give`;
          p.push(`"${name}": ${which} a "${key}", but there is no "${target}" list; add one or leave "${key}" out`);
        }

        const o = d.options ?? {};
        if (!isObject(o)) {
          p.push(`"options" must be an object, not ${show(o)}`);
          return done();
        }
        for (const key of Object.keys(o)) {
          if (!OPTIONS.includes(key) && typo(key, OPTIONS)) note(`options|${key}`, unused('"options"', 'a field', key, OPTIONS));
        }
        for (const key of ['title', 'sub', 'intro', 'label']) {
          if (given(o, key) && typeof o[key] !== 'string') p.push(`"options": "${key}" must be text, not ${show(o[key])}`);
        }
        if (given(o, 'layout') && !LAYOUTS.includes(o.layout))
          p.push(`"options": "layout" must be one of ${oneOf(LAYOUTS)}, not ${show(o.layout)}`);
        for (const key of ['motion', 'legend', 'summary', 'bundle_links']) {
          if (given(o, key) && typeof o[key] !== 'boolean')
            p.push(`"options": "${key}" must be true or false, not ${show(o[key])}`);
        }
        if (columnsOf(o.cell_columns) === null)
          p.push(`"options": "cell_columns" must be a whole number from ${MIN_COLUMNS} to ${MAX_COLUMNS}, or "auto", not ${show(o.cell_columns)}`);
        for (const r of regions(o.hosted).filter((x) => !REGIONS.includes(x)))
          p.push(`"options": "hosted" must name only ${oneOf(REGIONS)}, not ${show(r)}${hint(r, REGIONS)}`);
        if (given(o, 'target')) joins('options', 'target', o.target, 'nodes', '"options"');
        if (given(o, 'variant')) {
          if (d.variants === undefined || d.variants === null)
            p.push(`"options": "variant" is ${show(o.variant)}, but there is no "variants" list`);
          else joins('options', 'variant', o.variant, 'variants', '"options"');
        }
        for (const key of ['target', 'variant']) {
          if (given(o, key) && typeof o[key] !== 'string') p.push(`"options": "${key}" must be an id (text)`);
        }
        if (given(o, 'highlight') && ids.nodes) {
          const { problem } = readHighlight(o.highlight, [...ids.nodes], traceable(d).links);
          if (problem) p.push(`"options": ${problem}`);
        }
        if (given(o, 'dismiss') && !DISMISS.includes(o.dismiss))
          p.push(`"options": "dismiss" must be one of ${oneOf(DISMISS)}, not ${show(o.dismiss)}`);
        if (given(o, 'statuses')) {
          if (!isObject(o.statuses)) {
            p.push(`"options": "statuses" must be an object such as {"done": "Pass"}, not ${show(o.statuses)}`);
          } else {
            for (const [key, word] of Object.entries(o.statuses)) {
              if (!stagemap.statuses.includes(key)) {
                if (typo(key, stagemap.statuses))
                  note(`statuses|${key}`, unused('"options" "statuses"', 'a word for', key, stagemap.statuses));
              } else if (word !== null && typeof word !== 'string') p.push(`"options": "statuses" ${show(key)} must be text`);
            }
          }
        }
        if (ids.zones && rows.nodes.length) {
          for (const z of ids.zones) {
            if (!rows.nodes.some(([n]) => n.zone === z)) note(`zone|${z}`, `The zone ${show(z)} has no cards; it is not drawn.`);
          }
        }
        return done();
      }

      function validate(d) {
        return check(normalise(d)).problems;
      }

      const GLYPH = {
        done: 'M-3.6,0.2L-1.2,2.8L3.6,-2.6',
        running: 'M-2.4,-3.2L3.2,0L-2.4,3.2Z',
        waiting: 'M-3.4,0h0.01M0,0h0.01M3.4,0h0.01',
        failed: 'M-3,-3L3,3M3,-3L-3,3',
        skipped: 'M-3.4,0H3.4',
      };
      const DOT_GLYPH = 'M-1.8,0a1.8,1.8 0 1,0 3.6,0a1.8,1.8 0 1,0 -3.6,0Z';
      const DEFAULT_KIND = { id: '', label: 'link', line: 'solid', end: 'arrow', quiet: false };
      const WARNED_ICONS = new Set();

      function drawGlyph(parent, st, x = 0, y = 0) {
        if (!st) return;
        if (st.iconNodes) {
          const g = parent.append('g').attr('class', 'v-sm-glyph');
          const t = x || y ? `translate(${x},${y}) scale(0.4167) translate(-12,-12)` : 'scale(0.4167) translate(-12,-12)';
          g.attr('transform', t);
          for (const node of st.iconNodes) g.node().append(node.cloneNode(true));
        } else {
          const path = parent.append('path');
          path.attr('class', st.isDot ? 'v-sm-glyph v-sm-solid' : 'v-sm-glyph').attr('d', st.glyph);
          if (x || y) path.attr('transform', `translate(${x},${y})`);
        }
      }

      const statusLook = (st) =>
        st && !st.toneOverride && stagemap.statuses.includes(st.id) ? ui.statusClass(st.id) : ui.toneClass(st?.tone || 'muted');

      const text = (v) => (typeof v === 'string' ? v.trim() : '');

      function motionDuration(el) {
        const style = getComputedStyle(el);
        const num = (name, fallback) => {
          const n = Number.parseFloat(style.getPropertyValue(name));
          return Number.isFinite(n) ? n : fallback;
        };
        return num('--stagemap-motion-base-m', 200) * num('--stagemap-motion-scale', 1) * num('--stagemap-motion-factor', 1);
      }

      function fold(d, at) {
        const nodes = util.rows(d.nodes);
        const all = util.rows(d.changes);
        if (!all.length) return { nodes, sig: '' };
        const place = new Map(util.rows(d.steps).map((s, k) => [s.id, k]));
        const todo = all
          .map((c, k) => [place.get(c.step) ?? Number.POSITIVE_INFINITY, k, c])
          .filter(([k]) => k <= at)
          .sort((a, b) => a[0] - b[0] || a[1] - b[1]);
        const cards = new Map(nodes.map((n) => [n.id, { ...n }]));
        for (const [, , c] of todo) {
          const card = cards.get(c.card);
          if (!card) continue;
          if (text(c.status)) card.status = c.status;
          if (text(c.stage)) card.stage = c.stage;
          if (typeof c.hidden === 'boolean') card.hidden = c.hidden;
        }
        const out = nodes.map((n) => cards.get(n.id) ?? n);
        return { nodes: out, sig: out.map((n) => `${n.status}|${n.stage}|${n.hidden === true}`).join(';') };
      }

      const name = (m, hidden) =>
        text(m.o.label) ||
        (text(m.o.title) && [text(m.o.title), hidden && stagemap.markdown.plain(text(m.o.sub))].filter(Boolean).join('. ')) ||
        'Stage map';

      function model(d) {
        const o = d.options ?? {};
        const byId = (rows) => new Map(rows.map((r, i) => [r.id, Object.assign(r, { i })]));
        const stages = byId(d.stages.map((s) => ({ ...s })));
        const lanes = byId(d.lanes.map((l) => ({ ...l })));
        const kinds = byId((d.kinds || []).map((k) => ({ ...k, line: k.line ?? 'solid', end: k.end ?? 'arrow', quiet: k.quiet === true })));
        const zones = byId((d.zones || []).map((z) => ({ ...z })));
        const nodes = byId(
          d.nodes.map((n) => ({ ...n, stage: stages.get(n.stage), lane: lanes.get(n.lane), zone: zones.get(n.zone) })),
        );
        const links = (d.links || []).map((l, i) => ({
          ...l,
          i,
          from: nodes.get(l.from),
          to: nodes.get(l.to),
          kind: kinds.get(l.kind) || DEFAULT_KIND,
        }));
        const statusMap = new Map();
        const baseStatuses = stagemap.statuses.map((id) => ({
          id,
          label: o.statuses?.[id] || id,
          tone: null,
          toneOverride: false,
          glyph: GLYPH[id],
          iconName: null,
          iconNodes: null,
          isDot: false,
        }));
        for (const st of baseStatuses) statusMap.set(st.id, st);

        const customStatuses = [];
        for (const row of util.rows(d.statuses)) {
          if (!util.isObject(row) || row.id === undefined || row.id === null) continue;
          const id = String(row.id);
          if (!id.trim()) continue;

          let iconNodes = null;
          let iconName = null;
          let isUnknownIcon = false;
          if (given(row, 'icon') && typeof row.icon === 'string' && row.icon.trim()) {
            iconName = row.icon.trim();
            if (stagemap.icons.includes(iconName)) {
              const ic = stagemap.ui.icon(iconName);
              if (ic) iconNodes = [...ic.childNodes].map((n) => n.cloneNode(true));
            } else {
              isUnknownIcon = true;
              if (!WARNED_ICONS.has(iconName)) {
                WARNED_ICONS.add(iconName);
                console.warn(`stagemap stage-map: no icon "${iconName}" (icons: ${stagemap.icons.join(', ')})${util.iconHint?.(iconName) ?? ''}`);
              }
            }
          }

          if (statusMap.has(id)) {
            const existing = statusMap.get(id);
            if (given(row, 'label') && typeof row.label === 'string') {
              existing.label = row.label;
            }
            if (given(row, 'tone') && stagemap.tones.includes(row.tone)) {
              existing.tone = row.tone;
              existing.toneOverride = true;
            }
            if (iconNodes) {
              existing.iconNodes = iconNodes;
              existing.iconName = iconName;
              existing.glyph = null;
              existing.isDot = false;
            } else if (isUnknownIcon) {
              existing.iconNodes = null;
              existing.iconName = null;
              existing.glyph = DOT_GLYPH;
              existing.isDot = true;
            }
          } else {
            const hasTone = given(row, 'tone') && stagemap.tones.includes(row.tone);
            const tone = hasTone ? row.tone : 'muted';
            const label = given(row, 'label') && typeof row.label === 'string' ? row.label : id;
            const glyph = iconNodes ? null : DOT_GLYPH;
            const custom = {
              id,
              label,
              tone,
              toneOverride: true,
              glyph,
              iconName,
              iconNodes,
              isDot: !iconNodes,
            };
            statusMap.set(id, custom);
            customStatuses.push(custom);
          }
        }
        const statuses = [...baseStatuses, ...customStatuses];
        const statusLookup = statusMap;
        const word = (status) => statusLookup.get(status)?.label || o.statuses?.[status] || status;
        const panel = d.stages.some((s) => s.text || s.kicker || s.code) || (d.steps || []).length > 0;
        const rows = (d.steps || []).length
          ? d.steps
          : d.stages.map((s) => ({ id: s.id, label: s.label, text: s.text, kicker: s.kicker, stage: s.id }));
        const steps = rows.map((s, i) => ({ ...s, i, stage: stages.get(s.stage) }));
        for (const l of links) {
          const own = given(l, 'step') ? steps.findIndex((s) => s.id === l.step) : -1;
          const here = steps.findIndex((s) => s.stage === l.to.stage);
          const later = steps.findIndex((s) => s.stage && s.stage.i >= l.to.stage.i);
          l.at = [own, here, later].find((k) => k >= 0) ?? null;
        }
        const moves = util.rows(d.changes).filter((c) => text(c.stage));
        let far = -1;
        for (const s of steps) {
          far = Math.max(
            far,
            s.stage ? s.stage.i : -1,
            ...links.filter((l) => l.at === s.i).map((l) => l.to.stage.i),
            ...moves.filter((c) => c.step === s.id).map((c) => stages.get(c.stage)?.i ?? -1),
          );
          s.reach = far;
        }
        return {
          o,
          stages: [...stages.values()],
          lanes: [...lanes.values()],
          nodes: [...nodes.values()],
          links,
          kinds,
          zones: [...zones.values()],
          statuses,
          statusLookup,
          word,
          panel,
          steps,
          levels: o.layout === 'levels',
          dates: o.layout === 'dates',
          target: nodes.get(o.target) || null,
          variants: d.variants || [],
        };
      }

      const r1 = (v) => Math.round(v * 10) / 10;
      const pt = ([x, y]) => `${r1(x)},${r1(y)}`;
      const curve = (segs) => `M${pt(segs[0][0])}${segs.map(([, c1, c2, p]) => `C${pt(c1)} ${pt(c2)} ${pt(p)}`).join('')}`;
      const bend = (p, q) => [p, [(p[0] + q[0]) / 2, p[1]], [(p[0] + q[0]) / 2, q[1]], q];
      const straight = (p, q) => [p, p, q, q];

      function bezier([p0, c1, c2, p3], t) {
        const u = 1 - t;
        const at = (k) => u * u * u * p0[k] + 3 * u * u * t * c1[k] + 3 * u * t * t * c2[k] + t * t * t * p3[k];
        return [at(0), at(1)];
      }

      function fit(text, room, lines) {
        const max = Math.max(1, room);
        const all = util.wrap(text, max).flatMap((line) => (line.length > max ? [line.slice(0, max)] : [line]));
        const kept = all.slice(0, lines);
        if (all.length > lines || all.join(' ').length < String(text).trim().length) {
          const last = kept[kept.length - 1] || '';
          kept[kept.length - 1] = `${last.slice(0, Math.max(1, max - 1)).trimEnd()}…`;
        }
        return kept.length ? kept : [''];
      }

      const FLAG_TONE = 'warn';
      const flagFit = (s, room) => {
        if (!s.flag) return { word: '', w: 0 };
        const word = fit(s.flag, Math.max(3, Math.floor((room - 14) / 6.2)), 1)[0];
        return { word, w: word.length * 6.2 + 14 };
      };
      function drawFlag(head, s, { word, w }, right, y) {
        if (!word) return;
        const g = head.append('g').attr('class', `v-sm-flag ${ui.toneClass(s.tone || FLAG_TONE)}`);
        g.append('rect').attr('class', 'sm-chip-bg').attr('x', r1(right - w)).attr('y', y).attr('width', r1(w)).attr('height', 17).attr('rx', 8.5);
        g.append('text').attr('class', 'sm-chip-txt').attr('x', r1(right - w / 2)).attr('y', y + 12.2).attr('text-anchor', 'middle').text(word);
      }
      const headName = (m, s) => `Stage ${s.i + 1} of ${m.stages.length}: ${s.label}${s.flag ? `, ${s.flag}` : ''}`;

      const LABEL_W = 116;
      const MIN_CARD = 150;
      const GUTTER = 34;
      const GUTTER_LABELS = 66;
      const LABEL_CHARS = 9;
      const GAP = 12;
      const ZONE_ROOM = 18;
      const HEAD = 34;
      const COL_GAP = GAP;
      const ALLEY = 22;
      const ALLEY_EDGE = 18;
      const CORNER = 6;

      function busiest(m) {
        const count = new Map();
        for (const n of m.nodes) {
          const key = `${n.lane.i}|${n.stage.i}`;
          count.set(key, (count.get(key) || 0) + 1);
        }
        const most = m.stages.map(() => 1);
        for (const n of m.nodes) most[n.stage.i] = Math.max(most[n.stage.i], count.get(`${n.lane.i}|${n.stage.i}`));
        return most;
      }
      const stageMin = (c, gutter) => c * MIN_CARD + (c - 1) * COL_GAP + gutter;
      function columnsPer(m, gutter, room) {
        const want = columnsOf(m.o.cell_columns) ?? 1;
        const busy = busiest(m);
        if (want === 1) return busy.map(() => 1);
        const cols = busy.map((b) => Math.max(1, Math.min(want === 'auto' ? MAX_COLUMNS : want, b)));
        if (want === 'auto') {
          while (d3.sum(cols, (c) => stageMin(c, gutter)) > room && Math.max(...cols) > 1) {
            let pick = -1;
            let minDensity = Infinity;
            for (let i = 0; i < cols.length; i++) {
              if (cols[i] > 1) {
                const density = busy[i] / (cols[i] - 1);
                if (density <= minDensity) {
                  minDensity = density;
                  pick = i;
                }
              }
            }
            cols[pick]--;
          }
        }
        return cols;
      }

      function gridNeed(m, width) {
        const labelW = width < 560 ? 84 : LABEL_W;
        const gutter = m.links.some((l) => l.label && l.to.stage.i > l.from.stage.i) ? GUTTER_LABELS : GUTTER;
        const cols = columnsPer(m, gutter, width - labelW);
        const mins = cols.map((c) => stageMin(c, gutter));
        return { labelW, gutter, cols, mins, need: labelW + d3.sum(mins) };
      }

      function orderedCells(m) {
        const forward = m.links.filter((l) => l.to.stage.i > l.from.stage.i);
        const cells = d3.group(
          m.nodes,
          (n) => n.lane.i,
          (n) => n.stage.i,
        );
        const sources = new Map(m.nodes.map((n) => [n, forward.filter((l) => l.to === n).map((l) => l.from)]));
        const rank = new Map();
        for (const s of m.stages) {
          for (const lane of m.lanes) {
            const list = cells.get(lane.i)?.get(s.i);
            if (!list) continue;
            const pull = new Map(
              list.map((n) => {
                const from = sources.get(n).filter((f) => rank.has(f));
                return [n, from.length ? d3.mean(from, (f) => rank.get(f)) : lane.i * 1000 + n.i / 1000];
              }),
            );
            const group = (n) => (n.zone ? d3.min(list.filter((o) => o.zone === n.zone), (o) => pull.get(o)) : pull.get(n));
            list.sort((a, b) => group(a) - group(b) || pull.get(a) - pull.get(b) || a.i - b.i);
            for (const [k, n] of list.entries()) rank.set(n, lane.i * 1000 + k);
          }
        }
        return cells;
      }

      const BUNDLE_MIN = 3;
      function bundleGroups(m) {
        if (m.o.bundle_links !== true) return [];
        const loose = m.links.filter((l) => l.to.stage.i > l.from.stage.i && !l.label);
        const groups = [];
        for (const [from, kinds] of d3.group(loose, (l) => l.from, (l) => l.kind)) {
          for (const [kind, links] of kinds) if (links.length >= BUNDLE_MIN) groups.push({ from, kind, links, parts: [] });
        }
        return groups;
      }

      function bundleRow(group, m, foot) {
        const a = group.from;
        const l = group.links[0];
        const at = a.right ? l.aOut : l.yOut;
        const far = d3.max(group.links, (k) => k.to.stage.i);
        const between = m.nodes.filter((n) => n.stage.i > a.stage.i && n.stage.i < far);
        const free = (y) => between.every((n) => y < n.y - 6 || y > n.y + n.h + 6);
        const gaps = m.lanes.slice(1).map((lane) => lane.y - 3);
        return [at, ...gaps.sort((u, v) => Math.abs(u - at) - Math.abs(v - at)), foot - 3].find(free) ?? null;
      }

      function layoutGrid(m, width) {
        const { labelW, gutter, cols, mins } = gridNeed(m, width);
        const forward = m.links.filter((l) => l.to.stage.i > l.from.stage.i);
        const colW = Math.max(MIN_CARD + gutter, Math.floor((width - labelW) / m.stages.length));
        const widths = cols.some((c) => c > 1)
          ? mins.map((w) => Math.max(w, Math.floor(((width - labelW) * w) / d3.sum(mins))))
          : mins.map(() => colW);
        const W = labelW + d3.sum(widths);
        let x0 = labelW;
        for (const s of m.stages) {
          const c = cols[s.i];
          const cardW = Math.floor((widths[s.i] - gutter - (c - 1) * COL_GAP) / c);
          Object.assign(s, { x: x0, w: widths[s.i], cols: c, cardW, xr: x0 + gutter / 2 + c * cardW + (c - 1) * COL_GAP });
          x0 += widths[s.i];
        }
        for (const n of m.nodes) n.lines = fit(n.label, Math.max(8, Math.floor((n.stage.cardW - 22) / 7.3)), 2);
        const cardH = 64 + (Math.max(...m.nodes.map((n) => n.lines.length)) - 1) * 16;

        const cells = orderedCells(m);
        const backwards = m.links.filter((l) => l.to.stage.i < l.from.stage.i);
        let y = HEAD;
        for (const lane of m.lanes) {
          const row = cells.get(lane.i) || new Map();
          const packed = [...row].some(([i, list]) => m.stages[i].cols > 1 && list.length > 1);
          const top = Math.max([...row.values()].some((list) => list[0].zone) ? 14 + ZONE_ROOM : 14, packed ? ALLEY_EDGE : 0);
          let tallest = cardH;
          for (const [i, list] of row) {
            const s = m.stages[i];
            const many = s.cols > 1 && list.length > 1;
            const gap = many ? ALLEY : GAP;
            const bottoms = [];
            let at = top;
            let c = 0;
            let r = 0;
            list.forEach((n, k) => {
              const zoned = k > 0 && n.zone !== list[k - 1].zone;
              if (k > 0 && (!many || c === s.cols || zoned)) {
                bottoms.push(y + at + cardH);
                at += cardH + gap;
                c = 0;
                r++;
              }
              if (k > 0 && n.zone && zoned) at += ZONE_ROOM;
              Object.assign(n, { x: s.x + gutter / 2 + c * (s.cardW + COL_GAP), y: y + at, w: s.cardW, h: cardH, col: c, row: r });
              c++;
            });
            bottoms.push(y + at + cardH);
            tallest = Math.max(tallest, at + cardH - top);
            list.forEach((n, k) => {
              n.right = list[k + 1]?.row === n.row;
              n.aboveY = n.row === 0 ? y + ALLEY_EDGE / 2 : bottoms[n.row - 1] + ALLEY / 2;
              n.belowY = bottoms[n.row] + (n.row === bottoms.length - 1 ? ALLEY_EDGE : ALLEY) / 2;
            });
          }
          const dips = backwards.some((l) => l.from.lane === lane || l.to.lane === lane);
          Object.assign(lane, { y, h: top + tallest + Math.max(dips ? 38 : 14, packed ? ALLEY_EDGE : 0) });
          y += lane.h + 6;
        }

        const lift = (k, len) => (k - (len - 1) / 2) * Math.min(3, 12 / Math.max(1, len - 1));
        const foot = y;
        const groups = bundleGroups(m);
        m.bundles = [];
        for (const n of m.nodes) {
          const spread = (slots, end, other, side) => {
            slots.sort((a, b) => other(a).y - other(b).y || other(a).x - other(b).x);
            slots.forEach((slot, k) => {
              for (const l of slot) {
                l[end] = n.y + (n.h * (k + 1)) / (slots.length + 1);
                l[side.x] = n.x + (n.w * (k + 1)) / (slots.length + 1);
                l[side.alley] = n[side.edge] - lift(k, slots.length);
              }
            });
          };
          spread(forward.filter((l) => l.to === n).map((l) => [l]), 'yIn', (slot) => slot[0].from, { x: 'xIn', alley: 'aIn', edge: 'aboveY' });
          const out = forward.filter((l) => l.from === n);
          let mine = groups.filter((g) => g.from === n);
          for (;;) {
            const bundled = new Set(mine.flatMap((g) => g.links));
            const slots = [...out.filter((l) => !bundled.has(l)).map((l) => [l]), ...mine.map((g) => g.links)];
            const reach = (slot) => (slot.length > 1 ? { x: d3.mean(slot, (l) => l.to.x), y: d3.mean(slot, (l) => l.to.y) } : slot[0].to);
            spread(slots, 'yOut', reach, { x: 'xOut', alley: 'aOut', edge: 'belowY' });
            for (const g of mine) g.y = bundleRow(g, m, foot);
            const apart = mine.filter((g) => g.y === null);
            if (!apart.length) break;
            mine = mine.filter((g) => !apart.includes(g));
          }
          for (const g of mine) {
            g.lastMax = d3.max(g.links, (l) => l.to.stage.x);
            for (const l of g.links) l.bundle = g;
            m.bundles.push(g);
          }
        }
        return { W, H: y, labelW, cardH };
      }

      function route(l, m, grid) {
        const a = l.from;
        const b = l.to;
        if (a === b) {
          const x = a.x + a.w - 34;
          const seg = [[x, a.y], [x, a.y - 30], [a.x + a.w + 22, a.y - 6], [a.x + a.w, a.y + 14]];
          return { segs: [seg], mark: bezier(seg, 0.5), spots: along(seg) };
        }
        if (b.stage.i === a.stage.i) {
          const p0 = [a.x + a.w, a.y + a.h / 2];
          const p3 = [b.x + b.w, b.y + b.h / 2];
          const seg = [p0, [p0[0] + 30, p0[1]], [p3[0] + 30, p3[1]], p3];
          return { segs: [seg], mark: bezier(seg, 0.5), spots: along(seg) };
        }
        if (b.stage.i < a.stage.i) {
          const p0 = [a.x + a.w / 2, a.y + a.h];
          const p3 = [b.x + b.w / 2, b.y + b.h];
          const dip = Math.max(p0[1], p3[1]) + 26;
          const seg = [p0, [p0[0], dip], [p3[0], dip], p3];
          return { segs: [seg], mark: bezier(seg, 0.5), spots: along(seg) };
        }
        let p0 = [a.x + a.w, l.yOut];
        const before = [];
        if (a.right) {
          const r = Math.min(CORNER, (a.stage.xr - l.xOut) / 2);
          p0 = [a.stage.xr, l.aOut];
          before.push([[l.xOut, a.y + a.h], [l.xOut, l.aOut], [l.xOut, l.aOut], [l.xOut + r, l.aOut]], straight([l.xOut + r, l.aOut], p0));
        }
        let p3 = [b.x, l.yIn];
        const after = [];
        if (b.col > 0) {
          const left = b.x - b.col * (b.w + COL_GAP);
          const r = Math.min(CORNER, (l.xIn - left) / 2);
          p3 = [left, l.aIn];
          after.push(straight(p3, [l.xIn - r, l.aIn]), [[l.xIn - r, l.aIn], [l.xIn, l.aIn], [l.xIn, l.aIn], [l.xIn, b.y]]);
        }
        const alleys = [before[1], after[0]].filter(Boolean);
        const first = m.stages[a.stage.i + 1].x;
        const last = b.stage.x;
        const group = l.bundle;
        if (group) {
          const y = group.y;
          const run = (to) => (to > first ? [straight([first, y], [to, y])] : []);
          const stem = [...before, bend(p0, [first, y])];
          const branch = [bend([last, y], p3), ...after];
          return { segs: [...stem, ...run(last), ...branch], trunk: [...stem, ...run(group.lastMax)], branch, mark: [first, y], spots: [] };
        }
        if (first === last) {
          const seg = bend(p0, p3);
          return { segs: [...before, seg, ...after], mark: [first, (p0[1] + p3[1]) / 2], spots: [...along(seg), ...alleys.flatMap(along)] };
        }
        const between = m.nodes.filter((n) => n.stage.i > a.stage.i && n.stage.i < b.stage.i);
        const free = (y) => between.every((n) => y < n.y - 6 || y > n.y + n.h + 6);
        const gaps = m.lanes.slice(1).map((lane) => lane.y - 3);
        const y = [p3[1], p0[1], ...gaps.sort((u, v) => Math.abs(u - p3[1]) - Math.abs(v - p3[1])), grid.H - 3].find(free);
        return {
          segs: [...before, bend(p0, [first, y]), straight([first, y], [last, y]), bend([last, y], p3), ...after],
          mark: [first, y],
          spots: [[first, y], ...[0.25, 0.5, 0.75].map((f) => [first + (last - first) * f, y]), ...alleys.flatMap(along)],
        };
      }

      const along = (seg) => [0.5, 0.35, 0.65, 0.2, 0.8].map((t) => bezier(seg, t));

      function placeLabels(m, paths) {
        const boxes = m.nodes.map((n) => [n.x - 2, n.y - 2, n.x + n.w + 2, n.y + n.h + 2]);
        const points = paths.map((path) => path.segs.flatMap((seg) => d3.range(17).map((k) => bezier(seg, k / 16))));
        m.links.forEach((l, i) => {
          if (!l.label) return;
          const path = paths[i];
          const lines = fit(l.label, LABEL_CHARS, 2);
          const w = Math.max(...lines.map((s) => s.length)) * 6.3 + 12;
          const h = lines.length * 12 + 6;
          const box = ([x, y]) => [x - w / 2, y - h / 2, x + w / 2, y + h / 2];
          const hits = (b) =>
            boxes.some((o) => b[0] < o[2] && b[2] > o[0] && b[1] < o[3] && b[3] > o[1]) ||
            points.some((list, j) => j !== i && list.some(([x, y]) => x > b[0] && x < b[2] && y > b[1] && y < b[3]));
          const spot = path.spots.find((s) => !hits(box(s))) || path.spots[0];
          Object.assign(path, { mark: spot, lines, w, h });
          boxes.push(box(spot));
        });
      }

      const ownParts = (l) => (l.bundle ? (l.parts ?? []).slice(0, 1) : (l.parts ?? []));

      function drawLink(g, l, path) {
        const k = l.kind;
        const looks = [k.tone && ui.toneClass(k.tone), k.quiet && 'v-sm-quiet'].filter(Boolean);
        const one = g.append('g').attr('class', looks.join(' ') || null);
        l.parts = [one.node()];
        l.d = curve(path.segs);
        const group = l.bundle;
        if (group && !group.parts.length) {
          const trunk = g.append('g').attr('class', ['v-sm-trunk', ...looks].join(' '));
          trunk.append('path').attr('class', `v-sm-link v-sm-${k.line}`).attr('d', curve(path.trunk));
          group.parts.push(trunk.node());
        }
        if (group) l.parts.push(group.parts[0]);
        one.append('path').attr('class', `v-sm-link v-sm-${k.line}`).attr('d', group ? curve(path.branch) : l.d);
        const [, , c2, end] = path.segs[path.segs.length - 1];
        const angle = (Math.atan2(end[1] - c2[1], end[0] - c2[0]) * 180) / Math.PI;
        if (k.end === 'arrow')
          one
            .append('path')
            .attr('class', 'v-sm-arrow')
            .attr('d', 'M0,0L-8,-4L-8,4Z')
            .attr('transform', `translate(${pt(end)}) rotate(${r1(angle)})`);
        else if (k.end === 'ring')
          one.append('circle').attr('class', 'v-sm-ring').attr('cx', r1(end[0])).attr('cy', r1(end[1])).attr('r', 3.6);
      }

      function drawMark(g, l, path) {
        const [x, y] = path.mark;
        const group = l.bundle;
        if (group?.parts.length > 1) {
          l.parts.push(group.parts[1]);
          return;
        }
        const one = g.append('g').attr('class', [l.kind.tone && ui.toneClass(l.kind.tone), l.kind.quiet && 'v-sm-quiet'].filter(Boolean).join(' ') || null);
        l.parts.push(one.node());
        group?.parts.push(one.node());
        if (!l.label) {
          if (l.to.stage.i > l.from.stage.i) one.append('circle').attr('class', 'v-sm-hand').attr('cx', r1(x)).attr('cy', r1(y)).attr('r', 2.6);
          return;
        }
        const { lines, w, h } = path;
        one
          .append('rect')
          .attr('class', 'v-sm-pill')
          .attr('x', r1(x - w / 2))
          .attr('y', r1(y - h / 2))
          .attr('width', r1(w))
          .attr('height', h)
          .attr('rx', 6);
        const text = one.append('text').attr('class', 'v-sm-pilltxt').attr('text-anchor', 'middle');
        lines.forEach((line, k) => {
          text.append('tspan').attr('x', r1(x)).attr('y', r1(y - h / 2 + 12 + k * 12)).text(line);
        });
      }

      function zoneBoxes(z, nodes) {
        const members = nodes.filter((n) => n.zone === z);
        const box = (list) => ({
          x0: Math.min(...list.map((n) => n.x)) - 9,
          x1: Math.max(...list.map((n) => n.x + n.w)) + 9,
          y0: Math.min(...list.map((n) => n.y)) - 21,
          y1: Math.max(...list.map((n) => n.y + n.h)) + 9,
        });
        const covers = (b) =>
          nodes.some((n) => n.zone !== z && n.x < b.x1 && n.x + n.w > b.x0 && n.y < b.y1 && n.y + n.h > b.y0);
        const whole = box(members);
        if (!covers(whole)) return [whole];
        const runs = [];
        for (const [i, list] of d3.groups(members, (n) => n.lane.i).sort((a, b) => a[0] - b[0])) {
          const last = runs[runs.length - 1];
          if (last && last.lane === i - 1) Object.assign(last, { lane: i, list: [...last.list, ...list] });
          else runs.push({ lane: i, list });
        }
        return runs.flatMap((r) => {
          const b = box(r.list);
          return covers(b) ? d3.groups(r.list, (n) => n.lane.i).map(([, list]) => box(list)) : [b];
        });
      }

      function drawZone(parent, z, boxes) {
        const g = parent.append('g').attr('class', z.tone ? `v-sm-toned ${ui.toneClass(z.tone)}` : null);
        boxes.forEach((b, k) => {
          g.append('rect').attr('class', 'v-sm-zone').attr('x', b.x0).attr('y', b.y0).attr('width', b.x1 - b.x0).attr('height', b.y1 - b.y0).attr('rx', 12);
          if (k === 0)
            g.append('text').attr('class', 'v-sm-zonelabel').attr('x', b.x0 + 10).attr('y', b.y0 + 14).text(fit(z.label, Math.floor((b.x1 - b.x0 - 16) / 6.6), 1)[0]);
        });
      }

      function drawGrid(ctx, m, width) {
        const grid = layoutGrid(m, width);
        const { W, H, labelW } = grid;
        m.gridH = H;
        const names = d3.create('svg').attr('aria-hidden', 'true');
        const svg = d3.create('svg').attr('role', 'group').attr('aria-label', name(m));
        const back = svg.append('g').attr('aria-hidden', 'true');
        for (const lane of m.lanes) {
          for (const [s, x0] of [
            [names, 0],
            [back, labelW - 12],
          ])
            s.append('rect').attr('class', 'v-sm-band').attr('x', x0).attr('y', lane.y).attr('width', W).attr('height', lane.h).attr('rx', 6);
          const name = names.append('text').attr('class', 'v-sm-lane');
          const lines = fit(lane.label, Math.floor((labelW - 18) / 7.2), 3);
          lines.forEach((line, k) => {
            name.append('tspan').attr('x', 10).attr('y', lane.y + 22 + k * 15).text(line);
          });
          lane.nameH = 22 + (lines.length - 1) * 15 + 8;
          lane.nameEl = name.node();
        }
        for (const s of m.stages) {
          if (m.panel)
            back.append('rect').attr('class', 'v-sm-chosen').attr('data-col', s.id).attr('x', s.x).attr('y', HEAD - 4).attr('width', s.w).attr('height', H - HEAD - 2);
          if (s.i > 0)
            back.append('line').attr('class', 'v-sm-divider').attr('x1', s.x).attr('x2', s.x).attr('y1', HEAD - 6).attr('y2', H - 6);
        }
        const zones = svg.append('g').attr('aria-hidden', 'true');
        for (const z of m.zones) drawZone(zones, z, zoneBoxes(z, m.nodes));
        const paths = m.links.map((l) => route(l, m, grid));
        placeLabels(m, paths);
        const links = svg.append('g').attr('aria-hidden', 'true');
        for (const [i, l] of m.links.entries()) drawLink(links, l, paths[i]);
        const cards = drawCards(svg, m);
        const marks = svg.append('g').attr('aria-hidden', 'true');
        for (const [i, l] of m.links.entries()) drawMark(marks, l, paths[i]);
        svg.append('g').attr('class', 'v-sm-dots').attr('aria-hidden', 'true');
        const headRow = svg.append('g').attr('class', 'v-sm-headrow');
        headRow
          .append('rect')
          .attr('class', 'v-sm-headbg')
          .attr('x', labelW)
          .attr('y', 0)
          .attr('width', W - labelW)
          .attr('height', HEAD)
          .attr('aria-hidden', 'true');
        headRow
          .append('line')
          .attr('class', 'v-sm-headline')
          .attr('x1', labelW)
          .attr('x2', W)
          .attr('y1', HEAD - 0.5)
          .attr('y2', HEAD - 0.5)
          .attr('aria-hidden', 'true');
        const heads = headRow
          .selectAll('g')
          .data(m.stages)
          .join('g')
          .attr('class', m.panel ? 'v-sm-head v-sm-stagebtn' : 'v-sm-head')
          .attr('data-stage', (s) => s.id);
        heads
          .append('rect')
          .attr('class', 'v-sm-stagebg')
          .attr('x', (s) => s.x + 8)
          .attr('y', 4)
          .attr('width', (s) => s.w - 16)
          .attr('height', 24)
          .attr('rx', 6);
        const flagged = (s) => flagFit(s, (s.w - 16) / 2);
        heads
          .append('text')
          .attr('class', 'v-sm-stage')
          .attr('x', (s) => s.x + (s.w - flagged(s).w) / 2)
          .attr('y', HEAD - 14)
          .attr('text-anchor', 'middle')
          .text((s) => fit(s.label, Math.floor((s.w - 20 - flagged(s).w) / 7.4), 1)[0]);
        heads.each(function (s) {
          drawFlag(d3.select(this), s, flagged(s), s.x + s.w - 12, 7.5);
        });
        if (m.panel)
          heads
            .attr('role', 'button')
            .attr('tabindex', 0)
            .attr('aria-pressed', 'false')
            .attr('aria-label', (s) => headName(m, s));
        names.attr('viewBox', `0 0 ${labelW} ${H}`).attr('width', labelW).style('width', `${labelW}px`);
        svg.attr('viewBox', `${labelW} 0 ${W - labelW} ${H}`).attr('width', W - labelW).style('width', `${W - labelW}px`);
        return { names, svg, cards: cards.sort((a, b) => a.stage.i - b.stage.i || a.y - b.y || a.x - b.x), heads };
      }

      function drawCards(svg, m) {
        const cards = svg
          .append('g')
          .selectAll('g')
          .data(m.nodes)
          .join('g')
          .attr('data-card', (n) => n.id)
          .attr('class', (n) => `v-sm-node sm-item ${ui.toneClass(n.tone || n.lane.tone || 'teal')}${n.milestone ? ' v-sm-milestone' : ''}`);
        cards.each(function (n) {
          const c = d3.select(this);
          c.append('rect').attr('class', 'v-sm-card').attr('x', n.x).attr('y', n.y).attr('width', n.w).attr('height', n.h).attr('rx', 7);
          c.append('rect').attr('class', 'v-sm-edge').attr('x', n.x).attr('y', n.y + 5).attr('width', 4).attr('height', n.h - 10).attr('rx', 2);
          const name = c.append('text').attr('class', 'v-sm-name');
          n.lines.forEach((line, k) => {
            name.append('tspan').attr('x', n.x + 14).attr('y', n.y + 21 + k * 16).text(line);
          });
          if (n.next) {
            const next = c.append('text').attr('class', 'v-sm-who');
            n.next.forEach((line, k) => {
              next.append('tspan').attr('x', n.x + 14).attr('y', n.y + 20 + n.lines.length * 16 + k * 15).text(line);
            });
          }
          const cy = n.y + n.h - 24;
          let left = n.x + 14;
          if (n.status) {
            const st = m.statusLookup.get(n.status);
            const word = st?.label || m.word(n.status);
            const cw = word.length * 6.4 + 26;
            const chip = c.append('g').attr('class', statusLook(st));
            chip.append('rect').attr('class', 'sm-chip-bg').attr('x', n.x + 12).attr('y', cy).attr('width', cw).attr('height', 17).attr('rx', 8.5);
            drawGlyph(chip, st, n.x + 22, cy + 8.5);
            chip.append('text').attr('class', 'sm-chip-txt').attr('x', n.x + 30).attr('y', cy + 12.2).text(word);
            left = n.x + 12 + cw + 8;
          }
          const room = Math.floor((n.x + n.w - 10 - left) / 6.2);
          if (n.sub && room >= 4)
            c.append('text').attr('class', 'v-sm-who').attr('x', n.x + n.w - 10).attr('y', cy + 12.5).attr('text-anchor', 'end').text(fit(n.sub, room, 1)[0]);
        });
        return cards;
      }

      const STACK_BELOW = 500;
      const MIN_ROOM = 200;
      const RAIL = 38;
      const INSET = 10;
      const LANE_LINE = 16;
      const ZONE_ROOM_STACK = 24;

      const whole = (text, room) => {
        const max = Math.max(1, room);
        return util.wrap(text, max).flatMap((line) => line.match(new RegExp(`.{1,${max}}`, 'gu')));
      };

      function layoutStack(m, width) {
        const cells = orderedCells(m);
        const left = RAIL + INSET;
        const cardW = width - left - INSET;
        const chars = Math.max(8, Math.floor((cardW - 22) / 7.3));
        const nextChars = Math.max(8, Math.floor((cardW - 22) / 6.2));
        for (const n of m.nodes) {
          const next = m.links.filter((l) => l.from === n && l.to !== n).map((l) => `${l.to.label}${l.label ? ` (${l.label})` : ''}`);
          n.lines = fit(n.label, chars, 3);
          n.next = next.length ? fit(`→ ${next.join(', ')}`, nextChars, 2) : [];
        }
        const bands = [];
        let y = 0;
        for (const s of m.stages) {
          const flag = flagFit(s, (width - RAIL - 20) / 2);
          const lines = whole(s.label, Math.floor((width - RAIL - 20 - flag.w) / 7.4));
          Object.assign(s, { x: RAIL, w: width - RAIL - 1, y, lines, flag_: flag, headH: 12 + lines.length * LANE_LINE });
          y += s.headH + 6;
          for (const lane of m.lanes) {
            const list = cells.get(lane.i)?.get(s.i);
            if (!list) continue;
            const names = whole(lane.label, Math.floor((cardW - 8) / 7.2));
            const top = y;
            let at = top + 12 + names.length * LANE_LINE;
            list.forEach((n, k) => {
              if (n.zone && n.zone !== list[k - 1]?.zone) at += ZONE_ROOM_STACK;
              const h = 64 + (n.lines.length - 1) * 16 + n.next.length * 15;
              Object.assign(n, { x: left, y: at, w: cardW, h });
              at += h + GAP;
            });
            const h = at - GAP + INSET - top;
            bands.push({ lane, names, y: top, h });
            y += h + 6;
          }
          s.h = y - s.y;
          y += 10;
        }
        for (const n of m.nodes) {
          const ends = [
            ...m.links.filter((l) => l.from === n).map((l) => ({ l, end: 'yOut', other: l.to })),
            ...m.links.filter((l) => l.to === n).map((l) => ({ l, end: 'yIn', other: l.from })),
          ].sort((a, b) => a.other.y - b.other.y);
          ends.forEach(({ l, end }, k) => {
            l[end] = n.y + (n.h * (k + 1)) / (ends.length + 1);
          });
        }
        return { W: width, H: y, bands };
      }

      function routeStack(l) {
        const reach = Math.min(44, 14 + Math.abs(l.yIn - l.yOut) / 40) / 0.75;
        const x = l.from.x;
        return { segs: [[[x, l.yOut], [x - reach, l.yOut], [x - reach, l.yIn], [x, l.yIn]]] };
      }

      function drawStack(ctx, m, width) {
        const { W, H, bands } = layoutStack(m, width);
        m.gridH = H;
        const svg = d3.create('svg').attr('role', 'group').attr('aria-label', name(m));
        const back = svg.append('g').attr('aria-hidden', 'true');
        for (const s of m.stages) {
          if (m.panel)
            back.append('rect').attr('class', 'v-sm-chosen').attr('data-col', s.id).attr('x', s.x).attr('y', s.y).attr('width', s.w).attr('height', s.h).attr('rx', 6);
        }
        for (const { lane, names, y, h } of bands) {
          back.append('rect').attr('class', 'v-sm-band').attr('x', RAIL).attr('y', y).attr('width', W - RAIL).attr('height', h).attr('rx', 6);
        }
        const zones = svg.append('g').attr('aria-hidden', 'true');
        for (const z of m.zones) {
          for (const s of m.stages) {
            const here = m.nodes.filter((n) => n.stage === s);
            if (here.some((n) => n.zone === z)) drawZone(zones, z, zoneBoxes(z, here));
          }
        }
        const laneNames = svg.append('g').attr('aria-hidden', 'true');
        for (const { names, y } of bands) {
          const name = laneNames.append('text').attr('class', 'v-sm-lane');
          names.forEach((line, k) => {
            name.append('tspan').attr('x', RAIL + INSET).attr('y', y + 20 + k * LANE_LINE).text(line);
          });
        }
        const links = svg.append('g').attr('aria-hidden', 'true');
        for (const l of m.links) drawLink(links, l, routeStack(l));
        const cards = drawCards(svg, m);
        svg.append('g').attr('class', 'v-sm-dots').attr('aria-hidden', 'true');
        const headRow = svg.append('g').attr('class', 'v-sm-headrow');
        const heads = headRow
          .selectAll('g')
          .data(m.stages)
          .join('g')
          .attr('class', m.panel ? 'v-sm-head v-sm-stagebtn' : 'v-sm-head')
          .attr('data-stage', (s) => s.id);
        heads
          .append('rect')
          .attr('class', 'v-sm-headbg')
          .attr('x', 0)
          .attr('y', (s) => s.y)
          .attr('width', W)
          .attr('height', (s) => s.headH + 1)
          .attr('aria-hidden', 'true');
        heads
          .append('line')
          .attr('class', 'v-sm-headline')
          .attr('x1', 0)
          .attr('x2', W)
          .attr('y1', (s) => s.y + s.headH + 0.5)
          .attr('y2', (s) => s.y + s.headH + 0.5)
          .attr('aria-hidden', 'true');
        heads
          .append('rect')
          .attr('class', 'v-sm-stagebg')
          .attr('x', (s) => s.x)
          .attr('y', (s) => s.y)
          .attr('width', (s) => s.w)
          .attr('height', (s) => s.headH)
          .attr('rx', 6);
        heads.each(function (s) {
          s.headEl = this;
          const label = d3.select(this).append('text').attr('class', 'v-sm-stage').attr('text-anchor', 'middle');
          s.lines.forEach((line, k) => {
            label.append('tspan').attr('x', s.x + (s.w - s.flag_.w) / 2).attr('y', s.y + 19 + k * LANE_LINE).text(line);
          });
          drawFlag(d3.select(this), s, s.flag_, s.x + s.w - 6, s.y + 5);
        });
        if (m.panel)
          heads
            .attr('role', 'button')
            .attr('tabindex', 0)
            .attr('aria-pressed', 'false')
            .attr('aria-label', (s) => headName(m, s));
        svg.attr('viewBox', `0 0 ${W} ${H}`).attr('width', W).style('width', `${W}px`);
        return {
          names: d3.create('svg').attr('aria-hidden', 'true').attr('width', 0),
          svg,
          cards: cards.sort((a, b) => a.stage.i - b.stage.i || a.y - b.y),
          heads,
        };
      }

      const LV_CARD = 150;
      const LV_GAP = 14;
      const LV_PAD = 14;
      const LV_HEAD = 30;
      const LV_CARD_H = 50;
      const LV_EMPTY = 18;

      const cardCount = (m) => m.nodes.length - (m.levels && m.target ? 1 : 0);

      function inVariant(m, id) {
        if (!id) return;
        const keep = (row) => !row.variants || several(row.variants).includes(id);
        m.nodes = m.nodes.filter((n) => n === m.target || keep(n));
        m.links = m.links.filter((l) => keep(l) && m.nodes.includes(l.from) && m.nodes.includes(l.to));
      }

      function layoutLevels(m, width) {
        const t = m.target;
        const wide = width >= 640;
        const boxW = t ? (wide ? Math.max(200, Math.min(300, Math.round(width * 0.28))) : width) : 0;
        const bandW = t ? (wide ? width - boxW - 64 : width - 24) : width;
        const per = Math.max(1, Math.floor((bandW - 2 * LV_PAD + LV_GAP) / (LV_CARD + LV_GAP)));
        const cardW = (bandW - 2 * LV_PAD - (per - 1) * LV_GAP) / per;
        let y = 0;
        for (const lane of m.lanes) {
          const list = m.nodes.filter((n) => n.lane === lane && n !== t).sort((a, b) => a.stage.i - b.stage.i || a.i - b.i);
          const rows = Math.ceil(list.length / per);
          list.forEach((n, k) => {
            const x = LV_PAD + (k % per) * (cardW + LV_GAP);
            Object.assign(n, { x, y: y + LV_HEAD + Math.floor(k / per) * (LV_CARD_H + LV_GAP), w: cardW, h: LV_CARD_H });
          });
          Object.assign(lane, { y, h: LV_HEAD + (rows ? rows * (LV_CARD_H + LV_GAP) - LV_GAP : LV_EMPTY) + LV_PAD, empty: !rows });
          y += lane.h + 8;
        }
        const bandsH = y - 8;
        const arrivals = t ? [...new Set(m.links.filter((l) => l.to === t).map((l) => l.from))] : [];
        const listH = 64 + Math.max(1, arrivals.length) * 19 + 12;
        const box = !t
          ? null
          : wide
            ? { x: width - boxW, y: 0, w: boxW, h: Math.max(bandsH, listH) }
            : { x: 0, y: bandsH + 40, w: width, h: listH };
        if (t) Object.assign(t, box);
        const H = !t ? bandsH : wide ? box.h : box.y + box.h;
        return { W: width, H, bandW, box, wide, arrivals };
      }

      function routeLevel(l, lv) {
        const c = l.from;
        const { box, bandW, wide } = lv;
        const p0 = [c.x + c.w, c.y + c.h / 2];
        const gy = c.y + c.h + LV_GAP / 2;
        const q1 = [c.x + c.w + LV_GAP / 2, gy];
        const first = [p0, [q1[0], p0[1]], [q1[0], p0[1]], q1];
        if (wide) {
          const port = [box.x, l.port];
          return { segs: [first, straight(q1, [bandW, gy]), bend([bandW, gy], port)] };
        }
        const x = bandW + 12;
        const top = box.y - 18;
        const port = [l.port, box.y];
        return {
          segs: [first, straight(q1, [x, gy]), straight([x, gy], [x, top]), [[x, top], [x, box.y - 4], [port[0], top + 4], port]],
        };
      }

      function drawLevels(ctx, m, width) {
        const lv = layoutLevels(m, width);
        const { W, H, bandW, box, wide } = lv;
        const t = m.target;
        const svg = d3.create('svg').attr('role', 'group').attr('aria-label', name(m));
        const back = svg.append('g').attr('aria-hidden', 'true');
        m.lanes.forEach((lane, k) => {
          const g = back.append('g').attr('class', ui.toneClass(lane.tone || 'teal'));
          g.append('rect').attr('class', 'v-sm-levelband').attr('x', 0).attr('y', lane.y).attr('width', bandW).attr('height', lane.h).attr('rx', 8);
          g.append('rect').attr('class', 'v-sm-edge').attr('x', 0).attr('y', lane.y + 6).attr('width', 4).attr('height', lane.h - 12).attr('rx', 2);
          g.append('text')
            .attr('class', 'v-sm-level')
            .attr('x', LV_PAD)
            .attr('y', lane.y + 20)
            .text(fit(`Level ${k + 1}: ${lane.label}`, Math.floor((bandW - 2 * LV_PAD) / 7), 1)[0]);
          if (lane.empty)
            g.append('text')
              .attr('class', 'v-sm-who')
              .attr('x', LV_PAD)
              .attr('y', lane.y + LV_HEAD + 12)
              .text(m.variant ? 'No cards in this variant' : 'No cards');
        });
        const into = m.links;
        into.sort((a, b) => (wide ? a.from.y - b.from.y || a.from.x - b.from.x : a.from.x - b.from.x || a.from.y - b.from.y));
        into.forEach((l, k) => {
          l.port = wide ? box.y + 60 + ((box.h - 76) * (k + 1)) / (into.length + 1) : box.x + 16 + ((box.w - 32) * (k + 1)) / (into.length + 1);
        });
        const links = svg.append('g').attr('aria-hidden', 'true');
        for (const l of into) drawLink(links, l, routeLevel(l, lv));

        const marks = m.nodes.filter((n) => n !== t);
        const cards = svg
          .append('g')
          .selectAll('g')
          .data(t ? [...marks, t] : marks)
          .join('g')
          .attr('data-card', (n) => n.id)
          .attr('class', (n) => `v-sm-node sm-item ${ui.toneClass(n.tone || n.lane.tone || 'teal')}${n === t ? ' v-sm-targetbox' : ''}`);
        cards.each(function (n) {
          const c = d3.select(this);
          if (n === t) return;
          c.append('rect').attr('class', 'v-sm-card').attr('x', n.x).attr('y', n.y).attr('width', n.w).attr('height', n.h).attr('rx', 6);
          const room = Math.floor((n.w - (n.status ? 40 : 20)) / 7.6);
          c.append('text').attr('class', 'v-sm-lvname').attr('x', n.x + 10).attr('y', n.y + 20).text(fit(n.label, room, 1)[0]);
          if (n.sub) c.append('text').attr('class', 'v-sm-who').attr('x', n.x + 10).attr('y', n.y + 38).text(fit(n.sub, Math.floor((n.w - 20) / 6.2), 1)[0]);
          if (n.status) {
            const st = m.statusLookup.get(n.status);
            const g = c.append('g').attr('class', statusLook(st));
            drawGlyph(g, st, n.x + n.w - 14, n.y + 15);
          }
        });
        m.arrivals = [];
        if (t) {
          const g = cards.filter((n) => n === t);
          g.append('rect').attr('class', 'v-sm-target').attr('x', box.x).attr('y', box.y).attr('width', box.w).attr('height', box.h).attr('rx', 10);
          g.append('text').attr('class', 'v-sm-stage').attr('x', box.x + 16).attr('y', box.y + 22).text('Target');
          g.append('text').attr('class', 'v-sm-name').attr('x', box.x + 16).attr('y', box.y + 42).text(fit(t.label, Math.floor((box.w - 32) / 7.4), 1)[0]);
          lv.arrivals.forEach((n, k) => {
            const at = d3.min(into.filter((l) => l.from === n), (l) => l.at) ?? null;
            const line = g
              .append('text')
              .attr('class', 'v-sm-arrived')
              .attr('x', box.x + 16)
              .attr('y', box.y + 70 + k * 19)
              .text(`✓ ${fit(n.label, Math.floor((box.w - 44) / 7.2), 1)[0]}`);
            m.arrivals.push({ el: line.node(), at });
          });
          if (!lv.arrivals.length)
            g.append('text').attr('class', 'v-sm-who').attr('x', box.x + 16).attr('y', box.y + 70).text('Nothing links into it yet.');
        }
        svg.append('g').attr('class', 'v-sm-dots').attr('aria-hidden', 'true');
        svg.attr('viewBox', `0 0 ${W} ${H}`).attr('width', W).style('width', `${W}px`);
        const order = (a, b) => (a === t) - (b === t) || a.lane.i - b.lane.i || a.y - b.y || a.x - b.x;
        return { names: d3.create('svg').attr('aria-hidden', 'true').attr('width', 0), svg, cards: cards.sort(order), heads: d3.selectAll([]) };
      }

      function variantSwitch(ctx, m) {
        const host = ctx.select('.v-sm-variants');
        host.replaceChildren();
        if (!m.levels || !m.variants.length) return;
        const place = ctx.state;
        host.append(Object.assign(document.createElement('span'), { className: 'sm-count', textContent: 'Variant' }));
        for (const v of m.variants) {
          const b = Object.assign(document.createElement('button'), { type: 'button', className: 'sm-btn', textContent: v.label });
          b.setAttribute('aria-pressed', String(v.id === m.variant));
          b.addEventListener('click', () => {
            if (v.id === m.variant) return;
            place.variant = v.id;
            place.variantFocus = v.id;
            setTimeout(ctx.redraw);
          });
          host.append(b);
          if (place.variantFocus === v.id) {
            place.variantFocus = undefined;
            b.focus({ preventScroll: true });
          }
        }
        if (cardCount(m) < m.allCards) {
          const note = `Showing ${cardCount(m)} of ${m.allCards} cards. The written text still covers all ${m.allCards}.`;
          host.append(Object.assign(document.createElement('span'), { className: 'sm-count v-sm-varnote', textContent: note }));
        }
      }

      const fmtDay = (date) =>
        date ? new Date(`${date}T00:00:00Z`).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', timeZone: 'UTC' }) : '';

      function drawDates(ctx, m, width) {
        const box = ctx.select('.v-sm-picture');
        box.classList.add('v-sm-table');
        box.style.setProperty('--lane-w', `${width <= 560 ? 104 : 150}px`);
        const laneW = width <= 560 ? 104 : 150;
        const inner = box.clientWidth || width - 2;
        const whole = Math.max(1, Math.floor((inner - laneW) / 120));
        const dayW = (inner - laneW) / Math.min(whole, m.stages.length);
        const table = d3
          .create('table')
          .attr('class', 'v-sm-dates')
          .style('--lane-w', `${laneW}px`)
          .style('--days', m.stages.length)
          .style('--day-w', `${dayW}px`);
        const head = table.append('thead').append('tr');
        head.append('th').attr('scope', 'col').attr('class', 'v-sm-rowhead').text('Lane');
        const heads = head
          .selectAll('th.v-sm-colhead')
          .data(m.stages)
          .join('th')
          .attr('scope', 'col')
          .attr('class', 'v-sm-colhead')
          .attr('data-col', (s) => s.id)
          .append(m.panel ? 'button' : 'span')
          .attr('class', 'v-sm-head')
          .attr('data-stage', (s) => s.id);
        if (m.panel) heads.attr('type', 'button').attr('aria-pressed', 'false');
        heads.append('span').text((s) => s.label);
        heads.filter((s) => s.date).append('small').text((s) => fmtDay(s.date));
        heads.filter((s) => s.flag).append((s) => ui.chip(s.flag, { tone: s.tone || FLAG_TONE }));
        const body = table.append('tbody');
        const chips = [];
        m.lanes.forEach((lane, k) => {
          const tr = body.append('tr');
          const name = tr.append('th').attr('scope', 'row').attr('class', `v-sm-rowhead ${ui.toneClass(lane.tone || 'teal')}`);
          name.append('span').attr('class', 'v-sm-num').text(String(k + 1).padStart(2, '0'));
          name.append('span').text(lane.label);
          for (const s of m.stages) {
            const td = tr.append('td').attr('data-col', s.id);
            const here = m.nodes.filter((n) => n.lane === lane && n.stage === s);
            if (!here.length) td.append('span').attr('class', 'v-sm-none').attr('aria-hidden', 'true').text('–');
            for (const n of here) {
              const st = n.status ? m.statusLookup.get(n.status) : null;
              const look = st ? statusLook(st) : ui.toneClass(n.tone || lane.tone || 'teal');
              const chip = td
                .append('span')
                .datum(n)
                .attr('data-card', n.id)
                .attr('class', `v-sm-chip sm-item ${look}${n.milestone ? ' v-sm-mile' : ''}`);
              if (n.status) {
                const svg = chip.append('svg').attr('viewBox', '-5 -5 10 10').attr('aria-hidden', 'true');
                drawGlyph(svg, st, 0, 0);
              }
              chip.append('span').attr('class', 'v-sm-chiptext').text(n.label);
              chips.push(chip.node());
            }
          }
        });
        return { names: d3.create('svg').attr('aria-hidden', 'true').attr('width', 0), svg: table, cards: d3.selectAll(chips), heads };
      }

      function lineSet(spec, last) {
        const out = new Set();
        for (const part of String(spec || '').split(',')) {
          const [a, b = a] = part.split('-').map((s) => Number(s.trim()));
          if (!Number.isInteger(a) || !Number.isInteger(b)) continue;
          for (let k = Math.max(1, Math.min(a, b)); k <= Math.min(last, Math.max(a, b)); k++) out.add(k);
        }
        return out;
      }

      function writePanel(ctx, m, entry) {
        const q = ctx.select;
        q('.v-sm-panel').hidden = !m.panel || m.hosted.has('stage') || (!entry && m.levels);
        q('.v-sm-kicker').textContent = entry ? entry.kicker || '' : '';
        q('.v-sm-ptitle').textContent = entry ? entry.label || entry.title : 'Choose a stage';
        if (entry?.flag) q('.v-sm-ptitle').append(' ', ui.chip(entry.flag, { tone: entry.tone || FLAG_TONE }));
        stagemap.markdown(
          q('.v-sm-ptext'),
          entry ? (entry.text ?? null) : `Choose a stage in the picture${m.player ? ', or a step below it,' : ''} to see what happens there.`,
          { field: entry ? (entry.textField ?? 'stages.text') : null, id: entry?.id ?? null },
        );
        const file = q('.v-sm-file');
        const code = entry?.code;
        file.hidden = !code;
        q('.v-sm-panel').classList.toggle('v-sm-two', Boolean(code));
        if (!code) return;
        const lines = code.split('\n');
        const marked = lineSet(entry.highlight, lines.length);
        q('.v-sm-fname').textContent = entry.file || 'File';
        q('.v-sm-fnote').textContent = marked.size
          ? `Changed lines: ${String(entry.highlight).replace(/\s*-\s*/g, ' to ')}.`
          : '';
        q('.v-sm-code').setAttribute('aria-label', entry.file || 'File');
        q('.v-sm-code code').replaceChildren(
          ...lines.map((line, k) => {
            const span = document.createElement('span');
            span.dataset.n = k + 1;
            span.textContent = line || ' ';
            if (marked.has(k + 1)) span.className = 'v-sm-hl';
            return span;
          }),
        );
      }

      function reveal(ctx, id) {
        const box = ctx.select('.v-sm-picture');
        const head = [...box.querySelectorAll('.v-sm-head')].find((el) => el.dataset.stage === id);
        if (head) ui.reveal(box, head);
      }

      const stageDetails = (s) => {
        const out = { title: s.label };
        for (const key of ['kicker', 'text', 'flag', 'tone', ...STEP_PANEL]) if (given(s, key)) out[key] = s[key];
        return out;
      };

      function selections(ctx) {
        ctx.state.selected ??= { card: null, stage: null };
        const now = ctx.state.selected;
        const changed = new Map();
        let holding = false;
        const say = (kind, one, by, still = null, from = null, via = null) =>
          ctx.emit('stagemap:select', {
            kind,
            id: one?.id ?? null,
            ids: one?.ids ?? [],
            from,
            label: one?.details?.title ?? null,
            details: one?.details ?? null,
            about: null,
            still,
            by,
            via,
          });
        const flush = () => {
          holding = false;
          const said = [...changed];
          changed.clear();
          if (said.length === 2 && !now.card && !now.stage) {
            say('all', null, said[0][1].by, null, (said.find(([kind]) => kind === 'card') ?? said[0])[1].from, said[0][1].via);
            return;
          }
          for (const [kind, { by, via, from }] of said) {
            const other = kind === 'card' ? 'stage' : 'card';
            say(kind, now[kind], by, !now[kind] && now[other] ? { kind: other, ...now[other] } : null, from, via);
          }
        };
        return {
          now,
          flush,
          hold() {
            holding = true;
          },
          set(kind, one, by, via = null) {
            changed.set(kind, { by, via, from: changed.get(kind)?.from ?? now[kind]?.id ?? null });
            now[kind] = one;
            if (!holding) flush();
          },
        };
      }

      function stageButtons(ctx, m, buttons, refresh, resting, said, letGoAll) {
        const place = ctx.state;
        const choose = (id, by, via = null) => {
          show(id, by, via);
          if (id) reveal(ctx, id);
        };
        const show = (chosen, by = 'reader', via = null) => {
          const rest = chosen ? null : resting();
          const id = chosen || rest?.id || null;
          place.stage = id;
          place.chosen = Boolean(chosen);
          ctx.select('.v-sm-body').classList.toggle('v-sm-reading', Boolean(chosen));
          for (const b of buttons.nodes()) b.setAttribute('aria-pressed', String(b.dataset.stage === id));
          for (const el of ctx.select('.v-sm-picture').querySelectorAll('[data-col]'))
            el.classList.toggle('v-sm-on', el.dataset.col === id);
          const stage = m.stages.find((s) => s.id === id);
          writePanel(ctx, m, (chosen ? null : rest?.entry) || stage || null);
          refresh();
          const one = chosen ? { id: chosen, ids: [chosen], details: stageDetails(stage) } : null;
          if ((said.now.stage?.id ?? null) !== (one?.id ?? null)) said.set('stage', one, by, via);
          else if (one && by === 'data' && JSON.stringify(said.now.stage.details) !== JSON.stringify(one.details)) said.set('stage', one, 'data');
          else said.now.stage = one;
        };
        const again = (s) => place.chosen && place.stage === s.id;
        buttons
          .on('click', (e, s) => {
            const via = e.detail === 0 ? 'key' : 'click';
            if (again(s)) letGoAll(via);
            else choose(s.id, 'reader', via);
          })
          .on('keydown', (e, s) => {
            if ((e.key === 'Enter' || e.key === ' ') && e.currentTarget.tagName !== 'BUTTON') {
              e.preventDefault();
              if (again(s)) letGoAll('key');
              else choose(s.id, 'reader', 'key');
            }
          });
        const panel = ctx.select('.v-sm-panel');
        ctx.outside((e) => {
          if (m.o.dismiss === 'no_outside' && !ctx.root.contains(e.target)) return;
          if (!place.chosen || buttons.nodes().some((b) => b.contains(e.target)) || panel.contains(e.target)) return;
          if (ctx.root.contains(e.target) && e.target.closest('.sm-item, .v-sm-tools, .v-sm-steps, .v-sm-caption')) return;
          show(null, 'reader', e.detail === 0 ? 'key' : 'click');
        });
        ctx.cleanup(() => {
          place.stageFocus = buttons.nodes().find((b) => b === document.activeElement)?.dataset.stage;
        });
        show(place.chosen && m.stages.some((s) => s.id === place.stage) ? place.stage : null, 'data');
        const back = buttons.nodes().find((b) => b.dataset.stage === place.stageFocus);
        place.stageFocus = undefined;
        back?.focus({ preventScroll: true });
        return { show, choose };
      }

      const stepEntry = (s) =>
        s.stage
          ? { ...s.stage, kicker: s.kicker || s.stage.kicker, ...(s.code ? { file: s.file, code: s.code, highlight: s.highlight } : {}) }
          : {
              id: s.id,
              textField: 'steps.text',
              kicker: s.kicker,
              title: s.label,
              text: s.text,
              file: s.file,
              code: s.code,
              highlight: s.highlight,
            };

      function changesAt(m, i) {
        const was = new Map(fold(m.source, i - 1).nodes.map((n) => [n.id, n]));
        const here = new Set(m.nodes.map((n) => n.id));
        const stage = (id) => m.stages.find((x) => x.id === id)?.label ?? id;
        const list = (words) => (words.length > 1 ? `${words.slice(0, -1).join(', ')} and ${words.at(-1)}` : words[0]);
        const said = [];
        for (const n of fold(m.source, i).nodes) {
          const before = was.get(n.id);
          const gone = n.hidden === true;
          if (!before || (gone && before.hidden === true) || (!gone && !here.has(n.id))) continue;
          const parts = gone ? ['hidden'] : [];
          if (!gone && before.hidden === true) parts.push('shown again');
          if (!gone && n.status !== before.status && n.status) parts.push(`now ${m.word(n.status)}`);
          if (!gone && n.stage !== before.stage) parts.push(`moved to ${stage(n.stage)}`);
          if (parts.length) said.push(`${n.label}, ${list(parts)}`);
        }
        return said.length ? ` Changed: ${said.join('; ')}.` : '';
      }

      function steps(ctx, m, cards, stages) {
        const dots = ctx.select('.v-sm-dots');
        return ui.player(ctx, {
          controls: ctx.select('.v-sm-tools'),
          caption: ctx.select('.v-sm-caption'),
          list: ctx.select('.v-sm-steps'),
          steps: m.steps.map((s) => ({ ...s, title: s.label })),
          intro: m.o.intro ?? undefined,
          motion: m.o.motion !== false,
          onStep(i, wanted) {
            const asked = wanted.again ? ctx.state.stepAsked : undefined;
            if (wanted.again) ctx.state.stepAsked = undefined;
            const { animate, again } = asked ?? wanted;
            if (!again && fold(m.source, i).sig !== ctx.state.foldSig) {
              ctx.state.stepAsked = { animate, again: false };
              if (animate && i >= 0 && !stagemap.reducedMotion()) {
                const boxes = new Map();
                cards.each(function (n) {
                  if (n?.id != null) boxes.set(String(n.id), this.getBoundingClientRect());
                });
                ctx.state.cardBoxes = boxes;
              } else {
                delete ctx.state.cardBoxes;
              }
              if (!ctx.state.stepWaiting) {
                ctx.state.stepWaiting = true;
                queueMicrotask(() => {
                  ctx.state.stepWaiting = false;
                  ctx.redraw();
                });
              }
              return;
            }
            const s = m.steps[i];
            const arriving = new Set((m.every || m.links).filter((l) => l.at === i).map((l) => l.to));
            const now = !s ? [] : m.nodes.filter((n) => (arriving.size ? arriving.has(n) : n.stage === s.stage));
            const names = now.map((n) => n.label).join(', ');
            ctx.select('.v-sm-summary').textContent =
              m.summary +
              (s ? ` Showing step ${i + 1} of ${m.steps.length}: ${s.label}${names ? `; now: ${names}` : ''}.${changesAt(m, i)}` : '');
            if (s && names) {
              ctx.select('.v-sm-caption').append(Object.assign(document.createElement('p'), { className: 'v-sm-nowline', textContent: `Now: ${names}` }));
            }
            cards.each(function (n) {
              this.classList.toggle('v-sm-later', Boolean(s) && n.stage.i > s.reach);
              this.classList.toggle('v-sm-now', now.includes(n));
            });
            for (const l of m.links) {
              const reveal = m.lit(l) || (m.shown ? l.from === m.shown || l.to === m.shown : Boolean(s) && l.at === i);
              for (const el of ownParts(l)) {
                el.classList.toggle('v-sm-later', Boolean(s) && l.at !== null && l.at > i);
                if (l.kind.quiet) el.classList.toggle('v-sm-quiet', !reveal);
              }
            }
            for (const b of m.bundles ?? []) {
              const reveal =
                b.links.some(m.lit) || (m.shown ? b.links.some((l) => l.from === m.shown || l.to === m.shown) : Boolean(s) && b.links.some((l) => l.at === i));
              for (const el of b.parts) {
                el.classList.toggle('v-sm-later', Boolean(s) && b.links.every((l) => l.at !== null && l.at > i));
                if (b.kind.quiet) el.classList.toggle('v-sm-quiet', !reveal);
              }
            }
            for (const a of m.arrivals || []) {
              a.el.classList.toggle('v-sm-later', Boolean(s) && a.at !== null && a.at > i);
            }
            dots?.replaceChildren();
            if (!again) {
              stages?.show(null);
              if (s?.stage) reveal(ctx, s.stage.id);
            }
            if (!s) return;
            m.links
              .filter((l) => l.at === i && l.d)
              .forEach((l, k) => {
                const dot = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
                dot.setAttribute('class', `v-sm-dot${l.kind.tone ? ` ${ui.toneClass(l.kind.tone)}` : ''}`);
                dot.setAttribute('r', 4.5);
                dots.append(dot);
                ui.travel(dot, l.d, { animate, delay: k * 0.12 });
              });
          },
        });
      }

      function legend(ctx, m) {
        const list = ctx.select('.v-sm-legend');
        list.replaceChildren();
        if (m.o.legend === false) return;
        if (m.dates) {
          const inUse = m.statuses.filter((st) => m.nodes.some((n) => n.status === st.id));
          for (const st of inUse) {
            const chip = document.createElement('span');
            chip.className = `v-sm-chip ${statusLook(st)}`;
            const svg = d3.create('svg').attr('viewBox', '-5 -5 10 10').attr('aria-hidden', 'true');
            drawGlyph(svg, st, 0, 0);
            chip.append(svg.node(), st.label);
            list.append(Object.assign(document.createElement('li'), {}));
            list.lastChild.append(chip);
          }
          if (m.nodes.some((n) => n.milestone)) {
            const li = document.createElement('li');
            li.append(Object.assign(document.createElement('span'), { className: 'v-sm-chip sm-t-teal v-sm-mile', textContent: 'Milestone' }));
            list.append(li);
          }
          return;
        }
        const used = [...new Set(m.links.map((l) => l.kind))].sort((a, b) => (a.i ?? -1) - (b.i ?? -1));
        for (const k of used) {
          const li = document.createElement('li');
          if (k.tone) li.className = ui.toneClass(k.tone);
          const s = d3.create('svg').attr('viewBox', '0 -6 30 12').attr('aria-hidden', 'true');
          s.append('path').attr('class', `v-sm-link v-sm-${k.line}`).attr('d', k.end === 'none' ? 'M1,0H29' : 'M1,0H23');
          if (k.end === 'arrow') s.append('path').attr('class', 'v-sm-arrow').attr('d', 'M29,0L21,-4L21,4Z');
          if (k.end === 'ring') s.append('circle').attr('class', 'v-sm-ring').attr('cx', 25).attr('cy', 0).attr('r', 3.6);
          li.append(s.node(), k.label);
          list.append(li);
        }
        for (const z of m.zones) {
          const li = document.createElement('li');
          li.className = z.tone ? `v-sm-toned ${ui.toneClass(z.tone)}` : '';
          const s = d3.create('svg').attr('viewBox', '0 -6 30 12').attr('aria-hidden', 'true');
          s.append('rect').attr('class', 'v-sm-zone v-sm-swatch').attr('x', 2).attr('y', -5).attr('width', 26).attr('height', 10).attr('rx', 4);
          li.append(s.node(), z.label);
          list.append(li);
        }
      }

      function widthNeed(m, width) {
        if (m.levels) return 900;
        if (m.dates) return 150 + m.stages.length * 120;
        return gridNeed(m, width).need;
      }

      const sizeOf = (m) => {
        const stack_below = m.levels || m.dates ? null : STACK_BELOW;
        return { needs: widthNeed(m, Number.POSITIVE_INFINITY) + (m.dates ? 2 : 0), stack_below, stacksBelow: stack_below };
      };

      function visible(d, host) {
        const nodes = host.apply(d.nodes);
        const gone = new Set(nodes.filter((n) => n.hidden).map((n) => String(n.id)));
        return {
          ...d,
          nodes: nodes.filter((n) => !n.hidden),
          links: util.rows(d.links).filter((l) => !gone.has(String(l.from)) && !gone.has(String(l.to))),
        };
      }

      function keepInView(ctx, m, stacked) {
        if (m.levels) return;
        const doc = ctx.root.ownerDocument;
        const win = doc.defaultView;
        if (!win) return;
        let scroller = null;
        for (let el = ctx.root.parentElement; el && el !== doc.body && el !== doc.documentElement; el = el.parentElement) {
          const oy = win.getComputedStyle(el).overflowY;
          if ((oy === 'auto' || oy === 'scroll' || oy === 'overlay') && el.scrollHeight > el.clientHeight) {
            scroller = el;
            break;
          }
        }
        if (!scroller) return;
        const pic = ctx.select('.v-sm-picture');
        const target = m.dates ? pic.querySelector('table') : pic;
        if (!target) return;
        const thead = m.dates ? target.querySelector('thead') : null;
        const ths = thead ? [...thead.querySelectorAll('th')] : [];
        const headRow = m.dates ? null : pic.querySelector('.v-sm-headrow');
        const totalH = m.dates ? target.offsetHeight : (m.gridH || 0);
        const headH = m.dates ? (thead?.offsetHeight || HEAD) : HEAD;
        let alive = true;
        let frame = 0;
        let printing = false;
        const setShift = (el, y) => {
          if (!el) return;
          if (y > 0) el.setAttribute('transform', `translate(0,${r1(y)})`);
          else el.removeAttribute('transform');
        };
        const apply = () => {
          frame = 0;
          if (!alive) return;
          const raw = printing ? 0 : scroller.getBoundingClientRect().top - target.getBoundingClientRect().top;
          if (m.dates) {
            const off = Math.max(0, Math.min(Math.max(0, totalH - headH), raw));
            thead?.classList.toggle('v-sm-stuck', off > 0);
            for (const th of ths) {
              if (off > 0) th.style.transform = `translateY(${r1(off)}px)`;
              else th.style.removeProperty('transform');
            }
          } else if (stacked) {
            for (const s of m.stages) {
              const off = Math.max(0, Math.min(Math.max(0, s.h - s.headH), raw - s.y));
              s.headEl?.classList.toggle('v-sm-stuck', off > 0);
              setShift(s.headEl, off);
            }
          } else {
            const off = Math.max(0, Math.min(Math.max(0, totalH - HEAD), raw));
            headRow?.classList.toggle('v-sm-stuck', off > 0);
            setShift(headRow, off);
            for (const lane of m.lanes) {
              const lOff = off > 0 ? Math.max(0, Math.min(Math.max(0, lane.h - lane.nameH), raw + HEAD - lane.y)) : 0;
              setShift(lane.nameEl, lOff);
            }
          }
        };
        const onScroll = () => {
          if (!frame && alive) frame = win.requestAnimationFrame(apply);
        };
        const onBeforePrint = () => {
          printing = true;
          if (frame) {
            win.cancelAnimationFrame(frame);
            frame = 0;
          }
          apply();
        };
        const onAfterPrint = () => {
          printing = false;
          apply();
        };
        const onFocus = (e) => {
          const item = e.target?.closest?.('.sm-item');
          if (!item || printing || scroller.scrollTop <= 0) return;
          const sTop = scroller.getBoundingClientRect().top;
          const cTop = item.getBoundingClientRect().top;
          const cover = stacked
            ? Math.max(0, ...m.stages.map((s) => (s.headEl?.classList.contains('v-sm-stuck') ? s.headH : 0)))
            : headH;
          if (cTop < sTop + cover) {
            scroller.scrollTop = Math.max(0, scroller.scrollTop - (sTop + cover - cTop + 6));
            apply();
          }
        };
        scroller.addEventListener('scroll', onScroll, { passive: true });
        win.addEventListener('beforeprint', onBeforePrint);
        win.addEventListener('afterprint', onAfterPrint);
        ctx.root.addEventListener('focusin', onFocus);
        apply();
        ctx.cleanup(() => {
          alive = false;
          if (frame) {
            win.cancelAnimationFrame(frame);
            frame = 0;
          }
          scroller.removeEventListener('scroll', onScroll);
          win.removeEventListener('beforeprint', onBeforePrint);
          win.removeEventListener('afterprint', onAfterPrint);
          ctx.root.removeEventListener('focusin', onFocus);
        });
      }

      function isLit(hl, l) {
        if (!hl.ids.includes(l.from.id) || !hl.ids.includes(l.to.id)) return false;
        return !hl.links.length || hl.links.some((x) => x.from === l.from.id && x.to === l.to.id && (x.kind === null || x.kind === (l.kind.id || null)));
      }
      const highlighted = (m) => ({ ids: [...m.hl.ids], links: m.hl.links.map((l) => ({ ...l })) });

      function hostCommands(ctx, m, apply = () => {}) {
        ctx.handle('highlight', (value) => {
          const next = readHighlight(value, m.traceable.cards, m.traceable.links);
          if (next.problem) {
            console.warn(`stagemap stage-map: ${next.problem}.`);
            return false;
          }
          ctx.state.highlight = next;
          m.hl = next;
          apply();
          return true;
        });
        ctx.handle('hosted', (value) => {
          const next = regions(value);
          const unknown = next.filter((r) => !REGIONS.includes(r));
          if (unknown.length) {
            console.warn(`stagemap stage-map: "hosted" takes ${oneOf(REGIONS)}, not ${show(unknown[0])}.`);
            return false;
          }
          ctx.state.hosted = next;
          if (next.length !== m.hosted.size || next.some((r) => !m.hosted.has(r))) ctx.redraw();
          return true;
        });
        ctx.handle('history', () => ({
          visual: 'list',
          data: { rows: m.steps.map((s) => ({ id: s.id, label: s.label, ...(s.text ? { text: s.text } : {}) })) },
          options: { select: 'none' },
        }));
        const size = sizeOf(m);
        ctx.handle('size', () => size);
        if (ctx.state.size?.needs !== size.needs || ctx.state.size?.stack_below !== size.stack_below) {
          ctx.state.size = size;
          ctx.emit('stagemap:size', { needs: size.needs, stack_below: size.stack_below, stacksBelow: size.stacksBelow });
        }
      }

      function draw(ctx) {
        const source = normalise(ctx.data);
        const hosted = new Set(ctx.state.hosted ?? regions(source.options?.hosted));
        const known = util.rows(source.steps).length || util.rows(source.stages).length;
        const at = known > 1 && !hosted.has('steps') ? Math.min(ctx.state.player?.i ?? -1, known - 1) : -1;
        const folded = fold(source, at);
        ctx.state.foldSig = folded.sig;
        const host = ui.hostItems(ctx, () => folded.nodes);
        const seen = visible({ ...source, nodes: folded.nodes }, host);
        const trace = traceable(source);
        const wanted = ctx.state.highlight ?? readHighlight(source.options?.highlight, trace.cards, trace.links);
        const kept = wanted.ids.filter((x) => trace.cards.includes(x));
        const hl = {
          ids: kept,
          links: wanted.links.filter(
            (l) => kept.includes(l.from) && kept.includes(l.to) && trace.links.some((k) => k.from === l.from && k.to === l.to && (l.kind === null || k.kind === l.kind)),
          ),
        };
        const tracing = (m) => {
          m.traceable = trace;
          m.hl = hl;
          m.lit = (l) => isLit(m.hl, l);
        };
        if (!seen.nodes.length) {
          ctx.handle('show', (value) => host.show(value));
          ctx.handle('hide', (value) => host.hide(value));
          ctx.handle('disable', (value) => host.disable(value));
          ctx.handle('enable', (value) => host.enable(value));
          ctx.handle('state', () => ({ selected: null, selected_ids: [], stage: null, step: at, highlighted: highlighted(bare), ...host.state() }));
          ctx.handle('select', (value) => {
            const s = Array.isArray(value) ? { ids: value } : util.isObject(value) ? value : { id: value };
            if (!util.ids(s).length) return true;
            console.warn(`stagemap stage-map: nothing to select at ${show(value)}.`);
            return false;
          });
          const bare = model(seen);
          bare.source = source;
          bare.hosted = hosted;
          tracing(bare);
          hostCommands(ctx, bare);
          const none = Object.assign(document.createElement('p'), { className: 'sm-sub', textContent: 'No card to show.' });
          const keep = known > 1 && !hosted.has('steps');
          for (const part of ['picture', 'lanes', 'zones', 'tiles', ...(keep ? [] : ['steps', 'caption']), 'notes']) ctx.select(`.v-sm-${part}`)?.replaceChildren();
          ctx.select('.v-sm-picture').append(none);
          ctx.select('.v-sm-summary').textContent = 'No card to show.';
          if (keep) {
            bare.summary = 'No card to show.';
            for (const sel of ['.v-sm-tools', '.v-sm-caption', '.v-sm-steps']) ctx.select(sel).hidden = false;
            steps(ctx, bare, { each() {} }, null);
          }
          const had = ctx.state.selected ?? {};
          const by = ctx.state.hostBy ? 'host' : 'data';
          ui.detailGone(ctx, ({ by: who, via, from, details: facts, ids }) =>
            ctx.emit('stagemap:select', { kind: 'card', id: null, ids, from, label: null, details: facts, about: null, still: null, by: who, via }),
          );
          if (had.stage) {
            const via = by === 'host' ? 'command' : null;
            ctx.emit('stagemap:select', { kind: 'stage', id: null, ids: [], from: had.stage.id, label: null, details: null, about: null, still: null, by, via });
          }
          ctx.state.selected = { card: null, stage: null };
          ctx.state.stage = null;
          ctx.state.chosen = false;
          return;
        }
        const m = model(seen);
        m.source = source;
        tracing(m);
        const q = ctx.select;
        const said = selections(ctx);
        said.hold();
        m.hosted = hosted;
        m.player = m.steps.length > 1 && !m.hosted.has('steps');
        q('.v-sm-title').parentElement.hidden = m.hosted.has('title') || !(text(m.o.title) || text(m.o.sub));
        q('.v-sm-title').hidden = !text(m.o.title);
        q('.sm-detail').hidden = m.hosted.has('details');
        for (const sel of ['.v-sm-tools', '.v-sm-caption', '.v-sm-steps']) q(sel).hidden = m.hosted.has('steps');
        q('.v-sm-zones').hidden = m.hosted.has('zones');
        q('.v-sm-title').textContent = text(m.o.title);
        stagemap.markdown(q('.v-sm-sub'), text(m.o.sub) || null, { inline: true, field: 'options.sub' });
        if (m.levels) {
          const known = (id) => m.variants.some((v) => v.id === id);
          m.variant = [ctx.state.variant, m.o.variant, m.variants[0]?.id].find(known) || null;
          m.allCards = cardCount(m);
          inVariant(m, m.variant);
          m.every = m.links;
          m.links = m.links.filter((l) => m.target && l.to === m.target && l.from !== m.target);
          m.zones = [];
        }
        if (m.dates) {
          m.every = m.links;
          m.links = [];
          m.zones = [];
        }
        m.zones = m.zones.filter((z) => m.nodes.some((n) => n.zone === z));
        variantSwitch(ctx, m);
        legend(ctx, m);
        const notes = check(normalise(ctx.data)).notes;
        ctx.select('.v-sm-notes').replaceChildren(...notes.map((text) => Object.assign(document.createElement('p'), { textContent: text })));
        if (!ctx.state.warned) ctx.state.warned = new Set();
        for (const text of notes.filter((x) => !ctx.state.warned.has(x))) {
          ctx.state.warned.add(text);
          console.warn(`stagemap stage-map: ${text}`);
        }
        const PANEL_W = 320;
        const beside = m.panel && !m.hosted.has('stage') && ctx.width - PANEL_W - 12 >= widthNeed(m, ctx.width - PANEL_W - 12);
        q('.v-sm-body').classList.toggle('v-sm-beside', beside);
        q('.v-sm-panel').hidden = !m.panel || m.hosted.has('stage');
        const room = beside ? ctx.width - PANEL_W - 12 : ctx.width;
        const stacked = !m.levels && !m.dates && !beside && room < STACK_BELOW;
        q('.v-sm-body').classList.toggle('v-sm-stacked', stacked);
        const drawing = m.levels ? drawLevels : m.dates ? drawDates : stacked ? drawStack : drawGrid;
        const { names, svg, cards, heads } = drawing(ctx, m, Math.max(MIN_ROOM, room));
        q('.v-sm-frame').classList.toggle('v-sm-ltr', !m.dates);
        q('.v-sm-picture').classList.toggle('v-sm-table', m.dates);
        if (m.hosted.has('title')) svg.attr('aria-label', name(m, true));
        q('.v-sm-lanes').replaceChildren(names.node());
        q('.v-sm-picture').replaceChildren(svg.node());
        const oldBoxes = ctx.state.cardBoxes;
        delete ctx.state.cardBoxes;
        if (oldBoxes && !stagemap.reducedMotion()) {
          const duration = motionDuration(ctx.root);
          const easing = getComputedStyle(ctx.root).getPropertyValue('--stagemap-motion-ease').trim() || 'cubic-bezier(0.2, 0, 0, 1)';
          if (duration > 0) {
            cards.each(function (n) {
              if (!n || n.id == null) return;
              const id = String(n.id);
              const old = oldBoxes.get(id);
              if (old) {
                const now = this.getBoundingClientRect();
                const dx = old.left - now.left;
                const dy = old.top - now.top;
                if (Math.abs(dx) > 0.5 || Math.abs(dy) > 0.5) {
                  this.animate([{ transform: `translate(${dx}px, ${dy}px)` }, { transform: 'none' }], { duration, easing });
                }
              } else {
                this.animate([{ opacity: 0 }, {}], { duration, easing });
              }
            });
          }
        }

        const zones = q('.v-sm-zones');
        zones.replaceChildren(
          ...m.zones
            .filter((z) => z.text || z.note)
            .map((z) => {
              const div = document.createElement('div');
              const head = div.appendChild(document.createElement('b'));
              if (z.text) stagemap.markdown(head, z.text, { inline: true, field: 'zones.text', id: z.id });
              else head.textContent = z.label;
              if (z.note) div.append(stagemap.markdown(document.createElement('span'), z.note, { inline: true, field: 'zones.note', id: z.id }));
              return div;
            }),
        );

        const tiles = q('.v-sm-tiles');
        tiles.replaceChildren();
        if (m.o.summary) {
          const tile = (big, small) => {
            const div = document.createElement('div');
            div.append(Object.assign(document.createElement('b'), { textContent: big }), Object.assign(document.createElement('span'), { textContent: small }));
            tiles.append(div);
          };
          const many = (n, one) => `${n} ${one}${n === 1 ? '' : 's'}`;
          tile(String(cardCount(m)), cardCount(m) === 1 ? 'card' : 'cards');
          tile(`${m.stages[0].label} → ${m.stages.at(-1).label}`, many(m.stages.length, 'stage'));
          tile(m.lanes.map((l) => l.label).join(' / '), many(m.lanes.length, 'lane'));
        }

        const count = (stId) => m.nodes.filter((n) => n.status === stId).length;
        const statuses = m.statuses
          .filter((st) => count(st.id))
          .map((st) => `${count(st.id)} ${st.label}`)
          .join(', ');
        const listed = (list) => list.map((x) => x.label).join(', ');
        if (m.levels) {
          const t = m.target;
          const arrived = t ? [...new Set(m.links.map((l) => l.from))] : [];
          m.summary =
            `A stage map drawn as ${m.lanes.length} levels (${listed(m.lanes)}) holding ${cardCount(m)} cards` +
            (t ? `, flowing into ${t.label}; ${arrived.length} reach it: ${listed(arrived) || 'none'}.` : '.') +
            (m.variant ? ` Variant: ${m.variants.find((v) => v.id === m.variant).label}.` : '') +
            (statuses ? ` ${statuses}.` : '');
        } else if (m.dates) {
          const dated = m.stages.map((s) => (s.date ? `${s.label} (${fmtDay(s.date)})` : s.label));
          m.summary =
            `A stage map drawn as a table of ${m.lanes.length} lanes (${listed(m.lanes)}) by ${m.stages.length} ` +
            `stages (${dated.join(', ')}), with ${m.nodes.length} cards as chips` +
            `${m.nodes.some((n) => n.milestone) ? `; milestones: ${listed(m.nodes.filter((n) => n.milestone))}` : ''}.` +
            (statuses ? ` ${statuses}.` : '');
        } else {
          m.summary =
            `A stage map of ${m.nodes.length} cards in ${m.stages.length} stages (${listed(m.stages)}) and ` +
            `${m.lanes.length} lanes (${listed(m.lanes)}), with ${m.links.length} links.` +
            (statuses ? ` ${statuses}.` : '');
        }
        const flagged = m.stages.filter((s) => s.flag);
        if (flagged.length) m.summary += ` Flagged: ${flagged.map((s) => `${s.label}, ${s.flag}`).join('; ')}.`;
        q('.v-sm-summary').textContent = m.summary;

        let shown = null;
        const refresh = () => {
          const stage = ctx.state.stage;
          const step = m.player ? (ctx.state.player?.i ?? -1) : -1;
          const traced = m.hl.ids.length > 0;
          m.shown = shown;
          ctx.root.classList.toggle('v-sm-traced', traced);
          for (const l of m.links) {
            const on = m.lit(l);
            const touch = Boolean(shown) && (l.from === shown || l.to === shown);
            const reveal = on || (shown ? touch : step >= 0 && l.at === step);
            for (const el of ownParts(l)) {
              el.classList.toggle('v-sm-faded', traced ? !on : Boolean(shown) && !touch);
              if (l.kind.quiet) el.classList.toggle('v-sm-quiet', !reveal);
            }
          }
          for (const b of m.bundles ?? []) {
            const on = b.links.some(m.lit);
            const touch = Boolean(shown) && b.links.some((l) => l.from === shown || l.to === shown);
            const reveal = on || (shown ? touch : step >= 0 && b.links.some((l) => l.at === step));
            for (const el of b.parts) {
              el.classList.toggle('v-sm-faded', traced ? !on : Boolean(shown) && !touch);
              if (b.kind.quiet) el.classList.toggle('v-sm-quiet', !reveal);
            }
          }
          const all = m.every || m.links;
          const near = new Set(all.filter((l) => l.from === shown || l.to === shown).flatMap((l) => [l.from, l.to]));
          cards.each(function (n) {
            const clear = m.hl.ids.includes(n.id);
            this.classList.toggle('v-sm-near', traced ? clear : Boolean(shown) && (near.has(n) || n.stage.id === stage));
            this.classList.toggle('v-sm-dim', traced && !clear && n !== shown);
          });
        };
        const ends = (list, other) =>
          list.map((l) => `${other(l).label}${l.kind.id ? ` (${l.kind.label}${l.label ? `: ${l.label}` : ''})` : l.label ? ` (${l.label})` : ''}`).join('; ');
        ctx.outside(said.hold);
        const hostMade = Boolean(ctx.state.hostBy);
        const details = ui.detail(
          ctx,
          cards,
          (n) => {
            const all = m.every || m.links;
            const ins = all.filter((l) => l.to === n);
            const outs = all.filter((l) => l.from === n);
            const st = n.status ? m.statusLookup.get(n.status) : null;
            const isBuiltInNoOverride = Boolean(st && !st.toneOverride && stagemap.statuses.includes(st.id));
            return {
              title: n.label,
              meta: [n.stage.flag ? `${n.stage.label} (${n.stage.flag})` : n.stage.label, n.lane.label, n.status && m.word(n.status), n.sub, n.milestone && 'milestone']
                .filter(Boolean)
                .join(', '),
              text: [n.zone && `In the zone "${stagemap.markdown.escape(n.zone.label)}".`, n.text].filter(Boolean).join('\n\n'),
              kpis: [
                ...(ins.length ? [['From', ends(ins, (l) => l.from)]] : []),
                ...(outs.length ? [['To', ends(outs, (l) => l.to)]] : []),
              ],
              status: isBuiltInNoOverride ? n.status : undefined,
              tone: isBuiltInNoOverride ? undefined : (st?.tone || n.tone || n.lane.tone),
              icon: isBuiltInNoOverride ? undefined : st?.iconName,
            };
          },
          'Hover or tap a card for its stage, lane and status, or use Tab and the arrow keys.',
          {
            onShow: (n) => {
              shown = n;
              refresh();
            },
            onPin: (n, { by, via, details: facts, ids }) => said.set('card', n ? { id: n.id, ids, details: facts } : null, by, via),
            key: (n) => n.id,
            field: 'nodes.text',
            many: true,
            disabled: (n) => (n.disabled ? n.reason : null),
            outside: m.o.dismiss !== 'no_outside',
          },
        );
        ui.hover(ctx, cards, (n) => ({ kind: 'card', id: n.id }));
        ui.hover(ctx, heads, (st) => ({ kind: 'stage', id: st.id }));
        const resting = () => {
          const s = m.player ? m.steps[ctx.state.player?.i ?? -1] : null;
          return s ? { id: s.stage ? s.stage.id : null, entry: stepEntry(s) } : null;
        };
        const letGoAll = (by, via) => {
          said.hold();
          stages?.show(null, by, via);
          details.pin(null);
          said.flush();
        };
        const stages = m.panel ? stageButtons(ctx, m, heads, refresh, resting, said, (via) => letGoAll('reader', via)) : null;
        ctx.outside(said.flush);
        const onEscape = (e) => {
          if (e.key !== 'Escape' || e.defaultPrevented || e.isComposing || e.keyCode === 229) return;
          if (details.showing()) details.clear('key');
          else if (ctx.state.chosen) stages?.show(null, 'reader', 'key');
          else return;
          e.preventDefault();
          e.stopPropagation();
        };
        ctx.root.addEventListener('keydown', onEscape);
        ctx.cleanup(() => ctx.root.removeEventListener('keydown', onEscape));
        refresh();
        if (m.player) steps(ctx, m, cards, stages);
        else for (const sel of ['.v-sm-tools', '.v-sm-caption', '.v-sm-steps']) q(sel).replaceChildren();
        ui.scrollBox(ctx, q('.v-sm-picture'));
        const head = q('.sm-head');
        head.hidden = [...head.children].every((el) => el.hidden || !el.childElementCount);
        keepInView(ctx, m, stacked);
        if (!stages && said.now.stage) said.set('stage', null, 'data');
        const pinned = details.pinned();
        const differ = (a, b) => JSON.stringify([a.details, a.ids]) !== JSON.stringify([b.details, b.ids]);
        if (pinned && said.now.card && differ(said.now.card, pinned)) said.set('card', pinned, hostMade ? 'host' : 'data', hostMade ? 'command' : null);
        else if (pinned) said.now.card = pinned;
        const before = ctx.state.regions ?? m.hosted;
        ctx.state.regions = m.hosted;
        const moved = (region) => before.has(region) !== m.hosted.has(region);
        if (moved('stage') && said.now.stage) said.set('stage', said.now.stage, 'data');
        if (moved('details') && said.now.card) said.set('card', said.now.card, 'data');
        said.flush();
        ctx.handle('select', (value) => {
          const s = Array.isArray(value) ? { ids: value } : util.isObject(value) ? value : { id: value };
          const list = util.ids(s);
          const kind = s.kind ?? (list.length ? 'card' : 'all');
          const lead = s.id ?? null;
          if (lead !== null && list.includes(String(lead))) list.push(...list.splice(list.indexOf(String(lead)), 1));
          const id = list.length === 1 ? list[0] : null;
          if (kind === 'all' && !list.length) letGoAll('host', 'command');
          else if (kind === 'card' && details.pin(list)) return true;
          else if (kind === 'stage' && !list.length) stages?.show(null, 'host', 'command');
          else if (kind === 'stage' && m.stages.some((x) => x.id === String(id))) {
            if (stages) stages.choose(String(id), 'host', 'command');
            else reveal(ctx, String(id));
          } else {
            console.warn(`stagemap stage-map: nothing to select at ${show(value)}.`);
            return false;
          }
          return true;
        });
        ctx.handle('show', (value) => host.show(value));
        ctx.handle('hide', (value) => host.hide(value));
        ctx.handle('disable', (value) => host.disable(value));
        ctx.handle('enable', (value) => host.enable(value));
        ctx.handle('state', () => {
          const picked = details.pinned();
          const step = m.player ? (ctx.state.player?.i ?? -1) : -1;
          return { selected: picked?.id ?? null, selected_ids: picked?.ids ?? [], stage: said.now.stage?.id ?? null, step, highlighted: highlighted(m), ...host.state() };
        });
        hostCommands(ctx, m, refresh);
      }

      const visual = {
        validate,
        draw,
        roles: ['target', 'card-line', 'band', 'selected', 'hover', 'disabled'],
        skeleton: { class: 'viz sm v-sm', html: SKELETON },
        commands: ['select', 'highlight', 'hosted', 'size', 'history', 'show', 'hide', 'disable', 'enable', 'state'],
      };
      stagemap.define('stage-map', visual);
      const root = document.currentScript?.closest('[data-stagemap-visual]');
      if (root) stagemap.mount(root, visual);
    })();
