/*
 * The Check room: renders R's error head and lines first, then one card per located fault with Show and Fix actions,
 * then any build notes; when clean, one line and nothing else. Also updates the Check button in the title block.
 * The room keeps one status line (role="status") across renders that says the count, so a fix that clears the list is
 * announced, and patches fault cards by fault id and their buttons by label, so a clicked button stays busy until its
 * own answer is drawn. Every word the page writes comes from `ctx.labels` (set by R). Never adds event listeners: the
 * studio root delegates all button clicks via `data-sms-event`.
 */
import { make, setDisabled, setText, syncChildren } from './dom.js';

const SVG_NS = 'http://www.w3.org/2000/svg';

function makeZigzag() {
  const svg = document.createElementNS(SVG_NS, 'svg');
  svg.classList.add('sms-zig');
  svg.setAttribute('width', '20');
  svg.setAttribute('height', '11');
  svg.setAttribute('viewBox', '0 0 22 12');
  svg.setAttribute('aria-hidden', 'true');
  const path = document.createElementNS(SVG_NS, 'path');
  path.setAttribute('d', 'M1 10l3.5-8 3.5 8 3.5-8 3.5 8 3.5-8');
  path.setAttribute('stroke', 'currentColor');
  path.setAttribute('stroke-width', '2');
  path.setAttribute('fill', 'none');
  svg.append(path);
  return svg;
}

function makeCheckIcon() {
  const svg = document.createElementNS(SVG_NS, 'svg');
  svg.classList.add('sms-check-icon');
  svg.setAttribute('width', '16');
  svg.setAttribute('height', '16');
  svg.setAttribute('viewBox', '0 0 20 20');
  svg.setAttribute('aria-hidden', 'true');
  const path = document.createElementNS(SVG_NS, 'path');
  path.setAttribute('d', 'M3 10.5l4.5 4.5L17 5');
  path.setAttribute('stroke', 'currentColor');
  path.setAttribute('stroke-width', '2.4');
  path.setAttribute('fill', 'none');
  svg.append(path);
  return svg;
}

function actionClass(style) {
  if (style === 'primary') return 'sms-btn sms-pri';
  if (style === 'danger') return 'sms-btn sms-danger';
  return 'sms-btn';
}

/* Keeps `existing` (a button of the same label) and updates it, or builds one; busy marks on it stay. */
function syncButton(existing, action, describedBy) {
  const btn = existing ?? make('button', '', action.label);
  btn.className = actionClass(action.style);
  setText(btn, action.label);
  btn.type = 'button';
  btn.dataset.smsAction = action.label;
  if (action.aria_label) btn.setAttribute('aria-label', action.aria_label);
  else btn.removeAttribute('aria-label');
  btn.setAttribute('aria-describedby', describedBy);
  btn.setAttribute('data-sms-event', JSON.stringify(action.event));
  setDisabled(btn, Boolean(action.disabled));
  return btn;
}

function updateSummaryButton(root, check, ctx) {
  const btn = root?.querySelector('[data-sms-room="check"]');
  const valEl = btn?.querySelector('.sms-val');
  if (!btn || !valEl) return;
  const count = problemCount(check);
  if (count === 0) {
    btn.dataset.smsState = 'good';
    valEl.replaceChildren(makeCheckIcon(), document.createTextNode(ctx.labels.clean));
  } else {
    btn.dataset.smsState = 'bad';
    valEl.replaceChildren(makeZigzag(), document.createTextNode(`${count} ${problemWord(count, ctx)}`));
  }
}

function problemCount(check) {
  const faults = check?.faults ?? [];
  return faults.length > 0 ? faults.length : check?.ok ? 0 : 1;
}

function problemWord(count, ctx) {
  return count === 1 ? ctx.labels.problem_one : ctx.labels.problem_many;
}

function buildLineNode(line, ctx) {
  const li = make('li', 'sms-check-line');
  const mark = line?.mark === 'i' ? 'i' : 'x';
  const glyph = make('span', 'sms-check-mark', mark === 'i' ? 'ℹ' : '✖');
  glyph.dataset.smsMark = mark;
  glyph.setAttribute('aria-hidden', 'true');
  const sr = make('span', 'sms-sr', `${mark === 'i' ? ctx.labels.info : ctx.labels.error} `);
  const text = make('span', 'sms-check-line-text', String(line?.text ?? ''));
  li.append(glyph, sr, text);
  return li;
}

/* One fault card: kept by fault id; its text names the card and describes each of its buttons. */
function syncFaultCard(existing, fault, ctx, textId) {
  let card = existing;
  let top;
  let textEl;
  let act;
  if (!card) {
    card = make('article', 'sms-chk');
    top = make('div', 'sms-chk-top');
    textEl = make('span', 'sms-chk-text');
    textEl.id = textId;
    top.append(makeZigzag(), textEl);
    act = make('div', 'sms-chk-act');
    card.append(top, act);
    card.dataset.smsFaultId = fault.id ?? '';
    card.setAttribute('aria-labelledby', textId);
  } else {
    textEl = card.querySelector('.sms-chk-text');
    act = card.querySelector(':scope > .sms-chk-act');
  }
  setText(textEl, String(fault.text ?? ''));

  const old = new Map(
    [...act.querySelectorAll(':scope > button[data-sms-action]')].map((b) => [b.dataset.smsAction, b]),
  );
  const nodes = [];
  if (fault.where?.kind && fault.where?.uid) {
    const show = {
      label: ctx.labels.show,
      style: 'plain',
      event: { type: 'target', data: { kind: fault.where.kind, uid: fault.where.uid } },
    };
    nodes.push(syncButton(old.get(show.label), show, textEl.id));
  }
  const fixes = fault.fixes ?? [];
  if (fixes.length > 0) {
    const lab = act.querySelector(':scope > .sms-chk-lab') ?? make('span', 'sms-chk-lab');
    setText(lab, ctx.labels.fix_prefix);
    nodes.push(lab);
    for (const fix of fixes) nodes.push(syncButton(old.get(fix.label), fix, textEl.id));
  }
  syncChildren(act, nodes);
  return card;
}

/* The faults list is kept across renders; its cards are patched by fault id, in R's order. */
function syncFaultList(list, faults, ctx) {
  const old = new Map([...list.children].map((card) => [card.dataset.smsFaultId, card]));
  const cards = faults.map((fault) => {
    const key = fault.id ?? '';
    const prior = old.get(key);
    let textId = prior?.getAttribute('aria-labelledby');
    if (!textId) {
      const next = Number(list.dataset.smsNextId ?? 0) + 1;
      list.dataset.smsNextId = String(next);
      textId = `${list.dataset.smsIdPrefix}${next}`;
    }
    return syncFaultCard(prior, fault, ctx, textId);
  });
  syncChildren(list, cards);
}

function buildClean(text) {
  const clean = make('div', 'sms-check-clean');
  clean.append(makeCheckIcon(), make('p', 'sms-check-clean-text', text));
  return clean;
}

/* The first control of the card at `index` (or the last card when the list got shorter), if any. */
function nextFaultControl(list, index) {
  const cards = [...list.children];
  if (cards.length === 0) return null;
  return cards[Math.min(index, cards.length - 1)].querySelector('button');
}

export function render(el, check, ctx) {
  const root = el.closest('.sms');
  updateSummaryButton(root, check, ctx);

  const ns = root?.dataset.smsNs ?? '';
  let status = el.querySelector(':scope > .sms-check-status');
  let body = el.querySelector(':scope > .sms-check-body');
  if (!status || !body) {
    status = make('p', 'sms-sr sms-check-status');
    status.setAttribute('role', 'status');
    status.setAttribute('aria-atomic', 'true');
    body = make('div', 'sms-check-body');
    el.replaceChildren(status, body);
  }
  let list = body.querySelector(':scope > .sms-check-faults');
  if (!list) {
    list = make('div', 'sms-check-faults');
    list.dataset.smsIdPrefix = `${ns}chk-text-`;
  }

  const active = document.activeElement;
  const hadFocus = el.contains(active);
  const focusCard = hadFocus ? active.closest('.sms-chk') : null;
  const focusIndex = focusCard ? [...list.children].indexOf(focusCard) : -1;

  const faults = check?.faults ?? [];
  const lines = check?.lines ?? [];
  const notes = check?.notes ?? [];
  const ok = Boolean(check?.ok);
  const head = String(check?.head ?? '');

  const count = problemCount(check);
  setText(status, count === 0 ? head : `${count} ${problemWord(count, ctx)}`);

  syncFaultList(list, faults, ctx);
  const parts = [];
  if (ok && faults.length === 0 && notes.length === 0) {
    parts.push(buildClean(head));
  } else {
    if (!ok) {
      const box = make('section', 'sms-check-r');
      box.setAttribute('aria-label', ctx.labels.r_message);
      const headEl = make('div', 'sms-check-r-head');
      headEl.append(makeZigzag(), make('span', 'sms-check-r-title', head));
      box.append(headEl);
      if (lines.length > 0) {
        const ul = make('ul', 'sms-check-lines');
        ul.setAttribute('role', 'list');
        for (const line of lines) ul.append(buildLineNode(line, ctx));
        box.append(ul);
      }
      parts.push(box);
    } else if (head) {
      parts.push(buildClean(head));
    }
    if (faults.length > 0) parts.push(list);
    if (notes.length > 0) {
      const notesSec = make('section', 'sms-check-notes');
      notesSec.append(make('h3', 'sms-sec-title', ctx.labels.notes));
      const ul = make('ul', 'sms-check-notes-list');
      ul.setAttribute('role', 'list');
      for (const note of notes) ul.append(make('li', '', String(note)));
      notesSec.append(ul);
      parts.push(notesSec);
    }
  }
  /* The faults list stays in place while it has cards, so a focused or busy button is never replaced. */
  syncChildren(body, parts);

  if (hadFocus && !el.contains(document.activeElement)) {
    const next = focusIndex >= 0 ? nextFaultControl(list, focusIndex) : null;
    const heading = el.closest('.sms-room')?.querySelector('[tabindex="-1"]');
    (next ?? heading)?.focus({ preventScroll: true });
  }
}
