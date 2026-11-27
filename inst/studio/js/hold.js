/*
 * Held text: what a person types in a text field waits `hold_ms` after the last key, then goes out with the field's own
 * event (from its `data-sms-event`, with `value` added). `flush()` sends everything held at once; the store calls it
 * before every send, and the page calls it on Enter and when a field loses focus. While its text is held a field's
 * `data-sms-seq` is Infinity, so no render overwrites it; once sent it is the seq of that send.
 */
import { readEvent } from './dom.js';

export function createHold(boot, send, tools) {
  const { later, cancel } = tools;
  const held = new Map(); /* field -> its timer */

  function hold(field) {
    cancel(held.get(field));
    field.dataset.smsSeq = 'Infinity';
    field.setAttribute('data-sms-wait', '');
    held.set(
      field,
      later(() => release(field), boot.hold_ms),
    );
  }

  /* Sends the field's text. It leaves the map first, so the store's flush before the send finds nothing to send. */
  function release(field) {
    cancel(held.get(field));
    held.delete(field);
    const event = readEvent(field);
    const seq = send(event.type, { ...event.data, value: field.value });
    field.dataset.smsSeq = String(seq);
    field.removeAttribute('data-sms-wait');
  }

  function flush() {
    for (const field of [...held.keys()]) release(field);
  }

  return { hold, flush, isHeld: (field) => held.has(field) };
}
