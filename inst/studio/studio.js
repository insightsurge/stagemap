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
import { readBoot, readEvent } from './js/dom.js';
import { createHold } from './js/hold.js';
import { render as renderCode } from './js/room-code.js';
import { createShell } from './js/shell.js';
import { createStore } from './js/store.js';
import { createTheme } from './js/theme.js';
import { render as renderHeader } from './js/view-header.js';

const instances = new Map(); /* namespace -> instance */

/* Text fields whose typing is held; any other field with an event sends on change. */
const isTextField = (node) =>
  node instanceof HTMLTextAreaElement || (node instanceof HTMLInputElement && /^(text|search|)$/.test(node.type));

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
  const shell = createShell(root, boot, { later, cancel });
  const theme = createTheme(root, { signal });

  const ctx = () => ({ send: store.send, labels: boot.labels, ack: store.ack, rev: store.rev });
  /* The header is drawn on every message, so a field whose edit the server refused shows the server's value again
     once it is acknowledged and has lost focus; the other sections only when they changed. */
  function draw(view, changed) {
    if (view.header) renderHeader(root, view.header, ctx());
    if (changed.includes('code') && view.code) renderCode(root, view.code, ctx());
    if (changed.includes('status')) shell.renderStatus(view.status);
    if (changed.includes('notice')) shell.renderNotice(view.notice);
  }
  store.subscribe(draw);

  root.addEventListener(
    'click',
    (event) => {
      const target = event.target instanceof Element ? event.target : null;
      const copy = target?.closest('[data-sms-copy]');
      if (copy) return copyCode(copy, { root, store, labels: boot.labels, toast: shell.toast });
      const room = target?.closest('[data-sms-room]');
      if (room) return shell.toggleRoom(room.dataset.smsRoom);
      const close = target?.closest('[data-sms-close]');
      if (close) return shell.closeRoom(close.dataset.smsClose);
      if (target?.closest('[data-sms-theme]')) return theme.toggle();
      const button = target?.closest('button[data-sms-event]');
      if (button && button.getAttribute('aria-disabled') !== 'true') {
        const sent = readEvent(button);
        store.track(button, store.send(sent.type, sent.data));
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
    'keydown',
    (event) => {
      if (event.key === 'Enter' && isTextField(event.target) && hold.isHeld(event.target)) hold.flush();
      else if (event.key === 'Escape' && shell.closeTopmost()) event.preventDefault();
    },
    { signal },
  );
  root.addEventListener(
    'focusout',
    (event) => {
      if (!isTextField(event.target) || !event.target.hasAttribute('data-sms-event')) return;
      hold.flush();
      /* Once focus has moved on, the field may show the server's value again. */
      later(() => {
        if (store.view.header) renderHeader(root, store.view.header, ctx());
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
