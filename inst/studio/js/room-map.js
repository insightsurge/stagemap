/*
 * The Map room: renders the server-described stage_map() options form via `form.js` and updates the layout label in
 * the title block's Map cell. Never adds event listeners.
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

function updateMapButton(root, fields) {
  const valEl = root?.querySelector('[data-sms-room="map"] .sms-val');
  if (valEl) {
    let layoutEl = valEl.querySelector('.sms-map-layout');
    if (!layoutEl) {
      layoutEl = make('span', 'sms-map-layout');
      valEl.append(layoutEl);
    }
    setText(layoutEl, selectedLayoutLabel(fields));
  }
}

export function render(el, mapView, ctx) {
  const root = el.closest('.sms');
  const ns = root?.dataset.smsNs ?? '';
  const fields = mapView?.fields ?? [];
  updateMapButton(root, fields);

  let formBox = el.querySelector(':scope > .sms-map-form');
  if (!formBox) {
    formBox = make('div', 'sms-map-form');
    el.replaceChildren(formBox);
  }
  renderForm(formBox, { fields }, ctx, `${ns}map-`);
}
