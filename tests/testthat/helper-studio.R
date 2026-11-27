# Helpers for the studio's tests. The browser helpers drive tests/testthat/apps/studio/app.R and wait on the page's own
# state (the root's data-sms-ack, data-sms-sent, aria-busy and the map's data-stagemap-stamp), never for a fixed time.
# They reach the page only through its DOM and its three seams (the stagemap-studio:send, :message and :deliver events
# on the root); what a helper keeps in the page lives under window.__sms or window.__smsCounts.

# The studio's root, as JavaScript and as a CSS selector helper.
studio_root_js <- "document.querySelector('.sms')"

# The CSS selector for the studio root of `app`.
studio_root <- function(app) {
  checkmate::assert_r6(app, "AppDriver")
  ".sms"
}

# Fixtures, built by arithmetic with no random numbers.

# The small studio fixture: full_map() with a title.
studio_small <- function(title = "A small piece of work", ...) {
  checkmate::assert_string(title, null.ok = TRUE)
  full_map(title = title, ...)
}

# The large studio fixture: 120 cards (8 stages, 5 lanes, 3 per cell), 150 links of 2 kinds, one zone, and 4 steps with
# changes. Card ids are c001 to c120.
studio_large <- function() {
  n_cards <- 120L
  idx <- seq_len(n_cards)
  stage_idx <- ((idx - 1L) %/% 15L) + 1L
  lane_idx <- (((idx - 1L) %/% 3L) %% 5L) + 1L
  statuses <- c("done", "running", "waiting", "failed", "skipped")
  cards <- data.frame(
    id = sprintf("c%03d", idx),
    label = sprintf("Card %03d", idx),
    stage = paste0("s", stage_idx),
    lane = paste0("l", lane_idx),
    status = statuses[((idx - 1L) %% length(statuses)) + 1L],
    zone = ifelse(idx <= 12L, "z1", NA_character_)
  )
  stages <- data.frame(id = paste0("s", 1:8), label = paste("Stage", 1:8))
  lanes <- data.frame(id = paste0("l", 1:5), label = paste("Lane", 1:5))

  link_idx <- seq_len(150L)
  from_i <- ((link_idx - 1L) %% 119L) + 1L
  to_i <- from_i + ifelse(link_idx <= 119L, 1L, 2L)
  links <- data.frame(
    from = sprintf("c%03d", from_i),
    to = sprintf("c%03d", to_i),
    kind = ifelse(link_idx %% 2L == 1L, "k1", "k2")
  )
  kinds <- data.frame(id = c("k1", "k2"), label = c("Hands off", "Checks"), line = c("solid", "dashed"))
  zones <- data.frame(id = "z1", label = "Review zone", note = "Twelve cards.")
  steps <- data.frame(
    id = paste0("step", 1:4),
    label = paste("Step", 1:4),
    stage = c("s1", "s3", "s5", "s7")
  )
  changes <- data.frame(
    step = c("step2", "step3", "step4", "step4"),
    card = c("c001", "c002", "c003", "c004"),
    status = c("done", "running", "failed", "done"),
    stage = c("s2", "s4", "s6", "s8")
  )

  stage_map(cards, stages, lanes, title = "Large workflow") |>
    add_links(links, kinds = kinds) |>
    add_zones(zones) |>
    add_steps(steps, changes = changes, intro = "Four steps")
}

# The steps studio fixture: full_map() with three steps, for the player tests.
studio_steps <- function() {
  full_map(title = "A small piece of work") |>
    add_steps(
      data.frame(
        id = c("s1", "s2", "s3"),
        label = c("Write draft", "Check work", "Ship release"),
        stage = c("write", "check", "ship")
      ),
      changes = data.frame(
        step = c("s2", "s3"),
        card = c("b", "c"),
        status = c("done", "running")
      ),
      intro = "Three steps"
    )
}

# JavaScript installed before the page's scripts via Page.addScriptToEvaluateOnNewDocument. Tracks unique event
# listeners (by target, type, listener and capture), active MutationObserver / ResizeObserver / IntersectionObserver
# instances, pending setTimeout / setInterval timers, and exposes window.__smsCounts().
studio_count_shim <- function() {
  paste(
    "(() => {",
    "  if (window.__smsCounts) return;",
    "  let listeners = 0;",
    "  let observers = 0;",
    "  const timers = new Set();",
    "  const targetMap = new WeakMap();",
    "  const origAdd = EventTarget.prototype.addEventListener;",
    "  const origRemove = EventTarget.prototype.removeEventListener;",
    "  const getCapture = (options) =>",
    "    Boolean(typeof options === 'boolean' ? options : options && options.capture);",
    "  const getEntryMap = (target, type, capture, create) => {",
    "    let byType = targetMap.get(target);",
    "    if (!byType) { if (!create) return null; byType = new Map(); targetMap.set(target, byType); }",
    "    let byCapture = byType.get(type);",
    "    if (!byCapture) { if (!create) return null; byCapture = new Map(); byType.set(type, byCapture); }",
    "    let byListener = byCapture.get(capture);",
    "    if (!byListener) { if (!create) return null; byListener = new Map(); byCapture.set(capture, byListener); }",
    "    return byListener;",
    "  };",
    "  const dropEntry = (target, type, capture, listener) => {",
    "    const byListener = getEntryMap(target, type, capture, false);",
    "    if (!byListener) return null;",
    "    const entry = byListener.get(listener);",
    "    if (!entry) return null;",
    "    byListener.delete(listener);",
    "    listeners -= 1;",
    "    return entry;",
    "  };",
    "  EventTarget.prototype.addEventListener = function (type, listener, options) {",
    "    if (!listener || (typeof listener !== 'function' && typeof listener !== 'object')) {",
    "      return origAdd.call(this, type, listener, options);",
    "    }",
    "    const opts = options && typeof options === 'object' ? options : null;",
    "    if (opts && opts.signal && opts.signal.aborted) {",
    "      return origAdd.call(this, type, listener, options);",
    "    }",
    "    const keyType = String(type);",
    "    const capture = getCapture(options);",
    "    const byListener = getEntryMap(this, keyType, capture, true);",
    "    if (!byListener.has(listener)) {",
    "      const target = this;",
    "      let actual = listener;",
    "      const entry = { wrapped: null };",
    "      if (opts && opts.once && typeof listener === 'function') {",
    "        actual = function (...args) {",
    "          dropEntry(target, keyType, capture, listener);",
    "          return listener.apply(this, args);",
    "        };",
    "        entry.wrapped = actual;",
    "      }",
    "      byListener.set(listener, entry);",
    "      listeners += 1;",
    "      if (opts && opts.signal) {",
    "        origAdd.call(opts.signal, 'abort', () => dropEntry(target, keyType, capture, listener), { once: true });",
    "      }",
    "      return origAdd.call(this, type, actual, options);",
    "    }",
    "    return origAdd.call(this, type, listener, options);",
    "  };",
    "  EventTarget.prototype.removeEventListener = function (type, listener, options) {",
    "    const keyType = String(type);",
    "    const capture = getCapture(options);",
    "    const entry = dropEntry(this, keyType, capture, listener);",
    "    return origRemove.call(this, type, entry && entry.wrapped ? entry.wrapped : listener, options);",
    "  };",
    "  const OrigMutation = window.MutationObserver;",
    "  if (OrigMutation) {",
    "    window.MutationObserver = class extends OrigMutation {",
    "      constructor(callback) { super(callback); this.__smsActive = false; }",
    "      observe(target, options) {",
    "        super.observe(target, options);",
    "        if (!this.__smsActive) { this.__smsActive = true; observers += 1; }",
    "      }",
    "      disconnect() {",
    "        if (this.__smsActive) { this.__smsActive = false; observers -= 1; }",
    "        super.disconnect();",
    "      }",
    "    };",
    "  }",
    "  const wrapTargetObserver = (Orig) => {",
    "    if (!Orig) return Orig;",
    "    return class extends Orig {",
    "      constructor(callback, options) { super(callback, options); this.__smsTargets = new Set(); }",
    "      observe(target, options) {",
    "        super.observe(target, options);",
    "        if (this.__smsTargets.size === 0) observers += 1;",
    "        this.__smsTargets.add(target);",
    "      }",
    "      unobserve(target) {",
    "        if (this.__smsTargets.delete(target) && this.__smsTargets.size === 0) observers -= 1;",
    "        super.unobserve(target);",
    "      }",
    "      disconnect() {",
    "        if (this.__smsTargets.size > 0) { this.__smsTargets.clear(); observers -= 1; }",
    "        super.disconnect();",
    "      }",
    "    };",
    "  };",
    "  window.ResizeObserver = wrapTargetObserver(window.ResizeObserver);",
    "  window.IntersectionObserver = wrapTargetObserver(window.IntersectionObserver);",
    "  const origSetTimeout = window.setTimeout.bind(window);",
    "  const origClearTimeout = window.clearTimeout.bind(window);",
    "  const origSetInterval = window.setInterval.bind(window);",
    "  const origClearInterval = window.clearInterval.bind(window);",
    "  window.setTimeout = function (fn, delay, ...args) {",
    "    let id;",
    "    const wrapped = typeof fn === 'function'",
    "      ? function (...cbArgs) { timers.delete(id); return fn.apply(this, cbArgs); }",
    "      : fn;",
    "    id = origSetTimeout(wrapped, delay, ...args);",
    "    timers.add(id);",
    "    return id;",
    "  };",
    "  window.clearTimeout = function (id) { timers.delete(id); return origClearTimeout(id); };",
    "  window.setInterval = function (fn, delay, ...args) {",
    "    const id = origSetInterval(fn, delay, ...args);",
    "    timers.add(id);",
    "    return id;",
    "  };",
    "  window.clearInterval = function (id) { timers.delete(id); return origClearInterval(id); };",
    "  window.__smsCounts = () => ({",
    "    listeners,",
    "    observers,",
    "    timers: timers.size,",
    "    nodes: document.querySelectorAll('*').length",
    "  });",
    "})();",
    sep = "\n"
  )
}

# Formats the app's logs for failure reporting when startup or initial draw fails.
studio_format_logs <- function(app) {
  logs <- tryCatch(as.data.frame(app$get_logs()), error = function(e) NULL)
  if (is.null(logs) || nrow(logs) == 0L) {
    return("(no app logs captured)")
  }
  lines <- paste(logs$location, logs$level, logs$message, sep = ": ")
  paste(utils::tail(lines, 20L), collapse = "\n")
}

# Aborts when the studio app fails to draw, interpolating message and logs through variables so braces are not parsed.
studio_abort_draw <- function(app, e) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_class(e, "condition")
  msg <- conditionMessage(e)
  logs <- studio_format_logs(app)
  cli::cli_abort(
    c(
      "The studio app did not draw in time.",
      "x" = "{msg}",
      "i" = "App logs:\n{logs}"
    ),
    parent = e
  )
}

# Starts the studio app on the map `fixture` ("none", "small", "large", or "steps"), installs the count shim before
# the page's scripts, and waits until the page has drawn the server's first message and the map. `copy_wait_ms` is
# Copy's wait (the app's default when NULL); `...` goes to AppDriver$new().
studio_driver <- function(fixture = "small", copy_wait_ms = NULL, ..., env = parent.frame()) {
  checkmate::assert_choice(fixture, c("none", "small", "large", "steps"))
  checkmate::assert_count(copy_wait_ms, positive = TRUE, null.ok = TRUE)
  checkmate::assert_environment(env)
  wait_val <- if (is.null(copy_wait_ms)) NA else as.character(copy_wait_ms)
  withr::local_envvar(
    STAGEMAP_STUDIO_FIXTURE = fixture,
    STAGEMAP_STUDIO_COPY_WAIT = wait_val,
    STAGEMAP_STUDIO_COPY_WAIT_MS = wait_val
  )
  app <- app_driver(testthat::test_path("apps", "studio"), ..., env = env)
  session <- app$get_chromote_session()
  session$Page$enable()
  session$Page$addScriptToEvaluateOnNewDocument(source = studio_count_shim())
  app$run_js("window.__smsShimPending = true; location.reload();")
  tryCatch(
    {
      app$wait_for_js("window.__smsShimPending === undefined && typeof window.__smsCounts === 'function'")
      studio_wait_drawn(app)
    },
    error = function(e) studio_abort_draw(app, e)
  )
  app
}

# Waits until the page has drawn a message from the server and the map has drawn its cards, with nothing pending.
studio_wait_drawn <- function(app) {
  checkmate::assert_r6(app, "AppDriver")
  app$wait_for_js(sprintf(
    "(() => { const r = %s; const m = r && r.querySelector('[data-stagemap-stamp]');
      return r !== null && r.dataset.smsAck !== undefined && !r.hasAttribute('aria-busy') &&
      m !== null && !m.hasAttribute('aria-busy') && Number(m.getAttribute('data-stagemap-stamp')) >= 1 &&
      r.querySelectorAll('[data-card]').length > 0; })()",
    studio_root_js
  ))
  invisible(app)
}

# Waits until the page and the server are in step: no text is held, the server has acknowledged everything the page
# sent, and the root is not busy. Returns the acknowledged seq observed by the last poll.
studio_wait_step <- function(app) {
  checkmate::assert_r6(app, "AppDriver")
  app$run_js("window.__smsLastAck = null;")
  app$wait_for_js(sprintf(
    "(() => { const r = %s; const ok = r.querySelector('[data-sms-wait]') === null &&
      Number(r.dataset.smsAck) >= Number(r.dataset.smsSent) && !r.hasAttribute('aria-busy');
      if (ok) window.__smsLastAck = Number(r.dataset.smsAck);
      return ok; })()",
    studio_root_js
  ))
  as.integer(app$get_js("window.__smsLastAck"))
}

# Runs the page action `js` and reads, in the same call, how many events the page has sent; then waits until the server
# has acknowledged them all and nothing is held or busy. Returns that count.
studio_do <- function(app, js) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_string(js, min.chars = 1L)
  sent <- app$get_js(sprintf("(() => { %s; return Number(%s.dataset.smsSent); })()", js, studio_root_js))
  app$wait_for_js(sprintf("Number(%s.dataset.smsAck) >= %d", studio_root_js, as.integer(sent)))
  studio_wait_step(app)
  as.integer(sent)
}

# The map's current render stamp (0 if not drawn yet).
studio_stamp <- function(app) {
  checkmate::assert_r6(app, "AppDriver")
  as.integer(app$get_js(sprintf(
    "Number(%s?.querySelector('[data-stagemap-stamp]')?.getAttribute('data-stagemap-stamp') ?? 0)",
    studio_root_js
  )))
}

# Waits until the map widget has rendered a stamp strictly above `since` and is not busy; returns that stamp.
studio_wait_map <- function(app, since) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_count(since)
  app$run_js("window.__smsLastStamp = null;")
  app$wait_for_js(sprintf(
    "(() => { const m = %s?.querySelector('[data-stagemap-stamp]'); if (!m) return false;
      const stamp = Number(m.getAttribute('data-stagemap-stamp') ?? 0);
      const ok = stamp > %d && !m.hasAttribute('aria-busy') && m.querySelectorAll('[data-card]').length > 0;
      if (ok) window.__smsLastStamp = stamp;
      return ok; })()",
    studio_root_js,
    as.integer(since)
  ))
  as.integer(app$get_js("window.__smsLastStamp"))
}

# Reads what the page last drew for section `name` directly from the DOM (never from a global).
studio_section <- function(app, name) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_choice(
    name,
    c("header", "outline", "inspector", "journal", "start", "status", "notice", "ask", "check", "code", "map", "tour")
  )
  raw <- app$get_js(sprintf(
    "(() => {
      const r = %s;
      const name = %s;
      const text = (sel) => r.querySelector(sel)?.textContent ?? null;
      if (name === 'header') {
        return JSON.stringify({
          rev: Number(text('.sms-rev') ?? 0),
          title: r.querySelector('.sms-title')?.value ?? null,
          facts: text('.sms-facts'),
          map_name: text('.sms-map-name')
        });
      }
      if (name === 'status') {
        return JSON.stringify({
          rev: Number(r.dataset.smsRev ?? 0),
          ack: Number(r.dataset.smsAck ?? 0),
          n: Number(r.dataset.smsN ?? 0),
          sent: Number(r.dataset.smsSent ?? 0),
          closed: r.dataset.smsClosed !== undefined,
          stamp: text('.sms-stamp')
        });
      }
      if (name === 'notice') {
        const box = r.querySelector('.sms-toast');
        return JSON.stringify({
          on: box?.dataset.smsOn !== undefined,
          tone: box?.dataset.smsTone ?? null,
          tone_label: text('.sms-toast-tone'),
          text: text('.sms-toast-text')
        });
      }
      if (name === 'code') {
        const lines = [...r.querySelectorAll('.sms-code .sms-l')].map((el) => ({
          text: el.textContent,
          changed: el.dataset.smsChanged !== undefined
        }));
        return JSON.stringify({
          text: text('.sms-code'),
          lines,
          count: text('.sms-code-count'),
          sum: text('.sms-code-sum'),
          problem: text('.sms-code-note')
        });
      }
      if (name === 'tour') {
        const hint = r.querySelector('.sms-hint');
        return JSON.stringify({ hidden: Boolean(hint?.hidden), text: hint?.textContent ?? '' });
      }
      if (name === 'ask' || name === 'check' || name === 'map') {
        const room = r.querySelector(`[data-sms-room-of=\"${name}\"]`);
        return JSON.stringify({
          hidden: Boolean(room?.hidden),
          inert: Boolean(room?.inert),
          text: room?.querySelector('.sms-room-body')?.textContent ?? ''
        });
      }
      const sel = { outline: '.sms-outline', inspector: '.sms-inspector', journal: '.sms-journal', start: '.sms-start' }[name];
      const el = r.querySelector(sel);
      return JSON.stringify({ hidden: Boolean(el?.hidden), text: el?.textContent ?? '' });
    })()",
    studio_root_js,
    jsonlite::toJSON(name, auto_unbox = TRUE)
  ))
  jsonlite::fromJSON(raw, simplifyVector = FALSE)
}

# JavaScript that types `text` into the field `selector` as a person does: focus, select all and delete it (one input
# event), then one input event per character. Returned as text, so a test can put it in one run_js() call with the
# action that follows.
studio_type_js <- function(selector, text) {
  checkmate::assert_string(selector, min.chars = 1L)
  checkmate::assert_string(text)
  sprintf(
    "{ const f = document.querySelector(%s); if (!f) throw new Error('Missing field: ' + %s); f.focus(); f.select(); f.value = '';
       f.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'deleteContentBackward' }));
       for (const ch of %s) { f.value += ch; f.dispatchEvent(new InputEvent('input', { bubbles: true, data: ch, inputType: 'insertText' })); } }",
    jsonlite::toJSON(selector, auto_unbox = TRUE),
    jsonlite::toJSON(selector, auto_unbox = TRUE),
    jsonlite::toJSON(text, auto_unbox = TRUE)
  )
}

# Focuses `selector`, replaces its value with `text` and dispatches `input` events as typing does; does not wait.
studio_type <- function(app, selector, text) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_string(selector, min.chars = 1L)
  checkmate::assert_string(text)
  app$run_js(studio_type_js(selector, text))
  invisible(app)
}

# JavaScript that types `text` into the studio's title input.
studio_title_js <- function(text) {
  checkmate::assert_string(text)
  studio_type_js(".sms-title", text)
}

# Types `text` as the title and blurs the field so it goes out at once; returns the seq of that send.
studio_title_sent <- function(app, text) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_string(text)
  app$get_js(sprintf(
    "(() => { %s; document.querySelector('.sms-title').blur(); return Number(%s.dataset.smsSent); })()",
    studio_title_js(text),
    studio_root_js
  ))
}

# JavaScript that computes the contrast ratio of the toast's problem edge and mark against its background.
studio_toast_contrast_js <- "(() => {
  const rgb = (c) => c.match(/[\\d.]+/g).slice(0, 3).map(Number);
  const lum = (c) => { const f = (v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; };
    return 0.2126 * f(c[0]) + 0.7152 * f(c[1]) + 0.0722 * f(c[2]); };
  const ratio = (a, b) => { const [x, y] = [lum(rgb(a)), lum(rgb(b))].sort((p, q) => q - p); return (x + 0.05) / (y + 0.05); };
  const box = document.querySelector('.sms-toast');
  box.dataset.smsTone = 'problem'; box.dataset.smsOn = '';
  const s = getComputedStyle(box);
  return { edge: ratio(s.borderLeftColor, s.backgroundColor),
           mark: ratio(getComputedStyle(box.querySelector('.sms-toast-mark')).color, s.backgroundColor) };
})()"

# JavaScript that clicks the element `selector` (a synthetic click, as click_now() makes).
studio_click_js <- function(selector) {
  checkmate::assert_string(selector, min.chars = 1L)
  sprintf("document.querySelector(%s).click();", jsonlite::toJSON(selector, auto_unbox = TRUE))
}

# Default virtual key codes for common keys when `key_code` is not supplied explicitly.
studio_key_codes <- c(
  Backspace = 8L,
  Tab = 9L,
  Enter = 13L,
  Escape = 27L,
  Space = 32L,
  ArrowLeft = 37L,
  ArrowUp = 38L,
  ArrowRight = 39L,
  ArrowDown = 40L
)

# A real key press (keyDown, then keyUp) through the browser's input domain, sent to the element with focus.
# `modifiers` is any subset of c("alt", "ctrl", "meta", "shift").
studio_press <- function(app, key, modifiers = character(), code = key, key_code = 0L) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_string(key, min.chars = 1L)
  checkmate::assert_character(modifiers, any.missing = FALSE)
  checkmate::assert_subset(modifiers, c("alt", "ctrl", "meta", "shift"))
  checkmate::assert_string(code, min.chars = 1L)
  checkmate::assert_count(key_code)
  if (key_code == 0L) {
    if (key %in% names(studio_key_codes)) {
      key_code <- studio_key_codes[[key]]
    } else if (nchar(key) == 1L) {
      key_code <- as.integer(charToRaw(toupper(key))[[1L]])
    }
  }
  mod_bits <- c(alt = 1L, ctrl = 2L, meta = 4L, shift = 8L)
  mod_mask <- sum(mod_bits[modifiers])
  session <- app$get_chromote_session()
  for (type in c("keyDown", "keyUp")) {
    session$Input$dispatchKeyEvent(
      type = type,
      key = key,
      code = code,
      modifiers = as.integer(mod_mask),
      windowsVirtualKeyCode = as.integer(key_code)
    )
  }
  invisible(app)
}

# A real mouse click (press and release, with the click's user activation) in the middle of the element `selector`.
studio_click_real <- function(app, selector) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_string(selector, min.chars = 1L)
  box <- app$get_js(sprintf(
    "(() => { const b = document.querySelector(%s).getBoundingClientRect(); return [b.x + b.width / 2, b.y + b.height / 2]; })()",
    jsonlite::toJSON(selector, auto_unbox = TRUE)
  ))
  session <- app$get_chromote_session()
  for (type in c("mousePressed", "mouseReleased")) {
    session$Input$dispatchMouseEvent(type = type, x = box[[1]], y = box[[2]], button = "left", clickCount = 1L)
  }
  invisible(app)
}

# Active emulated media features per chromote session id, so setting one feature preserves earlier ones.
studio_emulated_media <- new.env(parent = emptyenv())

# Merges `feature = value` into the active media features recorded for `key` and returns the CDP features list.
studio_merge_media <- function(key, feature, value) {
  checkmate::assert_string(key, min.chars = 1L)
  checkmate::assert_string(feature, min.chars = 1L)
  checkmate::assert_string(value)
  current <- studio_emulated_media[[key]] %||% list()
  current[[feature]] <- value
  studio_emulated_media[[key]] <- current
  lapply(names(current), function(name) list(name = name, value = current[[name]]))
}

# Sets a media feature of the page (such as ("prefers-reduced-motion", "reduce")), preserving features already set
# on the same session, or resizes the viewport width when `feature == "width"` (for phone layout tests).
studio_emulate <- function(app, feature, value) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_string(feature, min.chars = 1L)
  if (identical(feature, "width")) {
    px <- if (is.numeric(value) && length(value) == 1L) {
      value
    } else if (is.character(value) && length(value) == 1L && grepl("^[0-9]+$", value)) {
      as.integer(value)
    } else {
      NA_integer_
    }
    checkmate::assert_count(px, positive = TRUE)
    size <- app$get_window_size()
    app$set_window_size(width = as.integer(px), height = size$height, wait = FALSE)
    app$wait_for_js(sprintf("window.innerWidth === %d", as.integer(px)))
    return(invisible(app))
  }
  checkmate::assert_string(value)
  session <- app$get_chromote_session()
  features <- studio_merge_media(session$get_session_id(), feature, value)
  session$Emulation$setEmulatedMedia(features = features)
  invisible(app)
}

# Records every event the page sends, in window.__sms.sent, without holding it.
record_studio_events <- function(app) {
  checkmate::assert_r6(app, "AppDriver")
  app$run_js(sprintf(
    "window.__sms = window.__sms || {}; window.__sms.sent = [];
     %s.addEventListener('stagemap-studio:send', (e) => window.__sms.sent.push(e.detail));",
    studio_root_js
  ))
  invisible(app)
}

# The events recorded by record_studio_events(), as a list.
studio_sent <- function(app) {
  checkmate::assert_r6(app, "AppDriver")
  app$get_js("JSON.stringify(window.__sms.sent)") |> jsonlite::fromJSON(simplifyVector = FALSE)
}

# Holds events the page is about to send through the stagemap-studio:send seam in window.__sms.heldEvents until
# release_studio_events() posts them to Shiny.
hold_studio_events <- function(app) {
  checkmate::assert_r6(app, "AppDriver")
  app$run_js(sprintf(
    "window.__sms = window.__sms || {}; window.__sms.heldEvents = [];
     window.__sms.eventHolder = (e) => { e.preventDefault(); window.__sms.heldEvents.push(e.detail); };
     %s.addEventListener('stagemap-studio:send', window.__sms.eventHolder);",
    studio_root_js
  ))
  invisible(app)
}

# Stops holding page events and posts any held events to Shiny in order (or reverse order when `reverse = TRUE`).
release_studio_events <- function(app, reverse = FALSE) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_flag(reverse)
  app$run_js(sprintf(
    "{ const r = %s; r.removeEventListener('stagemap-studio:send', window.__sms.eventHolder);
       const held = (window.__sms.heldEvents || []).splice(0); if (%s) held.reverse();
       const name = r.dataset.smsNs + 'event';
       for (const ev of held) window.Shiny.setInputValue(name, ev, { priority: 'event' }); }",
    studio_root_js,
    tolower(reverse)
  ))
  invisible(app)
}

# Records, in window.__sms.wire, what the page sends over its websocket, in the order it leaves: "init" for Shiny's own
# init message and "post <type> <seq>" for each studio event. It patches WebSocket.send, so it sees the real order,
# which Shiny's connected and sessioninitialized events do not show to a listener added after the studio's.
record_studio_wire <- function(app) {
  checkmate::assert_r6(app, "AppDriver")
  app$run_js(
    "window.__sms = window.__sms || {}; window.__sms.wire = [];
     const send = WebSocket.prototype.send;
     WebSocket.prototype.send = function (data) {
       try {
         const m = JSON.parse(data);
         if (m.method === 'init') window.__sms.wire.push('init');
         else if (m.method === 'update') {
           for (const [name, value] of Object.entries(m.data)) {
             if (/event/.test(name) && value && value.type) window.__sms.wire.push(`post ${value.type} ${value.seq}`);
           }
         }
       } catch (e) { /* not a message of Shiny's */ }
       return send.call(this, data);
     };"
  )
  invisible(app)
}

# Closes the page's websocket as a network drop does, and waits until Shiny says it is disconnected.
drop_studio_connection <- function(app) {
  checkmate::assert_r6(app, "AppDriver")
  app$run_js(
    "window.__sms = window.__sms || {}; window.__sms.dropped = false;
     $(document).one('shiny:disconnected', () => { window.__sms.dropped = true; });
     Shiny.shinyapp.$socket.close();"
  )
  app$wait_for_js("window.__sms.dropped === true")
  invisible(app)
}

# Opens a new websocket, which is a new session of the app, as Shiny's own reconnect does.
reconnect_studio <- function(app) {
  checkmate::assert_r6(app, "AppDriver")
  app$run_js("Shiny.shinyapp.reconnect();")
  invisible(app)
}

# Holds what the server answers: each message is kept in window.__sms.held and not drawn until
# release_studio_messages() delivers them, in order, through the page's own seam.
hold_studio_messages <- function(app) {
  checkmate::assert_r6(app, "AppDriver")
  app$run_js(sprintf(
    "window.__sms = window.__sms || {}; window.__sms.held = [];
     window.__sms.holder = (e) => { e.preventDefault(); window.__sms.held.push(e.detail); };
     %s.addEventListener('stagemap-studio:message', window.__sms.holder);",
    studio_root_js
  ))
  invisible(app)
}

# Lets the held messages through, in order, or with `reverse = TRUE` last to first (answers that arrive out of order).
release_studio_messages <- function(app, reverse = FALSE) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_flag(reverse)
  app$run_js(sprintf(
    "{ const r = %s; r.removeEventListener('stagemap-studio:message', window.__sms.holder);
       const held = window.__sms.held.splice(0); if (%s) held.reverse();
       for (const m of held) r.dispatchEvent(new CustomEvent('stagemap-studio:deliver', { detail: m })); }",
    studio_root_js,
    tolower(reverse)
  ))
  invisible(app)
}

# Waits until at least `n` held `"events"` or `"messages"` have been recorded.
wait_studio_held <- function(app, what, n = 1L) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_choice(what, c("events", "messages"))
  checkmate::assert_count(n, positive = TRUE)
  field <- if (identical(what, "events")) "heldEvents" else "held"
  app$wait_for_js(sprintf("(window.__sms?.%s?.length ?? 0) >= %d", field, as.integer(n)))
  invisible(app)
}

# Waits until the server has answered the event `seq` with a message the page holds (hold_studio_messages()).
studio_wait_held <- function(app, seq) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_count(seq, positive = TRUE)
  app$wait_for_js(sprintf("window.__sms.held.some((m) => m.ack >= %d)", as.integer(seq)))
  invisible(app)
}

# Replaces the clipboard API in the page with recorders: what Copy writes lands in window.__sms.copied as
# `{path, text}`, and window.__sms.begun counts the ClipboardItem writes that have been started, whether or not their
# text has come yet (it is raised in the call itself, so a test reads it in the click's own JavaScript to show the write
# starts inside the click). `item` keeps ClipboardItem with a write() that reads the item's promised text; `text` gives
# a writeText() that records (FALSE: one that refuses); `exec` gives a copy command that records the selected text of
# the text area (FALSE: one that fails).
stub_studio_clipboard <- function(app, item = TRUE, text = TRUE, exec = TRUE) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_flag(item)
  checkmate::assert_flag(text)
  checkmate::assert_flag(exec)
  app$run_js(sprintf(
    "window.__sms = window.__sms || {}; window.__sms.copied = []; window.__sms.begun = 0;
     const item = %s, text = %s, exec = %s;
     const record = (path, value) => window.__sms.copied.push({ path, text: value });
     if (!item) delete window.ClipboardItem;
     Object.defineProperty(navigator, 'clipboard', { configurable: true, value: {
       write: async (items) => { window.__sms.begun += 1; const blob = await items[0].getType('text/plain'); record('item', await blob.text()); },
       writeText: async (value) => { if (!text) throw new DOMException('refused', 'NotAllowedError'); record('text', value); }
     } });
     document.execCommand = (command) => {
       if (!exec || command !== 'copy') return false;
       const a = document.activeElement; record('exec', a.value.slice(a.selectionStart, a.selectionEnd)); return true;
     };",
    tolower(item),
    tolower(text),
    tolower(exec)
  ))
  invisible(app)
}

# What the clipboard stubs recorded, as a list of `list(path, text)`.
studio_copied <- function(app) {
  checkmate::assert_r6(app, "AppDriver")
  jsonlite::fromJSON(app$get_js("JSON.stringify(window.__sms.copied)"), simplifyVector = FALSE)
}

# Clicks Copy (clearing the way the last copy went first) as JavaScript, for one run_js() with what comes before it.
studio_copy_js <- paste(
  "{ const b = document.querySelector('[data-sms-copy]'); delete b.dataset.smsCopied; b.click(); }"
)

# Waits until the last Copy has finished, and returns the way it went (item, text, exec, manual or late).
studio_wait_copy <- function(app) {
  checkmate::assert_r6(app, "AppDriver")
  app$run_js("window.__smsLastCopy = null;")
  app$wait_for_js(
    "(() => { const b = document.querySelector('[data-sms-copy]');
      const done = b.dataset.smsCopied !== undefined && b.getAttribute('aria-busy') !== 'true';
      if (done) window.__smsLastCopy = b.dataset.smsCopied;
      return done; })()"
  )
  app$get_js("window.__smsLastCopy")
}

# Opens the R code room with its button and waits until it is open and the tray has finished sliding up (its computed
# transform is "none" only once the transition is over), so a click at a point lands where it is aimed.
studio_open_code <- function(app) {
  checkmate::assert_r6(app, "AppDriver")
  click_now(app, "[data-sms-room='code']")
  app$wait_for_js(
    "document.querySelector('[data-sms-room-of=\"code\"]').hidden === false &&
     getComputedStyle(document.querySelector('.sms-tray')).transform === 'none'"
  )
  invisible(app)
}

# The console errors and uncaught exceptions of the page so far, as text.
studio_console <- function(app) {
  checkmate::assert_r6(app, "AppDriver")
  logs <- as.data.frame(app$get_logs())
  page <- logs[logs$location == "chromote", , drop = FALSE]
  page$message[page$level %in% c("error", "throw") | grepl("Uncaught|exception", page$message)]
}

# Expects the page to be clean: no console error, nothing busy, nothing inert that is shown (a closed room is
# hidden as well as inert), and focus is inside the page (not inside a hidden or inert container). After Done
# (`closed = TRUE`) the sheet, the tray and the title block are inert on purpose. Console lines that match the regular
# expression `ignore` are left out (a test says why).
expect_studio_clean <- function(app, closed = FALSE, ignore = NULL) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_flag(closed)
  checkmate::assert_string(ignore, null.ok = TRUE)
  console <- studio_console(app)
  if (!is.null(ignore)) {
    console <- console[!grepl(ignore, console)]
  }
  testthat::expect_identical(console, character())
  state <- app$get_js(sprintf(
    "(() => { const r = %s; const shown = (n) => !n.closest('[hidden]');
      const closed = %s;
      const a = document.activeElement;
      const focus_ok = a !== null && a.isConnected &&
        (a === document.body || (!a.closest('[hidden]') && (!a.closest('[inert]') || closed)));
      return { busy: r.hasAttribute('aria-busy') || r.querySelector('[aria-busy=\"true\"]') !== null,
               focus_ok,
               inert: [...r.querySelectorAll('[inert]')].filter((n) => shown(n) &&
                 !(n.matches('.sms-tray') && (closed || r.dataset.smsTray === undefined)) &&
                 !(closed && n.matches('.sms-sheet, .sms-block'))).map((n) => n.className) }; })()",
    studio_root_js,
    tolower(closed)
  ))
  testthat::expect_false(state$busy)
  testthat::expect_true(state$focus_ok)
  testthat::expect_length(state$inert, 0L)
  invisible(app)
}

# Reads the live counts of listeners, observers, pending timers and DOM nodes from the page shim.
studio_counts <- function(app) {
  checkmate::assert_r6(app, "AppDriver")
  counts <- app$get_js("window.__smsCounts()")
  list(
    listeners = as.integer(counts$listeners),
    observers = as.integer(counts$observers),
    timers = as.integer(counts$timers),
    nodes = as.integer(counts$nodes)
  )
}
