/*
 * The `code` section: the R code room's lines, numbered by CSS, each made of spans whose class comes from the server,
 * the problem note above the code, the `.R` and `CSV` download buttons in the room's head, and the count of lines in
 * the room's head and in the title block. Adds no event listeners: download clicks and menus are delegated on root.
 */
import { make, setText, syncChildren } from './dom.js';

function syncDownloads(root, downloads) {
  const room = root.querySelector('[data-sms-room-of="code"]');
  const head = room?.querySelector('.sms-room-head');
  const closeBtn = head?.querySelector('[data-sms-close="code"]');
  if (!head || !closeBtn) return;

  const list = downloads ?? [];
  const sig = JSON.stringify(list.map((d) => [d.id, d.label]));
  if (head.dataset.smsDownloads === sig) return;
  head.dataset.smsDownloads = sig;

  const ns = root.dataset.smsNs ?? '';
  const rItem = list.find((d) => d.id === 'download_r');
  const csvItems = list.filter((d) => d.id !== 'download_r');

  let rBtn = head.querySelector('[data-sms-download="download_r"]');
  if (rItem) {
    if (!rBtn) {
      rBtn = make('button', 'sms-btn', '.R');
      rBtn.type = 'button';
      rBtn.dataset.smsDownload = rItem.id;
      rBtn.setAttribute('aria-label', `.R file (${rItem.label})`);
    }
    if (rBtn.nextElementSibling !== closeBtn) {
      head.insertBefore(rBtn, closeBtn);
    }
  } else {
    rBtn?.remove();
  }

  let csvWrap = head.querySelector('.sms-menu.sms-code-csv');
  if (csvItems.length > 0) {
    let pop;
    if (!csvWrap) {
      csvWrap = make('div', 'sms-menu sms-code-csv');
      const triggerWrap = make('span', 'sms-menu-trigger');
      const trigger = make('button', 'sms-btn', 'CSV');
      trigger.type = 'button';
      trigger.dataset.smsMenu = 'csv';
      trigger.setAttribute('aria-haspopup', 'menu');
      trigger.setAttribute('aria-expanded', 'false');
      trigger.setAttribute('aria-controls', `${ns}menu-csv`);
      triggerWrap.append(trigger);
      pop = make('div', 'sms-menu-pop');
      pop.id = `${ns}menu-csv`;
      pop.setAttribute('role', 'menu');
      pop.hidden = true;
      csvWrap.append(triggerWrap, pop);
    } else {
      pop = csvWrap.querySelector('.sms-menu-pop');
    }
    const existing = new Map(
      [...pop.querySelectorAll('[role="menuitem"][data-sms-download]')].map((btn) => [btn.dataset.smsDownload, btn]),
    );
    const items = csvItems.map((item) => {
      let btn = existing.get(item.id);
      if (!btn) {
        btn = make('button', 'sms-menu-item', item.label);
        btn.type = 'button';
        btn.setAttribute('role', 'menuitem');
        btn.dataset.smsDownload = item.id;
      } else {
        setText(btn, item.label);
      }
      return btn;
    });
    syncChildren(pop, items);
    if (csvWrap.nextElementSibling !== closeBtn) {
      head.insertBefore(csvWrap, closeBtn);
    }
  } else {
    csvWrap?.remove();
  }
}

export function render(root, code, ctx) {
  const room = root.querySelector('[data-sms-room-of="code"]');
  const body = room?.querySelector('.sms-room-body');
  const box = root.querySelector('.sms-code');
  const note = root.querySelector('.sms-code-note');
  if (body && box && note && note.nextElementSibling !== box) {
    body.insertBefore(note, box);
  }
  const lines = code.lines ?? [];
  box.replaceChildren(
    ...lines.map((line) => {
      const node = make('span', 'sms-l');
      if (line.changed) node.dataset.smsChanged = '';
      for (const [text, kind] of line.spans ?? []) {
        node.append(kind ? make('span', `sms-tok-${kind}`, text) : document.createTextNode(text));
      }
      return node;
    }),
  );
  const count = `${lines.length} ${lines.length === 1 ? ctx.labels.line : ctx.labels.lines}`;
  setText(root.querySelector('.sms-code-sum'), count);
  setText(root.querySelector('.sms-code-count'), count);
  setText(note, code.problem ?? '');
  syncDownloads(root, code.downloads);
}
