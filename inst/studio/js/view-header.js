/*
 * The `header` section: the title field, the facts under it, the revision, and the map's name in the title block. The
 * title field is left alone while it has focus or holds text the server has not acknowledged.
 */
import { canPatch, setText } from './dom.js';

export function render(root, header, ctx) {
  const title = root.querySelector('.sms-title');
  if (title && canPatch(title, ctx.ack) && title.value !== header.title) title.value = header.title;
  setText(root.querySelector('.sms-facts'), header.facts);
  setText(root.querySelector('.sms-map-name'), header.title);
  setText(root.querySelector('.sms-rev'), String(ctx.rev));
}
