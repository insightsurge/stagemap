skip_without_chrome()

# Leak count for the studio: after a warm-up round, runs 30 rounds of each shell action and checks that the page's
# listeners, active observers, pending timers and DOM nodes settle back to the warm-up reading.

describe("the studio leak count", {
  it("[SMS-085] keeps listener, observer, pending timer and node counts flat across 30 rounds of shell actions", {
    app <- studio_driver()
    # Warm-up round so lazy caches, theme storage and room state are already initialised.
    studio_do(app, paste(studio_title_js("Warm up"), "document.querySelector('.sms-title').blur();"))
    studio_open_code(app)
    click_now(app, "[data-sms-close='code']")
    click_now(app, ".sms-theme")
    app$wait_for_js(sprintf("%s.dataset.theme === 'dark'", studio_root_js))
    click_now(app, ".sms-theme")
    app$wait_for_js(sprintf("%s.dataset.theme === 'light'", studio_root_js))
    studio_wait_step(app)

    before <- studio_counts(app)

    for (i in seq_len(30L)) {
      studio_do(
        app,
        paste(studio_title_js(sprintf("Round %d", i)), "document.querySelector('.sms-title').blur();")
      )
      studio_open_code(app)
      click_now(app, "[data-sms-close='code']")
      click_now(app, ".sms-theme")
      app$wait_for_js(sprintf("%s.dataset.theme === 'dark'", studio_root_js))
      click_now(app, ".sms-theme")
      app$wait_for_js(sprintf("%s.dataset.theme === 'light'", studio_root_js))
    }

    studio_wait_step(app)
    # Wait for the toast timer from any action to finish so pending timers settle to baseline.
    app$wait_for_js("document.querySelector('.sms-toast').dataset.smsOn === undefined")
    after <- studio_counts(app)

    expect_identical(after$listeners, before$listeners)
    expect_identical(after$observers, before$observers)
    expect_identical(after$timers, before$timers)
    expect_identical(after$nodes, before$nodes)
    expect_studio_clean(app)
  })
})
