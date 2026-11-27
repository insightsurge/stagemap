/*
 * Generic form renderer: draws `{ fields, lists, actions }` described by R into any container (inspector, Map room,
 * Ask room). Patches fields by `name`, list rows by `uid`, and actions by `label` so unchanged nodes stay put and
 * focus and the caret survive. Never adds event listeners: the studio root delegates all input, change and click
 * handling through `data-sms-event` and `data-sms-collect`. Knows no table, column, rule or engine class name.
 */
import { canPatch, make, setDisabled, setText, syncChildren } from './dom.js';

const SVG_NS = 'http://www.w3.org/2000/svg';

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

const GLYPH_PATHS = {
  check: { w: 12, h: 12, d: 'M2 6.5l2.6 2.6L10 3.5', stroke: true },
  play: { w: 12, h: 12, d: 'M3 2l7 4-7 4z', stroke: false },
  cross: { w: 12, h: 12, d: 'M3 3l6 6M9 3l-6 6', stroke: true },
  dash: { w: 12, h: 12, d: 'M2.5 6h7', stroke: true },
  'line-solid': { w: 26, h: 8, d: 'M1 4h24', stroke: true },
  'line-dashed': { w: 26, h: 8, d: 'M1 4h5M10 4h5M19 4h6', stroke: true },
  'line-dotted': { w: 26, h: 8, d: 'M1 4h2M6 4h2M11 4h2M16 4h2M21 4h2', stroke: true },
  'line-dashdot': { w: 26, h: 8, d: 'M1 4h6M10 4h2M15 4h6M24 4h1', stroke: true },
};

function makeGlyph(name) {
  if (!name) return null;
  if (name === 'dots') {
    const svg = document.createElementNS(SVG_NS, 'svg');
    svg.classList.add('sms-glyph');
    svg.setAttribute('width', '12');
    svg.setAttribute('height', '12');
    svg.setAttribute('viewBox', '0 0 12 12');
    svg.setAttribute('aria-hidden', 'true');
    for (const cx of ['2.5', '6', '9.5']) {
      const c = document.createElementNS(SVG_NS, 'circle');
      c.setAttribute('cx', cx);
      c.setAttribute('cy', '6');
      c.setAttribute('r', '1.2');
      c.setAttribute('fill', 'currentColor');
      svg.append(c);
    }
    return svg;
  }
  if (!Object.hasOwn(GLYPH_PATHS, name)) return null;
  const spec = GLYPH_PATHS[name];
  const svg = document.createElementNS(SVG_NS, 'svg');
  svg.classList.add('sms-glyph');
  if (spec.w > 12) svg.classList.add('sms-glyph-line');
  svg.setAttribute('width', String(spec.w));
  svg.setAttribute('height', String(spec.h));
  svg.setAttribute('viewBox', `0 0 ${spec.w} ${spec.h}`);
  svg.setAttribute('aria-hidden', 'true');
  const path = document.createElementNS(SVG_NS, 'path');
  path.setAttribute('d', spec.d);
  if (spec.stroke) {
    path.setAttribute('stroke', 'currentColor');
    path.setAttribute('stroke-width', '1.8');
    path.setAttribute('fill', 'none');
  } else {
    path.setAttribute('fill', 'currentColor');
  }
  svg.append(path);
  return svg;
}

function actionClass(style) {
  if (style === 'primary') return 'sms-btn sms-pri';
  if (style === 'danger') return 'sms-btn sms-danger';
  return 'sms-btn';
}

function syncAction(existing, action, idPrefix) {
  let wrap = existing;
  let btn;
  if (!wrap) {
    wrap = make('span', 'sms-act-wrap');
    wrap.dataset.smsActionWrap = action.label;
    btn = make('button', actionClass(action.style), action.label);
    btn.type = 'button';
    btn.dataset.smsAction = action.label;
    wrap.append(btn);
  } else {
    btn = wrap.querySelector(':scope > button[data-sms-action]');
    btn.className = actionClass(action.style);
    setText(btn, action.label);
  }
  if (action.aria_label) btn.setAttribute('aria-label', action.aria_label);
  else btn.removeAttribute('aria-label');
  btn.setAttribute('data-sms-event', JSON.stringify(action.event));
  if (action.collect) btn.dataset.smsCollect = 'true';
  else delete btn.dataset.smsCollect;

  const hasReason = typeof action.disabled === 'string' && action.disabled.length > 0;
  setDisabled(btn, hasReason || Boolean(action.disabled));
  let reason = wrap.querySelector(':scope > .sms-act-reason');
  if (hasReason) {
    const rid = `${idPrefix}r-${action.label.toLowerCase().replace(/[^a-z0-9]+/g, '-')}`;
    if (!reason) reason = make('span', 'sms-act-reason');
    reason.id = rid;
    setText(reason, action.disabled);
    btn.setAttribute('aria-describedby', rid);
    syncChildren(wrap, [btn, reason]);
  } else {
    btn.removeAttribute('aria-describedby');
    syncChildren(wrap, [btn]);
  }
  return wrap;
}

function syncActions(container, actions, idPrefix) {
  const existing = new Map(
    [...container.querySelectorAll(':scope > .sms-act-wrap[data-sms-action-wrap]')].map((w) => [
      w.dataset.smsActionWrap,
      w,
    ]),
  );
  const nodes = (actions ?? []).map((act, idx) => syncAction(existing.get(act.label), act, `${idPrefix}a${idx}-`));
  syncChildren(container, nodes);
}

function setControlEvent(control, event) {
  if (event) {
    control.setAttribute('data-sms-event', JSON.stringify(event));
    delete control.dataset.smsDraft;
  } else {
    control.removeAttribute('data-sms-event');
    control.dataset.smsDraft = 'true';
  }
}

function syncSelectOptions(select, choices, wanted, isDraft, ack, created) {
  const list = choices ?? [];
  const sig = JSON.stringify(list.map((c) => [c.value, c.label, Boolean(c.missing)]));
  const changed = select.dataset.smsChoices !== sig;
  if (changed) {
    const byVal = new Map([...select.options].map((opt) => [opt.value, opt]));
    const opts = list.map((choice) => {
      const val = String(choice.value ?? '');
      let opt = byVal.get(val);
      if (!opt) {
        opt = document.createElement('option');
        opt.value = val;
      }
      setText(opt, String(choice.label ?? ''));
      if (choice.missing) opt.dataset.smsMissing = 'true';
      else delete opt.dataset.smsMissing;
      return opt;
    });
    syncChildren(select, opts);
    select.dataset.smsChoices = sig;
  }
  if (isDraft) {
    /* A draft keeps the person's pick, but takes a value the server has newly chosen (the card now selected on the
       map) unless the person is using the control. The value last seen from the server is kept on the control. */
    const valid = list.some((c) => String(c.value ?? '') === select.value);
    const moved = select.dataset.smsServer !== wanted && select !== document.activeElement;
    if (created || !valid || moved) select.value = wanted;
    select.dataset.smsServer = wanted;
  } else if (canPatch(select, ack) && select.value !== wanted) {
    select.value = wanted;
  }
}

function syncRadioGroup(wrap, field, id, ctx, created) {
  let fieldset = wrap.querySelector(':scope > fieldset.sms-fieldset');
  let legend;
  let seg;
  if (!fieldset) {
    fieldset = make('fieldset', 'sms-fieldset');
    legend = make('legend', 'sms-fld-lab', field.label);
    seg = make('div', 'sms-seg');
    fieldset.append(legend, seg);
  } else {
    legend = fieldset.querySelector(':scope > legend');
    seg = fieldset.querySelector(':scope > .sms-seg');
    setText(legend, field.label);
  }

  const choices = field.choices ?? [];
  const wanted = String(field.value ?? '');
  const isDraft = !field.event;
  const inFlight = Number(seg.dataset.smsSeq ?? 0) > ctx.ack;
  const byVal = new Map(
    [...seg.querySelectorAll(':scope > label.sms-seg-opt[data-sms-choice]')].map((lab) => [lab.dataset.smsChoice, lab]),
  );

  let hadChecked = false;
  if (isDraft && !created) {
    const cur = seg.querySelector('input[type="radio"]:checked');
    if (cur && choices.some((c) => String(c.value ?? '') === cur.value)) hadChecked = true;
  }

  const items = choices.map((choice) => {
    const val = String(choice.value ?? '');
    let lab = byVal.get(val);
    let input;
    let face;
    let txt;
    if (!lab) {
      lab = make('label', 'sms-seg-opt');
      lab.dataset.smsChoice = val;
      input = document.createElement('input');
      input.type = 'radio';
      input.name = id;
      input.value = val;
      input.setAttribute('data-shiny-no-bind-input', '');
      face = make('span', 'sms-seg-face');
      txt = make('span', 'sms-seg-text');
      face.append(txt);
      lab.append(input, face);
    } else {
      input = lab.querySelector('input[type="radio"]');
      face = lab.querySelector('.sms-seg-face');
      txt = face.querySelector('.sms-seg-text');
      if (input.name !== id) input.name = id;
    }
    setControlEvent(input, field.event);
    setText(txt, String(choice.label ?? ''));
    if (choice.missing) lab.dataset.smsMissing = 'true';
    else delete lab.dataset.smsMissing;

    const glyphKey = choice.glyph ?? '';
    if (face.dataset.smsGlyph !== glyphKey) {
      face.dataset.smsGlyph = glyphKey;
      const svg = makeGlyph(glyphKey);
      syncChildren(face, svg ? [svg, txt] : [txt]);
    }

    if (isDraft) {
      if ((created || !hadChecked) && input.checked !== (val === wanted)) {
        input.checked = val === wanted;
      }
    } else if (!inFlight) {
      const should = val === wanted;
      if (input.checked !== should) input.checked = should;
    }
    return lab;
  });

  syncChildren(seg, items);
  return { rootNode: fieldset, ariaTarget: fieldset, invalidTargets: [...seg.querySelectorAll('input[type="radio"]')] };
}

function syncToggle(wrap, field, id, ctx, created) {
  let lab = wrap.querySelector(':scope > label.sms-toggle');
  let input;
  let txt;
  if (!lab) {
    lab = make('label', 'sms-toggle');
    lab.htmlFor = id;
    input = document.createElement('input');
    input.className = 'sms-toggle-in';
    input.type = 'checkbox';
    input.id = id;
    input.setAttribute('data-shiny-no-bind-input', '');
    txt = make('span', 'sms-toggle-text', field.label);
    lab.append(input, txt);
  } else {
    input = lab.querySelector('input[type="checkbox"]');
    txt = lab.querySelector('.sms-toggle-text');
    if (lab.htmlFor !== id) lab.htmlFor = id;
    if (input.id !== id) input.id = id;
    setText(txt, field.label);
  }
  setControlEvent(input, field.event);
  const isDraft = !field.event;
  const wanted = Boolean(field.value);
  const inFlight = Number(input.dataset.smsSeq ?? 0) > ctx.ack;
  if (isDraft) {
    if (created && input.checked !== wanted) input.checked = wanted;
  } else if (!inFlight && input.checked !== wanted) {
    input.checked = wanted;
  }
  return { rootNode: lab, ariaTarget: input };
}

function syncInputField(wrap, field, id, ctx, created, idPrefix) {
  let label = wrap.querySelector(':scope > label');
  let row = wrap.querySelector(':scope > .sms-fld-row');
  let control = row?.querySelector(':scope > .sms-in');
  if (!label || !row || !control) {
    label = make('label', '', field.label);
    label.htmlFor = id;
    row = make('div', 'sms-fld-row');
    if (field.type === 'textarea') {
      control = make('textarea', 'sms-in');
      control.rows = 2;
    } else if (field.type === 'select') {
      control = make('select', 'sms-in');
    } else {
      control = make('input', field.type === 'id' ? 'sms-in sms-mono' : 'sms-in');
      control.type = field.type === 'date' ? 'date' : field.type === 'number' ? 'number' : 'text';
      if (control.type === 'text') {
        control.autocomplete = 'off';
        control.spellcheck = false;
      }
    }
    control.id = id;
    control.setAttribute('data-shiny-no-bind-input', '');
    row.append(control);
  } else {
    setText(label, field.label);
    if (label.htmlFor !== id) label.htmlFor = id;
    if (control.id !== id) control.id = id;
  }

  setControlEvent(control, field.event);
  const isDraft = !field.event;
  const wanted = field.value == null ? '' : String(field.value);
  if (field.type === 'select') {
    syncSelectOptions(control, field.choices, wanted, isDraft, ctx.ack, created);
  } else if (isDraft) {
    if (created && control.value !== wanted) control.value = wanted;
  } else if (canPatch(control, ctx.ack) && control.value !== wanted) {
    control.value = wanted;
  }

  if (field.action) {
    const existingAct = row.querySelector(':scope > .sms-act-wrap');
    const actNode = syncAction(
      existingAct?.dataset.smsActionWrap === field.action.label ? existingAct : null,
      field.action,
      `${idPrefix}${field.name}-`,
    );
    syncChildren(row, [control, actNode]);
  } else {
    syncChildren(row, [control]);
  }

  return { nodes: [label, row], ariaTarget: control };
}

function syncField(existing, field, ctx, idPrefix) {
  const created = !existing || existing.dataset.smsType !== field.type;
  const wrap = created ? make('div', 'sms-fld') : existing;
  wrap.dataset.smsField = field.name;
  wrap.dataset.smsType = field.type;

  const id = `${idPrefix}f-${field.name}`;
  let mainNodes;
  let ariaTarget;
  let invalidTargets;
  if (field.type === 'radio') {
    const res = syncRadioGroup(wrap, field, id, ctx, created);
    mainNodes = [res.rootNode];
    ariaTarget = res.ariaTarget;
    invalidTargets = res.invalidTargets;
  } else if (field.type === 'toggle') {
    const res = syncToggle(wrap, field, id, ctx, created);
    mainNodes = [res.rootNode];
    ariaTarget = res.ariaTarget;
    invalidTargets = [ariaTarget];
  } else {
    const res = syncInputField(wrap, field, id, ctx, created, idPrefix);
    mainNodes = res.nodes;
    ariaTarget = res.ariaTarget;
    invalidTargets = [ariaTarget];
  }

  const tail = [];
  const describedBy = [];
  if (field.hint) {
    let hintEl = wrap.querySelector(':scope > .sms-fld-hint');
    if (!hintEl) hintEl = make('p', 'sms-fld-hint');
    hintEl.id = `${id}-hint`;
    setText(hintEl, field.hint);
    tail.push(hintEl);
    describedBy.push(hintEl.id);
  }

  let liveEl = wrap.querySelector(':scope > .sms-fld-live');
  if (!liveEl) {
    liveEl = make('div', 'sms-fld-live');
    liveEl.setAttribute('aria-live', 'polite');
    liveEl.setAttribute('aria-atomic', 'true');
  }
  tail.push(liveEl);

  if (field.problem) {
    let errEl = liveEl.querySelector(':scope > .sms-err');
    let errText;
    if (!errEl) {
      errEl = make('p', 'sms-err');
      errText = make('span', 'sms-err-text');
      errEl.append(makeZigzag(), errText);
    } else {
      errText = errEl.querySelector('.sms-err-text');
    }
    errEl.id = `${id}-prob`;
    setText(errText, field.problem.text ?? '');
    syncChildren(liveEl, [errEl]);
    describedBy.unshift(errEl.id);

    if (field.problem.fixes?.length > 0) {
      let fixesEl = wrap.querySelector(':scope > .sms-prob-fixes');
      if (!fixesEl) fixesEl = make('div', 'sms-prob-fixes');
      syncActions(fixesEl, field.problem.fixes, `${id}-fix-`);
      tail.push(fixesEl);
    }
    for (const el of invalidTargets) el.setAttribute('aria-invalid', 'true');
  } else {
    syncChildren(liveEl, []);
    for (const el of invalidTargets) el.removeAttribute('aria-invalid');
  }

  if (describedBy.length > 0) ariaTarget.setAttribute('aria-describedby', describedBy.join(' '));
  else ariaTarget.removeAttribute('aria-describedby');

  syncChildren(wrap, [...mainNodes, ...tail]);
  return wrap;
}

function syncFields(container, fields, ctx, idPrefix) {
  const existing = new Map(
    [...container.querySelectorAll(':scope > .sms-fld[data-sms-field]')].map((el) => [el.dataset.smsField, el]),
  );
  const nodes = (fields ?? []).map((field) => syncField(existing.get(field.name), field, ctx, idPrefix));
  syncChildren(container, nodes);
}

function syncRow(existing, row, idPrefix) {
  let li = existing;
  let main;
  let txt;
  let acts;
  if (!li) {
    li = make('li', 'sms-row');
    li.dataset.smsUid = row.uid;
    main = make('div', 'sms-row-main');
    txt = make('span', 'sms-row-text');
    main.append(txt);
    acts = make('div', 'sms-row-acts');
    li.append(main, acts);
  } else {
    main = li.querySelector(':scope > .sms-row-main');
    txt = main.querySelector('.sms-row-text');
    acts = li.querySelector(':scope > .sms-row-acts');
  }
  setText(txt, String(row.text ?? ''));
  let sub = main.querySelector('.sms-row-sub');
  if (row.sub) {
    if (!sub) sub = make('span', 'sms-row-sub');
    setText(sub, String(row.sub));
    syncChildren(main, [txt, sub]);
  } else {
    syncChildren(main, [txt]);
  }
  syncActions(acts, row.actions ?? [], `${idPrefix}${row.uid}-`);
  return li;
}

function syncList(existing, list, ctx, idPrefix) {
  let sec = existing;
  let heading;
  if (!sec) {
    sec = make('section', 'sms-sec');
    sec.dataset.smsList = list.name;
    heading = make('h3', 'sms-sec-title', list.label);
    sec.append(heading);
  } else {
    heading = sec.querySelector(':scope > .sms-sec-title');
    setText(heading, list.label);
  }

  const parts = [heading];
  const rows = list.rows ?? [];
  if (rows.length > 0) {
    let ul = sec.querySelector(':scope > ul.sms-rows');
    if (!ul) {
      ul = make('ul', 'sms-rows');
      ul.setAttribute('role', 'list');
    }
    const existingRows = new Map(
      [...ul.querySelectorAll(':scope > li.sms-row[data-sms-uid]')].map((li) => [li.dataset.smsUid, li]),
    );
    const rowNodes = rows.map((row) => syncRow(existingRows.get(row.uid), row, `${idPrefix}${list.name}-`));
    syncChildren(ul, rowNodes);
    parts.push(ul);
  } else {
    let empty = sec.querySelector(':scope > p.sms-empty');
    if (!empty) empty = make('p', 'sms-empty');
    setText(empty, ctx.labels.empty_list ?? '');
    parts.push(empty);
  }

  if (list.add) {
    let addBox = sec.querySelector(':scope > .sms-add');
    let addFields;
    let addAct;
    if (!addBox) {
      addBox = make('div', 'sms-add');
      addBox.dataset.smsGroup = list.name;
      addFields = make('div', 'sms-add-fields');
      addAct = make('div', 'sms-add-act');
      addBox.append(addFields, addAct);
    } else {
      addFields = addBox.querySelector(':scope > .sms-add-fields');
      addAct = addBox.querySelector(':scope > .sms-add-act');
    }
    syncFields(addFields, list.add.fields ?? [], ctx, `${idPrefix}${list.name}-`);
    syncActions(addAct, list.add.action ? [list.add.action] : [], `${idPrefix}${list.name}-add-`);
    parts.push(addBox);
  }

  syncChildren(sec, parts);
  return sec;
}

/* Reads the current value of one rendered `.sms-fld` wrapper (used by `collect: true` actions). */
export function readFieldValue(fld) {
  const type = fld.dataset.smsType;
  if (type === 'radio') {
    const checked = fld.querySelector('input[type="radio"]:checked');
    return checked ? checked.value : null;
  }
  if (type === 'toggle') {
    const box = fld.querySelector('input[type="checkbox"]');
    return box ? Boolean(box.checked) : false;
  }
  const control = fld.querySelector('.sms-in');
  if (!control) return undefined;
  if (type === 'number') {
    return control.value === '' ? null : Number(control.value);
  }
  return control.value;
}

export function render(el, form, ctx, idPrefix = '') {
  if (!form) {
    ctx.flush?.();
    delete el.dataset.smsFormKey;
    el.replaceChildren();
    return;
  }

  const formKey = form.uid ?? '';
  const switching = Boolean(formKey) && Boolean(el.dataset.smsFormKey) && el.dataset.smsFormKey !== formKey;
  if (switching) {
    ctx.flush?.();
    el.replaceChildren();
  }
  if (formKey) el.dataset.smsFormKey = formKey;
  else delete el.dataset.smsFormKey;

  let body = el.querySelector(':scope > .sms-form-body');
  let fieldsEl;
  let listsEl;
  let foot = el.querySelector(':scope > .sms-form-foot');
  if (!body || !foot) {
    body = make('div', 'sms-form-body');
    fieldsEl = make('div', 'sms-form-fields');
    listsEl = make('div', 'sms-form-lists');
    body.append(fieldsEl, listsEl);
    foot = make('div', 'sms-form-foot');
    el.replaceChildren(body, foot);
  } else {
    fieldsEl = body.querySelector(':scope > .sms-form-fields');
    listsEl = body.querySelector(':scope > .sms-form-lists');
  }

  const prefix = idPrefix || `${el.closest('.sms')?.dataset.smsNs ?? ''}form-`;
  syncFields(fieldsEl, form.fields ?? [], ctx, prefix);

  const lists = form.lists ?? [];
  if (lists.length > 0) {
    listsEl.hidden = false;
    const existingLists = new Map(
      [...listsEl.querySelectorAll(':scope > section.sms-sec[data-sms-list]')].map((s) => [s.dataset.smsList, s]),
    );
    const listNodes = lists.map((list) => syncList(existingLists.get(list.name), list, ctx, prefix));
    syncChildren(listsEl, listNodes);
  } else {
    listsEl.hidden = true;
    listsEl.replaceChildren();
  }

  const actions = form.actions ?? [];
  if (actions.length > 0) {
    foot.hidden = false;
    syncActions(foot, actions, `${prefix}foot-`);
  } else {
    foot.hidden = true;
    foot.replaceChildren();
  }
}
