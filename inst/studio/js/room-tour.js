/*
 * The guide (the `tour` section): the hint bar shows the next step, and the "Try it n/m" button opens the list of
 * steps, each with a tick and the word "done" once the server has proved it. The server decides what is done; the page
 * counts and draws. `closeGuide` and `toggleGuide` are called by the page's one click and Escape handlers, and
 * `closeGuide` also when a room or a new pick opens over the list (a renderer adds no listener).
 */
import { make, setText, syncChildren } from './dom.js';

const hintOf = (root) => root.querySelector('.sms-hint');

/* Closes the list of steps; with `refocus`, focus that was inside the bar goes back to the button. True when it was
   open. */
export function closeGuide(root, refocus = true) {
  const hint = hintOf(root);
  const panel = hint?.querySelector('.sms-try');
  const button = hint?.querySelector('.sms-try-btn');
  if (!panel || panel.hidden) return false;
  const inside = hint.contains(document.activeElement);
  panel.hidden = true;
  button.setAttribute('aria-expanded', 'false');
  if (refocus && inside) button.focus();
  return true;
}

export function toggleGuide(root) {
  const hint = hintOf(root);
  const panel = hint?.querySelector('.sms-try');
  const button = hint?.querySelector('.sms-try-btn');
  if (!panel || button.hidden) return;
  if (panel.hidden) {
    panel.hidden = false;
    button.setAttribute('aria-expanded', 'true');
  } else {
    closeGuide(root);
  }
}

function syncSteps(list, steps, nextIndex, labels) {
  const nodes = steps.map((step, i) => {
    const item = list.children[i] ?? make('li', 'sms-try-step');
    const word = item.querySelector('.sms-try-done');
    const label = item.querySelector('.sms-try-text') ?? make('span', 'sms-try-text');
    setText(label, step.text);
    const parts = [label];
    if (step.done) parts.push(word ?? make('span', 'sms-try-done', labels.guide_done));
    syncChildren(item, parts);
    if (step.done) item.dataset.smsDone = '';
    else delete item.dataset.smsDone;
    if (i + 1 === nextIndex) {
      item.dataset.smsNext = '';
      item.setAttribute('aria-current', 'step');
    } else {
      delete item.dataset.smsNext;
      item.removeAttribute('aria-current');
    }
    return item;
  });
  syncChildren(list, nodes);
}

export function render(el, tour, ctx) {
  const root = el.closest('.sms');
  const next = el.querySelector('.sms-hint-next');
  const button = el.querySelector('.sms-try-btn');
  const panel = el.querySelector('.sms-try');
  if (!tour) {
    const had = el.contains(document.activeElement) && (button.hidden === false || !panel.hidden);
    closeGuide(root, false);
    delete el.dataset.smsTour;
    setText(next, '');
    setText(button, '');
    button.hidden = true;
    setText(panel.querySelector('h2'), '');
    panel.querySelector('ol').replaceChildren();
    el.hidden = el.dataset.smsHover === undefined;
    if (had) root.querySelector('.sms-title')?.focus();
    return;
  }
  const steps = tour.steps ?? [];
  const done = steps.filter((step) => step.done).length;
  el.dataset.smsTour = '';
  el.hidden = false;
  setText(next, tour.next ? `${ctx.labels.guide_next} ${steps[tour.next - 1]?.text ?? ''}` : ctx.labels.guide_all_done);
  setText(button, `${ctx.labels.guide_try} ${done}/${steps.length}`);
  button.hidden = false;
  setText(panel.querySelector('h2'), tour.title);
  syncSteps(panel.querySelector('ol'), steps, tour.next, ctx.labels);
}
