/*
 * The `code` section: the R code room's lines, numbered by CSS, each made of spans whose class comes from the server,
 * and the count of lines in the room's head and in the title block.
 */
import { make, setText } from './dom.js';

export function render(root, code, ctx) {
  const box = root.querySelector('.sms-code');
  const lines = code.lines ?? [];
  box.replaceChildren(
    ...lines.map((line) => {
      const node = make('span', 'sms-l');
      if (line.changed) node.dataset.smsChanged = '';
      for (const [text, kind] of line.spans ?? []) {
        node.append(kind ? make('span', `sms-tok-${kind}`, text) : document.createTextNode(text));
      }
      return node;
    }),
  );
  const count = `${lines.length} ${lines.length === 1 ? ctx.labels.line : ctx.labels.lines}`;
  setText(root.querySelector('.sms-code-sum'), count);
  setText(root.querySelector('.sms-code-count'), count);
  setText(root.querySelector('.sms-code-note'), code.problem ?? '');
}
