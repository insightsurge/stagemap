skip_without_chrome()

# Browser tests for the studio's start card: initial opening on map = NULL, choosing templates, and confirmation when
# edits would be lost.

describe("the studio start card", {
  it("[SMS-022] opens on map = NULL as a modal dialog with focus on the first option", {
    app <- studio_driver("none")
    start <- app$get_js(
      "({ hidden: document.querySelector('.sms-start').hidden,
          role: document.querySelector('.sms-start').getAttribute('role'),
          modal: document.querySelector('.sms-start').getAttribute('aria-modal'),
          active: document.activeElement?.dataset?.smsOpen ?? null,
          topInert: document.querySelector('.sms-top').inert,
          blockInert: document.querySelector('.sms-block').inert,
          opts: [...document.querySelectorAll('.sms-start [data-sms-open]')].map((b) => b.dataset.smsOpen) })"
    )
    expect_false(start$hidden)
    expect_identical(start$role, "dialog")
    expect_identical(start$modal, "true")
    expect_identical(start$active, "example")
    expect_true(start$topInert)
    expect_true(start$blockInert)
    expect_identical(unlist(start$opts), c("example", "blank"))

    # Shift+Tab stays trapped inside the modal start card
    studio_press(app, "Tab", modifiers = "shift", code = "Tab", key_code = 9L)
    expect_identical(app$get_js("document.activeElement?.dataset?.smsOpen"), "blank")
    expect_studio_clean(app)
  })

  it("[SMS-023] loads the worked example from the start card with the problem stamp", {
    app <- studio_driver("none")
    app$run_js("document.querySelector('[data-sms-open=\"example\"]').focus()")
    studio_press(app, "Enter", key_code = 13L)
    app$wait_for_js("document.querySelector('.sms-start').hidden === true")
    studio_wait_step(app)
    expect_true(app$get_js("document.querySelector('.sms-start').hidden"))
    expect_false(app$get_js("document.querySelector('.sms-top').inert"))
    expect_false(app$get_js("document.querySelector('.sms-block').inert"))
    expect_identical(app$get_js("document.activeElement.className"), "sms-title")
    expect_identical(app$get_js("document.querySelectorAll('[data-card]').length"), 13L)
    expect_identical(app$get_js("document.querySelector('.sms-title').value"), "Dose calculator validation")
    stamp <- app$get_js(
      "({ text: document.querySelector('.sms-stamp').textContent,
          svg: document.querySelectorAll('.sms-stamp svg').length })"
    )
    expect_match(stamp$text, "The map shows the last version that worked: 1 problem", fixed = TRUE)
    expect_identical(stamp$svg, 1L)
    expect_studio_clean(app)
  })

  it("closes a header-opened start card with no edits once a template opens", {
    app <- studio_driver("small")
    click_now(app, "[data-sms-start='open']")
    app$wait_for_js("document.querySelector('.sms-start').hidden === false")
    since <- studio_stamp(app)
    studio_do(app, studio_click_js("[data-sms-open='blank']"))
    studio_wait_map(app, since)
    expect_true(app$get_js("document.querySelector('.sms-start').hidden"))
    expect_false(app$get_js("document.querySelector('.sms-top').inert"))
    expect_identical(app$get_js("document.querySelectorAll('[data-card]').length"), 1L)
    expect_studio_clean(app)
  })

  it("[SMS-024] loads the one-card blank map from the start card without a problem stamp", {
    app <- studio_driver("none")
    since <- studio_stamp(app)
    studio_do(app, studio_click_js("[data-sms-open='blank']"))
    studio_wait_map(app, since)
    expect_true(app$get_js("document.querySelector('.sms-start').hidden"))
    expect_identical(app$get_js("document.querySelectorAll('[data-card]').length"), 1L)
    expect_identical(studio_section(app, "header")$facts, "1 card in 1 stage and 1 lane, 0 links")
    expect_identical(app$get_js("document.querySelector('.sms-stamp').textContent"), "")
    expect_studio_clean(app)
  })

  it("[SMS-025] offers Your map when given one and asks confirmation before replacing edits", {
    app <- studio_driver("small")
    expect_true(app$get_js("document.querySelector('.sms-start').hidden"))
    studio_do(app, paste(studio_title_js("Edited"), "document.querySelector('.sms-title').blur();"))
    click_now(app, "[data-sms-start='open']")
    app$wait_for_js("document.querySelector('.sms-start').hidden === false")
    opts <- unlist(app$get_js(
      "[...document.querySelectorAll('.sms-start [data-sms-open]')].map((b) => b.dataset.smsOpen)"
    ))
    expect_identical(opts, c("example", "blank", "given"))

    # First click via keyboard asks confirmation, keeps edits and keeps focus on the option
    app$run_js("document.querySelector('[data-sms-open=\"blank\"]').focus()")
    studio_press(app, "Enter", key_code = 13L)
    studio_wait_step(app)
    expect_false(app$get_js("document.querySelector('.sms-start').hidden"))
    expect_identical(app$get_js("document.activeElement?.dataset?.smsOpen"), "blank")
    expect_identical(studio_section(app, "status")$rev, 1L)
    expect_match(
      app$get_js("document.querySelector('[data-sms-open=\"blank\"] small').textContent"),
      "Click again to replace your changes",
      fixed = TRUE
    )
    expect_match(studio_section(app, "notice")$text, "lose your changes")

    # Second click confirms and resets the document and journal
    since <- studio_stamp(app)
    studio_do(app, studio_click_js("[data-sms-open='blank']"))
    studio_wait_map(app, since)
    expect_true(app$get_js("document.querySelector('.sms-start').hidden"))
    expect_identical(app$get_js("document.querySelectorAll('[data-card]').length"), 1L)
    expect_true(studio_section(app, "journal")$hidden)
    expect_studio_clean(app)
  })
})
