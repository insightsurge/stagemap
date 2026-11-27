/*
 * The Check room: renders R's error head and lines first, then one card per located fault with Show and Fix actions,
 * then any build notes; when clean, one line and nothing else. Also updates the Check button in the title block.
 * Never adds event listeners: the studio root delegates all button clicks via `data-sms-event`.
 */
import { make, setDisabled, setText } from './dom.js';

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

function buildButton(action) {
  const btn = make('button', actionClass(action.style), action.label);
  btn.type = 'button';
  btn.dataset.smsAction = action.label;
  if (action.aria_label) btn.setAttribute('aria-label', action.aria_label);
  btn.setAttribute('data-sms-event', JSON.stringify(action.event));
  setDisabled(btn, Boolean(action.disabled));
  return btn;
}

function updateSummaryButton(root, check, ctx) {
  const btn = root?.querySelector('[data-sms-room="check"]');
  const valEl = btn?.querySelector('.sms-val');
  if (!btn || !valEl) return;
  const faults = check?.faults ?? [];
  const count = faults.length > 0 ? faults.length : check?.ok ? 0 : 1;
  if (count === 0) {
    btn.dataset.smsState = 'good';
    valEl.replaceChildren(makeCheckIcon(), document.createTextNode('Clean'));
  } else {
    btn.dataset.smsState = 'bad';
    const word = count === 1 ? ctx.labels.problem_one : ctx.labels.problem_many;
    valEl.replaceChildren(makeZigzag(), document.createTextNode(`${count} ${word}`));
  }
}

function buildLineNode(line) {
  const li = make('li', 'sms-check-line');
  const mark = line?.mark === 'i' ? 'i' : 'x';
  const glyph = make('span', 'sms-check-mark', mark === 'i' ? '\u2139' : '\u2716');
  glyph.dataset.smsMark = mark;
  glyph.setAttribute('aria-hidden', 'true');
  const sr = make('span', 'sms-sr', mark === 'i' ? 'Info: ' : 'Error: ');
  const text = make('span', 'sms-check-line-text', String(line?.text ?? ''));
  li.append(glyph, sr, text);
  return li;
}

function buildFaultCard(fault) {
  const card = make('article', 'sms-chk');
  card.dataset.smsFaultId = fault.id ?? '';
  const top = make('div', 'sms-chk-top');
  top.append(makeZigzag(), make('span', 'sms-chk-text', String(fault.text ?? '')));
  card.append(top);

  const hasShow = Boolean(fault.where?.kind && fault.where?.uid);
  const fixes = fault.fixes ?? [];
  if (hasShow || fixes.length > 0) {
    const act = make('div', 'sms-chk-act');
    if (hasShow) {
      act.append(
        buildButton({
          label: 'Show',
          style: 'plain',
          event: { type: 'target', data: { kind: fault.where.kind, uid: fault.where.uid } },
        }),
      );
    }
    if (fixes.length > 0) {
      act.append(make('span', 'sms-chk-lab', 'Fix:'));
      for (const fix of fixes) act.append(buildButton(fix));
    }
    card.append(act);
  }
  return card;
}

export function render(el, check, ctx) {
  const root = el.closest('.sms');
  updateSummaryButton(root, check, ctx);

  const hadFocus = el.contains(document.activeElement);
  const faults = check?.faults ?? [];
  const lines = check?.lines ?? [];
  const notes = check?.notes ?? [];
  const ok = Boolean(check?.ok);

  if (ok && faults.length === 0 && notes.length === 0) {
    const clean = make('div', 'sms-check-clean');
    clean.append(makeCheckIcon(), make('p', 'sms-check-clean-text', check?.head || 'stage_map() accepts this map.'));
    el.replaceChildren(clean);
  } else {
    const parts = [];
    if (!ok) {
      const box = make('section', 'sms-check-r');
      box.setAttribute('aria-label', 'R check message');
      const head = make('div', 'sms-check-r-head');
      head.append(makeZigzag(), make('span', 'sms-check-r-title', check?.head || 'Problems found.'));
      box.append(head);
      if (lines.length > 0) {
        const ul = make('ul', 'sms-check-lines');
        ul.setAttribute('role', 'list');
        for (const line of lines) ul.append(buildLineNode(line));
        box.append(ul);
      }
      parts.push(box);
    } else if (check?.head) {
      const clean = make('div', 'sms-check-clean');
      clean.append(makeCheckIcon(), make('p', 'sms-check-clean-text', check.head));
      parts.push(clean);
    }

    if (faults.length > 0) {
      const list = make('div', 'sms-check-faults');
      for (const fault of faults) list.append(buildFaultCard(fault));
      parts.push(list);
    }

    if (notes.length > 0) {
      const notesSec = make('section', 'sms-check-notes');
      notesSec.append(make('h3', 'sms-sec-title', 'Notes'));
      const ul = make('ul', 'sms-check-notes-list');
      ul.setAttribute('role', 'list');
      for (const note of notes) ul.append(make('li', '', String(note)));
      notesSec.append(ul);
      parts.push(notesSec);
    }

    el.replaceChildren(...parts);
  }

  if (hadFocus && !el.contains(document.activeElement)) {
    const heading = el.closest('.sms-room')?.querySelector('[tabindex="-1"]');
    heading?.focus({ preventScroll: true });
  }
  setText(root?.querySelector('[data-sms-room-of="check"] .sms-room-head h2'), 'Check');
}
