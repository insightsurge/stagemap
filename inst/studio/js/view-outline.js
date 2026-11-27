/*
 * The `outline` section: the add buttons and the dropdown menus supplied by R.
 * All labels, counts and event payloads come from R; listeners live on the studio root in studio.js.
 */
import { make, setDisabled, setText, syncChildren } from './dom.js';

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
    } else {
      setText(btn, action.label);
    }
    btn.setAttribute('data-sms-event', JSON.stringify(action.event));
    setDisabled(btn, Boolean(action.disabled));
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
      countSpan = make('span', 'sms-menu-count', String(item.count ?? 0));
      btn.append(nameSpan, countSpan);
    } else {
      nameSpan = btn.querySelector('.sms-menu-label');
      countSpan = btn.querySelector('.sms-menu-count');
      setText(nameSpan, item.label);
      setText(countSpan, String(item.count ?? 0));
    }
    btn.setAttribute('data-sms-event', JSON.stringify(item.event));
    children.push(btn);
  }
  syncChildren(pop, children);
  return wrap;
}

export function render(el, outline) {
  const root = el.closest('.sms');
  if (!outline) {
    if (el.contains(document.activeElement)) root?.querySelector('.sms-title')?.focus();
    el.hidden = true;
    el.replaceChildren();
    return;
  }
  const ns = root?.dataset.smsNs ?? '';
  el.hidden = false;
  const actionButtons = syncActionButtons(el, outline.actions);
  const menus = (outline.menus ?? []).map((menu) => syncMenu(el, ns, menu.id, menu.label, menu.items));
  syncChildren(el, [...actionButtons, ...menus]);
}
