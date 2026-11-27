/*
 * The `outline` section: the add buttons (+ Card, + Stage, + Lane) and the Stages and Lanes dropdown menus.
 * All event payloads come from R; listeners live on the studio root in studio.js.
 */
import { make, setBusy, setText } from './dom.js';

function syncActionButtons(el, actions) {
  const existing = new Map(
    [...el.querySelectorAll(':scope > button[data-sms-action]')].map((btn) => [btn.dataset.smsAction, btn]),
  );
  const nodes = [];
  for (const action of actions ?? []) {
    let btn = existing.get(action.label);
    if (!btn) {
      btn = make('button', 'sms-btn', action.label);
      btn.type = 'button';
      btn.dataset.smsAction = action.label;
    }
    btn.setAttribute('data-sms-event', JSON.stringify(action.event));
    if (!btn.hasAttribute('data-sms-wait-seq')) {
      setBusy(btn, Boolean(action.disabled));
    }
    nodes.push(btn);
  }
  return nodes;
}

function syncMenu(el, ns, name, label, items) {
  let wrap = el.querySelector(`.sms-menu[data-sms-menu-box="${name}"]`);
  let trigger;
  let pop;
  if (!wrap) {
    wrap = make('div', 'sms-menu');
    wrap.dataset.smsMenuBox = name;
    trigger = make('button', 'sms-btn', label);
    trigger.type = 'button';
    trigger.dataset.smsMenu = name;
    trigger.setAttribute('aria-expanded', 'false');
    trigger.setAttribute('aria-controls', `${ns}menu-${name}`);
    pop = make('div', 'sms-menu-pop');
    pop.id = `${ns}menu-${name}`;
    pop.setAttribute('role', 'menu');
    pop.hidden = true;
    wrap.append(trigger, pop);
  } else {
    trigger = wrap.querySelector('[data-sms-menu]');
    pop = wrap.querySelector('.sms-menu-pop');
    setText(trigger, label);
  }
  const byUid = new Map(
    [...pop.querySelectorAll('[role="menuitem"][data-sms-uid]')].map((btn) => [btn.dataset.smsUid, btn]),
  );
  const children = [];
  for (const item of items ?? []) {
    let btn = byUid.get(item.uid);
    let nameSpan;
    let countSpan;
    if (!btn) {
      btn = make('button', 'sms-menu-item');
      btn.type = 'button';
      btn.setAttribute('role', 'menuitem');
      btn.dataset.smsUid = item.uid;
      nameSpan = make('span', 'sms-menu-label', item.label);
      countSpan = make('span', 'sms-menu-count', String(item.cards ?? 0));
      btn.append(nameSpan, countSpan);
    } else {
      nameSpan = btn.querySelector('.sms-menu-label');
      countSpan = btn.querySelector('.sms-menu-count');
      setText(nameSpan, item.label);
      setText(countSpan, String(item.cards ?? 0));
    }
    btn.setAttribute('data-sms-event', JSON.stringify(item.event));
    children.push(btn);
  }
  pop.replaceChildren(...children);
  return wrap;
}

export function render(el, outline, ctx) {
  if (!outline) {
    el.hidden = true;
    el.replaceChildren();
    return;
  }
  const root = el.closest('.sms');
  const ns = root?.dataset.smsNs ?? '';
  el.hidden = false;
  const actionButtons = syncActionButtons(el, outline.actions);
  const stagesMenu = syncMenu(el, ns, 'stages', ctx.labels.stages, outline.stages);
  const lanesMenu = syncMenu(el, ns, 'lanes', ctx.labels.lanes, outline.lanes);
  el.replaceChildren(...actionButtons, stagesMenu, lanesMenu);
}
