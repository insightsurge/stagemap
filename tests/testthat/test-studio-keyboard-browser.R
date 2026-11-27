skip_without_chrome()

# Browser tests for the keyboard pass: the Tab order and its ring in both themes, picking a card and Undo and Escape by
# key, a walk through the whole studio by key, the order Escape closes layers in, and reduced motion. Every key is a
# real key event (studio_press()). SMS-086 uses key events only and checks that no pointer event fired; the other tests
# use key events for what they test and click where a step only sets the page up.

# A short description of the element with focus: its tag and class, what names it, whether it shows the studio's own
# ring, and where it is. `ring` is true when the box shadow of the focused element is not 'none' and differs from the
# one the same element has at rest (a clone beside it, not focused): the browser's own outline does not count, and
# neither does a shadow the control has at rest. `faceRing` is for a segment's radio: its face shows the
# `--_stagemap-studio-ring` token, read from a probe in the same theme.
focus_js <- "(() => {
  const a = document.activeElement;
  const root = a.closest('.sms') ?? document.querySelector('.sms');
  const shadow = (el) => getComputedStyle(el).boxShadow;
  const probe = document.createElement('span');
  probe.style.boxShadow = 'var(--_stagemap-studio-ring)';
  root.appendChild(probe);
  const token = shadow(probe);
  probe.remove();
  const rest = a.cloneNode(false);
  rest.removeAttribute('id');
  a.after(rest);
  const resting = shadow(rest);
  rest.remove();
  const ring = shadow(a) !== 'none' && shadow(a) !== resting;
  const face = a.matches('.sms-seg-opt input') ? a.parentElement.querySelector('.sms-seg-face') : null;
  const faceRing = face ? shadow(face) === token : null;
  const name = a.getAttribute('aria-label') || a.dataset?.card || a.dataset?.smsRoom || a.textContent.trim().slice(0, 30);
  const where = a.closest('.sms-skip') ? 'skip' : a.closest('#studio-map') ? 'map' : a.closest('.sms-tray') ? 'tray' :
    a.closest('.sms-block') ? 'block' : a.closest('.sms-inspector') ? 'inspector' : a.closest('.sms-hint') ? 'hint' :
    a.closest('.sms-top') ? 'top' : a.closest('.sms') ? 'sheet' : 'outside';
  return JSON.stringify({ tag: a.tagName, cls: String(a.getAttribute('class') ?? ''), name, ring, faceRing, where,
    id: a.id, shadow: shadow(a), token, resting, visible: a.matches(':focus-visible') });
})()"

focus_now <- function(app) {
  jsonlite::fromJSON(app$get_js(focus_js), simplifyVector = FALSE)
}

# Presses Tab (or Shift+Tab) until the focus is on an element that matches `selector`, at most `max` times; the test
# fails when it is not reached, which is how a trap or a missing stop shows. Returns how many presses it took.
tab_to <- function(app, selector, max = 40L, back = FALSE) {
  for (i in seq_len(max)) {
    if (
      isTRUE(app$get_js(sprintf("document.activeElement.matches(%s)", jsonlite::toJSON(selector, auto_unbox = TRUE))))
    ) {
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
  it("[SMS-081] visits every control in page order, each with the studio's ring in both themes, and has no trap", {
    app <- studio_driver("none")
    open_example_by_key(app)
    expect_identical(focus_now(app)$cls, "sms-title")
    set_theme <- function(theme) {
      app$run_js(sprintf("%s.dataset.theme = '%s'", studio_root_js, theme))
      expect_identical(app$get_js(sprintf("%s.dataset.theme", studio_root_js)), theme)
    }
    # Focus on a stop reached with Tab shows the studio's ring, in the colours of the theme
    expect_ring <- function(stop, label) {
      expect_true(stop$ring, label = paste("ring on", label, "-", stop$shadow, "at rest:", stop$resting))
      expect_true(stop$visible, label = paste("focus-visible on", label))
      if (!is.null(stop$faceRing)) expect_true(stop$faceRing, label = paste("ring on the face of", label))
    }

    for (theme in c("light", "dark")) {
      set_theme(theme)
      # Back to the start of the page, then forward through all of it
      app$run_js("document.querySelector('.sms-title').focus()")
      studio_press(app, "Tab", modifiers = "shift")
      first <- focus_now(app)
      expect_identical(first$where, "skip")
      expect_ring(first, paste("the skip link,", theme))

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
      for (stop in seen[where %in% c("top", "hint", "block")]) {
        expect_ring(stop, paste(stop$name, theme))
      }
      names_block <- vapply(seen[where == "block"], function(s) s$name, character(1))
      expect_match(names_block, "^(map|ask|check|code|Theme, dark mode|Done)", all = TRUE)
      expect_length(names_block, 6L)
      expect_match(names_block[[6L]], "^Done")

      # One more Tab leaves the page or wraps to the skip link; none stays on the last control
      expect_false(identical(focus_now(app)$name, names_block[[6L]]))
    }

    # With a room open, its controls come before the title block, and ring in both themes
    app$run_js("document.querySelector(\"[data-sms-room='code']\").focus()")
    studio_press(app, "Enter")
    app$wait_for_js("document.querySelector('[data-sms-room-of=\"code\"]').hidden === false")
    expect_identical(app$get_js("document.activeElement.tagName"), "H2")
    for (theme in c("light", "dark")) {
      set_theme(theme)
      app$run_js("document.querySelector(\"[data-sms-room-of='code']\").querySelector('[tabindex=\"-1\"]').focus()")
      tab_to(app, "[data-sms-close='code']")
      expect_identical(focus_now(app)$where, "tray")
      expect_ring(focus_now(app), paste("the room's Close,", theme))
      tab_to(app, ".sms-block [data-sms-room='code']")
      expect_identical(focus_now(app)$where, "block")
    }
    studio_press(app, "Escape")
    app$wait_for_js("document.querySelector('[data-sms-room-of=\"code\"]').hidden === true")

    # A card's form (its title, a segment, a field and Close) and a menu's items ring in both themes
    app$run_js("document.querySelector('#studio-map [data-card=\"round_dose\"]').focus()")
    studio_press(app, "Enter")
    app$wait_for_js("document.activeElement?.id === 'studio-inspector-title'")
    for (theme in c("light", "dark")) {
      set_theme(theme)
      for (selector in c(
        ".sms-inspector [data-sms-field='status'] input:checked",
        ".sms-inspector [data-sms-field='label'] input",
        ".sms-inspector .sms-insp-acts button"
      )) {
        app$run_js("document.getElementById('studio-inspector-title').focus()")
        tab_to(app, selector, max = 80L)
        expect_ring(focus_now(app), paste(selector, theme))
      }
      expect_identical(focus_now(app)$where, "inspector")
    }
    studio_press(app, "Escape")
    app$wait_for_js("document.querySelector('.sms-inspector').hidden === true")
    app$run_js("document.querySelector(\"[data-sms-menu='stages']\").focus()")
    studio_press(app, "Enter")
    expect_identical(app$get_js("document.activeElement.getAttribute('role')"), "menuitem")
    for (theme in c("light", "dark")) {
      set_theme(theme)
      expect_ring(focus_now(app), paste("a menu item,", theme))
    }
    studio_press(app, "Escape")
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

    # Change the status with the arrow keys (focus is on a radio, not in text); the edit can be undone
    app$run_js("document.querySelector('.sms-inspector [data-sms-field=\"status\"] input:checked').focus()")
    before <- app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"status\"] input:checked').value")
    since <- studio_stamp(app)
    studio_press(app, "ArrowRight")
    studio_wait_step(app)
    studio_wait_map(app, since)
    changed <- app$get_js(
      "document.querySelector('.sms-inspector [data-sms-field=\"status\"] input:checked').value"
    )
    expect_false(identical(changed, before))
    undo_on <- "document.querySelector('.sms-undo').getAttribute('aria-disabled') !== 'true'"
    journal <- "JSON.stringify([...document.querySelectorAll('.sms-ev')].map((e) => e.dataset.smsState ?? ''))"
    expect_true(app$get_js(undo_on))
    entries <- app$get_js(journal)

    # Ctrl+Z in a text field is the field's own: nothing is sent, the journal stays and Undo stays on
    record_studio_events(app)
    app$run_js("document.querySelector('.sms-inspector [data-sms-field=\"label\"] input').focus()")
    studio_press(app, "z", modifiers = "ctrl")
    studio_wait_step(app)
    expect_length(studio_sent(app), 0L)
    expect_identical(app$get_js(journal), entries)
    expect_true(app$get_js(undo_on))
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"status\"] input:checked').value"),
      changed
    )

    # Ctrl+Z outside text undoes the edit
    app$run_js("document.querySelector('.sms-inspector [data-sms-field=\"status\"] input:checked').focus()")
    since <- studio_stamp(app)
    studio_press(app, "z", modifiers = "ctrl")
    studio_wait_step(app)
    studio_wait_map(app, since)
    expect_identical(
      vapply(studio_sent(app), function(e) e$type, character(1)),
      "undo"
    )
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"status\"] input:checked').value"),
      before
    )
    expect_identical(app$get_js("document.querySelector('.sms-ev').dataset.smsState"), "undone")

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
    expect_false(identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"status\"] input:checked').value"),
      before
    ))
    expect_identical(app$get_js("document.activeElement.name !== undefined && document.activeElement.type"), "radio")
    expect_identical(app$get_js("document.querySelectorAll('.sms-ev').length"), 1L)

    # Connect it to another card: the select, then the button
    tab_to(app, ".sms-inspector [data-sms-list='out'] [data-sms-field='to'] select")
    # A native select is changed by the browser's own keys, which differ by system; the page's part is what follows
    # the change, so the value is set on the control that Tab reached.
    to_before <- app$get_js("document.activeElement.value")
    app$run_js(
      "{ const s = document.activeElement; s.selectedIndex = (s.selectedIndex + 1) % s.options.length; s.dispatchEvent(new Event('change', { bubbles: true })); }"
    )
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
      ) |>
        jsonlite::fromJSON()
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

  it("[SMS-087] closes a room or form opened over the guide's list with the first Escape", {
    app <- studio_driver("none")
    open_example_by_key(app)
    app$run_js("document.querySelector('.sms-try-btn').focus()")
    studio_press(app, "Enter")
    expect_false(app$get_js("document.querySelector('.sms-try').hidden"))
    app$run_js("document.querySelector(\"[data-sms-room='code']\").focus()")
    studio_press(app, "Enter")
    app$wait_for_js("document.querySelector('[data-sms-room-of=\"code\"]').hidden === false")
    # The room covers the list, so the list is closed and its button says so
    expect_true(app$get_js("document.querySelector('.sms-try').hidden"))
    expect_identical(app$get_js("document.querySelector('.sms-try-btn').getAttribute('aria-expanded')"), "false")
    studio_press(app, "Escape")
    app$wait_for_js("document.querySelector('[data-sms-room-of=\"code\"]').hidden === true")
    expect_identical(app$get_js("document.activeElement.dataset.smsRoom"), "code")
    studio_wait_step(app)

    # The same for a card's form: a pick over the open list closes the list, and Escape closes the form
    app$run_js("document.querySelector('.sms-try-btn').focus()")
    studio_press(app, "Enter")
    expect_false(app$get_js("document.querySelector('.sms-try').hidden"))
    app$run_js("document.querySelector('#studio-map [data-card=\"round_dose\"]').focus()")
    studio_press(app, "Enter")
    app$wait_for_js("document.querySelector('.sms-inspector').hidden === false")
    expect_true(app$get_js("document.querySelector('.sms-try').hidden"))
    studio_press(app, "Escape")
    app$wait_for_js("document.querySelector('.sms-inspector').hidden === true")
    studio_wait_step(app)
    expect_studio_clean(app)
  })

  it("[SMS-088] leaves the focus on a control when a menu closes with Tab, and moves between items with the arrows", {
    app <- studio_driver("small")
    app$run_js("document.querySelector(\"[data-sms-menu='stages']\").focus()")
    studio_press(app, "Enter")
    expect_identical(app$get_js("document.activeElement.getAttribute('role')"), "menuitem")
    expect_identical(
      app$get_js(
        "[...document.querySelectorAll('#studio-menu-stages [role=menuitem]')].every((b) => b.tabIndex === -1)"
      ),
      TRUE
    )
    studio_press(app, "ArrowDown")
    expect_identical(app$get_js("document.activeElement.dataset.smsUid !== undefined"), TRUE)
    studio_press(app, "End")
    studio_press(app, "Home")
    # Tab closes the menu and goes on from its button
    studio_press(app, "Tab")
    expect_true(app$get_js("document.querySelector('#studio-menu-stages').hidden"))
    expect_identical(
      app$get_js("document.querySelector(\"[data-sms-menu='stages']\").getAttribute('aria-expanded')"),
      "false"
    )
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
    studio_wait_step(app)
    expect_studio_clean(app)
  })

  it("[SMS-090] gives every control a name, and stops the slip, the tray and the toast under reduced motion", {
    app <- studio_driver("none")
    open_example_by_key(app)
    app$run_js(
      "document.querySelector('#studio-map [data-card=\"round_dose\"]').dispatchEvent(new MouseEvent('click', { bubbles: true, detail: 1 }))"
    )
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
    expect_false(identical(
      app$get_js("getComputedStyle(document.querySelector('.sms-inspector')).animationName"),
      "none"
    ))
    studio_wait_step(app)
    studio_wait_drawn(app)
    expect_studio_clean(app)
  })
})
