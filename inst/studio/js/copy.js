/*
 * Copy: the code it copies is the server's (`code.text` of the view), once the server has answered everything sent
 * before the click. The clipboard write starts inside the click, with the text as a promise (a ClipboardItem), so the
 * browser keeps the click's permission while the server answers. Without ClipboardItem it waits, then uses writeText();
 * if that is refused, a hidden text area and the copy command; if that fails too, it selects the code and says how to
 * copy it by hand. Waiting longer than `copy_wait_ms` gives up with a message. The button stays busy until then, and
 * `data-sms-copied` on it names the way the last copy went: item, text, exec, manual or late.
 */
import { setBusy } from './dom.js';
import { LateError } from './store.js';

/* Starts the ClipboardItem write, or returns null when the browser has no ClipboardItem. Read at click time, so a page
   that loses the API later is seen. */
function startWrite(text) {
  const Item = window.ClipboardItem;
  const clipboard = navigator.clipboard;
  if (typeof Item !== 'function' || typeof clipboard?.write !== 'function') return null;
  const blob = text.then((value) => new Blob([value], { type: 'text/plain' }));
  blob.catch(() => {}); /* its failure is read from `text` below */
  try {
    return clipboard.write([new Item({ 'text/plain': blob })]);
  } catch (error) {
    return Promise.reject(error);
  }
}

/* The copy command on a hidden text area inside the studio; focus goes back where it was. */
function execCopy(root, value) {
  const before = document.activeElement;
  const area = document.createElement('textarea');
  area.className = 'sms-copy-area';
  area.value = value;
  area.setAttribute('readonly', '');
  area.setAttribute('aria-hidden', 'true');
  root.append(area);
  area.select();
  let done = false;
  try {
    done = document.execCommand('copy') === true;
  } catch {
    done = false;
  }
  area.remove();
  before?.focus?.();
  return done;
}

function selectCode(node) {
  if (!node) return;
  const range = document.createRange();
  range.selectNodeContents(node);
  const selection = window.getSelection();
  selection.removeAllRanges();
  selection.addRange(range);
  node.focus();
}

async function finish(root, write, text, codeNode) {
  if (write) {
    try {
      await write;
      return 'item';
    } catch {
      /* refused, or the text never came: the next ways say which */
    }
  }
  let value;
  try {
    value = await text;
  } catch (error) {
    if (error instanceof LateError) return 'late';
    throw error;
  }
  try {
    if (typeof navigator.clipboard?.writeText === 'function') {
      await navigator.clipboard.writeText(value);
      return 'text';
    }
  } catch {
    /* refused: try the copy command */
  }
  if (execCopy(root, value)) return 'exec';
  selectCode(codeNode);
  return 'manual';
}

/* Copies the server's code for the click on `button`. `ctx` holds the root, the store, the words and the toast. */
export function copyCode(button, ctx) {
  const { root, store, labels, toast } = ctx;
  if (button.getAttribute('aria-busy') === 'true') return;
  setBusy(button, true);
  const text = store.whenInStep().then((view) => view.code?.text ?? '');
  text.catch(() => {}); /* read by finish() */
  const write = startWrite(text);
  finish(root, write, text, root.querySelector('.sms-code'))
    .then((path) => {
      button.dataset.smsCopied = path;
      if (path === 'late') toast(labels.copy_late, 'problem');
      else if (path === 'manual') toast(labels.copy_manual, 'problem');
      else toast(labels.copied, 'info');
    })
    .catch((error) => {
      button.dataset.smsCopied = 'error';
      toast(labels.copy_manual, 'problem');
      console.error(error);
    })
    .finally(() => setBusy(button, false));
}
