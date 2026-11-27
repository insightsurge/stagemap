/*
 * The `inspector` section: head-only slip showing target kind, title, sub and its Close action.
 */
import { make, setDisabled, setText, syncChildren } from './dom.js';

function ensureSkeleton(el, ns) {
  let head = el.querySelector('.sms-insp-head');
  if (head) return head;
  head = make('div', 'sms-insp-head');
  const meta = make('div', 'sms-insp-meta');
  const kick = make('p', 'sms-kick');
  const heading = make('h2');
  heading.id = `${ns}inspector-title`;
  heading.tabIndex = -1;
  const sub = make('p', 'sms-insp-sub');
  meta.append(kick, heading, sub);
  const acts = make('div', 'sms-insp-acts');
  head.append(meta, acts);
  el.replaceChildren(head);
  return head;
}

export function render(el, inspector, ctx) {
  const root = el.closest('.sms');
  const ns = root?.dataset.smsNs ?? '';
  if (!inspector) {
    if (el.contains(document.activeElement)) {
      ctx.restoreInspectorFocus?.();
    }
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

  const head = ensureSkeleton(el, ns);
  const kick = head.querySelector('.sms-kick');
  const heading = head.querySelector('h2');
  const sub = head.querySelector('.sms-insp-sub');
  setText(kick, inspector.kind);
  setText(heading, inspector.title);
  setText(sub, inspector.sub);

  const acts = head.querySelector('.sms-insp-acts');
  const existing = new Map(
    [...acts.querySelectorAll('button[data-sms-action]')].map((btn) => [btn.dataset.smsAction, btn]),
  );
  const buttons = (inspector.actions ?? []).map((action) => {
    let btn = existing.get(action.label);
    if (!btn) {
      btn = make('button', 'sms-btn', action.label);
      btn.type = 'button';
      btn.dataset.smsAction = action.label;
    } else {
      setText(btn, action.label);
    }
    if (action.label === 'Close') {
      btn.setAttribute('aria-label', 'Close inspector');
    }
    btn.setAttribute('data-sms-event', JSON.stringify(action.event));
    setDisabled(btn, Boolean(action.disabled));
    return btn;
  });
  syncChildren(acts, buttons);

  if (prevUid !== inspector.uid && ctx.shouldFocusInspector?.()) {
    heading.focus({ preventScroll: true });
  }
}
