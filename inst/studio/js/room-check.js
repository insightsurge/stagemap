/*
 * The Check room stub: renders the empty or summary state.
 */
import { make } from './dom.js';

export function render(el, check) {
  const text = check?.ok ? 'Nothing to report.' : check?.head || 'Problems found.';
  el.replaceChildren(make('p', 'sms-empty', text));
}
