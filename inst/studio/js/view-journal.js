/*
 * The `journal` section: a single-line ribbon of changes since the map opened, hidden until the first entry, with an
 * Undo button. Undone entries show the word "undone"; clickable entries target their row when it still exists.
 */
import { make, setBusy } from './dom.js';

function entryContent(entry, labels) {
  const parts = [
    make('span', 'sms-ev-n', `#${entry.n}`),
    make('span', 'sms-ev-v', entry.verb),
    make('span', 'sms-ev-d', entry.text),
  ];
  if (entry.state === 'undone') {
    parts.push(make('span', 'sms-ev-undone', labels.undone));
  }
  return parts;
}

export function render(el, journal, ctx) {
  const entries = journal?.entries ?? [];
  if (entries.length === 0) {
    el.hidden = true;
    el.replaceChildren();
    return;
  }
  el.hidden = false;

  const lab = el.querySelector('.sms-journal-lab') ?? make('span', 'sms-journal-lab', ctx.labels.journal);
  const list = el.querySelector('.sms-journal-list') ?? make('ol', 'sms-journal-list');
  const items = entries.map((entry) => {
    const li = make('li', 'sms-ev');
    li.dataset.smsState = entry.state;
    if (entry.target) {
      const btn = make('button', 'sms-ev-btn');
      btn.type = 'button';
      btn.setAttribute('data-sms-event', JSON.stringify({ type: 'target', data: entry.target }));
      btn.append(...entryContent(entry, ctx.labels));
      li.append(btn);
    } else {
      const span = make('span', 'sms-ev-item');
      span.append(...entryContent(entry, ctx.labels));
      li.append(span);
    }
    return li;
  });
  list.replaceChildren(...items);

  let undoBtn = el.querySelector('.sms-undo');
  if (!undoBtn) {
    undoBtn = make('button', 'sms-btn sms-undo', ctx.labels.undo);
    undoBtn.type = 'button';
    undoBtn.setAttribute('data-sms-event', JSON.stringify({ type: 'undo', data: {} }));
  }
  if (!undoBtn.hasAttribute('data-sms-wait-seq')) {
    setBusy(undoBtn, !journal.can_undo);
  }

  el.replaceChildren(lab, list, undoBtn);
  list.scrollLeft = list.scrollWidth;
}
