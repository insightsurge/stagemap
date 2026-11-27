/*
 * The `inspector` section: head (kind, title, sub, Close from boot labels) plus the generic form renderer (`form.js`).
 * Inert when closed; flushes held text before closing or switching rows; restores focus cleanly on close or row swap.
 */
import { make, setText } from './dom.js';
import { render as renderForm } from './form.js';

/* Whether the inspector can be reached: not while the page is closed, the start card is the modal, or (on a phone, one
   sheet at a time) a room covers it. `modal` is the start card's state when the caller knows it before the DOM does. */
export function syncInspectorInert(root, modal = null) {
  const el = root.querySelector('.sms-inspector');
  if (!el) return;
  const startOpen = modal ?? !root.querySelector('.sms-start')?.hidden;
  el.inert = Boolean(
    el.hidden || startOpen || root.dataset.smsClosed !== undefined || root.dataset.smsCovered !== undefined,
  );
}

const CLOSE_EVENT = JSON.stringify({ type: 'target', data: { kind: 'none', uid: null } });

function ensureSkeleton(el, ns, labels) {
  let head = el.querySelector(':scope > .sms-insp-head');
  let formBox = el.querySelector(':scope > .sms-insp-form');
  if (head && formBox) return { head, formBox };
  head = make('div', 'sms-insp-head');
  const meta = make('div', 'sms-insp-meta');
  const kick = make('p', 'sms-kick');
  const heading = make('h2');
  heading.id = `${ns}inspector-title`;
  heading.tabIndex = -1;
  const sub = make('p', 'sms-insp-sub');
  meta.append(kick, heading, sub);
  const acts = make('div', 'sms-insp-acts');
  const closeBtn = make('button', 'sms-btn', labels.close);
  closeBtn.type = 'button';
  closeBtn.dataset.smsAction = labels.close;
  closeBtn.setAttribute('aria-label', labels.close_inspector);
  closeBtn.setAttribute('data-sms-event', CLOSE_EVENT);
  acts.append(closeBtn);
  head.append(meta, acts);
  formBox = make('div', 'sms-insp-form');
  el.replaceChildren(head, formBox);
  return { head, formBox };
}

export function render(el, inspector, ctx) {
  const root = el.closest('.sms');
  const ns = root?.dataset.smsNs ?? '';
  if (!inspector) {
    if (el.hidden && !el.dataset.smsUid) {
      el.inert = true;
      return;
    }
    ctx.flush?.();
    if (el.contains(document.activeElement)) {
      ctx.restoreInspectorFocus?.();
    }
    el.hidden = true;
    el.inert = true;
    if (root) delete root.dataset.smsInspector;
    delete el.dataset.smsUid;
    el.replaceChildren();
    return;
  }

  const prevUid = el.dataset.smsUid ?? '';
  const hadFocus = el.contains(document.activeElement);
  el.hidden = false;
  /* On a phone one sheet is open at a time: a new pick closes the rooms. */
  if (prevUid !== inspector.uid && ctx.isPhone?.()) ctx.closeAllRooms?.();
  syncInspectorInert(root);
  if (root) root.dataset.smsInspector = inspector.kind;
  el.dataset.smsUid = inspector.uid;

  const { head, formBox } = ensureSkeleton(el, ns, ctx.labels);
  const kick = head.querySelector('.sms-kick');
  const heading = head.querySelector('h2');
  const sub = head.querySelector('.sms-insp-sub');
  const closeBtn = head.querySelector('.sms-insp-acts button');
  if (closeBtn) {
    setText(closeBtn, ctx.labels.close);
    closeBtn.dataset.smsAction = ctx.labels.close;
    closeBtn.setAttribute('aria-label', ctx.labels.close_inspector);
  }
  setText(kick, inspector.kind);
  setText(heading, inspector.title);
  setText(sub, inspector.sub);

  renderForm(formBox, inspector, ctx, `${ns}insp-`);

  if (prevUid !== inspector.uid && ctx.shouldFocusInspector?.()) {
    heading.focus({ preventScroll: true });
  } else if (hadFocus && !el.contains(document.activeElement)) {
    heading.focus({ preventScroll: true });
  }
}
