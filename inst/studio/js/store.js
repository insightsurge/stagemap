/*
 * The store: the one owner of the event count (`seq`), of what has been sent and acknowledged, and of the view the
 * server drew. Every event goes out through `send()`, which first sends held text, so an action always follows the
 * edits typed before it. Every message comes in through `receive()`, which applies only a message newer than the last.
 *
 * Seams for tools and tests, DOM events on the root (they bubble): `stagemap-studio:send` (cancelable; `detail` is the
 * event about to be sent), `stagemap-studio:message` (cancelable; `detail` is the message about to be applied) and
 * `stagemap-studio:deliver` (applies the message in `detail`).
 */
import { setBusy } from './dom.js';

/* The reason whenInStep() gives up: the server did not answer within `copy_wait_ms`. */
export class LateError extends Error {
  constructor() {
    super('the server did not answer in time');
    this.name = 'LateError';
  }
}

/* `tools` holds `flush` (sends held text), `later` and `cancel` (the instance's timers) and `signal` (its listeners). */
export function createStore(root, boot, tools) {
  const { flush, later, cancel, signal } = tools;
  const ns = root.dataset.smsNs;
  const view = {};
  const waiters = new Set(); /* whenInStep() promises: { target, resolve, reject, timer } */
  const listeners = new Set();
  const waiting = []; /* events sent before Shiny connected */
  let seq = 0;
  let sent = 0;
  let ack = 0;
  let n = 0;
  let rev = 0;
  let connected = Boolean(window.Shiny?.shinyapp?.isConnected?.());
  let started = connected;

  function post(event) {
    window.Shiny.setInputValue(`${ns}event`, event, { priority: 'event' });
  }

  function markBusy() {
    if (sent > ack) root.setAttribute('aria-busy', 'true');
    else root.removeAttribute('aria-busy');
  }

  /* Sends the event `type` with `data` and returns its seq. Held text goes first. */
  function send(type, data = {}) {
    flush();
    seq += 1;
    const event = { seq, type, data, rev };
    sent = seq;
    root.dataset.smsSent = String(sent);
    markBusy();
    const go = root.dispatchEvent(
      new CustomEvent('stagemap-studio:send', { detail: event, cancelable: true, bubbles: true }),
    );
    if (go) {
      if (connected) post(event);
      else waiting.push(event);
    }
    return seq;
  }

  /* Draws a message: its sections join the view, the subscribers draw them, then the root says what it shows. */
  function apply(message) {
    if (!message || typeof message.n !== 'number' || message.n <= n) return;
    n = message.n;
    ack = Math.max(ack, message.ack ?? 0);
    rev = message.rev ?? rev;
    const sections = message.sections ?? {};
    const changed = Object.keys(sections);
    for (const name of changed) view[name] = sections[name];
    for (const listener of listeners) listener(view, changed);
    root.dataset.smsRev = String(rev);
    root.dataset.smsAck = String(ack);
    root.dataset.smsN = String(n);
    settle();
  }

  /* After a message: buttons whose own event is answered stop being busy, and waiters in step resolve. */
  function settle() {
    markBusy();
    for (const button of root.querySelectorAll('[data-sms-wait-seq]')) {
      if (Number(button.dataset.smsWaitSeq) <= ack) {
        button.removeAttribute('data-sms-wait-seq');
        setBusy(button, false);
      }
    }
    for (const waiter of [...waiters]) {
      if (ack >= waiter.target) {
        waiters.delete(waiter);
        cancel(waiter.timer);
        waiter.resolve(view);
      }
    }
  }

  function receive(message) {
    const go = root.dispatchEvent(
      new CustomEvent('stagemap-studio:message', { detail: message, cancelable: true, bubbles: true }),
    );
    if (go) apply(message);
  }

  /* Sends held text, then resolves with the view once the server has answered everything sent so far (at once when it
     has), or rejects with a LateError after `copy_wait_ms`. */
  function whenInStep() {
    flush();
    const target = sent;
    if (ack >= target) return Promise.resolve(view);
    return new Promise((resolve, reject) => {
      const waiter = { target, resolve, reject };
      waiter.timer = later(() => {
        waiters.delete(waiter);
        reject(new LateError());
      }, boot.copy_wait_ms);
      waiters.add(waiter);
    });
  }

  /* A button stays busy until the message that acknowledges `buttonSeq` has been drawn. */
  function track(button, buttonSeq) {
    button.dataset.smsWaitSeq = String(buttonSeq);
    setBusy(button, true);
  }

  function subscribe(listener) {
    listeners.add(listener);
    return () => listeners.delete(listener);
  }

  /* Shiny connected: what waited goes out. After a reconnect the server has a new session, whose messages count from
     1 again, so the page forgets its count and asks for everything with `ready`. */
  function onConnected() {
    connected = true;
    if (started) {
      n = 0;
      send('ready');
    }
    started = true;
    for (const event of waiting.splice(0)) post(event);
  }
  function onDisconnected() {
    connected = false;
  }

  const $ = window.jQuery;
  $?.(document).on('shiny:connected', onConnected);
  $?.(document).on('shiny:disconnected', onDisconnected);
  root.addEventListener('stagemap-studio:deliver', (event) => apply(event.detail), { signal });

  function destroy() {
    $?.(document).off('shiny:connected', onConnected);
    $?.(document).off('shiny:disconnected', onDisconnected);
    waiters.clear();
    listeners.clear();
  }

  return {
    send,
    flush,
    whenInStep,
    subscribe,
    receive,
    track,
    destroy,
    view,
    get ack() {
      return ack;
    },
    get rev() {
      return rev;
    },
  };
}
