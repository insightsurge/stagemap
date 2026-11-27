skip_without_chrome()

# Browser tests for the phone layout (640px and below), at 390px and 360px: the dock and the header's Map, one sheet at
# a time, touch targets, the journal as one entry, form controls, menus and the guide's list inside the screen, no
# sideways scroll, a tap, and the colours of the page's own tokens in both themes.

phone_widths <- c(390L, 360L)

phone_driver <- function(width, fixture = "none", env = parent.frame()) {
  app <- studio_driver(fixture, env = env)
  if (identical(fixture, "none")) {
    click_now(app, ".sms-start [data-sms-open='example']")
    app$wait_for_js("document.querySelector('.sms-start').hidden === true")
    studio_wait_step(app)
  }
  studio_emulate(app, "width", width)
  studio_wait_step(app)
  app
}

pick_card_js <- function(id) {
  sprintf(
    "document.querySelector('#studio-map [data-card=\"%s\"]').dispatchEvent(new MouseEvent('click', { bubbles: true, detail: 1 }));",
    id
  )
}

# Opens a room with its dock button and waits until the tray has stopped sliding.
open_room <- function(app, room) {
  click_now(app, sprintf(".sms-block [data-sms-room='%s']", room))
  app$wait_for_js(sprintf(
    "document.querySelector('[data-sms-room-of=\"%s\"]').hidden === false &&
     getComputedStyle(document.querySelector('.sms-tray')).transform === 'none'",
    room
  ))
  invisible(app)
}

# Which sheets are shown: each room that is shown (display and not inert), and the form. It waits until nothing is
# sliding, so the boxes it reads are where they stay.
sheets <- function(app) {
  app$wait_for_js("document.getAnimations().length === 0")
  jsonlite::fromJSON(
    app$get_js(
      "JSON.stringify((() => {
         const shown = (el) => getComputedStyle(el).display !== 'none' && !el.hidden && !el.inert && !el.closest('[inert]');
         const rooms = [...document.querySelectorAll('[data-sms-room-of]')].filter(shown).map((r) => r.dataset.smsRoomOf);
         const insp = document.querySelector('.sms-inspector');
         return { rooms, form: shown(insp), form_inert: insp.inert, form_display: getComputedStyle(insp).display,
                  form_target: insp.dataset.smsUid ?? null,
                  hint: getComputedStyle(document.querySelector('.sms-hint')).display !== 'none' };
       })())"
    ),
    simplifyVector = TRUE
  )
}

# Whether the guide's list is open: its panel is shown and the button says so.
guide_open <- function(app) {
  app$get_js(
    "(() => { const p = document.querySelector('.sms-try'); const b = document.querySelector('.sms-try-btn');
       return !p.hidden && b.getAttribute('aria-expanded') === 'true'; })()"
  )
}

# How far the studio reaches past the screen's width: the sheet's scroll width, the dock, and the right edge of each
# part of the page of its own.
overflow <- function(app) {
  app$wait_for_js("document.getAnimations().length === 0")
  jsonlite::fromJSON(
    app$get_js(
      "JSON.stringify((() => {
         const w = window.innerWidth;
         const sheet = document.querySelector('.sms-sheet');
         const parts = ['.sms-top', '.sms-journal', '.sms-paper', '.sms-hint', '.sms-block', '.sms-tray', '.sms-inspector']
           .map((s) => document.querySelector(s)).filter((el) => el && getComputedStyle(el).display !== 'none' && !el.hidden);
         return { sheet: sheet.scrollWidth - sheet.clientWidth, root: document.querySelector('.sms').scrollWidth - w,
                  right: Math.max(0, ...parts.map((el) => el.getBoundingClientRect().right - w)),
                  left: Math.min(0, ...parts.map((el) => el.getBoundingClientRect().left)) };
       })())"
    )
  )
}

expect_no_sideways <- function(app, info = "") {
  o <- overflow(app)
  expect_lte(o$sheet, 0, label = paste("sheet overflow", info))
  expect_lte(o$root, 0, label = paste("root overflow", info))
  expect_lte(o$right, 0.5, label = paste("right edge", info))
  expect_gte(o$left, -0.5, label = paste("left edge", info))
}

describe("the studio on a phone", {
  it("[SMS-077] shows a dock of four, the header's Map and theme, and never scrolls sideways", {
    for (width in phone_widths) {
      app <- phone_driver(width)
      dock <- jsonlite::fromJSON(app$get_js(
        "JSON.stringify([...document.querySelectorAll('.sms-block > *')].filter((el) => getComputedStyle(el).display !== 'none')
           .map((el) => ({ cls: el.className, name: el.dataset.smsRoom ?? (el.matches('.sms-done') ? 'done' : ''), h: el.getBoundingClientRect().height })))"
      ))
      expect_identical(dock$name, c("ask", "check", "code", "done"))
      expect_true(all(dock$h >= 44))
      expect_true(app$get_js("getComputedStyle(document.querySelector('.sms-phone-map')).display !== 'none'"))
      expect_true(app$get_js("getComputedStyle(document.querySelector('.sms-phone-theme')).display !== 'none'"))
      expect_identical(app$get_js("getComputedStyle(document.querySelector('.sms-block .sms-theme')).display"), "none")
      expect_no_sideways(app, width)

      # Map opens from the header
      click_now(app, ".sms-phone-map")
      app$wait_for_js("document.querySelector('[data-sms-room-of=\"map\"]').hidden === false")
      expect_identical(app$get_js("document.querySelector('.sms-phone-map').getAttribute('aria-expanded')"), "true")
      expect_no_sideways(app, paste(width, "with the Map room"))
      # The header's theme button is a switch that says which mode is on, and switches it
      theme_state <- function() {
        jsonlite::fromJSON(app$get_js(
          sprintf(
            "JSON.stringify({ role: document.querySelector('.sms-phone-theme').getAttribute('role'),
               checked: document.querySelector('.sms-phone-theme').getAttribute('aria-checked'),
               name: document.querySelector('.sms-phone-theme').getAttribute('aria-label'),
               dark: document.documentElement.getAttribute('data-bs-theme') === 'dark' })"
          )
        ))
      }
      before <- theme_state()
      expect_identical(before$role, "switch")
      expect_identical(before$checked, tolower(as.character(before$dark)))
      expect_true(startsWith(before$name, "Light or dark"))
      app$run_js("document.querySelector('.sms-phone-theme').click()")
      after <- theme_state()
      expect_identical(after$dark, !before$dark)
      expect_identical(after$checked, tolower(as.character(after$dark)))
      expect_true(app$get_js(sprintf(
        "%s.dataset.theme === 'dark' || %s.dataset.theme === 'light'",
        studio_root_js,
        studio_root_js
      )))
      expect_studio_clean(app)
    }
  })

  it("[SMS-078] opens one sheet at a time: a room, or the form, never both", {
    for (width in phone_widths) {
      app <- phone_driver(width)
      expect_true(sheets(app)$hint)
      # The guide's list is open when a room opens: it closes, and Escape closes the room that can be seen
      click_now(app, ".sms-try-btn")
      expect_true(guide_open(app))
      open_room(app, "ask")
      expect_false(guide_open(app))
      expect_identical(app$get_js("document.querySelector('.sms-try-btn').getAttribute('aria-expanded')"), "false")
      expect_identical(sheets(app)$rooms, "ask")
      studio_press(app, "Escape")
      app$wait_for_js("document.querySelector('[data-sms-room-of=\"ask\"]').hidden === true")
      expect_length(sheets(app)$rooms, 0L)
      expect_true(sheets(app)$hint)
      open_room(app, "ask")
      expect_identical(sheets(app)$rooms, "ask")
      open_room(app, "check")
      s <- sheets(app)
      expect_identical(s$rooms, "check")
      expect_true(app$get_js("document.querySelector('[data-sms-room-of=\"ask\"]').inert"))
      expect_identical(
        app$get_js("document.querySelector(\".sms-block [data-sms-room='ask']\").getAttribute('aria-expanded')"),
        "false"
      )
      expect_false(s$hint)
      expect_no_sideways(app, paste(width, "with a room"))

      # A pick closes the room and opens the form as a sheet at the foot
      app$run_js(pick_card_js("round_dose"))
      app$wait_for_js(
        "document.querySelector('.sms-inspector').hidden === false && document.querySelector('[data-sms-room-of=\"check\"]').hidden === true"
      )
      s <- sheets(app)
      expect_length(s$rooms, 0L)
      expect_true(s$form)
      expect_false(s$hint)
      app$wait_for_js("document.getAnimations().length === 0")
      box <- app$get_js(
        "(() => { const r = document.querySelector('.sms-inspector').getBoundingClientRect(); return { left: r.left, right: r.right, bottom: r.bottom, h: r.height, vh: window.innerHeight, block: document.querySelector('.sms-block').getBoundingClientRect().height }; })()"
      )
      expect_equal(box$left, 0)
      expect_equal(box$right, width)
      expect_lte(box$h, box$vh * 0.58 + 1)
      expect_equal(box$bottom, box$vh - box$block, tolerance = 0.01)
      expect_no_sideways(app, paste(width, "with the form"))

      # A room covers the form (hidden and inert) while the server keeps the target; closing the room brings it back
      open_room(app, "ask")
      s <- sheets(app)
      expect_identical(s$rooms, "ask")
      expect_false(s$form)
      expect_true(s$form_inert)
      expect_identical(s$form_display, "none")
      expect_false(is.null(s$form_target))
      click_now(app, "[data-sms-close='ask']")
      app$wait_for_js("document.querySelector('[data-sms-room-of=\"ask\"]').hidden === true")
      s <- sheets(app)
      expect_true(s$form)
      expect_length(s$rooms, 0L)
      expect_identical(app$get_js("document.activeElement.dataset.smsRoom"), "ask")

      # Escape closes the form (the room is closed already) and the bar comes back
      studio_press(app, "Escape")
      app$wait_for_js("document.querySelector('.sms-inspector').hidden === true")
      expect_true(sheets(app)$hint)

      # The guide's list is open when a pick opens the form: it closes, and Escape closes the form
      click_now(app, ".sms-try-btn")
      expect_true(guide_open(app))
      app$run_js(pick_card_js("round_dose"))
      app$wait_for_js("document.querySelector('.sms-inspector').hidden === false")
      expect_false(guide_open(app))
      studio_press(app, "Escape")
      app$wait_for_js("document.querySelector('.sms-inspector').hidden === true")
      expect_true(sheets(app)$hint)
      expect_false(guide_open(app))
      expect_studio_clean(app)
    }
  })

  it("[SMS-078] leaves one sheet when a pick and a room are asked for at once, and with answers held", {
    app <- phone_driver(390L)
    # At once: the pick's answer arrives after the room has opened, and the pick wins
    studio_do(
      app,
      paste(pick_card_js("round_dose"), "document.querySelector(\".sms-block [data-sms-room='ask']\").click();")
    )
    s <- sheets(app)
    expect_true(s$form)
    expect_length(s$rooms, 0L)
    studio_do(app, studio_click_js(".sms-inspector .sms-insp-acts button"))
    app$wait_for_js("document.querySelector('.sms-inspector').hidden === true")

    # With the answer held: the room is the only sheet until the answer is drawn, then the form
    hold_studio_messages(app)
    seq <- app$get_js(paste(
      pick_card_js("round_dose"),
      "document.querySelector(\".sms-block [data-sms-room='ask']\").click();",
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, seq)
    s <- sheets(app)
    expect_identical(s$rooms, "ask")
    expect_false(s$form)
    release_studio_messages(app)
    studio_wait_step(app)
    s <- sheets(app)
    expect_true(s$form)
    expect_length(s$rooms, 0L)
    expect_studio_clean(app)
  })

  it("[SMS-079] keeps targets 44px high, the journal to one whole entry, controls at 16px and menus on the screen", {
    for (width in phone_widths) {
      app <- phone_driver(width)
      heights <- function(selector) {
        unlist(app$get_js(sprintf(
          "[...document.querySelectorAll(%s)].filter((el) => el.getClientRects().length > 0 && !el.closest('[hidden]'))
             .map((el) => el.getBoundingClientRect().height)",
          jsonlite::toJSON(selector, auto_unbox = TRUE)
        )))
      }
      expect_true(all(heights(".sms-block button") >= 44))
      expect_true(all(heights(".sms-top .sms-btn, .sms-outline .sms-btn") >= 44))

      # Two edits: the journal shows the newest entry and Undo, and Undo marks it with its word, whole and on screen
      studio_do(app, studio_click_js("[data-sms-action='+ Card']"))
      studio_do(app, studio_click_js("[data-sms-action='+ Stage']"))
      studio_do(app, studio_click_js(".sms-inspector .sms-insp-acts button"))
      visible_entries <- app$get_js(
        "[...document.querySelectorAll('.sms-ev')].filter((el) => getComputedStyle(el).display !== 'none').length"
      )
      expect_identical(visible_entries, 1L)
      expect_gte(heights(".sms-undo"), 44)
      # The focus ring of the entry has room in the ribbon
      app$run_js("document.querySelector('.sms-ev:last-child .sms-ev-btn')?.focus()")
      ring <- app$get_js(
        "(() => { const b = document.activeElement.getBoundingClientRect();
           const l = document.querySelector('.sms-journal-list').getBoundingClientRect();
           return { onEntry: document.activeElement.classList.contains('sms-ev-btn'),
                    room: Math.min(b.left - l.left, l.right - b.right, b.top - l.top, l.bottom - b.bottom) }; })()"
      )
      expect_true(ring$onEntry)
      expect_gte(ring$room, 4)

      studio_do(app, studio_click_js(".sms-undo"))
      undone <- app$get_js(
        "(() => { const w = document.querySelector('.sms-ev:last-child .sms-ev-undone');
           const row = document.querySelector('.sms-journal').getBoundingClientRect();
           const r = w.getBoundingClientRect();
           return { text: w.textContent, shown: getComputedStyle(w).display !== 'none' && r.width > 0,
                    inside: r.left >= row.left && r.right <= row.right && r.right <= window.innerWidth,
                    whole: w.scrollWidth <= w.clientWidth + 1 }; })()"
      )
      expect_identical(undone$text, "undone")
      expect_true(undone$shown)
      expect_true(undone$inside)
      expect_true(undone$whole)
      expect_gte(tail(heights(".sms-ev-btn, .sms-ev-item"), 1L), 44)

      # The Check count fits its cell, for one problem and for a longer number
      fit <- function() {
        app$get_js(
          "(() => { const v = document.querySelector(\".sms-block [data-sms-room='check'] .sms-val\");
             const cell = document.querySelector(\".sms-block [data-sms-room='check']\").getBoundingClientRect();
             const r = v.getBoundingClientRect();
             return { fits: v.scrollWidth <= v.clientWidth + 1, inside: r.left >= cell.left - 1 && r.right <= cell.right + 1,
                      word_clipped: getComputedStyle(v.querySelector('.sms-check-w')).clipPath !== 'none' }; })()"
        )
      }
      expect_true(fit()$fits)
      expect_true(fit()$inside)
      expect_true(fit()$word_clipped)
      app$run_js("document.querySelector('.sms-check-n').textContent = '128'")
      expect_true(fit()$fits)
      expect_true(fit()$inside)

      # Form controls are 16px or more in the form and in every room
      app$run_js(pick_card_js("round_dose"))
      app$wait_for_js("document.querySelector('.sms-inspector').hidden === false")
      sizes <- function() {
        unlist(app$get_js(
          "[...document.querySelectorAll('.sms input, .sms select, .sms textarea')].filter((el) => el.type !== 'hidden' && el.type !== 'radio' && el.type !== 'checkbox')
             .map((el) => parseFloat(getComputedStyle(el).fontSize))"
        ))
      }
      expect_gt(length(sizes()), 3L)
      expect_true(all(sizes() >= 16))
      # The status segments and the switches of the form are 44px high
      app$wait_for_js("document.getAnimations().length === 0")
      for (selector in c(".sms-inspector .sms-seg-face", ".sms-inspector .sms-toggle")) {
        selected <- heights(selector)
        expect_gt(length(selected), 0L, label = selector)
        expect_true(all(selected >= 44), label = paste(selector, "heights", paste(selected, collapse = ", ")))
      }
      studio_do(app, studio_click_js(".sms-inspector .sms-insp-acts button"))
      for (room in c("ask", "map")) {
        open_room(app, room)
        expect_true(all(sizes() >= 16))
        room_heights <- heights(sprintf("[data-sms-room-of='%s'] .sms-in", room))
        expect_gt(length(room_heights), 0L)
        expect_true(all(room_heights >= 44))
      }
      # The Ask room's segments, and the Map room's Bundle links and Legend switches
      open_room(app, "ask")
      expect_gt(length(heights("[data-sms-room-of='ask'] .sms-seg-face")), 0L)
      expect_true(all(heights("[data-sms-room-of='ask'] .sms-seg-face") >= 44))
      open_room(app, "map")
      expect_gt(length(heights("[data-sms-room-of='map'] .sms-toggle")), 0L)
      expect_true(all(heights("[data-sms-room-of='map'] .sms-toggle") >= 44))
      click_now(app, "[data-sms-close='map']")

      # Menus open inside the screen, with items 44px high
      for (menu in c("stages", "lanes")) {
        click_now(app, sprintf("[data-sms-menu='%s']", menu))
        pop <- app$get_js(sprintf(
          "(() => { const r = document.querySelector('#studio-menu-%s').getBoundingClientRect(); return { left: r.left, right: r.right, w: window.innerWidth }; })()",
          menu
        ))
        expect_gt(pop$right - pop$left, 0)
        expect_gte(pop$left, 0)
        expect_lte(pop$right, pop$w)
        items <- heights(sprintf("#studio-menu-%s .sms-menu-item", menu))
        expect_gt(length(items), 0L)
        expect_true(all(items >= 44))
        expect_no_sideways(app, paste(width, menu, "menu"))
        click_now(app, sprintf("[data-sms-menu='%s']", menu))
      }
      open_room(app, "code")
      app$wait_for_js("document.querySelector('.sms-code-csv [data-sms-menu]') !== null")
      click_now(app, ".sms-code-csv [data-sms-menu]")
      pop <- app$get_js(
        "(() => { const r = document.querySelector('#studio-menu-csv').getBoundingClientRect(); return { left: r.left, right: r.right, w: window.innerWidth }; })()"
      )
      expect_gt(pop$right - pop$left, 0)
      expect_false(app$get_js("document.querySelector('#studio-menu-csv').hidden"))
      expect_gte(pop$left, 0)
      expect_lte(pop$right, pop$w)
      expect_no_sideways(app, paste(width, "CSV menu"))
      click_now(app, "[data-sms-close='code']")

      # The guide's list is inside the screen too
      expect_true(sheets(app)$hint)
      click_now(app, ".sms-try-btn")
      expect_true(guide_open(app))
      list <- app$get_js(
        "(() => { const r = document.querySelector('.sms-try').getBoundingClientRect(); return { left: r.left, right: r.right, top: r.top, bottom: r.bottom, w: window.innerWidth, block: document.querySelector('.sms-block').getBoundingClientRect().top }; })()"
      )
      expect_gt(list$right - list$left, 0)
      expect_gt(list$bottom - list$top, 0)
      expect_gte(list$left, 0)
      expect_lte(list$right, list$w)
      expect_gte(list$top, 0)
      expect_lte(list$bottom, list$block)
      expect_no_sideways(app, paste(width, "guide list"))
      studio_wait_step(app)
      studio_wait_drawn(app)
      expect_studio_clean(app)
    }
  })

  it("[SMS-091] opens a card's form with a tap, and nothing needs hover", {
    app <- phone_driver(390L)
    session <- app$get_chromote_session()
    session$Emulation$setTouchEmulationEnabled(enabled = TRUE)
    app$run_js("document.querySelector('#studio-map [data-card=\"scale_weight\"]').scrollIntoView({ block: 'center' })")
    pos <- app$get_js(
      "(() => { const r = document.querySelector('#studio-map [data-card=\"scale_weight\"]').getBoundingClientRect(); return [r.left + r.width / 2, r.top + r.height / 2]; })()"
    )
    session$Input$dispatchTouchEvent(type = "touchStart", touchPoints = list(list(x = pos[[1]], y = pos[[2]])))
    session$Input$dispatchTouchEvent(type = "touchEnd", touchPoints = list())
    app$wait_for_js("document.querySelector('.sms-inspector').hidden === false")
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-insp-sub').textContent"), "scale_weight")
    expect_identical(app$get_js("document.querySelector('.sms-inspector').inert"), FALSE)

    # Every action of the form is a button, a field or a menu: none is reached only by hover
    hover_rules <- app$get_js(
      "(() => { const rules = (list) => [...list].flatMap((r) => (r.cssRules ? rules(r.cssRules) : [r]));
         return rules([...document.styleSheets].flatMap((sheet) => [...sheet.cssRules])).filter((r) =>
           r.selectorText?.includes('.sms') && r.selectorText.includes(':hover') &&
           /(display|visibility|opacity|pointer-events)/.test(r.style.cssText)).length; })()"
    )
    expect_identical(hover_rules, 0L)
    session$Emulation$setTouchEmulationEnabled(enabled = FALSE)
    studio_wait_step(app)
    expect_studio_clean(app)
  })

  it("[SMS-092] keeps the page's own text colours at 4.5:1 or more against their backgrounds, in both themes and widths", {
    pairs <- list(
      c("ink", "panel"),
      c("ink", "field"),
      c("ink", "bg"),
      c("ink", "panel2"),
      c("muted", "panel"),
      c("muted", "field"),
      c("muted", "panel2"),
      c("faint", "panel"),
      c("blue", "panel"),
      c("blue", "field"),
      c("blue-ink", "blue"),
      c("blue", "blue-soft"),
      c("red", "panel"),
      c("red", "red-soft"),
      c("good", "panel"),
      c("good", "good-soft"),
      c("warn", "panel"),
      c("warn", "warn-soft"),
      c("panel", "ink"),
      c("code-ink", "code-bg"),
      c("code-mute", "code-bg"),
      c("code-str", "code-bg"),
      c("code-fn", "code-bg"),
      c("code-kw", "code-bg"),
      c("mark", "code-bg")
    )
    ratio_js <- sprintf(
      "(() => {
         const root = document.querySelector('.sms');
         const cs = getComputedStyle(root);
         const probe = document.createElement('span'); root.append(probe);
         const rgb = (name) => { probe.style.color = cs.getPropertyValue('--_stagemap-studio-' + name).trim();
           return getComputedStyle(probe).color.match(/[\\d.]+/g).slice(0, 3).map(Number); };
         const lum = (c) => { const f = (v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; };
           return 0.2126 * f(c[0]) + 0.7152 * f(c[1]) + 0.0722 * f(c[2]); };
         const out = %s.map(([a, b]) => { const [x, y] = [lum(rgb(a)), lum(rgb(b))].sort((p, q) => q - p);
           return { pair: a + ' on ' + b, ratio: (x + 0.05) / (y + 0.05) }; });
         probe.remove();
         return JSON.stringify(out);
       })()",
      jsonlite::toJSON(pairs)
    )
    for (width in phone_widths) {
      app <- phone_driver(width, "small")
      for (mode in c("light", "dark")) {
        app$run_js(sprintf("document.querySelector('.sms').dataset.theme = '%s'", mode))
        ratios <- jsonlite::fromJSON(app$get_js(ratio_js))
        low <- ratios[ratios$ratio < 4.5, , drop = FALSE]
        expect_identical(low$pair, character(), info = paste(width, mode))
        expect_identical(nrow(ratios), length(pairs))
      }
      expect_studio_clean(app)
    }
  })
  it("[SMS-093] keeps the word for a changed line in view while a long line is scrolled, from the page's labels", {
    app <- phone_driver(360L, "small")
    studio_do(app, studio_click_js("[data-sms-action='+ Card']"))
    studio_do(app, studio_click_js(".sms-inspector .sms-insp-acts button"))
    open_room(app, "code")
    mark <- app$get_js(
      "(() => { const line = document.querySelector('.sms-l[data-sms-changed]');
         const after = getComputedStyle(line, '::after');
         const code = document.querySelector('.sms-code');
         code.scrollLeft = 0;
         return { word: line.dataset.smsChanged, content: after.content, position: after.position, right: after.right,
                  scrolls: code.scrollWidth > code.clientWidth }; })()"
    )
    expect_identical(mark$word, "changed")
    expect_identical(mark$content, "\"changed\"")
    expect_identical(mark$position, "sticky")
    expect_identical(mark$right, "10px")
    expect_true(mark$scrolls)
    expect_studio_clean(app)
  })
})
