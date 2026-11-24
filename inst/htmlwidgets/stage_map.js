/*
 * The htmlwidgets binding for the stage map. It only calls the stage-map engine's public API: `mount` on the first
 * render, `view.update` on later ones, `view.destroy` when the element leaves the page, `view.send` for commands from R,
 * and the engine's events, which it passes to Shiny. It also pushes what the map answers to the `state` command into an
 * input. `x` is { v: 1, engine: { global, prefix, visual }, data, look, stamp }: the names of the engine's global, of its
 * events (`<prefix>:select`) and of the visual come from R, which reads them from the engine's contract; `stamp` is for
 * Shiny only. htmlwidgets loads this file before the widget's dependencies, so the engine is touched only inside the
 * functions.
 */
(() => {
  const QUEUE_LIMIT = 100;
  /* The engine's events that reach Shiny, and the input each one becomes: input$<id>_<suffix>. */
  const EVENTS = {
    select: 'selected',
    hover: 'hover' /* what is under the pointer, or NULL in R once it leaves; never a numbered choice */,
  };

  const warned = new Set(); /* console warnings already written, so a repeated mistake is told once */
  const warnOnce = (key, words) => {
    if (warned.has(key)) return;
    warned.add(key);
    console.warn(`stagemap: ${words}`);
  };

  /* Commands from R. While one runs, the events it makes are not the reader's. A command the engine holds (answer null)
     runs later, so its cause is kept until then; 1000 is a cap. */
  let cmdSeq = 0;
  let running = 0;
  const causes = new Set();
  const recordCause = (cause) => {
    causes.add(cause);
    if (causes.size > 1000) causes.delete(causes.values().next().value);
  };

  const handles = new Map(); /* element id -> the widget that takes commands for it */
  const queues = new Map(); /* element id -> commands for a widget that is not drawn yet */
  const watched = new Set(); /* widgets whose element may leave the page */
  /* The reader's choices so far, per element: kept here, so a widget made again with the same id (renderUI) goes on
     from the number R has seen. */
  const choices = new Map();
  let observer = null;

  /* One observer for all widgets (Shiny has no hook for a removed output) destroys a view whose element has left the
     page once the mutations settle. */
  function checkRemoved() {
    for (const widget of [...watched]) {
      if (!widget.el.isConnected) {
        watched.delete(widget);
        widget.destroy();
      }
    }
    if (watched.size === 0) observer = void observer?.disconnect(); /* stop watching, forget the observer */
  }

  function watch(widget) {
    watched.add(widget);
    if (!observer) {
      observer = new MutationObserver(checkRemoved);
      observer.observe(document.body, { childList: true, subtree: true });
    }
  }

  /* A map in a Shiny ui draws before Shiny has started, when setInputValue does not exist yet: what it says waits. */
  const early = [];
  function sendInput(name, value) {
    if (!window.HTMLWidgets?.shinyMode) return;
    if (window.Shiny?.setInputValue) window.Shiny.setInputValue(name, value, { priority: 'event' });
    else if (early.push([name, value]) === 1)
      window.jQuery?.(document).one('shiny:connected', () => {
        for (const input of early.splice(0)) sendInput(...input);
      });
  }

  /* A command from R: run it on the widget, or keep it until the widget is drawn (the oldest goes first when full). */
  function deliver(message) {
    const widget = handles.get(message.id);
    if (widget?.drawn()) widget.run(message);
    else queues.set(message.id, [...(queues.get(message.id) ?? []), message].slice(-QUEUE_LIMIT));
  }

  let registered = false;
  function register() {
    if (registered) return;
    if (!window.Shiny?.addCustomMessageHandler) {
      window.jQuery?.(document).one('shiny:connected', register); /* Shiny has not started: try again when it has */
      return;
    }
    registered = true;
    window.Shiny.addCustomMessageHandler('stagemap:command', deliver);
    window.jQuery?.(document).on('shiny:disconnected', () => queues.clear());
  }
  register();

  window.HTMLWidgets.widget({
    name: 'stage_map',
    type: 'output',
    factory: (el) => {
      register();
      let root = null;
      let view = null;
      let visual = null;
      let engine = null; /* the engine's names, as R sent them with the data */
      let listening = []; /* the event types heard on the element */
      let watching = false;
      let pushTimer = 0;
      let lastState = null; /* the state last sent, as text, so only a change is sent */
      /* Whether the last answer to `state` was null (not drawn yet): each such ask makes the engine hold one more
         command, so it is not asked again until something has drawn (new data, or an event from the engine). */
      let notReady = false;

      /* R only reads the state: the binding asks the map for it and sets an input when the answer changed. */
      function pushState() {
        pushTimer = 0;
        if (!view || notReady) return;
        const answer = view.send('state');
        if (answer === null) notReady = true;
        if (answer === null || typeof answer !== 'object') return;
        const text = JSON.stringify(answer);
        if (lastState === text) return;
        lastState = text;
        sendInput(`${el.id}_state:stagemap.state`, answer);
      }
      /* One push after the engine has reacted, however many events came in this turn. */
      const scheduleState = () => {
        if (!pushTimer) pushTimer = setTimeout(pushState, 0);
      };

      const widget = {
        el,
        drawn: () => view !== null,
        /* A select older than the reader's latest choice is dropped, so a late answer cannot undo a newer click. */
        run: (message) => {
          if (message.command === 'select' && (message.revision ?? 0) < (choices.get(el.id) ?? 0)) return;
          const cause = `stagemap:${++cmdSeq}`;
          recordCause(cause);
          let answer;
          running += 1;
          try {
            answer = view.send(message.command, message.data, { cause });
          } finally {
            running -= 1;
          }
          if (answer !== null) causes.delete(cause);
          if (answer === false)
            warnOnce(
              `${el.id}/${message.command}`,
              `"${el.id}" did not take "${message.command}" (it may not take it, or is not drawn yet).`,
            );
          scheduleState();
        },
        destroy: () => {
          unmount();
          clearTimeout(pushTimer);
          /* A map drawn again under the same id has taken over: what waits for it stays. */
          if (handles.get(el.id) === widget) {
            handles.delete(el.id);
            queues.delete(el.id);
          }
          for (const type of listening) el.removeEventListener(type, onEvent);
          listening = [];
          window.jQuery?.(el).off('shiny:recalculating', markBusy);
          window.jQuery?.(el).off('shiny:error shiny:value', clearBusyUnlessValue);
          watching = false;
        },
      };

      function unmount() {
        view?.destroy();
        root?.remove();
        [view, root, visual] = [null, null, null];
        lastState = null;
      }

      function onEvent(event) {
        const name = event.type.slice(engine.prefix.length + 1);
        if (name !== 'hover') {
          notReady = false; /* something drew, so ask again */
          scheduleState();
        }
        const detail = event.detail ?? {};
        if (running > 0 || (detail.cause && causes.has(detail.cause))) return;
        const input = `${el.id}_${EVENTS[name]}`;
        if (name === 'select') {
          /* The selection is a typed input (stagemap.select), so R always gets the same shape. A choice by the reader
             is numbered; one by a command (by: 'host') or by new data (by: 'data') is sent as it is. */
          if (detail.by === 'reader') choices.set(el.id, (choices.get(el.id) ?? 0) + 1);
          sendInput(`${input}:stagemap.select`, { ...detail, revision: choices.get(el.id) ?? 0 });
        } else {
          /* Every field the engine sent goes to R; a pointer that left a card sends NULL. */
          sendInput(detail.id == null ? input : `${input}:stagemap.hover`, detail.id == null ? null : detail);
        }
      }

      const markBusy = () => el.setAttribute('aria-busy', 'true');
      const markIdle = () => el.removeAttribute('aria-busy');
      /* Busy ends with the result: the drawn value (renderValue), an error, or a value of nothing (NULL in R). */
      function clearBusyUnlessValue(event) {
        if (event.type === 'shiny:error' || event.value === null || event.value?.x === null) markIdle();
      }

      function start(names) {
        if (watching) return;
        watching = true;
        engine = names;
        handles.set(el.id, widget);
        listening = Object.keys(EVENTS).map((name) => `${engine.prefix}:${name}`);
        for (const type of listening) el.addEventListener(type, onEvent);
        window.jQuery?.(el).on('shiny:recalculating', markBusy);
        window.jQuery?.(el).on('shiny:error shiny:value', clearBusyUnlessValue);
        watch(widget);
      }

      function draw(x) {
        const kit = window[x.engine.global];
        if (!kit) throw new Error(`the engine "${x.engine.global}" is not loaded`);
        /* The engine takes a page's look (colours, mode) inside the mount options, as `look`. */
        const options = x.look ? { look: x.look } : undefined;
        if (view && visual === x.engine.visual) {
          view.update(x.data, options);
          return;
        }
        unmount();
        root = document.createElement('div');
        el.replaceChildren(root);
        view = kit.mount(root, x.engine.visual, x.data, options);
        visual = x.engine.visual;
      }

      return {
        renderValue: (x) => {
          start(x.engine);
          notReady = false;
          try {
            draw(x);
          } catch (error) {
            unmount();
            el.textContent = `stagemap: ${error.message}`;
            console.error(error);
          }
          if (x.stamp !== undefined && x.stamp !== null) el.setAttribute('data-stagemap-stamp', x.stamp);
          markIdle();
          const waiting = queues.get(el.id) ?? [];
          queues.delete(el.id);
          if (view) for (const message of waiting) widget.run(message);
          scheduleState();
        },
        resize: () => view?.resize(),
      };
    },
  });
})();
