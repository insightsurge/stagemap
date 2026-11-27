/*
 * The `journal` section: a single-line ribbon of changes since the map opened, hidden until the first entry, with an
 * Undo button. Undone entries show the word "undone"; clickable entries target their row when it still exists.
 */
import { make, setDisabled, setText, syncChildren } from './dom.js';

function syncEntryShell(holder, entry, labels) {
  let num = holder.querySelector('.sms-ev-n');
  let verb = holder.querySelector('.sms-ev-v');
  let desc = holder.querySelector('.sms-ev-d');
  if (!num || !verb || !desc) {
    num = make('span', 'sms-ev-n');
    verb = make('span', 'sms-ev-v');
    desc = make('span', 'sms-ev-d');
  }
  setText(num, `#${entry.n}`);
  setText(verb, entry.verb);
  setText(desc, entry.text);
  const parts = [num, verb, desc];
  let undone = holder.querySelector('.sms-ev-undone');
  if (entry.state === 'undone') {
    if (!undone) undone = make('span', 'sms-ev-undone', labels.undone);
    else setText(undone, labels.undone);
    parts.push(undone);
  }
  syncChildren(holder, parts);
}

function syncEntryNode(existing, entry, labels) {
  const li = existing ?? make('li', 'sms-ev');
  li.dataset.smsN = String(entry.n);
  li.dataset.smsState = entry.state;
  const wantTag = entry.target ? 'BUTTON' : 'SPAN';
  let holder = li.firstElementChild;
  if (!holder || holder.tagName !== wantTag) {
    holder = entry.target ? make('button', 'sms-ev-btn') : make('span', 'sms-ev-item');
    if (entry.target) holder.type = 'button';
    li.replaceChildren(holder);
  }
  if (entry.target) {
    holder.setAttribute('data-sms-event', JSON.stringify({ type: 'target', data: entry.target }));
  }
  syncEntryShell(holder, entry, labels);
  return li;
}

export function render(el, journal, ctx) {
  const entries = journal?.entries ?? [];
  if (entries.length === 0) {
    if (el.contains(document.activeElement)) {
      el.closest('.sms')?.querySelector('.sms-title')?.focus();
    }
    el.hidden = true;
    el.replaceChildren();
    return;
  }
  el.hidden = false;

  const lab = el.querySelector('.sms-journal-lab') ?? make('span', 'sms-journal-lab', ctx.labels.journal);
  const list = el.querySelector('.sms-journal-list') ?? make('ol', 'sms-journal-list');
  const byN = new Map([...list.querySelectorAll(':scope > li[data-sms-n]')].map((li) => [li.dataset.smsN, li]));
  const items = entries.map((entry) => syncEntryNode(byN.get(String(entry.n)), entry, ctx.labels));
  syncChildren(list, items);

  let undoBtn = el.querySelector('.sms-undo');
  if (!undoBtn) {
    undoBtn = make('button', 'sms-btn sms-undo', ctx.labels.undo);
    undoBtn.type = 'button';
    undoBtn.setAttribute('data-sms-event', JSON.stringify({ type: 'undo', data: {} }));
  }
  setDisabled(undoBtn, !journal.can_undo);

  syncChildren(el, [lab, list, undoBtn]);
  list.scrollLeft = list.scrollWidth;
}
