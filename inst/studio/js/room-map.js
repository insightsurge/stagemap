/*
 * The Map room: renders the server-described stage_map() options form via `form.js`, updates the layout label in the
 * title block's Map cell, and ensures the phone header carries a Map opener when the bottom cell is hidden.
 * Never adds event listeners.
 */
import { make, setText } from './dom.js';
import { render as renderForm } from './form.js';

function selectedLayoutLabel(fields) {
  for (const field of fields ?? []) {
    if (field.choices?.length) {
      const match = field.choices.find((c) => String(c.value ?? '') === String(field.value ?? ''));
      if (match) return String(match.label ?? '');
    }
  }
  return '';
}

function updateMapButton(root, ns, fields) {
  const valEl = root?.querySelector('[data-sms-room="map"] .sms-val');
  if (valEl) {
    let layoutEl = valEl.querySelector('.sms-map-layout');
    if (!layoutEl) {
      layoutEl = make('span', 'sms-map-layout');
      valEl.append(layoutEl);
    }
    setText(layoutEl, selectedLayoutLabel(fields));
  }

  const acts = root?.querySelector('.sms-acts');
  if (acts && !acts.querySelector('.sms-phone-map')) {
    const btn = make('button', 'sms-btn sms-phone-map', 'Map');
    btn.type = 'button';
    btn.dataset.smsRoom = 'map';
    const roomEl = root?.querySelector('[data-sms-room-of="map"]');
    btn.setAttribute('aria-expanded', roomEl && !roomEl.hidden ? 'true' : 'false');
    btn.setAttribute('aria-controls', `${ns}room-map`);
    const themeBtn = acts.querySelector('.sms-phone-theme');
    if (themeBtn) acts.insertBefore(btn, themeBtn);
    else acts.append(btn);
  }
}

export function render(el, mapView, ctx) {
  const root = el.closest('.sms');
  const ns = root?.dataset.smsNs ?? '';
  const fields = mapView?.fields ?? [];
  updateMapButton(root, ns, fields);

  let formBox = el.querySelector(':scope > .sms-map-form');
  if (!formBox) {
    formBox = make('div', 'sms-map-form');
    el.replaceChildren(formBox);
  }
  renderForm(formBox, { fields }, ctx, `${ns}map-`);
}
