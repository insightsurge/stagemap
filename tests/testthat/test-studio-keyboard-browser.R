skip_without_chrome()

# Browser tests for the keyboard pass: the Tab order and its ring, picking a card and Undo and Escape by key, a walk
# through the whole studio with key events only, the order Escape closes layers in, and reduced motion. Every key is a
# real key event (studio_press()); nothing here clicks.

# A short description of the element with focus: its tag and class, what names it, whether it shows a ring, and where
# it is. `ring` is a box shadow or an outline the page gives a keyboard focus.
focus_js <- "(() => {
  const a = document.activeElement;
  const cs = getComputedStyle(a);
  const ring = (cs.boxShadow !== 'none') || (cs.outlineStyle !== 'none' && parseFloat(cs.outlineWidth) > 0 &&
    cs.outlineColor !== 'rgba(0, 0, 0, 0)');
  const name = a.getAttribute('aria-label') || a.dataset?.card || a.dataset?.smsRoom || a.textContent.trim().slice(0, 30);
  const where = a.closest('.sms-skip') ? 'skip' : a.closest('#studio-map') ? 'map' : a.closest('.sms-tray') ? 'tray' :
    a.closest('.sms-block') ? 'block' : a.closest('.sms-inspector') ? 'inspector' : a.closest('.sms-hint') ? 'hint' :
    a.closest('.sms-top') ? 'top' : a.closest('.sms') ? 'sheet' : 'outside';
  return JSON.stringify({ tag: a.tagName, cls: String(a.getAttribute('class') ?? ''), name, ring, where, id: a.id,
    visible: a.matches(':focus-visible') });
})()"

focus_now <- function(app) {
  jsonlite::fromJSON(app$get_js(focus_js), simplifyVector = FALSE)
}

# Presses Tab (or Shift+Tab) until the focus is on an element that matches `selector`, at most `max` times; the test
# fails when it is not reached, which is how a trap or a missing stop shows. Returns how many presses it took.
tab_to <- function(app, selector, max = 40L, back = FALSE) {
  for (i in seq_len(max)) {
    if (isTRUE(app$get_js(sprintf("document.activeElement.matches(%s)", jsonlite::toJSON(selector, auto_unbox = TRUE))))) {
      return(i - 1L)
    }
    studio_press(app, "Tab", modifiers = if (back) "shift" else character())
  }
  testthat::fail(sprintf("Tab did not reach %s in %d presses; focus is on %s", selector, max, focus_now(app)$name))
  max
}

open_example_by_key <- function(app) {
  studio_press(app, "Enter")
  app$wait_for_js("document.querySelector('.sms-start').hidden === true")
  studio_wait_step(app)
  invisible(app)
}

describe("the studio from the keyboard", {
  it("[SMS-081] visits every control in page order with a ring, leaves the page at the end and has no trap", {
    app <- studio_driver("none")
    open_example_by_key(app)
    expect_identical(focus_now(app)$cls, "sms-title")

    # Back to the start of the page, then forward through all of it
    studio_press(app, "Tab", modifiers = "shift")
    first <- focus_now(app)
    expect_identical(first$where, "skip")
    expect_true(first$ring)

    seen <- list()
    for (i in 1:60) {
      studio_press(app, "Tab")
      now <- focus_now(app)
      if (identical(now$tag, "BODY") || identical(now$where, "skip")) {
        break
      }
      seen[[length(seen) + 1L]] <- now
    }
    expect_lt(length(seen), 60L)
    where <- vapply(seen, function(s) s$where, character(1))
    # Page order: header, the map, the hint bar, then the title block; every stop of the studio's own shows a ring
    expect_identical(rle(where)$values, c("top", "map", "hint", "block"))
    own <- seen[where %in% c("top", "hint", "block")]
    expect_true(all(vapply(own, function(s) s$ring, logical(1))))
    expect_true(all(vapply(own, function(s) s$visible, logical(1))))
    names_block <- vapply(seen[where == "block"], function(s) s$name, character(1))
    expect_match(names_block, "^(map|ask|check|code|Theme, dark mode|Done)", all = FALSE)
    expect_length(names_block, 6L)
    expect_match(names_block[[6L]], "^Done")

    # One more Tab leaves the page or wraps to the skip link; none stays on the last control
    expect_false(identical(focus_now(app)$name, names_block[[6L]]))

    # With a room open, its controls come before the title block
    app$run_js("document.querySelector(\"[data-sms-room='code']\").focus()")
    studio_press(app, "Enter")
    app$wait_for_js("document.querySelector('[data-sms-room-of=\"code\"]').hidden === false")
    expect_identical(app$get_js("document.activeElement.tagName"), "H2")
    tab_to(app, "[data-sms-close='code']")
    expect_identical(focus_now(app)$where, "tray")
    tab_to(app, ".sms-block [data-sms-room='code']")
    expect_identical(focus_now(app)$where, "block")
    expect_studio_clean(app)
  })

  it("[SMS-082] picks a card by key, moves focus to its form, undoes with Ctrl+Z outside text and closes with Escape", {
    app <- studio_driver("small")
    # The skip link puts focus on the map's first stop
    app$run_js("document.querySelector('.sms-title').focus()")
    studio_press(app, "Tab", modifiers = "shift")
    expect_identical(focus_now(app)$where, "skip")
    studio_press(app, "Enter")
    expect_identical(focus_now(app)$where, "map")
    studio_press(app, "Tab")
    expect_identical(focus_now(app)$where, "map")

    # Enter on the card opens its form and focus goes to the form's heading
    app$run_js("document.querySelector('#studio-map [data-card=\"b\"]').focus()")
    studio_press(app, "Enter")
    app$wait_for_js("document.activeElement?.id === 'studio-inspector-title'")

    # Change the status with the arrow keys, then Ctrl+Z (focus is on a radio, not in text)
    app$run_js("document.querySelector('.sms-inspector [data-sms-field=\"status\"] input:checked').focus()")
    before <- app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"status\"] input:checked').value")
    since <- studio_stamp(app)
    studio_press(app, "ArrowRight")
    studio_wait_step(app)
    studio_wait_map(app, since)
    expect_false(identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"status\"] input:checked').value"),
      before
    ))
    since <- studio_stamp(app)
    studio_press(app, "z", modifiers = "ctrl")
    studio_wait_step(app)
    studio_wait_map(app, since)
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"status\"] input:checked').value"),
      before
    )
    expect_identical(app$get_js("document.querySelector('.sms-ev').dataset.smsState"), "undone")

    # Ctrl+Z in a text field is the field's own: nothing is sent
    record_studio_events(app)
    app$run_js("document.querySelector('.sms-inspector [data-sms-field=\"label\"] input').focus()")
    studio_press(app, "z", modifiers = "ctrl")
    expect_length(studio_sent(app), 0L)

    # Escape closes the form and focus goes back into the map
    studio_press(app, "Escape")
    app$wait_for_js("document.querySelector('.sms-inspector').hidden === true")
    expect_identical(focus_now(app)$where, "map")
    expect_studio_clean(app)
  })

  it("[SMS-086] walks the whole studio by key events only, with the focus where it should be after each step", {
    app <- studio_driver("none")
    stub_studio_clipboard(app)
    where <- function() focus_now(app)$where
    key <- function(k, ...) studio_press(app, k, ...)
    expect_pointer_free <- function() {
      expect_identical(app$get_js("window.__smsPointer ?? 0"), 0L)
    }
    app$run_js(
      "window.__smsPointer = 0; for (const t of ['pointerdown', 'mousedown', 'click']) document.addEventListener(t, (e) => { if (e.detail > 0 || e.pointerType) window.__smsPointer += 1; }, true);"
    )

    # Open the example: focus goes to the title
    open_example_by_key(app)
    expect_identical(focus_now(app)$cls, "sms-title")

    # Skip to the map and pick the card with Enter; the form's heading has focus
    key("Tab", modifiers = "shift")
    key("Enter")
    expect_identical(where(), "map")
    expect_identical(app$get_js("document.activeElement.dataset?.card ?? ''") != "", TRUE)
    key("Enter")
    app$wait_for_js("document.activeElement?.id === 'studio-inspector-title'")
    expect_identical(where(), "inspector")

    # Change its status with the keys
    tab_to(app, ".sms-inspector [data-sms-field='status'] input:checked")
    before <- app$get_js("document.activeElement.value")
    key("ArrowRight")
    studio_wait_step(app)
    expect_false(identical(app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"status\"] input:checked').value"), before))
    expect_identical(app$get_js("document.activeElement.name !== undefined && document.activeElement.type"), "radio")
    expect_identical(app$get_js("document.querySelectorAll('.sms-ev').length"), 1L)

    # Connect it to another card: the select, then the button
    tab_to(app, ".sms-inspector [data-sms-list='out'] [data-sms-field='to'] select")
    # A native select is changed by the browser's own keys, which differ by system; the page's part is what follows
    # the change, so the value is set on the control that Tab reached.
    to_before <- app$get_js("document.activeElement.value")
    app$run_js("{ const s = document.activeElement; s.selectedIndex = (s.selectedIndex + 1) % s.options.length; s.dispatchEvent(new Event('change', { bubbles: true })); }")
    expect_false(identical(app$get_js("document.activeElement.value"), to_before))
    tab_to(app, ".sms-inspector [data-sms-list='out'] [data-sms-action='Connect']")
    links_before <- studio_section(app, "header")$facts
    key("Enter")
    studio_wait_step(app)
    expect_false(identical(studio_section(app, "header")$facts, links_before))
    expect_identical(where(), "inspector")

    # Check: apply the fix (a question is refused while the map has a problem)
    tab_to(app, ".sms-block [data-sms-room='check']")
    key("Enter")
    app$wait_for_js("document.querySelector('[data-sms-room-of=\"check\"]').hidden === false")
    expect_identical(app$get_js("document.activeElement.tagName"), "H2")
    tab_to(app, "[data-sms-room-of='check'] .sms-btn.sms-pri")
    key("Enter")
    studio_wait_step(app)
    app$wait_for_js("document.querySelector('.sms-stamp').textContent === ''")
    expect_identical(app$get_js("document.activeElement.closest('[data-sms-room-of=\"check\"]') !== null"), TRUE)
    key("Escape")
    app$wait_for_js("document.querySelector('[data-sms-room-of=\"check\"]').hidden === true")
    expect_identical(app$get_js("document.activeElement.dataset.smsRoom"), "check")

    # R code: open, Copy
    tab_to(app, ".sms-block [data-sms-room='code']")
    key("Enter")
    app$wait_for_js("document.querySelector('[data-sms-room-of=\"code\"]').hidden === false")
    tab_to(app, "[data-sms-copy]")
    key("Enter")
    app$wait_for_js("window.__sms.copied.length === 1")
    expect_match(studio_copied(app)[[1L]]$text, "library(stagemap)", fixed = TRUE)
    expect_identical(app$get_js("document.activeElement.hasAttribute('data-sms-copy')"), TRUE)
    key("Escape")
    app$wait_for_js("document.querySelector('[data-sms-room-of=\"code\"]').hidden === true")
    expect_identical(app$get_js("document.activeElement.dataset.smsRoom"), "code")

    # Ask: run a trace
    tab_to(app, ".sms-block [data-sms-room='ask']", back = TRUE)
    key("Enter")
    app$wait_for_js("document.querySelector('[data-sms-room-of=\"ask\"]').hidden === false")
    tab_to(app, "[data-sms-q='trace'] button[data-sms-collect]")
    key("Enter")
    studio_wait_step(app)
    app$wait_for_js("document.querySelector('[data-sms-room-of=\"ask\"] .sms-ask-ans') !== null")
    expect_identical(where(), "tray")
    key("Escape")
    app$wait_for_js("document.querySelector('[data-sms-room-of=\"ask\"]').hidden === true")

    # Change the layout in the Map room
    tab_to(app, ".sms-block [data-sms-room='map']", back = TRUE)
    key("Enter")
    app$wait_for_js("document.querySelector('[data-sms-room-of=\"map\"]').hidden === false")
    tab_to(app, "[data-sms-room-of='map'] [data-sms-field='layout'] input:checked")
    since <- studio_stamp(app)
    key("ArrowRight")
    studio_wait_step(app)
    studio_wait_map(app, since)
    expect_identical(app$get_js("document.activeElement.type"), "radio")
    expect_match(studio_section(app, "journal")$text, "layout", fixed = TRUE)

    # Undo with Ctrl+Z from the radio, then close the room
    key("z", modifiers = "ctrl")
    studio_wait_step(app)
    expect_identical(app$get_js("[...document.querySelectorAll('.sms-ev')].at(-1).dataset.smsState"), "undone")
    expect_identical(app$get_js("document.activeElement.type"), "radio")
    key("Escape")
    app$wait_for_js("document.querySelector('[data-sms-room-of=\"map\"]').hidden === true")

    # Done
    tab_to(app, ".sms-done")
    key("Enter")
    app$wait_for_js(sprintf("%s.dataset.smsClosed !== undefined", studio_root_js))
    expect_match(app$get_js("document.getElementById('done_seen').textContent"), "stagemap_widget", fixed = TRUE)
    expect_pointer_free()
    expect_studio_clean(app, closed = TRUE)
  })

  it("[SMS-087] closes the topmost layer on each Escape and puts focus back on its opener", {
    app <- studio_driver("none")
    open_example_by_key(app)

    # A card's form (picked by key), an open room, the guide's list and the Stages menu, in that order
    app$run_js("document.querySelector('#studio-map [data-card=\"round_dose\"]').focus()")
    studio_press(app, "Enter")
    app$wait_for_js("document.activeElement?.id === 'studio-inspector-title'")
    app$run_js("document.querySelector(\"[data-sms-room='code']\").focus()")
    studio_press(app, "Enter")
    app$wait_for_js("document.querySelector('[data-sms-room-of=\"code\"]').hidden === false")
    app$run_js("document.querySelector('.sms-try-btn').focus()")
    studio_press(app, "Enter")
    app$run_js("document.querySelector(\"[data-sms-menu='stages']\").focus()")
    studio_press(app, "Enter")
    open <- function() {
      app$get_js(
        "JSON.stringify({ menu: !document.querySelector('.sms-menu-pop').hidden, guide: !document.querySelector('.sms-try').hidden,
           room: !document.querySelector('[data-sms-room-of=\"code\"]').hidden, form: !document.querySelector('.sms-inspector').hidden })"
      ) |> jsonlite::fromJSON()
    }
    expect_identical(unlist(open()), c(menu = TRUE, guide = TRUE, room = TRUE, form = TRUE))
    expect_identical(app$get_js("document.activeElement.getAttribute('role')"), "menuitem")

    # 1. The menu, and focus goes back to its button
    studio_press(app, "Escape")
    expect_identical(unlist(open()), c(menu = FALSE, guide = TRUE, room = TRUE, form = TRUE))
    expect_identical(app$get_js("document.activeElement.dataset.smsMenu"), "stages")

    # 2. The guide's list, with focus inside the bar
    app$run_js("document.querySelector('.sms-try-btn').focus()")
    studio_press(app, "Escape")
    expect_identical(unlist(open()), c(menu = FALSE, guide = FALSE, room = TRUE, form = TRUE))
    expect_identical(app$get_js("document.activeElement.className"), "sms-btn sms-try-btn")

    # 3. The room, with focus inside it: back on the button that opened it
    tab_to(app, "[data-sms-copy]", max = 80L, back = FALSE)
    studio_press(app, "Escape")
    app$wait_for_js("document.querySelector('[data-sms-room-of=\"code\"]').hidden === true")
    expect_identical(app$get_js("document.activeElement.dataset.smsRoom"), "code")
    expect_identical(unlist(open()), c(menu = FALSE, guide = FALSE, room = FALSE, form = TRUE))

    # 4. The form: focus goes back into the map
    app$run_js("document.querySelector('.sms-inspector [data-sms-field=\"label\"] input').focus()")
    studio_press(app, "Escape")
    app$wait_for_js("document.querySelector('.sms-inspector').hidden === true")
    expect_identical(focus_now(app)$where, "map")

    # Nothing is left to close: Escape changes nothing
    studio_press(app, "Escape")
    expect_identical(unlist(open()), c(menu = FALSE, guide = FALSE, room = FALSE, form = FALSE))
    expect_studio_clean(app)
  })

  it("[SMS-088] leaves the focus on a control when a menu closes with Tab, and moves between items with the arrows", {
    app <- studio_driver("small")
    app$run_js("document.querySelector(\"[data-sms-menu='stages']\").focus()")
    studio_press(app, "Enter")
    expect_identical(app$get_js("document.activeElement.getAttribute('role')"), "menuitem")
    expect_identical(app$get_js("[...document.querySelectorAll('#studio-menu-stages [role=menuitem]')].every((b) => b.tabIndex === -1)"), TRUE)
    studio_press(app, "ArrowDown")
    expect_identical(app$get_js("document.activeElement.dataset.smsUid !== undefined"), TRUE)
    studio_press(app, "End")
    studio_press(app, "Home")
    # Tab closes the menu and goes on from its button
    studio_press(app, "Tab")
    expect_true(app$get_js("document.querySelector('#studio-menu-stages').hidden"))
    expect_identical(app$get_js("document.querySelector(\"[data-sms-menu='stages']\").getAttribute('aria-expanded')"), "false")
    expect_identical(app$get_js("document.activeElement.dataset.smsMenu"), "lanes")
    expect_studio_clean(app)
  })

  it("[SMS-089] closes the CSV menu when its room closes, with Close or with Escape", {
    app <- studio_driver("small")
    studio_open_code(app)
    app$wait_for_js("document.querySelector('.sms-code-csv [data-sms-menu]') !== null")
    for (how in c("close", "escape", "dock")) {
      app$run_js("document.querySelector(\".sms-code-csv [data-sms-menu]\").focus()")
      studio_press(app, "Enter")
      expect_false(app$get_js("document.querySelector('#studio-menu-csv').hidden"))
      if (how == "close") {
        click_now(app, "[data-sms-close='code']")
      } else if (how == "escape") {
        studio_press(app, "Escape")
        expect_true(app$get_js("document.querySelector('#studio-menu-csv').hidden"))
        studio_press(app, "Escape")
      } else {
        click_now(app, ".sms-block [data-sms-room='code']")
      }
      app$wait_for_js("document.querySelector('[data-sms-room-of=\"code\"]').hidden === true")
      expect_true(app$get_js("document.querySelector('#studio-menu-csv').hidden"))
      expect_identical(
        app$get_js("document.querySelector(\".sms-code-csv [data-sms-menu]\").getAttribute('aria-expanded')"),
        "false"
      )
      studio_open_code(app)
    }
    expect_studio_clean(app)
  })

  it("[SMS-090] gives every control a name, and stops the slip, the tray and the toast under reduced motion", {
    app <- studio_driver("none")
    open_example_by_key(app)
    app$run_js("document.querySelector('#studio-map [data-card=\"round_dose\"]').dispatchEvent(new MouseEvent('click', { bubbles: true, detail: 1 }))")
    app$wait_for_js("document.querySelector('.sms-inspector').hidden === false")
    for (room in c("ask", "check", "code", "map")) {
      click_now(app, sprintf(".sms-block [data-sms-room='%s']", room))
    }
    unnamed <- app$get_js(
      "[...document.querySelectorAll('.sms button, .sms a[href], .sms input, .sms select, .sms textarea')]
         .filter((el) => el.getClientRects().length > 0 || el.closest('[hidden]') === null)
         .filter((el) => {
           const label = el.getAttribute('aria-label') || el.getAttribute('aria-labelledby') || el.textContent.trim() ||
             (el.id && document.querySelector('label[for=\"' + el.id + '\"]')) || el.closest('label') ||
             el.closest('fieldset')?.querySelector('legend') || el.getAttribute('title');
           return !label;
         }).map((el) => el.outerHTML.slice(0, 120))"
    )
    expect_identical(unlist(unnamed), NULL)

    studio_emulate(app, "prefers-reduced-motion", "reduce")
    motion <- app$get_js(
      "(() => { const pick = (sel) => { const cs = getComputedStyle(document.querySelector(sel));
         return { transition: cs.transitionDuration, animation: cs.animationName }; };
         return { inspector: pick('.sms-inspector'), tray: pick('.sms-tray'), toast: pick('.sms-toast') }; })()"
    )
    for (part in motion) {
      expect_identical(part$animation, "none")
      expect_match(part$transition, "^(0s)(, 0s)*$")
    }
    # And, without the preference, the slip does move
    studio_emulate(app, "prefers-reduced-motion", "no-preference")
    expect_false(identical(app$get_js("getComputedStyle(document.querySelector('.sms-inspector')).animationName"), "none"))
    studio_wait_step(app)
    studio_wait_drawn(app)
    expect_studio_clean(app)
  })
})
