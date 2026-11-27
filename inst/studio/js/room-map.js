/*
 * The Map room stub: renders the empty state until display options are populated.
 */
import { make } from './dom.js';

export function render(el) {
  el.replaceChildren(make('p', 'sms-empty', 'Map display options.'));
}
