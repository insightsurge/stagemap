/*
 * The `notice` section: shows each notice once as a toast, resetting when the server clears `notice` so repeated
 * refusals always announce again, and opening `notice.room` when named.
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
  ctx.toast(notice.text, notice.tone);
  if (notice.room) {
    const roomEl = el.querySelector(`[data-sms-room-of="${CSS.escape(notice.room)}"]`);
    const roomBtn = el.querySelector(`[data-sms-room="${CSS.escape(notice.room)}"]`);
    if (roomEl?.hidden && roomBtn && !roomBtn.closest('[inert]')) {
      roomBtn.click();
    }
  }
}
