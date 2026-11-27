/*
 * The `inspector` section: head-only slip showing target kind, title, sub and its Close action.
 */
import { make, setBusy } from './dom.js';

export function render(el, inspector, ctx) {
  const root = el.closest('.sms');
  const ns = root?.dataset.smsNs ?? '';
  if (!inspector) {
    el.hidden = true;
    if (root) delete root.dataset.smsInspector;
    delete el.dataset.smsUid;
    el.replaceChildren();
    return;
  }

  const prevUid = el.dataset.smsUid ?? '';
  el.hidden = false;
  if (root) root.dataset.smsInspector = inspector.kind;
  el.dataset.smsUid = inspector.uid;

  const head = make('div', 'sms-insp-head');
  const meta = make('div', 'sms-insp-meta');
  const kick = make('p', 'sms-kick', inspector.kind);
  const heading = make('h2', '', inspector.title);
  heading.id = `${ns}inspector-title`;
  heading.tabIndex = -1;
  const sub = make('p', 'sms-insp-sub', inspector.sub);
  meta.append(kick, heading, sub);

  const acts = make('div', 'sms-insp-acts');
  for (const action of inspector.actions ?? []) {
    const btn = make('button', 'sms-btn', action.label);
    btn.type = 'button';
    if (action.label === 'Close') {
      btn.setAttribute('aria-label', 'Close inspector');
    }
    btn.setAttribute('data-sms-event', JSON.stringify(action.event));
    if (action.disabled) setBusy(btn, true);
    acts.append(btn);
  }

  head.append(meta, acts);
  el.replaceChildren(head);

  if (prevUid !== inspector.uid && ctx.shouldFocusInspector?.()) {
    heading.focus({ preventScroll: true });
  }
}
