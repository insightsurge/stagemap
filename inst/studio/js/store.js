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
  const waiting = []; /* events sent while the session is not initialised, in the order they were sent */
  const deferred = []; /* events held one tick so a reader's map pick leaves before an immediate action */
  let deferTimer = 0;
  let seq = 0;
  let sent = 0;
  let ack = 0;
  let n = 0;
  let rev = 0;
  /* Whether events may go out: the session is initialised (Shiny has applied its `init` message), which is later than
     `shiny:connected`. `begun` says a session was initialised before, so the next one is a reconnect. */
  let connected = Boolean(window.Shiny?.shinyapp?.config) && Boolean(window.Shiny?.shinyapp?.isConnected?.());
  let begun = connected;
  let restarting = false; /* the `ready` for the next session is already waiting */

  function post(event) {
    window.Shiny.setInputValue(`${ns}event`, event, { priority: 'event' });
  }

  function flushDeferred() {
    deferTimer = 0;
    for (const event of deferred.splice(0)) {
      if (connected) post(event);
      else waiting.push(event);
    }
  }

  /* Holds outgoing events for one tick so the map widget's own 0 ms pick push reaches Shiny first. */
  function deferNextTick() {
    if (!deferTimer) deferTimer = later(flushDeferred, 0);
  }

  function markBusy() {
    if (sent > ack) root.setAttribute('aria-busy', 'true');
    else root.removeAttribute('aria-busy');
  }

  /* Numbers and raises the event `type`; it goes out at once, or waits for the session. */
  function emit(type, data) {
    seq += 1;
    const event = { seq, type, data, rev };
    sent = seq;
    root.dataset.smsSent = String(sent);
    markBusy();
    const go = root.dispatchEvent(
      new CustomEvent('stagemap-studio:send', { detail: event, cancelable: true, bubbles: true }),
    );
    if (go) {
      if (deferTimer) deferred.push(event);
      else if (connected) post(event);
      else waiting.push(event);
    }
    return seq;
  }

  /* Sends the event `type` with `data` and returns its seq. Held text goes first. */
  function send(type, data = {}) {
    flush();
    return emit(type, data);
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

  /* The connection dropped. The next session has none of this page's events and its server steps no event before `ready`, so the
     `ready` that asks for everything is numbered now, once for the gap: every event typed from here on has a higher
     seq, and the answer to `ready` cannot acknowledge an edit the new session has not applied. It does not flush held
     text first, which would number that text ahead of it. */
  function onDisconnected() {
    connected = false;
    if (begun && !restarting) {
      restarting = true;
      emit('ready', {});
    }
  }

  /* Shiny has applied its `init` message: what waited goes out, in order. It is posted here and not on
     `shiny:connected`, which comes before `init`, whose copy of the inputs would overwrite what was posted. After a
     reconnect the server has a new session, whose messages count from 1 again, so the page forgets its count. */
  function onInitialized() {
    connected = true;
    if (begun) n = 0;
    begun = true;
    restarting = false;
    for (const event of waiting.splice(0)) post(event);
  }

  const $ = window.jQuery;
  $?.(document).on('shiny:sessioninitialized', onInitialized);
  $?.(document).on('shiny:disconnected', onDisconnected);
  root.addEventListener('stagemap-studio:deliver', (event) => apply(event.detail), { signal });

  function destroy() {
    $?.(document).off('shiny:sessioninitialized', onInitialized);
    $?.(document).off('shiny:disconnected', onDisconnected);
    waiters.clear();
    listeners.clear();
  }

  return {
    send,
    flush,
    deferNextTick,
    whenInStep,
    subscribe,
    receive,
    track,
    destroy,
    view,
    get ack() {
      return ack;
    },
    get sent() {
      return sent;
    },
    get rev() {
      return rev;
    },
  };
}
