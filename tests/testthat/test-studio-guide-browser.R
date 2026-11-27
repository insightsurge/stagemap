skip_without_chrome()

# Browser tests for the guide: the hint bar's next step, the "Try it" list, steps that tick on the server's proof (by
# real actions, in order and never early), Escape and the one-guide rule.

open_from_start <- function(app, template) {
  click_now(app, sprintf(".sms-start [data-sms-open='%s']", template))
  app$wait_for_js("document.querySelector('.sms-start').hidden === true")
  studio_wait_step(app)
  invisible(app)
}

pick_card_js <- function(id) {
  sprintf(
    "document.querySelector('#studio-map [data-card=\"%s\"]').dispatchEvent(new MouseEvent('click', { bubbles: true, detail: 1 }));",
    id
  )
}

# What the guide shows: the hint bar's words, the button's words, and each step's text and whether it has a tick.
guide_state <- function(app) {
  raw <- app$get_js(
    "JSON.stringify({
       hidden: document.querySelector('.sms-hint').hidden,
       hint: document.querySelector('.sms-hint-next').textContent,
       button: document.querySelector('.sms-try-btn').textContent,
       button_hidden: document.querySelector('.sms-try-btn').hidden,
       open: !document.querySelector('.sms-try').hidden,
       expanded: document.querySelector('.sms-try-btn').getAttribute('aria-expanded'),
       steps: [...document.querySelectorAll('.sms-try li')].map((li) => ({
         text: li.querySelector('.sms-try-text').textContent,
         done: li.dataset.smsDone !== undefined,
         word: li.querySelector('.sms-try-done')?.textContent ?? null,
         current: li.getAttribute('aria-current')
       }))
     })"
  )
  state <- jsonlite::fromJSON(raw, simplifyVector = FALSE)
  state$done <- vapply(state$steps, function(step) step$done, logical(1))
  state
}

# The value of the option of the select `selector` whose text is `text` (a card's uid, for the forms' selects).
option_value <- function(app, selector, text) {
  app$get_js(sprintf(
    "[...document.querySelector(%s).options].find((o) => o.textContent.includes(%s))?.value ?? null",
    jsonlite::toJSON(selector, auto_unbox = TRUE),
    jsonlite::toJSON(text, auto_unbox = TRUE)
  ))
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

describe("the studio guide", {
  it("[SMS-074] shows the next step and the count on the example, and no guide on other maps", {
    app <- studio_driver("none")
    open_from_start(app, "example")
    guide <- guide_state(app)
    expect_false(guide$hidden)
    expect_identical(guide$hint, "Next: Click round_dose() and set its status to Done.")
    expect_identical(guide$button, "Try it 1/6")
    expect_length(guide$steps, 6L)
    expect_identical(guide$done, c(TRUE, rep(FALSE, 5L)))
    expect_identical(guide$steps[[1L]]$word, "done")
    expect_null(guide$steps[[2L]]$word)
    expect_identical(guide$steps[[2L]]$current, "step")
    expect_false(guide$open)

    # Hovering the map says what is under the pointer, then the next step comes back
    app$run_js(
      "document.querySelector('#studio-map').dispatchEvent(new CustomEvent('stagemap:hover', { bubbles: true, detail: { kind: 'card', id: 'round_dose' } }))"
    )
    expect_false(
      grepl("^Next:", guide_state(app)$hint) &&
        app$get_js("getComputedStyle(document.querySelector('.sms-hint-next')).display !== 'none'")
    )
    app$run_js(
      "document.querySelector('#studio-map').dispatchEvent(new CustomEvent('stagemap:hover', { bubbles: true, detail: { kind: 'card', id: null } }))"
    )
    expect_identical(app$get_js("getComputedStyle(document.querySelector('.sms-hint-next')).display"), "block")

    # A map with no guide has no bar, no button and no list
    app2 <- studio_driver("none")
    open_from_start(app2, "blank")
    blank <- guide_state(app2)
    expect_true(blank$hidden)
    expect_true(blank$button_hidden)
    expect_identical(blank$button, "")
    expect_length(blank$steps, 0L)
    app3 <- studio_driver("small")
    expect_true(guide_state(app3)$hidden)
    expect_studio_clean(app)
    expect_studio_clean(app2)
    expect_studio_clean(app3)
  })

  it("[SMS-075] ticks each step when its action is done, never before, and keeps ticks after Undo", {
    app <- studio_driver("none")
    open_from_start(app, "example")
    expect_identical(guide_state(app)$done, c(TRUE, rep(FALSE, 5L)))

    # 2. round_dose() to Done
    app$run_js(pick_card_js("round_dose"))
    app$wait_for_js("document.querySelector('.sms-inspector [data-sms-field=\"status\"] input') !== null")
    expect_identical(guide_state(app)$done, c(TRUE, rep(FALSE, 5L)))
    studio_do(app, studio_click_js(".sms-inspector [data-sms-field='status'] input[value='done']"))
    guide <- guide_state(app)
    expect_identical(guide$done, c(TRUE, TRUE, rep(FALSE, 4L)))
    expect_identical(guide$hint, "Next: Select Log every call and connect it to calc_dose().")
    expect_identical(guide$button, "Try it 2/6")

    # 3. Log every call to calc_dose()
    app$run_js(pick_card_js("log_calls"))
    app$wait_for_js("document.querySelector('.sms-inspector .sms-insp-sub')?.textContent === 'log_calls'")
    to <- option_value(app, ".sms-inspector [data-sms-list='out'] [data-sms-field='to'] select", "calc_dose()")
    expect_false(is.null(to))
    studio_do(
      app,
      paste(
        set_select_js(".sms-inspector [data-sms-list='out'] [data-sms-field='to'] select", to),
        studio_click_js(".sms-inspector [data-sms-list='out'] [data-sms-action='Connect']")
      )
    )
    expect_identical(guide_state(app)$done, c(TRUE, TRUE, TRUE, rep(FALSE, 3L)))

    # 4. R code
    expect_false(guide_state(app)$done[[4L]])
    click_now(app, "[data-sms-room='code']")
    app$wait_for_js("document.querySelector('[data-sms-room-of=\"code\"]').hidden === false")
    studio_wait_step(app)
    expect_identical(guide_state(app)$done, c(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE))
    click_now(app, "[data-sms-close='code']")

    # A question is refused while the map has a problem, so the trace step is still open
    click_now(app, "[data-sms-room='ask']")
    app$wait_for_js("document.querySelector('[data-sms-room-of=\"ask\"]').hidden === false")
    scale <- option_value(app, "[data-sms-q='trace'] [data-sms-field='ids'] select", "Doses scale with weight")
    expect_false(is.null(scale))
    studio_do(
      app,
      paste(
        set_select_js("[data-sms-q='trace'] [data-sms-field='ids'] select", scale),
        studio_click_js("[data-sms-q='trace'] button[data-sms-collect]")
      )
    )
    expect_identical(guide_state(app)$done, c(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE))
    click_now(app, "[data-sms-close='ask']")

    # 5. The fix under Check (the refused question has opened that room)
    app$wait_for_js("document.querySelector('[data-sms-room-of=\"check\"]').hidden === false")
    studio_do(app, studio_click_js("[data-sms-room-of='check'] .sms-btn.sms-pri"))
    expect_identical(guide_state(app)$done, c(TRUE, TRUE, TRUE, TRUE, TRUE, FALSE))
    click_now(app, "[data-sms-close='check']")

    # 6. The trace, now that the map builds
    click_now(app, "[data-sms-room='ask']")
    app$wait_for_js("document.querySelector('[data-sms-room-of=\"ask\"]').hidden === false")
    studio_do(
      app,
      paste(
        set_select_js("[data-sms-q='trace'] [data-sms-field='ids'] select", scale),
        studio_click_js("[data-sms-q='trace'] button[data-sms-collect]")
      )
    )
    guide <- guide_state(app)
    expect_identical(guide$done, rep(TRUE, 6L))
    expect_identical(guide$button, "Try it 6/6")
    expect_identical(guide$hint, "Every step is done.")
    expect_true(all(vapply(guide$steps, function(step) identical(step$word, "done"), logical(1))))
    click_now(app, "[data-sms-close='ask']")

    # Undo does not take a tick back
    studio_do(app, studio_click_js(".sms-undo"))
    expect_identical(guide_state(app)$done, rep(TRUE, 6L))
    expect_studio_clean(app)
  })

  it("[SMS-075] ticks only when the server's answer is drawn, with messages held", {
    app <- studio_driver("none")
    open_from_start(app, "example")
    app$run_js(pick_card_js("round_dose"))
    app$wait_for_js("document.querySelector('.sms-inspector [data-sms-field=\"status\"] input') !== null")
    hold_studio_messages(app)
    seq <- app$get_js(paste(
      studio_click_js(".sms-inspector [data-sms-field='status'] input[value='done']"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, seq)
    expect_identical(guide_state(app)$button, "Try it 1/6")
    release_studio_messages(app)
    studio_wait_step(app)
    expect_identical(guide_state(app)$button, "Try it 2/6")
    expect_studio_clean(app)
  })

  it("[SMS-076] opens the list with its button, and Escape closes it with focus back on the button", {
    app <- studio_driver("none")
    open_from_start(app, "example")
    app$run_js("document.querySelector('.sms-try-btn').focus()")
    expect_false(guide_state(app)$open)
    studio_press(app, "Enter")
    guide <- guide_state(app)
    expect_true(guide$open)
    expect_identical(guide$expanded, "true")
    expect_identical(app$get_js("document.querySelector('.sms-try-btn').getAttribute('aria-controls')"), "studio-try")
    expect_identical(app$get_js("document.getElementById('studio-try-title').textContent"), "Try the studio")
    expect_identical(app$get_js("document.activeElement.className"), "sms-btn sms-try-btn")

    # Focus has moved on: Escape still closes the list, and does not take focus from where it is
    app$run_js("document.querySelector('.sms-title').focus()")
    studio_press(app, "Escape")
    expect_false(guide_state(app)$open)
    expect_identical(app$get_js("document.activeElement.className"), "sms-title")

    # Open again, press Escape on the button: focus stays there
    app$run_js("document.querySelector('.sms-try-btn').focus()")
    studio_press(app, "Enter")
    expect_true(guide_state(app)$open)
    studio_press(app, "Escape")
    guide <- guide_state(app)
    expect_false(guide$open)
    expect_identical(guide$expanded, "false")
    expect_identical(app$get_js("document.activeElement.className"), "sms-btn sms-try-btn")

    # Space opens and the button closes it
    studio_press(app, " ", code = "Space", key_code = 32L)
    expect_true(guide_state(app)$open)
    studio_press(app, " ", code = "Space", key_code = 32L)
    expect_false(guide_state(app)$open)
    expect_studio_clean(app)
  })

  it("[SMS-076] closes the list when the example is replaced by a map with no guide", {
    app <- studio_driver("none")
    open_from_start(app, "example")
    click_now(app, ".sms-try-btn")
    expect_true(guide_state(app)$open)
    click_now(app, "[data-sms-start='open']")
    app$wait_for_js("document.querySelector('.sms-start').hidden === false")
    studio_do(app, studio_click_js("[data-sms-open='blank']"))
    app$wait_for_js("document.querySelector('.sms-start').hidden === true")
    guide <- guide_state(app)
    expect_false(guide$open)
    expect_true(guide$hidden)
    expect_identical(guide$expanded, "false")
    expect_studio_clean(app)
  })
})
