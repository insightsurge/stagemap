/*
 * The stagemap studio's page script, an ES module. It mounts every studio root (`div.sms`) on the page and keeps a
 * map from namespace to instance; the one handler of the `stagemap:studio` message routes each message by its `ns`.
 *
 * An instance keeps its page and the server in step (the five rules of the package's Shiny apps):
 * - what it shows and copies is the server's view, never a value read from its own controls;
 * - every event first sends the text still held (hold.js), so an action follows the edits typed before it;
 * - a render never overwrites a field with focus or with text the server has not acknowledged;
 * - messages are whole sections in order; one that is not newer is dropped;
 * - a clicked button is busy until the message that acknowledges its event has been drawn.
 * All its listeners are on the root (or on window and Shiny's document events) and end with one AbortController;
 * its timers are in one set that destroy() clears. Renderers add no listener.
 */
import { copyCode } from './js/copy.js';
import { readBoot, readEvent, setBusy, setText } from './js/dom.js';
import { readFieldValue } from './js/form.js';
import { createHold } from './js/hold.js';
import { render as renderAsk } from './js/room-ask.js';
import { render as renderCheck } from './js/room-check.js';
import { render as renderCode } from './js/room-code.js';
import { render as renderMap } from './js/room-map.js';
import { closeGuide, render as renderTour, toggleGuide } from './js/room-tour.js';
import { createShell } from './js/shell.js';
import { createStore, LateError } from './js/store.js';
import { createTheme } from './js/theme.js';
import { render as renderHeader } from './js/view-header.js';
import { render as renderInspector, syncInspectorInert } from './js/view-inspector.js';
import { render as renderJournal } from './js/view-journal.js';
import { render as renderNotice } from './js/view-notice.js';
import { render as renderOutline } from './js/view-outline.js';
import { render as renderStart } from './js/view-start.js';
import { render as renderStatus } from './js/view-status.js';

const instances = new Map(); /* namespace -> instance */

/* The one list of sections and rooms: { name, render, target }. */
const sections = [
  { name: 'header', render: renderHeader, target: null },
  { name: 'outline', render: renderOutline, target: '.sms-outline' },
  { name: 'inspector', render: renderInspector, target: '.sms-inspector' },
  { name: 'journal', render: renderJournal, target: '.sms-journal' },
  { name: 'start', render: renderStart, target: '.sms-start' },
  { name: 'status', render: renderStatus, target: null },
  { name: 'notice', render: renderNotice, target: null },
  { name: 'ask', render: renderAsk, target: '[data-sms-room-of="ask"] .sms-room-body' },
  { name: 'check', render: renderCheck, target: '[data-sms-room-of="check"] .sms-room-body' },
  { name: 'code', render: renderCode, target: null },
  { name: 'map', render: renderMap, target: '[data-sms-room-of="map"] .sms-room-body' },
  { name: 'tour', render: renderTour, target: '.sms-hint' },
];

/* Text fields whose typing is held; any other field with an event sends on change. */
const isTextField = (node) =>
  node instanceof HTMLTextAreaElement || (node instanceof HTMLInputElement && /^(text|search|)$/.test(node.type));

const isUndoBlocked = (node) =>
  node instanceof Element && (node.matches('input, textarea, select') || node.isContentEditable);

function mount(root) {
  const ns = root.dataset.smsNs;
  if (instances.has(ns)) return;
  const boot = readBoot(root);
  const controller = new AbortController();
  const { signal } = controller;
  const timers = new Set();
  const later = (fn, ms) => {
    const id = setTimeout(() => {
      timers.delete(id);
      fn();
    }, ms);
    timers.add(id);
    return id;
  };
  const cancel = (id) => {
    clearTimeout(id);
    timers.delete(id);
  };

  let hold = null;
  const store = createStore(root, boot, { flush: () => hold?.flush(), later, cancel, signal });
  hold = createHold(boot, store.send, { later, cancel });
  const shell = createShell(root, boot, { later, cancel, send: store.send, signal });
  const theme = createTheme(root, { signal });

  let modality = 'pointer';
  let pendingInspectorSeq = 0;
  let inspectorOpener = null;

  const shouldFocusInspector = () => {
    if (pendingInspectorSeq === 0 || store.ack < pendingInspectorSeq) return false;
    pendingInspectorSeq = 0;
    return true;
  };

  function syncModalInert(modal) {
    if (root.dataset.smsClosed !== undefined) return;
    const startEl = root.querySelector('.sms-start');
    const sheet = root.querySelector('.sms-sheet');
    if (sheet) {
      for (const child of sheet.children) {
        if (child !== startEl) child.inert = modal;
      }
    }
    for (const child of root.children) {
      if (child.matches('.sms-skip, .sms-block')) {
        child.inert = modal;
      }
    }
    syncInspectorInert(root, modal);
    const tray = root.querySelector('.sms-tray');
    if (tray) tray.inert = modal || root.dataset.smsTray === undefined;
  }

  function restoreInspectorFocus() {
    if (inspectorOpener?.isConnected && !inspectorOpener.closest('[hidden]') && !inspectorOpener.closest('[inert]')) {
      inspectorOpener.focus();
    } else {
      const mapEl = document.getElementById(`${ns}map`);
      const mapTarget = mapEl?.querySelector(
        '[aria-pressed="true"], [aria-current="true"], [tabindex="0"], button:not([disabled])',
      );
      if (mapTarget && !mapTarget.closest('[hidden]') && !mapTarget.closest('[inert]')) {
        mapTarget.focus();
      } else {
        root.querySelector('.sms-title')?.focus();
      }
    }
    inspectorOpener = null;
  }

  function closeMenus(refocus = false) {
    let closedTrigger = null;
    for (const pop of root.querySelectorAll('.sms-menu-pop:not([hidden])')) {
      const box = pop.closest('.sms-menu');
      const trigger = box?.querySelector('[data-sms-menu]');
      if (refocus && trigger && pop.contains(document.activeElement)) {
        trigger.focus();
      }
      pop.hidden = true;
      if (trigger) {
        trigger.setAttribute('aria-expanded', 'false');
        closedTrigger = trigger;
      }
    }
    return closedTrigger;
  }

  function syncStart(show, reason = 'opened') {
    const startEl = root.querySelector('.sms-start');
    if (!startEl) return false;
    const wasShown = !startEl.hidden;
    if (show) {
      if (!wasShown) shell.closeAllRooms();
      startEl.hidden = false;
      syncModalInert(true);
      if (!wasShown && !startEl.contains(document.activeElement)) {
        startEl.querySelector('.sms-opt')?.focus();
      }
      return true;
    }
    if (!wasShown && startEl.dataset.smsOpen !== 'true') return false;
    const hadFocus = startEl.contains(document.activeElement);
    delete startEl.dataset.smsOpen;
    delete startEl.dataset.smsOpenedRev;
    syncModalInert(false);
    if (hadFocus || reason === 'cancel') {
      const dest =
        reason === 'cancel'
          ? (root.querySelector('[data-sms-start="open"]') ?? root.querySelector('.sms-title'))
          : (root.querySelector('.sms-title') ?? root.querySelector('[data-sms-start="open"]'));
      dest?.focus();
    }
    startEl.hidden = true;
    return true;
  }

  const ctx = () => ({
    send: store.send,
    flush: store.flush,
    whenInStep: store.whenInStep,
    labels: boot.labels,
    ack: store.ack,
    rev: store.rev,
    toast: shell.toast,
    closeAllRooms: shell.closeAllRooms,
    isPhone: shell.isPhone,
    shouldFocusInspector,
    restoreInspectorFocus,
    syncStart,
  });

  function showHint(detail) {
    const hintEl = root.querySelector('.sms-hint');
    if (!hintEl) return;
    const hints = store.view.outline?.hints;
    const text = detail && detail.id != null ? hints?.[detail.kind]?.[String(detail.id)] : null;
    setText(hintEl.querySelector('.sms-hint-text'), text ?? '');
    if (text) {
      hintEl.dataset.smsHover = '';
      hintEl.hidden = false;
    } else {
      delete hintEl.dataset.smsHover;
      hintEl.hidden = hintEl.dataset.smsTour === undefined;
    }
  }

  /* The header and inspector are patched on every message, so a field whose edit the server refused shows the server's
     value again once it is acknowledged and has lost focus; the other sections only when they changed. */
  function draw(view, changed) {
    for (const section of sections) {
      const always = section.name === 'header' || section.name === 'inspector';
      if (!always && !changed.includes(section.name)) continue;
      if (view[section.name] === undefined) continue;
      const el = section.target ? root.querySelector(section.target) : root;
      if (el) section.render(el, view[section.name], ctx());
    }
    const startEl = root.querySelector('.sms-start');
    if (
      startEl?.dataset.smsOpen === 'true' &&
      Number(startEl.dataset.smsOpenedRev ?? -1) !== store.rev &&
      !view.start?.open
    ) {
      syncStart(false, 'opened');
    }
    /* Clear any pending focus request once its answer has arrived, even when the inspector stayed unchanged. */
    if (pendingInspectorSeq > 0 && store.ack >= pendingInspectorSeq) {
      pendingInspectorSeq = 0;
    }
  }
  store.subscribe(draw);

  root.addEventListener('pointerdown', () => (modality = 'pointer'), { capture: true, signal });
  root.addEventListener(
    'click',
    (event) => {
      if (event.target instanceof Element && !hold.isHeld(event.target)) hold.flush();
    },
    { capture: true, signal },
  );
  root.addEventListener(
    'keydown',
    (event) => {
      if (event.key === 'Enter' || event.key === ' ') modality = 'key';
    },
    { capture: true, signal },
  );

  if (boot.events?.hover) {
    root.addEventListener(boot.events.hover, (event) => showHint(event.detail), { signal });
  }
  if (boot.events?.select) {
    root.addEventListener(
      boot.events.select,
      (event) => {
        const detail = event.detail ?? {};
        if (detail.by === 'reader') {
          hold.flush();
          store.deferNextTick();
          if (detail.id != null && (detail.via === 'key' || modality === 'key')) {
            pendingInspectorSeq = Math.max(1, store.sent);
            inspectorOpener = document.activeElement instanceof Element ? document.activeElement : null;
          }
        }
      },
      { signal },
    );
  }

  root.addEventListener(
    'click',
    (event) => {
      const target = event.target instanceof Element ? event.target : null;
      const copy = target?.closest('[data-sms-copy]');
      if (copy) return copyCode(copy, { root, store, labels: boot.labels, toast: shell.toast });
      const download = target?.closest('[data-sms-download]');
      if (download) {
        if (download.closest('.sms-menu-pop')) closeMenus(true);
        if (download.getAttribute('aria-busy') === 'true') return;
        const id = download.dataset.smsDownload;
        const link = id ? document.getElementById(`${ns}${id}`) : null;
        if (!link) return;
        setBusy(download, true);
        store
          .whenInStep()
          .then(() => {
            link.click();
          })
          .catch((error) => {
            if (error instanceof LateError) shell.toast(boot.labels.download_late, 'problem');
            else console.error(error);
          })
          .finally(() => setBusy(download, false));
        return;
      }
      if (target?.closest('[data-sms-try]')) return toggleGuide(root);
      const room = target?.closest('[data-sms-room]');
      if (room) return shell.toggleRoom(room.dataset.smsRoom);
      const close = target?.closest('[data-sms-close]');
      if (close) return shell.closeRoom(close.dataset.smsClose);
      if (target?.closest('[data-sms-theme]')) return theme.toggle();

      const startAct = target?.closest('[data-sms-start]');
      if (startAct) {
        if (startAct.dataset.smsStart === 'open') {
          const startEl = root.querySelector('.sms-start');
          if (startEl) {
            startEl.dataset.smsOpen = 'true';
            startEl.dataset.smsOpenedRev = String(store.rev);
            syncStart(true);
            startEl.querySelector('.sms-opt')?.focus();
          }
        } else if (startAct.dataset.smsStart === 'close') {
          syncStart(false, 'cancel');
        }
        return;
      }

      const menuBtn = target?.closest('[data-sms-menu]');
      if (menuBtn) {
        const pop = document.getElementById(menuBtn.getAttribute('aria-controls'));
        const opening = Boolean(pop?.hidden);
        closeMenus();
        if (opening && pop) {
          pop.hidden = false;
          menuBtn.setAttribute('aria-expanded', 'true');
          pop.querySelector('[role="menuitem"]')?.focus();
        }
        return;
      }

      if (!target?.closest('.sms-menu')) closeMenus();

      const button = target?.closest('button[data-sms-event]');
      if (button && button.getAttribute('aria-disabled') !== 'true') {
        const menuTrigger = button.closest('.sms-menu')?.querySelector('[data-sms-menu]');
        if (button.closest('.sms-menu-pop')) closeMenus(true);
        const sent = readEvent(button);
        const data = { ...sent.data };
        if (button.dataset.smsCollect === 'true') {
          const group = button.closest('[data-sms-group]');
          if (group) {
            for (const fld of group.querySelectorAll('[data-sms-field]')) {
              const name = fld.dataset.smsField;
              const val = readFieldValue(fld);
              if (name !== undefined && val !== undefined) data[name] = val;
            }
          }
        }
        const sentSeq = store.send(sent.type, data);
        if (button.closest('.sms-outline') || button.closest('.sms-journal')) {
          pendingInspectorSeq = sentSeq;
          inspectorOpener = menuTrigger ?? button;
        } else if (button.closest('.sms-inspector') && (sent.type === 'target' || sent.type === 'add')) {
          pendingInspectorSeq = sentSeq;
        }
        store.track(button, sentSeq);
      }
    },
    { signal },
  );
  root.addEventListener(
    'input',
    (event) => {
      if (isTextField(event.target) && event.target.hasAttribute('data-sms-event')) hold.hold(event.target);
    },
    { signal },
  );
  root.addEventListener(
    'change',
    (event) => {
      const target = event.target;
      if (!(target instanceof Element) || !target.hasAttribute('data-sms-event')) return;
      if (isTextField(target)) {
        if (hold.isHeld(target)) hold.flush();
        return;
      }
      const ev = readEvent(target);
      if (!ev) return;
      let value;
      if (target instanceof HTMLInputElement && target.type === 'checkbox') {
        value = Boolean(target.checked);
      } else if (target instanceof HTMLInputElement && target.type === 'number') {
        value = target.value === '' ? null : Number(target.value);
      } else {
        value = target.value;
      }
      const seq = store.send(ev.type, { ...ev.data, value });
      if (target instanceof HTMLInputElement && target.type === 'radio') {
        const group = target.closest('.sms-seg');
        if (group) group.dataset.smsSeq = String(seq);
      } else {
        target.dataset.smsSeq = String(seq);
      }
    },
    { signal },
  );
  root.addEventListener(
    'keydown',
    (event) => {
      if (
        event.key === 'Enter' &&
        event.target instanceof HTMLInputElement &&
        isTextField(event.target) &&
        hold.isHeld(event.target)
      ) {
        hold.flush();
        return;
      }

      const menuPop = event.target instanceof Element ? event.target.closest('.sms-menu-pop') : null;
      if (menuPop && event.key === 'Tab') {
        /* Tab leaves a menu: it closes, and the key goes on from its button. */
        closeMenus(true);
        return;
      }
      if (menuPop && ['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(event.key)) {
        const items = [...menuPop.querySelectorAll('[role="menuitem"]')];
        if (items.length > 0) {
          const cur = items.indexOf(document.activeElement);
          let next = 0;
          if (event.key === 'ArrowDown') next = cur < 0 ? 0 : (cur + 1) % items.length;
          else if (event.key === 'ArrowUp') next = cur < 0 ? items.length - 1 : (cur - 1 + items.length) % items.length;
          else if (event.key === 'End') next = items.length - 1;
          items[next].focus();
          event.preventDefault();
        }
        return;
      }

      const startEl = root.querySelector('.sms-start');
      if (startEl && !startEl.hidden && event.key === 'Tab') {
        const focusables = [...startEl.querySelectorAll('button:not([hidden])')].filter(
          (node) => !node.closest('[hidden]'),
        );
        if (focusables.length > 0) {
          const first = focusables[0];
          const last = focusables[focusables.length - 1];
          if (event.shiftKey && (document.activeElement === first || !startEl.contains(document.activeElement))) {
            event.preventDefault();
            last.focus();
          } else if (!event.shiftKey && document.activeElement === last) {
            event.preventDefault();
            first.focus();
          }
        }
        return;
      }

      if (event.key === 'Escape') {
        const trigger = closeMenus(true);
        if (trigger) {
          trigger.focus();
          event.preventDefault();
          return;
        }
        if (syncStart(false, 'cancel') || closeGuide(root) || shell.closeTopmost()) {
          event.preventDefault();
          return;
        }
        if (store.view.inspector) {
          const mapEl = document.getElementById(`${ns}map`);
          if (!mapEl?.contains(event.target)) {
            event.preventDefault();
            store.send('target', { kind: 'none', uid: null });
            restoreInspectorFocus();
          }
        }
        return;
      }

      if (
        (event.metaKey || event.ctrlKey) &&
        !event.shiftKey &&
        !event.altKey &&
        event.key.toLowerCase() === 'z' &&
        !isUndoBlocked(event.target)
      ) {
        const undoBtn = root.querySelector('.sms-undo');
        if (undoBtn && undoBtn.getAttribute('aria-disabled') !== 'true' && !undoBtn.closest('[inert]')) {
          event.preventDefault();
          store.track(undoBtn, store.send('undo', {}));
        }
      }
    },
    { signal },
  );
  root.addEventListener(
    'focusout',
    (event) => {
      if (
        !(event.target instanceof Element) ||
        !event.target.matches('input, select, textarea') ||
        !event.target.hasAttribute('data-sms-event')
      ) {
        return;
      }
      if (isTextField(event.target)) hold.flush();
      /* Once focus has moved on, the field may show the server's value again. */
      later(() => {
        if (store.view.header) renderHeader(root, store.view.header, ctx());
        const insp = root.querySelector('.sms-inspector');
        if (insp && store.view.inspector) renderInspector(insp, store.view.inspector, ctx());
      }, 0);
    },
    { signal },
  );

  const instance = {
    store,
    destroy() {
      controller.abort();
      for (const id of timers) clearTimeout(id);
      timers.clear();
      store.destroy();
      instances.delete(ns);
    },
  };
  instances.set(ns, instance);
  window.addEventListener('pagehide', () => instance.destroy(), { signal });
  store.send('ready');
}

window.Shiny?.addCustomMessageHandler('stagemap:studio', (message) => {
  instances.get(message?.ns)?.store.receive(message);
});
for (const root of document.querySelectorAll('.sms[data-sms-ns]')) mount(root);
