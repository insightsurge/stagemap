skip_without_chrome()

# The studio in a real browser (tests/testthat/apps/studio/app.R): the page and the server keep in step through the
# one event input and the one message, typed text is held and then sent once, and Copy and Done act on the server's
# answer to everything sent before them, also when the action comes at once after the change. Every test ends with
# expect_studio_clean(). The clipboard is the page's own only in the test that grants it; the others replace it with
# recorders (stub_studio_clipboard()), which show what Copy wrote and which way it went.

title_js <- function(text) studio_type_js(".sms-title", text)

# Types `text` as the title and leaves the field, so the text goes out at once; returns the seq of that send.
title_sent <- function(app, text) {
  app$get_js(sprintf(
    "(() => { %s; document.querySelector('.sms-title').blur(); return Number(%s.dataset.smsSent); })()",
    title_js(text),
    studio_root_js
  ))
}

# The contrast ratio between two colours of the toast (its border and its background, or its mark and its background),
# as the browser computes them, in the theme the page has.
toast_contrast_js <- "(() => {
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

describe("the studio page", {
  it("opens, draws the map and the server's first message, and is not busy", {
    app <- studio_driver()
    state <- app$get_js(sprintf(
      "(() => { const r = %s; return { ack: r.dataset.smsAck, n: r.dataset.smsN, rev: r.dataset.smsRev,
        title: r.querySelector('.sms-title').value, facts: r.querySelector('.sms-facts').textContent,
        code: r.querySelector('.sms-code').textContent, count: r.querySelector('.sms-code-count').textContent,
        cards: r.querySelectorAll('[data-card]').length, busy: r.getAttribute('aria-busy') }; })()",
      studio_root_js
    ))
    expect_identical(state$ack, "1")
    expect_identical(state$n, "1")
    expect_identical(state$rev, "0")
    expect_identical(state$title, "A small piece of work")
    expect_identical(state$facts, "4 cards in 3 stages and 2 lanes")
    expect_match(state$code, "A small piece of work", fixed = TRUE)
    expect_identical(state$count, "1 line")
    expect_identical(state$cards, 4L)
    expect_null(state$busy)
    expect_studio_clean(app)
  })

  it("opens on the example map when it is given none", {
    app <- studio_driver("none")
    expect_identical(app$get_js("document.querySelectorAll('[data-card]').length"), 13L)
    expect_identical(app$get_js("document.querySelector('.sms-title').value"), "Dose calculator validation")
    expect_studio_clean(app)
  })
})

describe("typing a title", {
  it("is held, then sent once, and the field is not overwritten while it has focus", {
    # Given a page that records what it sends
    app <- studio_driver()
    record_studio_events(app)
    # When a title is typed, one character at a time
    app$run_js(title_js("Plan B"))
    held <- app$get_js("document.querySelector('.sms-title').dataset.smsSeq")
    studio_wait_step(app)
    # Then it was held, and went out once, with the whole title
    expect_identical(held, "Infinity")
    sent <- studio_sent(app)
    expect_length(sent, 1L)
    expect_identical(sent[[1]]$type, "option")
    expect_identical(sent[[1]]$data, list(name = "title", value = "Plan B"))
    expect_identical(app$get_js("document.querySelector('.sms-map-name').textContent"), "Plan B")
    expect_identical(app$get_js("document.querySelector('.sms').dataset.smsRev"), "1")
    # When a newer message with another title arrives while the field has focus
    app$run_js(sprintf(
      "{ const r = %s; r.dispatchEvent(new CustomEvent('stagemap-studio:deliver', { detail: {
          ns: r.dataset.smsNs, n: Number(r.dataset.smsN) + 0.5, ack: Number(r.dataset.smsAck), rev: 1,
          sections: { header: { title: 'Other', facts: '', template: null } } } })); }",
      studio_root_js
    ))
    # Then the field keeps what was typed, while the title block shows the message
    expect_true(app$get_js("document.activeElement.classList.contains('sms-title')"))
    expect_identical(app$get_js("document.querySelector('.sms-title').value"), "Plan B")
    expect_identical(app$get_js("document.querySelector('.sms-map-name').textContent"), "Other")
    expect_studio_clean(app)
  })

  it("puts the server's title back when a blank title is refused, and says why", {
    app <- studio_driver()
    studio_do(app, paste(title_js(""), "document.querySelector('.sms-title').blur();"))
    app$wait_for_js("document.querySelector('.sms-title').value === 'A small piece of work'")
    expect_match(app$get_js("document.querySelector('.sms-toast-text').textContent"), "cannot be blank")
    expect_identical(app$get_js("document.querySelector('.sms-toast').dataset.smsTone"), "problem")
    # The tone is not the colour alone: the word and a mark show beside the text
    expect_identical(app$get_js("document.querySelector('.sms-toast-tone').textContent"), "Problem")
    expect_identical(app$get_js("getComputedStyle(document.querySelector('.sms-toast-mark')).display"), "grid")
    expect_identical(app$get_js(sprintf("%s.dataset.smsRev", studio_root_js)), "0")
    expect_studio_clean(app)
  })
})

describe("Copy", {
  it("copies at once what the code room shows when the page is in step (the page's own clipboard)", {
    # Given the page's own clipboard, allowed for this page, and a focused page
    app <- studio_driver()
    session <- app$get_chromote_session()
    session$Browser$grantPermissions(
      permissions = list("clipboardReadWrite", "clipboardSanitizedWrite"),
      origin = sub("^(https?://[^/]+).*$", "\\1", app$get_url())
    )
    session$Emulation$setFocusEmulationEnabled(enabled = TRUE)
    studio_open_code(app)
    # When Copy is clicked with the mouse
    studio_click_real(app, "[data-sms-copy]")
    path <- studio_wait_copy(app)
    # Then the clipboard holds the code the room shows, written through a ClipboardItem
    expect_identical(path, "item")
    shown <- app$get_js("document.querySelector('.sms-code').textContent")
    expect_identical(app$get_js("navigator.clipboard.readText()"), shown)
    expect_identical(app$get_js("document.querySelector('.sms-toast-text').textContent"), "Copied the R code.")
    expect_studio_clean(app)
  })

  it("copies the title typed just before it, when both happen at once", {
    app <- studio_driver()
    studio_open_code(app)
    stub_studio_clipboard(app)
    # When a title is typed and Copy clicked in one go, before the server has seen the title
    app$run_js(paste(title_js("Typed then copied"), studio_copy_js))
    # Then the copy has the typed title
    expect_identical(studio_wait_copy(app), "item")
    copied <- studio_copied(app)
    expect_length(copied, 1L)
    studio_wait_step(app)
    # and it is the whole code the server drew for that title, not the title field's text or an older code
    shown <- app$get_js("document.querySelector('.sms-code').textContent")
    expect_identical(copied[[1]]$text, shown)
    expect_match(shown, "Typed then copied", fixed = TRUE)
    expect_false(identical(copied[[1]]$text, "Typed then copied"))
    expect_studio_clean(app)
  })

  it("stays busy while the server's answer is held, then copies the new text", {
    app <- studio_driver()
    studio_open_code(app)
    stub_studio_clipboard(app)
    hold_studio_messages(app)
    # When a title is typed and Copy clicked at once, and the server's answers are held
    # (the count of clipboard writes begun is read in the same call, as the click returns)
    started <- app$get_js(paste(
      title_js("Held answer"),
      studio_copy_js,
      "({ begun: window.__sms.begun, sent: Number(document.querySelector('.sms').dataset.smsSent) })"
    ))
    sent <- started$sent
    studio_wait_held(app, sent)
    # Then the write began inside the click, with the text still to come, and Copy is busy with nothing copied yet
    expect_identical(started$begun, 1L)
    expect_identical(app$get_js("document.querySelector('[data-sms-copy]').getAttribute('aria-busy')"), "true")
    expect_identical(app$get_js("document.querySelector('[data-sms-copy]').getAttribute('aria-disabled')"), "true")
    expect_length(studio_copied(app), 0L)
    # When the answers are let through
    release_studio_messages(app)
    # Then the copy has the new title and Copy is no longer busy
    expect_identical(studio_wait_copy(app), "item")
    studio_wait_step(app)
    shown <- app$get_js("document.querySelector('.sms-code').textContent")
    expect_identical(studio_copied(app)[[1]]$text, shown)
    expect_match(shown, "Held answer", fixed = TRUE)
    expect_null(app$get_js("document.querySelector('[data-sms-copy]').getAttribute('aria-busy')"))
    studio_wait_step(app)
    expect_studio_clean(app)
  })

  it("uses writeText() without ClipboardItem, the copy command when that is refused, and asks for Ctrl+C last", {
    app <- studio_driver()
    studio_open_code(app)
    shown <- app$get_js("document.querySelector('.sms-code').textContent")
    # Without ClipboardItem
    stub_studio_clipboard(app, item = FALSE)
    app$run_js(studio_copy_js)
    expect_identical(studio_wait_copy(app), "text")
    expect_identical(studio_copied(app), list(list(path = "text", text = shown)))
    # Without ClipboardItem, and writeText() refused
    stub_studio_clipboard(app, item = FALSE, text = FALSE)
    app$run_js(studio_copy_js)
    expect_identical(studio_wait_copy(app), "exec")
    expect_identical(studio_copied(app), list(list(path = "exec", text = shown)))
    expect_identical(app$get_js("document.querySelectorAll('.sms-copy-area').length"), 0L)
    # With every way refused, the code is selected and the page says how to copy it
    stub_studio_clipboard(app, item = FALSE, text = FALSE, exec = FALSE)
    app$run_js(studio_copy_js)
    expect_identical(studio_wait_copy(app), "manual")
    expect_length(studio_copied(app), 0L)
    expect_identical(app$get_js("window.getSelection().toString()"), shown)
    expect_match(app$get_js("document.querySelector('.sms-toast-text').textContent"), "press Ctrl+C", fixed = TRUE)
    expect_studio_clean(app)
  })

  it("says it could not copy, and is not busy, when the answer is held longer than Copy waits", {
    app <- studio_driver(copy_wait_ms = 300L)
    studio_open_code(app)
    stub_studio_clipboard(app)
    hold_studio_messages(app)
    app$run_js(paste(title_js("Too late"), studio_copy_js))
    expect_identical(studio_wait_copy(app), "late")
    expect_length(studio_copied(app), 0L)
    expect_match(app$get_js("document.querySelector('.sms-toast-text').textContent"), "did not answer in time")
    expect_null(app$get_js("document.querySelector('[data-sms-copy]').getAttribute('aria-busy')"))
    release_studio_messages(app)
    studio_wait_step(app)
    expect_studio_clean(app)
  })
})

describe("Done", {
  it("returns the map with the title typed just before it, when both happen at once, and shows the closed state", {
    app <- studio_driver()
    app$run_js(paste(title_js("Done at once"), studio_click_js(".sms-done")))
    app$wait_for_js(sprintf(
      "%s.dataset.smsClosed !== undefined && document.getElementById('done').textContent !== ''",
      studio_root_js
    ))
    done <- jsonlite::fromJSON(app$get_js("document.getElementById('done').textContent"))
    expect_true("stagemap_widget" %in% done$class)
    expect_identical(done$title, "Done at once")
    expect_match(app$get_js("document.querySelector('.sms-closed').textContent"), "gone back to R", fixed = TRUE)
    expect_true(app$get_js("document.querySelector('.sms-block').inert"))
    studio_wait_step(app)
    expect_studio_clean(app, closed = TRUE)
  })
})

describe("Done with the server's answers held", {
  it("stays busy and does not close the page until its own answer is drawn", {
    app <- studio_driver()
    hold_studio_messages(app)
    # When a title is typed and Done clicked at once, and the server's answers are held
    sent <- app$get_js(paste(
      title_js("Held Done"),
      studio_click_js(".sms-done"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, sent)
    # Then Done is busy and the page is not closed, while R already has the map with the typed title
    expect_identical(app$get_js("document.querySelector('.sms-done').getAttribute('aria-busy')"), "true")
    expect_identical(app$get_js("document.querySelector('.sms-done').getAttribute('aria-disabled')"), "true")
    expect_null(app$get_js(sprintf("%s.dataset.smsClosed", studio_root_js)))
    app$wait_for_js("document.getElementById('done').textContent !== ''")
    expect_identical(jsonlite::fromJSON(app$get_js("document.getElementById('done').textContent"))$title, "Held Done")
    # When the answers are let through, the page shows the closed state and Done is no longer busy
    release_studio_messages(app)
    app$wait_for_js(sprintf("%s.dataset.smsClosed !== undefined", studio_root_js))
    expect_null(app$get_js("document.querySelector('.sms-done').getAttribute('aria-busy')"))
    studio_wait_step(app)
    expect_studio_clean(app, closed = TRUE)
  })
})

describe("the rooms", {
  it("open and close by their button and by Escape, give focus back to the button, and are inert when closed", {
    app <- studio_driver()
    room <- "document.querySelector('[data-sms-room-of=\"code\"]')"
    button <- "document.querySelector('[data-sms-room=\"code\"]')"
    state <- function() {
      app$get_js(sprintf(
        "({ hidden: %s.hidden, inert: %s.inert, expanded: %s.getAttribute('aria-expanded'),
            tray: document.querySelector('.sms-tray').inert, focus: document.activeElement === %s })",
        room,
        room,
        button,
        button
      ))
    }
    # Closed at the start
    expect_identical(
      state()[c("hidden", "inert", "expanded", "tray")],
      list(hidden = TRUE, inert = TRUE, expanded = "false", tray = TRUE)
    )
    # Its button opens it, and focus goes to the room's heading, ahead of its first control
    studio_open_code(app)
    expect_identical(
      state()[c("hidden", "inert", "expanded", "tray")],
      list(hidden = FALSE, inert = FALSE, expanded = "true", tray = FALSE)
    )
    expect_identical(app$get_js("document.activeElement.id"), "studio-room-code-title")
    # Its Close button closes it and puts focus on the room's button
    click_now(app, "[data-sms-close='code']")
    expect_identical(state(), list(hidden = TRUE, inert = TRUE, expanded = "false", tray = TRUE, focus = TRUE))
    # Escape closes it from inside the room, and focus goes back to the button
    studio_open_code(app)
    app$run_js("document.querySelector('[data-sms-copy]').focus()")
    studio_press(app, "Escape", key_code = 27L)
    app$wait_for_js(sprintf("%s.hidden === true", room))
    expect_identical(state(), list(hidden = TRUE, inert = TRUE, expanded = "false", tray = TRUE, focus = TRUE))
    # Escape with focus in the title field closes it too, and leaves focus in the field
    studio_open_code(app)
    app$run_js("document.querySelector('.sms-title').focus()")
    studio_press(app, "Escape", key_code = 27L)
    app$wait_for_js(sprintf("%s.hidden === true", room))
    expect_identical(app$get_js("document.activeElement.className"), "sms-title")
    expect_studio_clean(app)
  })
})

describe("the theme and motion", {
  it("changes a card's colour in dark, and leaves no transition on the tray when motion is reduced", {
    app <- studio_driver()
    # The card's own colour hook (what its face is painted with) and its text colour
    card <- "(() => { const s = getComputedStyle(document.querySelector('[data-card]'));
      return s.getPropertyValue('--stagemap-card').trim() + ' ' + s.color; })()"
    light <- app$get_js(card)
    click_now(app, ".sms-theme")
    app$wait_for_js(sprintf("%s.dataset.theme === 'dark'", studio_root_js))
    expect_identical(app$get_js("document.documentElement.dataset.bsTheme"), "dark")
    expect_identical(app$get_js("document.querySelector('.sms-theme').getAttribute('aria-checked')"), "true")
    expect_false(identical(app$get_js(card), light))
    # Back to light, kept for the next page
    click_now(app, ".sms-theme")
    app$wait_for_js(sprintf("%s.dataset.theme === 'light'", studio_root_js))
    expect_identical(app$get_js(card), light)
    expect_identical(app$get_js("localStorage.getItem('stagemap-studio-theme')"), "light")
    # Reduced motion
    expect_identical(
      app$get_js("getComputedStyle(document.querySelector('.sms-tray')).transitionDuration") == "0s",
      FALSE
    )
    studio_emulate(app, "prefers-reduced-motion", "reduce")
    expect_true(app$get_js("matchMedia('(prefers-reduced-motion: reduce)').matches"))
    durations <- app$get_js("getComputedStyle(document.querySelector('.sms-tray')).transitionDuration")
    expect_true(all(trimws(strsplit(durations, ",")[[1]]) == "0s"))
    expect_studio_clean(app)
  })
})

describe("answers that arrive late", {
  it("cannot undo a newer answer: the one for the older event arrives after the one for the newer", {
    # Given two titles sent one after the other, with the server's answers held
    app <- studio_driver()
    hold_studio_messages(app)
    first <- title_sent(app, "Older title")
    studio_wait_held(app, first)
    second <- title_sent(app, "Newer title")
    studio_wait_held(app, second)
    # When the answers are let through, the newer one first
    release_studio_messages(app, reverse = TRUE)
    studio_wait_step(app)
    # Then the page shows the newer answer, and its count and ack did not go down
    expect_identical(app$get_js(sprintf("%s.dataset.smsN", studio_root_js)), "3")
    expect_identical(app$get_js(sprintf("%s.dataset.smsAck", studio_root_js)), as.character(second))
    expect_match(app$get_js("document.querySelector('.sms-code').textContent"), "Newer title", fixed = TRUE)
    expect_false(grepl("Older title", app$get_js("document.querySelector('.sms-code').textContent"), fixed = TRUE))
    expect_identical(app$get_js("document.querySelector('.sms-map-name').textContent"), "Newer title")
    expect_studio_clean(app)
  })
})

describe("a reconnect", {
  it("sends ready first and, after Shiny has set up the session, what was done while the connection was down", {
    # Given a page that notes what it sends over the websocket, in the order it leaves
    app <- studio_driver()
    studio_open_code(app)
    stub_studio_clipboard(app)
    record_studio_wire(app)
    drop_studio_connection(app)
    # When a title is typed, Copy clicked and Done clicked while it is down, and the page then reconnects
    app$run_js(paste(title_js("Typed while down"), studio_copy_js, studio_click_js(".sms-done")))
    expect_identical(app$get_js("window.__sms.wire.length"), 0L)
    reconnect_studio(app)
    app$wait_for_js(sprintf(
      "%s.dataset.smsClosed !== undefined && document.getElementById('done').textContent !== ''",
      studio_root_js
    ))
    # Then Shiny's own init went first, and ready came after it, ahead of what was typed, each with a higher seq
    wire <- unlist(app$get_js("window.__sms.wire"))
    expect_match(wire, "^(init|post (ready|option|done) [0-9]+)$")
    expect_identical(sub("^post ([a-z]+) .*$", "\\1", wire), c("init", "ready", "option", "done"))
    seqs <- as.integer(sub("^post [a-z]+ ([0-9]+)$", "\\1", wire[-1]))
    expect_true(all(diff(seqs) > 0L))
    # and the new session applied it all in order: Done returned the typed title, and Copy has the code for it
    done <- jsonlite::fromJSON(app$get_js("document.getElementById('done').textContent"))
    expect_identical(done$title, "Typed while down")
    expect_identical(studio_wait_copy(app), "item")
    shown <- app$get_js("document.querySelector('.sms-code').textContent")
    expect_identical(studio_copied(app)[[1]]$text, shown)
    expect_match(shown, "Typed while down", fixed = TRUE)
    studio_wait_step(app)
    # Shiny's own page refuses a new session's outputs after a manual reconnect and says so in the console; nothing
    # else may be in it
    expect_studio_clean(app, closed = TRUE, ignore = "unexpected state of")
  })
})

describe("the focus ring and the toast", {
  it("keep a visible outline in forced-colors mode", {
    app <- studio_driver()
    studio_emulate(app, "forced-colors", "active")
    studio_press(app, "Tab", code = "Tab", key_code = 9L)
    for (selector in c(".sms-skip", ".sms-title", "[data-sms-room='code']", ".sms-theme", ".sms-done")) {
      app$run_js(sprintf("document.querySelector(%s).focus()", jsonlite::toJSON(selector, auto_unbox = TRUE)))
      state <- app$get_js(
        "(() => { const a = document.activeElement, s = getComputedStyle(a);
           return { visible: a.matches(':focus-visible'), style: s.outlineStyle, width: s.outlineWidth }; })()"
      )
      expect_true(state$visible, info = selector)
      expect_false(state$style == "none", info = selector)
      expect_false(state$width == "0px", info = selector)
    }
    expect_studio_clean(app)
  })

  it("draw a problem's edge and mark with 3:1 against the toast, in light and in dark", {
    app <- studio_driver()
    light <- app$get_js(toast_contrast_js)
    click_now(app, ".sms-theme")
    app$wait_for_js(sprintf("%s.dataset.theme === 'dark'", studio_root_js))
    dark <- app$get_js(toast_contrast_js)
    expect_gte(light$edge, 3)
    expect_gte(light$mark, 3)
    expect_gte(dark$edge, 3)
    expect_gte(dark$mark, 3)
  })
})

describe("a page reload", {
  it("starts a fresh session on the given map and draws it with no error", {
    app <- studio_driver()
    studio_do(app, paste(title_js("Changed before the reload"), "document.querySelector('.sms-title').blur();"))
    app$run_js("window.__smsBefore = true; location.reload();")
    app$wait_for_js("window.__smsBefore === undefined")
    studio_wait_drawn(app)
    expect_identical(app$get_js("document.querySelector('.sms-title').value"), "A small piece of work")
    expect_identical(app$get_js(sprintf("%s.dataset.smsAck", studio_root_js)), "1")
    expect_studio_clean(app)
  })
})
