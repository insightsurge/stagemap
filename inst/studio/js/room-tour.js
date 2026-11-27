/*
 * The Guide tour stub: keeps the hint bar clean until the guide view is populated.
 */
export function render(el, tour) {
  if (!tour) {
    el.hidden = true;
    el.replaceChildren();
  }
}
