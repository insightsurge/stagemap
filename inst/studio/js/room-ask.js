/*
 * The Ask room stub: renders the empty state until questions are populated.
 */
import { make } from './dom.js';

export function render(el) {
  el.replaceChildren(make('p', 'sms-empty', 'No questions run yet.'));
}
