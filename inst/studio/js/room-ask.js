/*
 * The Ask room: segmented switch between the three questions (pure CSS + native radios, no listeners here), one
 * form per question rendered by `form.js` (`event: null`, collected on Run), and the answer box (code call, stale
 * mark as words, Clear button, and table with target buttons and distance squares).
 */
import { make, setText, syncChildren } from './dom.js';
import { render as renderForm } from './form.js';

const SVG_NS = 'http://www.w3.org/2000/svg';
const STALE_TEXT = 'Map changed since: ask again';
const CLEAR_EVENT = JSON.stringify({ type: 'ask_clear', data: {} });
const prevAnswers = new WeakMap();

function makeZigzag() {
  const svg = document.createElementNS(SVG_NS, 'svg');
  svg.classList.add('sms-zig');
  svg.setAttribute('width', '16');
  svg.setAttribute('height', '10');
  svg.setAttribute('viewBox', '0 0 16 10');
  svg.setAttribute('aria-hidden', 'true');
  const path = document.createElementNS(SVG_NS, 'path');
  path.setAttribute('d', 'M1 8l3-6 3 6 3-6 3 6');
  path.setAttribute('stroke', 'currentColor');
  path.setAttribute('stroke-width', '1.8');
  path.setAttribute('fill', 'none');
  svg.append(path);
  return svg;
}

function syncSwitch(wrap, questions, ns, forceSelect) {
  let fieldset = wrap.querySelector(':scope > fieldset.sms-ask-switch');
  let seg;
  if (!fieldset) {
    fieldset = make('fieldset', 'sms-fieldset sms-ask-switch');
    const legend = make('legend', 'sms-ask-sr', 'Question');
    seg = make('div', 'sms-seg');
    fieldset.append(legend, seg);
  } else {
    seg = fieldset.querySelector(':scope > .sms-seg');
  }

  const byVal = new Map(
    [...seg.querySelectorAll(':scope > label.sms-seg-opt[data-sms-choice]')].map((lab) => [lab.dataset.smsChoice, lab]),
  );
  const currentChecked = seg.querySelector('input[type="radio"]:checked')?.value;
  const radioName = `${ns}ask-q`;
  const wanted = forceSelect || (questions.some((q) => q.id === currentChecked) ? currentChecked : questions[0]?.id);

  const items = questions.map((q) => {
    let lab = byVal.get(q.id);
    let input;
    let txt;
    if (!lab) {
      lab = make('label', 'sms-seg-opt');
      lab.dataset.smsChoice = q.id;
      input = document.createElement('input');
      input.type = 'radio';
      input.name = radioName;
      input.value = q.id;
      input.setAttribute('data-shiny-no-bind-input', '');
      const face = make('span', 'sms-seg-face');
      txt = make('span', 'sms-seg-text', q.label);
      face.append(txt);
      lab.append(input, face);
    } else {
      input = lab.querySelector('input[type="radio"]');
      txt = lab.querySelector('.sms-seg-text');
      if (input.name !== radioName) input.name = radioName;
      setText(txt, q.label);
    }
    if (forceSelect) {
      input.checked = q.id === wanted;
    } else if (!currentChecked) {
      input.checked = q.id === wanted;
    }
    return lab;
  });

  syncChildren(seg, items);
  return fieldset;
}

function resetPanelDrafts(panel, fields) {
  for (const field of fields ?? []) {
    const fld = panel.querySelector(`[data-sms-field="${CSS.escape(field.name)}"]`);
    if (!fld) continue;
    if (field.type === 'radio') {
      const wanted = String(field.value ?? '');
      for (const radio of fld.querySelectorAll('input[type="radio"]')) {
        radio.checked = radio.value === wanted;
      }
    } else if (field.type === 'toggle') {
      const box = fld.querySelector('input[type="checkbox"]');
      if (box) box.checked = Boolean(field.value);
    } else {
      const ctrl = fld.querySelector('.sms-in');
      if (ctrl) ctrl.value = field.value == null ? '' : String(field.value);
    }
  }
}

function syncPanels(wrap, questions, ctx, ns, syncTraceDrafts) {
  let box = wrap.querySelector(':scope > .sms-ask-panels');
  if (!box) box = make('div', 'sms-ask-panels');

  const byId = new Map(
    [...box.querySelectorAll(':scope > .sms-ask-panel[data-sms-q]')].map((p) => [p.dataset.smsQ, p]),
  );
  const nodes = questions.map((q) => {
    let panel = byId.get(q.id);
    let formHost;
    if (!panel) {
      panel = make('div', 'sms-ask-panel');
      panel.dataset.smsQ = q.id;
      panel.dataset.smsGroup = q.id;
      formHost = make('div', 'sms-ask-form');
      panel.append(formHost);
    } else {
      formHost = panel.querySelector(':scope > .sms-ask-form');
    }
    renderForm(
      formHost,
      { fields: q.fields ?? [], lists: [], actions: q.run ? [q.run] : [] },
      ctx,
      `${ns}ask-${q.id}-`,
    );
    if (syncTraceDrafts && q.id === 'trace') {
      resetPanelDrafts(formHost, q.fields);
    }
    return panel;
  });

  syncChildren(box, nodes);
  return box;
}

/* What a cell of an answer row holds: a card with a button, a card mark alone, distance squares, or text. */
function cellKind(cell, row) {
  if (cell.kind === 'card') return row.event ? 'pick' : 'mark';
  if (cell.kind === 'distance') return 'distance';
  return 'text';
}

function makeCell(kind) {
  const td = document.createElement('td');
  td.dataset.smsKind = kind;
  if (kind === 'pick') {
    const btn = make('button', 'sms-ask-pick');
    btn.type = 'button';
    btn.append(make('span', 'sms-ask-mk'));
    td.append(btn);
  } else if (kind === 'mark') {
    td.append(make('span', 'sms-ask-mk'));
  } else if (kind === 'distance') {
    const boxes = make('span', 'sms-ask-dist');
    boxes.setAttribute('aria-hidden', 'true');
    td.append(boxes, make('span', 'sms-ask-dist-text'));
  }
  return td;
}

/* Sets what changed in a cell and leaves its nodes (and so a button's focus and busy state) alone. */
function patchCell(td, kind, cell, row) {
  const text = String(cell.text ?? '');
  if (kind === 'pick') {
    const btn = td.firstElementChild;
    const event = JSON.stringify(row.event);
    if (btn.getAttribute('data-sms-event') !== event) btn.setAttribute('data-sms-event', event);
    setText(btn.firstElementChild, text);
  } else if (kind === 'mark') {
    setText(td.firstElementChild, text);
  } else if (kind === 'distance') {
    const boxes = td.firstElementChild;
    const max = Math.max(0, Number(cell.max ?? 0));
    const val = Math.max(0, Number(cell.value ?? 0));
    while (boxes.children.length > max) boxes.lastElementChild.remove();
    while (boxes.children.length < max) boxes.append(document.createElement('i'));
    [...boxes.children].forEach((sq, i) => {
      const cls = i < val ? 'sms-ask-dist-on' : '';
      if (sq.className !== cls) sq.className = cls;
    });
    setText(boxes.nextElementSibling, text);
  } else {
    setText(td, text);
  }
}

function makeRowNode(existing, row) {
  const tr = existing ?? document.createElement('tr');
  if (row.uid) tr.dataset.smsUid = row.uid;
  else delete tr.dataset.smsUid;

  const old = [...tr.children];
  const tds = (row.cells ?? []).map((cell, i) => {
    const kind = cellKind(cell, row);
    const td = old[i]?.dataset.smsKind === kind ? old[i] : makeCell(kind);
    patchCell(td, kind, cell, row);
    return td;
  });

  syncChildren(tr, tds);
  return tr;
}

/* The slot's status region, made empty with the slot so a later change is read out. It says what the answer says (the
   head sentence or the error, and the stale words); the table stays out of it. */
function getAnnouncer(slot) {
  let live = slot.querySelector(':scope > .sms-ask-live');
  if (!live) {
    live = make('p', 'sms-ask-sr sms-ask-live');
    live.setAttribute('role', 'status');
    live.setAttribute('aria-live', 'polite');
    slot.prepend(live);
  }
  return live;
}

function announcement(answer) {
  const said = answer.error ? `Could not run question. ${String(answer.error.head ?? '')}` : String(answer.head ?? '');
  return answer.stale ? `${said}. ${STALE_TEXT}` : said;
}

function syncAnswer(slot, answer, wrap) {
  const live = getAnnouncer(slot);
  if (!answer) {
    const hadFocus = slot.contains(document.activeElement);
    setText(live, '');
    slot.querySelector(':scope > .sms-ask-ans')?.remove();
    if (hadFocus) {
      const checked = wrap.querySelector('.sms-ask-switch input[type="radio"]:checked')?.value;
      const activePanel = checked ? wrap.querySelector(`.sms-ask-panel[data-sms-q="${CSS.escape(checked)}"]`) : null;
      const target =
        activePanel?.querySelector('button[data-sms-collect]') ?? wrap.closest('.sms-room')?.querySelector('h2');
      target?.focus();
    }
    return;
  }

  let box = slot.querySelector(':scope > .sms-ask-ans');
  let head;
  let meta;
  let titleEl;
  let clearBtn;
  if (!box) {
    box = make('div', 'sms-ask-ans');
    head = make('div', 'sms-ask-ans-head');
    meta = make('div', 'sms-ask-ans-meta');
    meta.setAttribute('aria-hidden', 'true'); /* the status region above the box says it */
    titleEl = make('p', 'sms-ask-ans-title');
    meta.append(titleEl);
    clearBtn = make('button', 'sms-btn', 'Clear');
    clearBtn.type = 'button';
    clearBtn.dataset.smsAction = 'Clear';
    clearBtn.setAttribute('data-sms-event', CLEAR_EVENT);
    head.append(meta, clearBtn);
    box.append(head);
    slot.append(box);
  } else {
    head = box.querySelector(':scope > .sms-ask-ans-head');
    meta = head.querySelector(':scope > .sms-ask-ans-meta');
    titleEl = meta.querySelector(':scope > .sms-ask-ans-title');
    clearBtn = head.querySelector(':scope > button[data-sms-action="Clear"]');
  }

  if (answer.stale) box.dataset.smsStale = 'true';
  else delete box.dataset.smsStale;

  setText(live, announcement(answer));
  setText(titleEl, answer.error ? 'Could not run question' : String(answer.head ?? ''));
  let staleEl = meta.querySelector(':scope > .sms-ask-stale');
  if (answer.stale) {
    if (!staleEl) staleEl = make('p', 'sms-ask-stale', STALE_TEXT);
    else setText(staleEl, STALE_TEXT);
    syncChildren(meta, [titleEl, staleEl]);
  } else {
    syncChildren(meta, [titleEl]);
  }

  const bodyParts = [head];
  if (answer.call) {
    let callEl = box.querySelector(':scope > .sms-ask-call');
    let codeEl;
    if (!callEl) {
      callEl = make('div', 'sms-ask-call');
      codeEl = make('code', 'sms-mono');
      callEl.append(codeEl);
    } else {
      codeEl = callEl.querySelector('code');
    }
    setText(codeEl, answer.call);
    bodyParts.push(callEl);
  }

  if (answer.error) {
    let errEl = box.querySelector(':scope > .sms-ask-err');
    let errHead;
    let errText;
    if (!errEl) {
      errEl = make('div', 'sms-ask-err');
      errHead = make('p', 'sms-err');
      errText = make('span', 'sms-err-text');
      errHead.append(makeZigzag(), errText);
      errEl.append(errHead);
    } else {
      errHead = errEl.querySelector(':scope > .sms-err');
      errText = errHead.querySelector('.sms-err-text');
    }
    setText(errText, String(answer.error.head ?? ''));
    const errNodes = [errHead];
    const lines = answer.error.lines ?? [];
    if (lines.length > 0) {
      let listEl = errEl.querySelector(':scope > ul.sms-ask-err-lines');
      if (!listEl) {
        listEl = make('ul', 'sms-ask-err-lines');
        listEl.setAttribute('role', 'list');
      }
      listEl.replaceChildren(
        ...lines.map((ln) => {
          const li = document.createElement('li');
          const mark = ln.mark === 'i' ? 'i' : 'x';
          const badge = make('span', `sms-ask-mark-${mark}`, mark === 'i' ? 'i' : 'x');
          li.append(badge, document.createTextNode(` ${String(ln.text ?? '')}`));
          return li;
        }),
      );
      errNodes.push(listEl);
    }
    syncChildren(errEl, errNodes);
    bodyParts.push(errEl);
  } else if ((answer.rows ?? []).length > 0) {
    let tableWrap = box.querySelector(':scope > .sms-ask-table-wrap');
    let table;
    let thead;
    let tbody;
    if (!tableWrap) {
      tableWrap = make('div', 'sms-ask-table-wrap');
      table = make('table', 'sms-ask-table');
      thead = document.createElement('thead');
      tbody = document.createElement('tbody');
      table.append(thead, tbody);
      tableWrap.append(table);
    } else {
      table = tableWrap.querySelector(':scope > table.sms-ask-table');
      thead = table.querySelector('thead');
      tbody = table.querySelector('tbody');
    }

    const headRow = document.createElement('tr');
    for (const col of answer.columns ?? []) {
      const th = make('th', '', String(col));
      th.scope = 'col';
      headRow.append(th);
    }
    thead.replaceChildren(headRow);

    const byUid = new Map(
      [...tbody.querySelectorAll(':scope > tr[data-sms-uid]')].map((tr) => [tr.dataset.smsUid, tr]),
    );
    const rowNodes = answer.rows.map((row) => makeRowNode(row.uid ? byUid.get(row.uid) : null, row));
    syncChildren(tbody, rowNodes);
    bodyParts.push(tableWrap);
  } else {
    let empty = box.querySelector(':scope > p.sms-empty');
    if (!empty) empty = make('p', 'sms-empty', 'Nothing to list.');
    else setText(empty, 'Nothing to list.');
    bodyParts.push(empty);
  }

  syncChildren(box, bodyParts);
}

export function render(el, ask, ctx) {
  const root = el.closest('.sms');
  const ns = root?.dataset.smsNs ?? '';
  const roomEl = el.closest('[data-sms-room-of="ask"]');
  const questions = ask?.questions ?? [];
  if (questions.length === 0) {
    prevAnswers.delete(el);
    el.replaceChildren(make('p', 'sms-empty', 'No questions available.'));
    return;
  }

  const answerJson = ask.answer ? JSON.stringify(ask.answer) : null;
  const answerChanged = answerJson !== (prevAnswers.get(el) ?? null);
  prevAnswers.set(el, answerJson);

  const fromInspector = Boolean(
    root?.querySelector('.sms-inspector [data-sms-action="Trace from here"][data-sms-wait-seq]'),
  );
  const openExternal = Boolean(ask.answer && !ask.answer.stale && (fromInspector || (roomEl?.hidden && answerChanged)));
  const forceSelect = openExternal ? ask.answer.question : null;

  let wrap = el.querySelector(':scope > .sms-ask');
  if (!wrap) {
    wrap = make('div', 'sms-ask');
    el.replaceChildren(wrap);
  }

  const switcher = syncSwitch(wrap, questions, ns, forceSelect);
  const panels = syncPanels(wrap, questions, ctx, ns, openExternal && ask.answer?.question === 'trace');

  let ansSlot = wrap.querySelector(':scope > .sms-ask-ans-slot');
  if (!ansSlot) ansSlot = make('div', 'sms-ask-ans-slot');
  syncChildren(wrap, [switcher, panels, ansSlot]);
  syncAnswer(ansSlot, ask.answer ?? null, wrap);

  if (openExternal && roomEl?.hidden) {
    root?.querySelector('[data-sms-room="ask"]')?.click();
  }
}
