skip_without_chrome()

# Browser tests for the Ask room: Trace, Loose ends, Gaps, at-once and held-message behaviour,
# stale/clear, row targeting, Trace from here, invalid map refusal, keyboard flow and phone width.

open_ask <- function(app) {
  click_now(app, "[data-sms-room='ask']")
  app$wait_for_js(
    "document.querySelector('[data-sms-room-of=\"ask\"]').hidden === false &&
     getComputedStyle(document.querySelector('.sms-tray')).transform === 'none'"
  )
  invisible(app)
}

switch_ask_js <- function(question) {
  sprintf(
    "{ const r = document.querySelector('.sms-ask-switch input[value=%s]');
       if (!r) throw new Error('Missing ask tab: ' + %s);
       r.click(); }",
    jsonlite::toJSON(question, auto_unbox = TRUE),
    jsonlite::toJSON(question, auto_unbox = TRUE)
  )
}

set_select_js <- function(selector, value) {
  sprintf(
    "{ const s = document.querySelector(%s); if (!s) throw new Error('Missing select: ' + %s);
       s.value = %s; s.dispatchEvent(new Event('change', { bubbles: true })); }",
    jsonlite::toJSON(selector, auto_unbox = TRUE),
    jsonlite::toJSON(selector, auto_unbox = TRUE),
    jsonlite::toJSON(value, auto_unbox = TRUE)
  )
}

expect_highlighted <- function(app, expected) {
  expected_json <- as.character(jsonlite::toJSON(as.list(sort(expected)), auto_unbox = TRUE))
  app$wait_for_js(sprintf(
    "(() => {
       const el = document.getElementById('map_state');
       if (!el || !el.textContent) return false;
       try {
         const st = JSON.parse(el.textContent);
         const got = [...(st.highlighted?.ids ?? [])].sort();
         return JSON.stringify(got) === %s;
       } catch (e) { return false; }
     })()",
    jsonlite::toJSON(expected_json, auto_unbox = TRUE)
  ))
  raw <- app$get_js("document.getElementById('map_state').textContent")
  got <- unlist(jsonlite::fromJSON(raw, simplifyVector = FALSE)$highlighted$ids) %||% character()
  expect_setequal(got, expected)
}


pick_card_on_map_js <- function(id) {
  sprintf(
    "document.querySelector('#studio-map [data-card=%s]').dispatchEvent(new MouseEvent('click', { bubbles: true, detail: 1 }));",
    jsonlite::toJSON(id, auto_unbox = TRUE)
  )
}

wait_ask_room <- function(app, hidden) {
  app$wait_for_js(sprintf("document.querySelector('[data-sms-room-of=\"ask\"]').hidden === %s", tolower(hidden)))
  invisible(app)
}

# Contrast ratios of the answer's text against the answer box, and the box's opacity.
ask_contrast_js <- "(() => {
  const rgb = (c) => c.match(/[\\d.]+/g).slice(0, 3).map(Number);
  const lum = (c) => { const f = (v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; };
    return 0.2126 * f(c[0]) + 0.7152 * f(c[1]) + 0.0722 * f(c[2]); };
  const ratio = (a, b) => { const [x, y] = [lum(rgb(a)), lum(rgb(b))].sort((p, q) => q - p); return (x + 0.05) / (y + 0.05); };
  const box = document.querySelector('.sms-ask-ans');
  const bg = getComputedStyle(box).backgroundColor;
  const col = (sel) => getComputedStyle(box.querySelector(sel)).color;
  return { opacity: getComputedStyle(box).opacity, stale: ratio(col('.sms-ask-stale'), bg),
           call: ratio(col('.sms-ask-call'), bg), title: ratio(col('.sms-ask-ans-title'), bg),
           heading: ratio(col('th'), bg) };
})()"

describe("the Ask room", {
  it("[SMS-051] runs Trace at once after changing options, shows table and call, lights cards, and stays busy while held", {
    app <- studio_driver("small")
    open_ask(app)

    # Pick start card u2 ("Review", id "b") and upstream direction, then Run in one run_js() call
    studio_do(
      app,
      paste(
        set_select_js("[data-sms-q='trace'] [data-sms-field='ids'] select", "u2"),
        "document.querySelector('[data-sms-q=\"trace\"] [data-sms-field=\"direction\"] input[value=\"upstream\"]').click();",
        studio_click_js("[data-sms-q='trace'] button[data-sms-collect]")
      )
    )

    ans <- app$get_js("document.querySelector('.sms-ask-ans')?.textContent ?? ''")
    expect_match(ans, "1 card upstream of Review", fixed = TRUE)
    expect_match(ans, 'sm_trace(map, "b", direction = "upstream")', fixed = TRUE)
    expect_match(ans, "1 up", fixed = TRUE)
    expect_highlighted(app, c("a", "b"))

    # Held messages: Run stays busy until its ack arrives
    hold_studio_messages(app)
    seq_held <- app$get_js(paste(
      "document.querySelector('[data-sms-q=\"trace\"] [data-sms-field=\"direction\"] input[value=\"downstream\"]').click();",
      studio_click_js("[data-sms-q='trace'] button[data-sms-collect]"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, seq_held)
    expect_identical(
      app$get_js("document.querySelector('[data-sms-q=\"trace\"] button[data-sms-collect]').getAttribute('aria-busy')"),
      "true"
    )
    expect_identical(
      app$get_js(
        "document.querySelector('[data-sms-q=\"trace\"] button[data-sms-collect]').getAttribute('aria-disabled')"
      ),
      "true"
    )
    release_studio_messages(app)
    studio_wait_step(app)
    expect_null(
      app$get_js("document.querySelector('[data-sms-q=\"trace\"] button[data-sms-collect]').getAttribute('aria-busy')")
    )
    expect_match(
      app$get_js("document.querySelector('.sms-ask-ans-title')?.textContent ?? ''"),
      "2 cards downstream of Review"
    )
    expect_highlighted(app, c("b", "c", "d"))

    # Run twice quickly with different directions -> second answer wins
    studio_do(
      app,
      paste(
        "document.querySelector('[data-sms-q=\"trace\"] [data-sms-field=\"direction\"] input[value=\"upstream\"]').click();",
        studio_click_js("[data-sms-q='trace'] button[data-sms-collect]")
      )
    )
    studio_do(
      app,
      paste(
        "document.querySelector('[data-sms-q=\"trace\"] [data-sms-field=\"direction\"] input[value=\"both\"]').click();",
        studio_click_js("[data-sms-q='trace'] button[data-sms-collect]")
      )
    )
    expect_match(
      app$get_js("document.querySelector('.sms-ask-ans-title')?.textContent ?? ''"),
      "3 cards either side of Review"
    )
    expect_highlighted(app, c("a", "b", "c", "d"))
    expect_studio_clean(app)
  })

  it("[SMS-052] runs Loose ends at once and with messages held", {
    app <- studio_driver("small")
    # Add an extra card so there is 1 loose end
    since <- studio_stamp(app)
    studio_do(app, studio_click_js("[data-sms-action='+ Card']"))
    studio_wait_map(app, since)

    open_ask(app)
    studio_do(
      app,
      paste(
        switch_ask_js("orphans"),
        studio_click_js("[data-sms-q='orphans'] button[data-sms-collect]")
      )
    )
    expect_match(app$get_js("document.querySelector('.sms-ask-ans-title')?.textContent ?? ''"), "1 card with no link")
    expect_match(
      app$get_js("document.querySelector('.sms-ask-call')?.textContent ?? ''"),
      "sm_orphans(map)",
      fixed = TRUE
    )
    expect_highlighted(app, "card")

    # Held messages test for Loose ends
    hold_studio_messages(app)
    seq_held <- app$get_js(paste(
      studio_click_js("[data-sms-q='orphans'] button[data-sms-collect]"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, seq_held)
    expect_identical(
      app$get_js(
        "document.querySelector('[data-sms-q=\"orphans\"] button[data-sms-collect]').getAttribute('aria-busy')"
      ),
      "true"
    )
    release_studio_messages(app)
    studio_wait_step(app)
    expect_null(
      app$get_js(
        "document.querySelector('[data-sms-q=\"orphans\"] button[data-sms-collect]').getAttribute('aria-busy')"
      )
    )
    expect_studio_clean(app)
  })

  it("[SMS-053] runs Gaps at once after changing stage parameters and with messages held", {
    app <- studio_driver("small")
    open_ask(app)

    # Switch to Gaps, pick Write -> Ship in one run_js() call
    studio_do(
      app,
      paste(
        switch_ask_js("missing"),
        set_select_js("[data-sms-q='missing'] [data-sms-field='stage'] select", "u5"),
        set_select_js("[data-sms-q='missing'] [data-sms-field='linked_to'] select", "u7"),
        studio_click_js("[data-sms-q='missing'] button[data-sms-collect]")
      )
    )
    expect_match(
      app$get_js("document.querySelector('.sms-ask-ans-title')?.textContent ?? ''"),
      "1 card in Write with no direct link to Ship"
    )
    expect_match(
      app$get_js("document.querySelector('.sms-ask-call')?.textContent ?? ''"),
      'sm_missing(map, "write", "ship")',
      fixed = TRUE
    )
    expect_highlighted(app, "a")

    # Held messages test for Gaps
    hold_studio_messages(app)
    seq_held <- app$get_js(paste(
      set_select_js("[data-sms-q='missing'] [data-sms-field='linked_to'] select", "u6"),
      studio_click_js("[data-sms-q='missing'] button[data-sms-collect]"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, seq_held)
    expect_identical(
      app$get_js(
        "document.querySelector('[data-sms-q=\"missing\"] button[data-sms-collect]').getAttribute('aria-busy')"
      ),
      "true"
    )
    release_studio_messages(app)
    studio_wait_step(app)
    expect_match(
      app$get_js("document.querySelector('.sms-ask-ans-title')?.textContent ?? ''"),
      "No gaps: every Write card links to Check"
    )
    expect_highlighted(app, character())
    expect_studio_clean(app)
  })

  it("[SMS-054] targets the card and opens the inspector when an answer row button is clicked (at once and held)", {
    app <- studio_driver("small")
    open_ask(app)
    studio_do(app, studio_click_js("[data-sms-q='trace'] button[data-sms-collect]"))

    # At once after typing title + held message check on row target button
    hold_studio_messages(app)
    seq_held <- app$get_js(paste(
      studio_title_js("Picked from Ask"),
      studio_click_js(".sms-ask-table tbody tr:nth-child(2) .sms-ask-pick"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, seq_held)
    expect_identical(
      app$get_js(
        "document.querySelector('.sms-ask-table tbody tr:nth-child(2) .sms-ask-pick').getAttribute('aria-busy')"
      ),
      "true"
    )
    release_studio_messages(app)
    studio_wait_step(app)
    expect_false(studio_section(app, "inspector")$hidden)
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-insp-sub').textContent"), "b")
    expect_identical(studio_section(app, "header")$title, "Picked from Ask")
    expect_studio_clean(app)
  })

  it("[SMS-055] opens Ask with the traced card selected when Trace from here is clicked in card inspector", {
    app <- studio_driver("small")
    app$run_js(
      "document.querySelector('#studio-map [data-card=\"b\"]').dispatchEvent(new MouseEvent('click', { bubbles: true, detail: 1 }));"
    )
    app$wait_for_js("document.querySelector('.sms-inspector').hidden === false")
    studio_do(app, studio_click_js(".sms-inspector [data-sms-action='Trace from here']"))

    app$wait_for_js("document.querySelector('[data-sms-room-of=\"ask\"]').hidden === false")
    expect_identical(
      app$get_js("document.querySelector('[data-sms-q=\"trace\"] [data-sms-field=\"ids\"] select').value"),
      "u2"
    )
    expect_match(
      app$get_js("document.querySelector('.sms-ask-ans-title')?.textContent ?? ''"),
      "2 cards downstream of Review"
    )
    expect_highlighted(app, c("b", "c", "d"))
    expect_studio_clean(app)
  })

  it("[SMS-055] opens Ask again when Trace from here is clicked a second time, at once and with messages held", {
    app <- studio_driver("small")
    # The same trace is run by hand and the room is closed: Trace from here gives the same answer again
    app$run_js(pick_card_on_map_js("b"))
    app$wait_for_js("document.querySelector('.sms-inspector').hidden === false")
    studio_wait_step(app)
    open_ask(app)
    studio_do(app, studio_click_js("[data-sms-q='trace'] button[data-sms-collect]"))
    expect_match(app$get_js("document.querySelector('.sms-ask-ans-title').textContent"), "2 cards downstream of Review")
    click_now(app, "[data-sms-room='ask']")
    wait_ask_room(app, TRUE)

    studio_do(app, studio_click_js(".sms-inspector [data-sms-action='Trace from here']"))
    wait_ask_room(app, FALSE)
    expect_highlighted(app, c("b", "c", "d"))

    # Close it and click again: the answer is the same, the room opens again
    click_now(app, "[data-sms-room='ask']")
    wait_ask_room(app, TRUE)
    studio_do(app, studio_click_js(".sms-inspector [data-sms-action='Trace from here']"))
    wait_ask_room(app, FALSE)
    expect_identical(
      app$get_js("document.querySelector('[data-sms-q=\"trace\"] [data-sms-field=\"ids\"] select').value"),
      "u2"
    )

    # Held: the room stays shut until the answer is drawn, then opens
    click_now(app, "[data-sms-room='ask']")
    wait_ask_room(app, TRUE)
    hold_studio_messages(app)
    seq_held <- app$get_js(paste(
      studio_click_js(".sms-inspector [data-sms-action='Trace from here']"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, seq_held)
    expect_true(app$get_js("document.querySelector('[data-sms-room-of=\"ask\"]').hidden"))
    expect_identical(
      app$get_js(
        "document.querySelector('.sms-inspector [data-sms-action=\"Trace from here\"]').getAttribute('aria-busy')"
      ),
      "true"
    )
    release_studio_messages(app)
    studio_wait_step(app)
    wait_ask_room(app, FALSE)
    expect_null(
      app$get_js(
        "document.querySelector('.sms-inspector [data-sms-action=\"Trace from here\"]').getAttribute('aria-busy')"
      )
    )
    expect_highlighted(app, c("b", "c", "d"))
    expect_studio_clean(app)
  })

  it("[SMS-051] starts the Trace form on the card picked on the map, and keeps a pick of the person's own", {
    app <- studio_driver("small")
    app$run_js(pick_card_on_map_js("b"))
    app$wait_for_js("document.querySelector('.sms-inspector').hidden === false")
    studio_wait_step(app)
    open_ask(app)
    start_card <- "document.querySelector('[data-sms-q=\"trace\"] [data-sms-field=\"ids\"] select').value"
    expect_identical(app$get_js(start_card), "u2")

    # Another card picked while Ask is open: the form follows it
    app$run_js(pick_card_on_map_js("c"))
    app$wait_for_js(paste0(start_card, " === 'u3'"))
    studio_wait_step(app)
    expect_identical(app$get_js(start_card), "u3")

    # The person chooses another card; a later answer that does not change the target leaves it alone
    studio_do(
      app,
      paste(
        set_select_js("[data-sms-q='trace'] [data-sms-field='ids'] select", "u1"),
        switch_ask_js("orphans"),
        studio_click_js("[data-sms-q='orphans'] button[data-sms-collect]")
      )
    )
    expect_identical(app$get_js(start_card), "u1")
    expect_studio_clean(app)
  })

  it("[SMS-054] keeps a row button, its focus and its busy mark when the answer is drawn again", {
    app <- studio_driver("small")
    open_ask(app)
    studio_do(app, studio_click_js("[data-sms-q='trace'] button[data-sms-collect]"))
    row_btn <- ".sms-ask-table tbody tr:nth-child(2) .sms-ask-pick"
    same_btn <- sprintf("document.querySelector('%s') === window.__pick", row_btn)

    # A keyboard user's focus stays on the button when the same question is run again
    app$run_js(sprintf("window.__pick = document.querySelector('%s'); window.__pick.focus();", row_btn))
    studio_do(app, studio_click_js("[data-sms-q='trace'] button[data-sms-collect]"))
    expect_true(app$get_js(same_btn))
    expect_true(app$get_js("document.activeElement === window.__pick"))

    # A clicked button stays busy when an earlier answer is drawn, until its own answer is
    hold_studio_events(app)
    hold_studio_messages(app)
    seq_pick <- app$get_js(paste(
      studio_click_js("[data-sms-q='trace'] button[data-sms-collect]"),
      studio_click_js(row_btn),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    post_held_event <- function(i) {
      app$run_js(sprintf(
        "window.Shiny.setInputValue(%s.dataset.smsNs + 'event', window.__sms.heldEvents[%d], { priority: 'event' });",
        studio_root_js,
        i
      ))
    }
    deliver_held <- function(i) {
      app$run_js(sprintf(
        "%s.dispatchEvent(new CustomEvent('stagemap-studio:deliver', { detail: window.__sms.held[%d] }));",
        studio_root_js,
        i
      ))
    }
    post_held_event(0L)
    studio_wait_held(app, seq_pick - 1L)
    deliver_held(0L)
    expect_true(app$get_js(same_btn))
    expect_identical(app$get_js(sprintf("document.querySelector('%s').getAttribute('aria-busy')", row_btn)), "true")
    post_held_event(1L)
    studio_wait_held(app, seq_pick)
    deliver_held(1L)
    expect_null(app$get_js(sprintf("document.querySelector('%s').getAttribute('aria-busy')", row_btn)))

    # The same when the form is drawn again because another card was picked on the map
    release_studio_messages(app)
    app$run_js(
      sprintf(
        "%s.removeEventListener('stagemap-studio:send', window.__sms.eventHolder);",
        studio_root_js
      )
    )
    app$run_js(paste("window.__pick.focus();", pick_card_on_map_js("c")))
    app$wait_for_js(
      "document.querySelector('[data-sms-q=\"trace\"] [data-sms-field=\"ids\"] select').value === 'u3'"
    )
    studio_wait_step(app)
    expect_true(app$get_js(same_btn))
    expect_true(app$get_js("document.activeElement === window.__pick"))
    expect_studio_clean(app)
  })

  it("[SMS-056] announces the answer and the stale words in a status region and keeps the table out of it", {
    app <- studio_driver("small")
    live <- ".sms-ask-ans-slot > .sms-ask-live"
    expect_identical(app$get_js(sprintf("document.querySelector('%s').getAttribute('role')", live)), "status")
    expect_identical(app$get_js(sprintf("document.querySelector('%s').getAttribute('aria-live')", live)), "polite")
    app$run_js(sprintf("window.__live = document.querySelector('%s');", live))
    open_ask(app)
    studio_do(app, studio_click_js("[data-sms-q='trace'] button[data-sms-collect]"))
    expect_true(app$get_js("document.querySelector('.sms-ask-ans-slot > .sms-ask-live') === window.__live"))
    expect_match(app$get_js("window.__live.textContent"), "cards downstream of Draft")
    expect_false(app$get_js("window.__live.contains(document.querySelector('.sms-ask-table'))"))
    expect_false(app$get_js("window.__live.closest('.sms-ask-ans') !== null"))

    studio_do(app, paste(studio_title_js("Changed map"), "document.querySelector('.sms-title').blur();"))
    expect_match(app$get_js("window.__live.textContent"), "Map changed since: ask again", fixed = TRUE)

    # Clear empties the status region
    studio_do(app, studio_click_js(".sms-ask-ans [data-sms-action='Clear']"))
    expect_identical(app$get_js("window.__live.textContent"), "")
    expect_studio_clean(app)
  })

  it("[SMS-056] keeps the stale answer's words at 4.5:1 and does not fade the answer, in light and in dark", {
    app <- studio_driver("small")
    open_ask(app)
    studio_do(app, studio_click_js("[data-sms-q='trace'] button[data-sms-collect]"))
    studio_do(app, paste(studio_title_js("Changed map"), "document.querySelector('.sms-title').blur();"))
    expect_identical(app$get_js("document.querySelector('.sms-ask-ans')?.dataset.smsStale"), "true")
    light <- app$get_js(ask_contrast_js)
    click_now(app, ".sms-theme")
    app$wait_for_js(sprintf("%s.dataset.theme === 'dark'", studio_root_js))
    dark <- app$get_js(ask_contrast_js)
    for (theme in list(light, dark)) {
      expect_identical(theme$opacity, "1")
      expect_gte(theme$stale, 4.5)
      expect_gte(theme$call, 4.5)
      expect_gte(theme$title, 4.5)
      expect_gte(theme$heading, 4.5)
    }
  })

  it("[SMS-056] marks the answer stale and unlights the map on edit, and Clear removes the answer at once and held", {
    app <- studio_driver("small")
    open_ask(app)
    studio_do(app, studio_click_js("[data-sms-q='trace'] button[data-sms-collect]"))
    expect_highlighted(app, c("a", "b", "c", "d"))

    # Edit title -> answer becomes stale and map unlights
    studio_do(
      app,
      paste(
        studio_title_js("Changed map"),
        "document.querySelector('.sms-title').blur();"
      )
    )
    expect_identical(app$get_js("document.querySelector('.sms-ask-ans')?.dataset.smsStale"), "true")
    expect_match(
      app$get_js("document.querySelector('.sms-ask-stale')?.textContent ?? ''"),
      "Map changed since: ask again"
    )
    expect_highlighted(app, character())

    # Run again so Clear unlights too, then Clear at once after typing with messages held
    studio_do(app, studio_click_js("[data-sms-q='trace'] button[data-sms-collect]"))
    expect_highlighted(app, c("a", "b", "c", "d"))

    hold_studio_messages(app)
    seq_clear <- app$get_js(paste(
      studio_title_js("Before clear"),
      studio_click_js(".sms-ask-ans [data-sms-action='Clear']"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, seq_clear)
    expect_identical(
      app$get_js("document.querySelector('.sms-ask-ans [data-sms-action=\"Clear\"]').getAttribute('aria-busy')"),
      "true"
    )
    release_studio_messages(app)
    studio_wait_step(app)
    expect_null(app$get_js("document.querySelector('.sms-ask-ans')"))
    expect_highlighted(app, character())
    expect_identical(studio_section(app, "header")$title, "Before clear")
    expect_studio_clean(app)
  })

  it("[SMS-057] refuses to run on a broken map and points to Check", {
    app <- studio_driver("none")
    # Open the example template (which has 1 seeded broken link) and dismiss/open Ask
    studio_do(app, studio_click_js(".sms-start [data-sms-open='example']"))
    open_ask(app)
    studio_do(app, studio_click_js("[data-sms-q='trace'] button[data-sms-collect]"))

    expect_match(
      app$get_js("document.querySelector('.sms-ask-err')?.textContent ?? ''"),
      "Fix the problems under Check first",
      fixed = TRUE
    )
    expect_identical(studio_section(app, "notice")$tone, "problem")
    expect_studio_clean(app)
  })

  it("operates Ask with keyboard only and fits cleanly at phone width", {
    app <- studio_driver("small")
    studio_emulate(app, "width", 375L)

    # Open Ask via keyboard on dock button
    app$run_js("document.querySelector('[data-sms-room=\"ask\"]').focus()")
    studio_press(app, "Enter", key_code = 13L)
    app$wait_for_js("document.querySelector('[data-sms-room-of=\"ask\"]').hidden === false")

    # Keyboard-switch question radio with ArrowRight to Loose ends
    app$run_js("document.querySelector('.sms-ask-switch input[value=\"trace\"]').focus()")
    studio_press(app, "ArrowRight", key_code = 39L)
    expect_identical(app$get_js("document.querySelector('.sms-ask-switch input:checked').value"), "orphans")

    # Switch back to Trace, run, and verify no horizontal overflow at 375px
    app$run_js("document.querySelector('.sms-ask-switch input[value=\"trace\"]').click()")
    studio_do(app, studio_click_js("[data-sms-q='trace'] button[data-sms-collect]"))
    overflow <- app$get_js(
      "(() => { const b = document.querySelector('[data-sms-room-of=\"ask\"] .sms-room-body');
         return b.scrollWidth > b.clientWidth; })()"
    )
    expect_false(overflow)
    expect_studio_clean(app)
  })
})
