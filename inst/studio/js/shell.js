/*
 * The shell: which room of the tray is open and where focus goes, the toast, and the closed state after Done. Rooms open
 * and close from their buttons in the title block (`data-sms-room`, with `aria-expanded` and `aria-controls`); a closed
 * room is hidden and `inert`, and so is the tray while no room is open. Escape closes the room opened last; focus goes
 * back to its button when it was inside the room, and stays where it was otherwise. On a phone (640px and below) one
 * room is open at a time.
 */
import { setText } from './dom.js';

const TOAST_MS = 6000;

export function createShell(root, boot, tools) {
  const { later, cancel } = tools;
  const tray = root.querySelector('.sms-tray');
  const open = []; /* the names of the open rooms, the last opened last */
  let toastTimer = 0;
  let noticeN = 0;

  const buttonOf = (name) =>
    [...root.querySelectorAll('[data-sms-room]')].find((button) => button.dataset.smsRoom === name);
  const roomOf = (button) => document.getElementById(button.getAttribute('aria-controls'));

  function openRoom(name) {
    const button = buttonOf(name);
    const room = button && roomOf(button);
    if (!room || open.includes(name)) return;
    if (window.matchMedia('(max-width: 640px)').matches) {
      for (const other of [...open]) closeRoom(other, false);
    }
    room.hidden = false;
    room.inert = false;
    button.setAttribute('aria-expanded', 'true');
    open.push(name);
    tray.inert = false;
    root.dataset.smsTray = open.join(' ');
    /* Focus goes into the room, to its heading, so the next Tab reaches the room's first control. */
    room.querySelector('[tabindex="-1"]')?.focus({ preventScroll: true });
  }

  /* Closes the room `name`; with `refocus`, focus that was inside the room goes back to the button that opened it. */
  function closeRoom(name, refocus = true) {
    const index = open.indexOf(name);
    if (index < 0) return;
    const button = buttonOf(name);
    const room = roomOf(button);
    /* Read before the room is hidden, which moves focus away: only focus that was inside the room goes back. */
    const inside = room.contains(document.activeElement);
    open.splice(index, 1);
    room.hidden = true;
    room.inert = true;
    button.setAttribute('aria-expanded', 'false');
    if (open.length === 0) {
      tray.inert = true;
      delete root.dataset.smsTray;
    } else {
      root.dataset.smsTray = open.join(' ');
    }
    if (refocus && inside) button.focus();
  }

  function toggleRoom(name) {
    if (open.includes(name)) closeRoom(name);
    else openRoom(name);
  }

  /* Closes the topmost open room; false when none was open. */
  function closeTopmost() {
    const name = open.at(-1);
    if (name === undefined) return false;
    closeRoom(name);
    return true;
  }

  /* A short message in the toast (a status region), gone after a while. `tone` is "info" or "problem". */
  function toast(text, tone = 'info') {
    const box = root.querySelector('.sms-toast');
    setText(box.querySelector('.sms-toast-tone'), tone === 'problem' ? boot.labels.problem : '');
    setText(box.querySelector('.sms-toast-text'), text);
    box.dataset.smsOn = '';
    box.dataset.smsTone = tone;
    cancel(toastTimer);
    toastTimer = later(() => {
      delete box.dataset.smsOn;
      setText(box.querySelector('.sms-toast-tone'), '');
      setText(box.querySelector('.sms-toast-text'), '');
    }, TOAST_MS);
  }

  /* The `notice` section: a toast, once per notice. */
  function renderNotice(notice) {
    if (!notice || notice.n === noticeN) return;
    noticeN = notice.n;
    toast(notice.text, notice.tone);
  }

  /* The `status` section: after Done, the sheet, the tray and the title block are inert and the page says so. */
  function renderStatus(status) {
    if (!status?.closed || root.dataset.smsClosed !== undefined) return;
    for (const name of [...open]) closeRoom(name, false);
    root.dataset.smsClosed = '';
    for (const part of root.querySelectorAll('.sms-sheet, .sms-tray, .sms-block')) part.inert = true;
    setText(root.querySelector('.sms-closed'), boot.labels.closed);
  }

  return { openRoom, closeRoom, toggleRoom, closeTopmost, toast, renderNotice, renderStatus };
}
