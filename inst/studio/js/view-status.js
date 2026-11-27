/*
 * The `status` section: the paper stamp when the current document has problems, and the closed state after Done.
 */
import { setText } from './dom.js';

const SVG_NS = 'http://www.w3.org/2000/svg';

function zigzagIcon() {
  const svg = document.createElementNS(SVG_NS, 'svg');
  svg.setAttribute('width', '16');
  svg.setAttribute('height', '12');
  svg.setAttribute('viewBox', '0 0 16 12');
  svg.setAttribute('aria-hidden', 'true');
  const path = document.createElementNS(SVG_NS, 'path');
  path.setAttribute('d', 'M1 9l3-6 3 6 3-6 3 6');
  path.setAttribute('stroke', 'currentColor');
  path.setAttribute('stroke-width', '1.8');
  path.setAttribute('fill', 'none');
  svg.append(path);
  return svg;
}

export function render(el, status, ctx) {
  const stamp = el.querySelector('.sms-stamp');
  if (stamp) {
    const problems = Number(status?.problems ?? 0);
    if (problems > 0) {
      const word = problems === 1 ? ctx.labels.problem_one : ctx.labels.problem_many;
      const text = `${ctx.labels.stamp_prefix} ${problems} ${word}`;
      stamp.replaceChildren(zigzagIcon(), document.createTextNode(text));
    } else {
      stamp.replaceChildren();
    }
  }

  if (status?.closed && el.dataset.smsClosed === undefined) {
    ctx.closeAllRooms?.();
    el.dataset.smsClosed = '';
    for (const part of el.querySelectorAll('.sms-sheet, .sms-tray, .sms-block')) {
      part.inert = true;
    }
    setText(el.querySelector('.sms-closed'), ctx.labels.closed);
  }
}
