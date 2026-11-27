/*
 * The `start` section: the start card overlay with template options. Shows when `start.open` is true or when opened
 * from the header button (`data-sms-open="true"`), closing automatically once an `open` bumps the revision.
 */
import { make, setText } from './dom.js';

const SVG_NS = 'http://www.w3.org/2000/svg';

function legendItem(stroke, d, label, isRect = false) {
  const row = document.createElement('div');
  const svg = document.createElementNS(SVG_NS, 'svg');
  svg.setAttribute('width', '34');
  svg.setAttribute('height', '10');
  if (isRect) {
    const rect = document.createElementNS(SVG_NS, 'rect');
    rect.setAttribute('x', '1');
    rect.setAttribute('y', '2');
    rect.setAttribute('width', '32');
    rect.setAttribute('height', '6');
    rect.setAttribute('fill', stroke);
    svg.append(rect);
  } else {
    const path = document.createElementNS(SVG_NS, 'path');
    path.setAttribute('d', d);
    path.setAttribute('stroke', stroke);
    path.setAttribute('stroke-width', '2');
    path.setAttribute('fill', 'none');
    svg.append(path);
  }
  row.append(svg, document.createTextNode(label));
  return row;
}

function buildSkeleton(el, labels) {
  const card = make('div', 'sms-start-in');
  const lede = make('div', 'sms-start-lede');
  const kicker = make('p', 'sms-kick', labels.start_kicker);
  const heading = make('h1', '', labels.start_heading);
  const p1 = make('p', '', labels.start_body_1);
  const p2 = make('p', '', labels.start_body_2);
  const legend = make('div', 'sms-start-legend');
  legend.setAttribute('aria-hidden', 'true');
  legend.append(
    legendItem('var(--_stagemap-studio-blue)', 'M1 5h32', 'blue pencil edits'),
    legendItem('var(--_stagemap-studio-red)', 'M1 8l4-6 4 6 4-6 4 6 4-6 4 6 4-6', 'red pencil flags a problem'),
    legendItem('var(--_stagemap-studio-mark)', '', 'yellow marks an answer', true),
  );
  lede.append(kicker, heading, p1, p2, legend);

  const right = make('div', 'sms-start-right');
  const head = make('div', 'sms-start-head');
  const closeBtn = make('button', 'sms-btn', labels.close);
  closeBtn.type = 'button';
  closeBtn.dataset.smsStart = 'close';
  closeBtn.setAttribute('aria-label', `${labels.close} start card`);
  head.append(closeBtn);

  const opts = make('ul', 'sms-start-opts');
  opts.setAttribute('role', 'list');
  right.append(head, opts);
  card.append(lede, right);
  el.replaceChildren(card);
}

export function render(el, start, ctx) {
  if (!start) {
    el.hidden = true;
    return;
  }
  if (el.dataset.smsOpen === 'true' && Number(el.dataset.smsOpenedRev ?? -1) !== ctx.rev) {
    delete el.dataset.smsOpen;
    delete el.dataset.smsOpenedRev;
  }
  const show = Boolean(start.open) || el.dataset.smsOpen === 'true';
  el.hidden = !show;

  if (!el.querySelector('.sms-start-in')) {
    buildSkeleton(el, ctx.labels);
  }
  const head = el.querySelector('.sms-start-head');
  if (head) head.hidden = Boolean(start.open);

  const list = el.querySelector('.sms-start-opts');
  const existing = new Map(
    [...list.querySelectorAll('button[data-sms-open]')].map((btn) => [btn.dataset.smsOpen, btn]),
  );
  const items = (start.options ?? []).map((opt, idx) => {
    const li = document.createElement('li');
    let btn = existing.get(opt.id);
    if (!btn) {
      btn = make('button', 'sms-opt');
      btn.type = 'button';
      btn.dataset.smsOpen = opt.id;
      btn.append(make('span', 'sms-opt-n'), make('b'), make('span', 'sms-opt-go'), make('small'));
    }
    setText(btn.querySelector('.sms-opt-n'), String(idx + 1));
    setText(btn.querySelector('b'), opt.title);
    setText(
      btn.querySelector('.sms-opt-go'),
      opt.event?.data?.confirm ? ctx.labels.start_confirm : ctx.labels.start_open,
    );
    setText(btn.querySelector('small'), opt.text);
    btn.setAttribute('data-sms-event', JSON.stringify(opt.event));
    li.append(btn);
    return li;
  });
  list.replaceChildren(...items);
}
