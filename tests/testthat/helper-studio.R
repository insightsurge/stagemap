# Helpers for the studio's tests. The browser helpers drive tests/testthat/apps/studio/app.R and wait on the page's own
# state (the root's data-sms-ack, data-sms-sent and aria-busy), never for a fixed time. They reach the page only
# through its DOM and its three seams (the stagemap-studio:send, :message and :deliver events on the root); what a
# helper keeps in the page lives under window.__sms, a name the studio's own script never uses.

# The studio's root, as JavaScript.
studio_root_js <- "document.querySelector('.sms')"

# Starts the studio app on the map `fixture` ("small" or "none") and waits until the page has drawn the server's first
# message and the map. `copy_wait_ms` is Copy's wait (the app's default when NULL); `...` goes to AppDriver$new().
studio_driver <- function(fixture = "small", copy_wait_ms = NULL, ..., env = parent.frame()) {
  checkmate::assert_choice(fixture, c("small", "none"))
  checkmate::assert_count(copy_wait_ms, positive = TRUE, null.ok = TRUE)
  checkmate::assert_environment(env)
  withr::local_envvar(
    STAGEMAP_STUDIO_FIXTURE = fixture,
    STAGEMAP_STUDIO_COPY_WAIT_MS = if (is.null(copy_wait_ms)) NA else as.character(copy_wait_ms)
  )
  app <- app_driver(testthat::test_path("apps", "studio"), ..., env = env)
  studio_wait_drawn(app)
  app
}

# Waits until the page has drawn a message from the server and the map has drawn its cards, with nothing pending.
studio_wait_drawn <- function(app) {
  checkmate::assert_r6(app, "AppDriver")
  app$wait_for_js(sprintf(
    "(() => { const r = %s; return r !== null && r.dataset.smsAck !== undefined &&
      !r.hasAttribute('aria-busy') && r.querySelectorAll('[data-card]').length > 0; })()",
    studio_root_js
  ))
  invisible(app)
}

# Waits until the page and the server are in step: no text is held, the server has acknowledged everything the page
# sent, and the root is not busy. Returns the acknowledged seq.
studio_wait_step <- function(app) {
  checkmate::assert_r6(app, "AppDriver")
  app$wait_for_js(sprintf(
    "(() => { const r = %s; return r.querySelector('[data-sms-wait]') === null &&
      Number(r.dataset.smsAck) >= Number(r.dataset.smsSent) && !r.hasAttribute('aria-busy'); })()",
    studio_root_js
  ))
  as.integer(app$get_js(sprintf("Number(%s.dataset.smsAck)", studio_root_js)))
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

# JavaScript that types `text` into the field `selector` as a person does: focus, select all and delete it (one input
# event), then one input event per character. Returned as text, so a test can put it in one run_js() call with the action that follows.
studio_type_js <- function(selector, text) {
  checkmate::assert_string(selector, min.chars = 1L)
  checkmate::assert_string(text)
  sprintf(
    "{ const f = document.querySelector(%s); f.focus(); f.select(); f.value = '';
       f.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'deleteContentBackward' }));
       for (const ch of %s) { f.value += ch; f.dispatchEvent(new InputEvent('input', { bubbles: true, data: ch, inputType: 'insertText' })); } }",
    jsonlite::toJSON(selector, auto_unbox = TRUE),
    jsonlite::toJSON(text, auto_unbox = TRUE)
  )
}

# JavaScript that clicks the element `selector` (a synthetic click, as click_now() makes).
studio_click_js <- function(selector) {
  checkmate::assert_string(selector, min.chars = 1L)
  sprintf("document.querySelector(%s).click();", jsonlite::toJSON(selector, auto_unbox = TRUE))
}

# A real key press (keyDown, then keyUp) through the browser's input domain, sent to the element with focus.
studio_press <- function(app, key, code = key, key_code = 0L) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_string(key, min.chars = 1L)
  checkmate::assert_string(code, min.chars = 1L)
  checkmate::assert_count(key_code)
  session <- app$get_chromote_session()
  for (type in c("keyDown", "keyUp")) {
    session$Input$dispatchKeyEvent(type = type, key = key, code = code, windowsVirtualKeyCode = key_code)
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

# Sets a media feature of the page, such as ("prefers-reduced-motion", "reduce").
studio_emulate <- function(app, feature, value) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_string(feature, min.chars = 1L)
  checkmate::assert_string(value)
  app$get_chromote_session()$Emulation$setEmulatedMedia(features = list(list(name = feature, value = value)))
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
# starts inside the click). `item` keeps ClipboardItem with a write() that reads the item's promised text; `text` gives a
# writeText() that records (FALSE: one that refuses); `exec` gives a copy command that records the selected text of the
# text area (FALSE: one that fails).
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
  app$wait_for_js(
    "(() => { const b = document.querySelector('[data-sms-copy]');
      return b.dataset.smsCopied !== undefined && b.getAttribute('aria-busy') !== 'true'; })()"
  )
  app$get_js("document.querySelector('[data-sms-copy]').dataset.smsCopied")
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

# Expects the page to be clean: no console error, nothing busy, and nothing inert that is shown (a closed room is
# hidden as well as inert). After Done (`closed = TRUE`) the sheet, the tray and the title block are inert on purpose.
# Console lines that match the regular expression `ignore` are left out (a test says why).
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
      return { busy: r.hasAttribute('aria-busy') || r.querySelector('[aria-busy=\"true\"]') !== null,
               inert: [...r.querySelectorAll('[inert]')].filter((n) => shown(n) &&
                 !(n.matches('.sms-tray') && (closed || r.dataset.smsTray === undefined)) &&
                 !(closed && n.matches('.sms-sheet, .sms-block'))).map((n) => n.className) }; })()",
    studio_root_js,
    tolower(closed)
  ))
  testthat::expect_false(state$busy)
  testthat::expect_length(state$inert, 0L)
  invisible(app)
}
