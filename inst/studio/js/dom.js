/*
 * Small DOM helpers shared by the studio's modules. Text always goes in as text, never as HTML.
 */

/* The boot JSON of a studio root: its words and settings, written by R. */
export function readBoot(root) {
  const node = root.querySelector('script.sms-boot');
  return JSON.parse(node?.textContent || '{}');
}

/* The event an element carries in `data-sms-event`, written by R: `{type, data}`, or null. */
export function readEvent(element) {
  const text = element.getAttribute('data-sms-event');
  if (!text) return null;
  const event = JSON.parse(text);
  return { type: event.type, data: event.data ?? {} };
}

/* Whether a render may set the value of `field`: not while it has focus, and not while its last send (its `seq`,
   Infinity while text is held) is above the acknowledged one. */
export function canPatch(field, ack) {
  if (field === document.activeElement) return false;
  return !(Number(field.dataset.smsSeq ?? 0) > ack);
}

/* Sets the text of `node` when it differs, so an unchanged node is left alone. */
export function setText(node, text) {
  if (node && node.textContent !== text) node.textContent = text;
}

/* An element with a class and text. */
export function make(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

/* Marks a button busy (aria-busy and aria-disabled, never `disabled`, which would move focus away), or not. */
export function setBusy(button, busy) {
  if (busy) {
    button.setAttribute('aria-busy', 'true');
    button.setAttribute('aria-disabled', 'true');
  } else {
    button.removeAttribute('aria-busy');
    if (button.dataset.smsDisabled !== 'true') {
      button.removeAttribute('aria-disabled');
    }
  }
}

/* Marks a button server-disabled (aria-disabled and data-sms-disabled), without setting aria-busy. */
export function setDisabled(button, disabled) {
  if (disabled) {
    button.dataset.smsDisabled = 'true';
    button.setAttribute('aria-disabled', 'true');
  } else {
    delete button.dataset.smsDisabled;
    if (!button.hasAttribute('data-sms-wait-seq')) {
      button.removeAttribute('aria-disabled');
    }
  }
}

/* Reorders and prunes `parent`'s children to match `nodes` in place so focused nodes stay put when kept. */
export function syncChildren(parent, nodes) {
  const wanted = new Set(nodes);
  for (const child of [...parent.children]) {
    if (!wanted.has(child)) child.remove();
  }
  for (let i = 0; i < nodes.length; i += 1) {
    const want = nodes[i];
    const current = parent.children[i] ?? null;
    if (current !== want) parent.insertBefore(want, current);
  }
}
