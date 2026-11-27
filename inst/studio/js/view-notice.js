/*
 * The `notice` section: shows each notice once as a toast, resetting when the server clears `notice` so repeated
 * refusals always announce again.
 */
const seenNotice = new WeakMap();

export function render(el, notice, ctx) {
  if (!notice) {
    seenNotice.set(el, 0);
    return;
  }
  const prev = seenNotice.get(el) ?? 0;
  if (notice.n === prev) return;
  seenNotice.set(el, notice.n);
  ctx.toast(notice.text, notice.tone, notice.undo ? 7000 : 4000);
}
