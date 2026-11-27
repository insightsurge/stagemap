skip_without_chrome()

# Browser tests for the Map room: layout switches (grid, levels, dates) on small and large fixtures, grid options,
# dates hint, cascade clearing target on card deletion, at-once Copy and held messages, keyboard and phone width.

open_map_room <- function(app) {
  click_now(app, ".sms-block [data-sms-room='map']")
  app$wait_for_js(
    "document.querySelector('[data-sms-room-of=\"map\"]').hidden === false &&
     getComputedStyle(document.querySelector('.sms-tray')).transform === 'none'"
  )
  invisible(app)
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

expect_map_drawn_clean <- function(app) {
  info <- app$get_js(
    "(() => {
       const m = document.querySelector('#studio-map');
       const err = m?.querySelector('.sm-has-error, .stagemap-error, [data-stagemap-error], .html-widget-error');
       return {
         cards: m ? m.querySelectorAll('[data-card]').length : 0,
         hasErr: Boolean(err)
       };
     })()"
  )
  expect_gt(info$cards, 0L)
  expect_false(info$hasErr)
  expect_identical(studio_console(app), character())
}

describe("the Map room", {
  it("[SMS-066] [SMS-067] [SMS-068] updates cell_columns, bundle_links and legend on the map and in R code", {
    app <- studio_driver("small")
    expect_identical(
      app$get_js("document.querySelector('.sms-block [data-sms-room=\"map\"]').getAttribute('aria-expanded')"),
      "false"
    )
    expect_match(app$get_js("document.querySelector('.sms-block [data-sms-room=\"map\"]').textContent"), "Grid")

    open_map_room(app)
    expect_identical(
      app$get_js("document.querySelector('.sms-block [data-sms-room=\"map\"]').getAttribute('aria-expanded')"),
      "true"
    )

    # Cards per cell: 2, then auto, then back to default 1
    s1 <- studio_stamp(app)
    studio_do(app, set_select_js("[data-sms-room-of='map'] [data-sms-field='cell_columns'] select", "2"))
    studio_wait_map(app, s1)
    expect_match(app$get_js("document.querySelector('.sms-code').textContent"), "cell_columns = 2", fixed = TRUE)

    s2 <- studio_stamp(app)
    studio_do(app, set_select_js("[data-sms-room-of='map'] [data-sms-field='cell_columns'] select", "auto"))
    studio_wait_map(app, s2)
    expect_match(app$get_js("document.querySelector('.sms-code').textContent"), "cell_columns = \"auto\"", fixed = TRUE)

    s3 <- studio_stamp(app)
    studio_do(app, set_select_js("[data-sms-room-of='map'] [data-sms-field='cell_columns'] select", "1"))
    studio_wait_map(app, s3)
    expect_false(grepl("cell_columns", app$get_js("document.querySelector('.sms-code').textContent"), fixed = TRUE))

    # Bundle links toggle
    s4 <- studio_stamp(app)
    studio_do(app, studio_click_js("[data-sms-room-of='map'] [data-sms-field='bundle_links'] input"))
    studio_wait_map(app, s4)
    expect_match(app$get_js("document.querySelector('.sms-code').textContent"), "bundle_links = TRUE", fixed = TRUE)

    s5 <- studio_stamp(app)
    studio_do(app, studio_click_js("[data-sms-room-of='map'] [data-sms-field='bundle_links'] input"))
    studio_wait_map(app, s5)
    expect_false(grepl("bundle_links", app$get_js("document.querySelector('.sms-code').textContent"), fixed = TRUE))

    # Legend toggle changes the drawn legend DOM and R code
    legend_visible <- function() {
      app$get_js("document.querySelectorAll('#studio-map .sm-legend li').length > 0")
    }
    expect_true(legend_visible())
    s6 <- studio_stamp(app)
    studio_do(app, studio_click_js("[data-sms-room-of='map'] [data-sms-field='legend'] input"))
    studio_wait_map(app, s6)
    expect_false(legend_visible())
    expect_match(app$get_js("document.querySelector('.sms-code').textContent"), "legend = FALSE", fixed = TRUE)

    s7 <- studio_stamp(app)
    studio_do(app, studio_click_js("[data-sms-room-of='map'] [data-sms-field='legend'] input"))
    studio_wait_map(app, s7)
    expect_true(legend_visible())
    expect_false(grepl("legend =", app$get_js("document.querySelector('.sms-code').textContent"), fixed = TRUE))
    expect_studio_clean(app)
  })

  it("[SMS-064] [SMS-065] switches between grid, levels and dates, keeps card selection and shows dates hint", {
    app <- studio_driver("small")
    app$run_js(
      "document.querySelector('#studio-map [data-card=\"b\"]').dispatchEvent(new MouseEvent('click', { bubbles: true, detail: 1 }))"
    )
    app$wait_for_js("document.querySelector('.sms-inspector').hidden === false")
    open_map_room(app)

    # Levels layout
    s_lv <- studio_stamp(app)
    studio_do(app, studio_click_js("[data-sms-room-of='map'] input[type='radio'][value='levels']"))
    studio_wait_map(app, s_lv)
    expect_map_drawn_clean(app)
    expect_match(app$get_js("document.querySelector('.sms-block [data-sms-room=\"map\"]').textContent"), "Levels")
    expect_null(app$get_js("document.querySelector('[data-sms-room-of=\"map\"] [data-sms-field=\"cell_columns\"]')"))
    expect_null(app$get_js("document.querySelector('[data-sms-room-of=\"map\"] [data-sms-field=\"bundle_links\"]')"))
    expect_false(is.null(app$get_js(
      "document.querySelector('[data-sms-room-of=\"map\"] [data-sms-field=\"target\"]')"
    )))
    expect_match(app$get_js("document.querySelector('.sms-code').textContent"), "layout = \"levels\"", fixed = TRUE)
    expect_identical(
      app$get_js("document.querySelector('#studio-map [data-card=\"b\"]').getAttribute('aria-pressed')"),
      "true"
    )

    # Target selection in levels
    s_tgt <- studio_stamp(app)
    studio_do(app, set_select_js("[data-sms-room-of='map'] [data-sms-field='target'] select", "c"))
    studio_wait_map(app, s_tgt)
    expect_map_drawn_clean(app)
    expect_match(app$get_js("document.querySelector('.sms-code').textContent"), "target = \"c\"", fixed = TRUE)

    # Dates layout shows hint until a stage has a date
    s_dt <- studio_stamp(app)
    studio_do(app, studio_click_js("[data-sms-room-of='map'] input[type='radio'][value='dates']"))
    studio_wait_map(app, s_dt)
    expect_map_drawn_clean(app)
    expect_match(app$get_js("document.querySelector('.sms-block [data-sms-room=\"map\"]').textContent"), "Dates")
    expect_match(
      app$get_js(
        "document.querySelector('[data-sms-room-of=\"map\"] [data-sms-field=\"layout\"] .sms-fld-hint').textContent"
      ),
      "No stage has a date yet",
      fixed = TRUE
    )
    expect_identical(
      app$get_js("document.querySelector('#studio-map [data-card=\"b\"]').getAttribute('aria-pressed')"),
      "true"
    )

    # Give a stage a date via the inspector and verify the hint clears
    click_now(app, "[data-sms-menu='stages']")
    studio_do(app, studio_click_js("[data-sms-menu-box='stages'] [role='menuitem']"))
    s_date <- studio_stamp(app)
    studio_do(
      app,
      "{ const d = document.querySelector('.sms-inspector [data-sms-field=\"date\"] input');
         d.value = '2026-06-01'; d.dispatchEvent(new Event('change', { bubbles: true })); }"
    )
    studio_wait_map(app, s_date)
    expect_map_drawn_clean(app)
    expect_null(app$get_js(
      "document.querySelector('[data-sms-room-of=\"map\"] [data-sms-field=\"layout\"] .sms-fld-hint')"
    ))

    # Back to grid restores grid controls
    s_gr <- studio_stamp(app)
    studio_do(app, studio_click_js("[data-sms-room-of='map'] input[type='radio'][value='grid']"))
    studio_wait_map(app, s_gr)
    expect_map_drawn_clean(app)
    expect_false(is.null(app$get_js(
      "document.querySelector('[data-sms-room-of=\"map\"] [data-sms-field=\"cell_columns\"]')"
    )))
    expect_false(is.null(app$get_js(
      "document.querySelector('[data-sms-room-of=\"map\"] [data-sms-field=\"bundle_links\"]')"
    )))
    expect_studio_clean(app)
  })

  it("draws levels and dates cleanly on the large fixture", {
    app <- studio_driver("large")
    open_map_room(app)
    for (lay in c("levels", "dates", "grid")) {
      since <- studio_stamp(app)
      studio_do(app, studio_click_js(sprintf("[data-sms-room-of='map'] input[type='radio'][value='%s']", lay)))
      studio_wait_map(app, since)
      expect_map_drawn_clean(app)
    }
    expect_studio_clean(app)
  })

  it("clears levels target when the targeted card is removed and keeps building cleanly", {
    app <- studio_driver("small")
    open_map_room(app)
    s1 <- studio_stamp(app)
    studio_do(app, studio_click_js("[data-sms-room-of='map'] input[type='radio'][value='levels']"))
    studio_wait_map(app, s1)
    s2 <- studio_stamp(app)
    studio_do(app, set_select_js("[data-sms-room-of='map'] [data-sms-field='target'] select", "b"))
    studio_wait_map(app, s2)

    app$run_js(
      "document.querySelector('#studio-map [data-card=\"b\"]').dispatchEvent(new MouseEvent('click', { bubbles: true, detail: 1 }))"
    )
    app$wait_for_js("document.querySelector('.sms-inspector').hidden === false")
    s3 <- studio_stamp(app)
    studio_do(app, studio_click_js(".sms-inspector [data-sms-action='Remove card']"))
    studio_wait_map(app, s3)

    expect_identical(app$get_js("document.querySelector('.sms-stamp').textContent"), "")
    expect_identical(
      app$get_js("document.querySelector('[data-sms-room-of=\"map\"] [data-sms-field=\"target\"] select').value"),
      ""
    )
    expect_false(grepl("target =", app$get_js("document.querySelector('.sms-code').textContent"), fixed = TRUE))
    expect_studio_clean(app)
  })

  it("copies updated layout code when layout change and Copy happen in one run_js() call, and holds cleanly", {
    app <- studio_driver("small")
    stub_studio_clipboard(app)
    open_map_room(app)
    studio_open_code(app)

    since <- studio_stamp(app)
    app$run_js(paste(
      studio_click_js("[data-sms-room-of='map'] input[type='radio'][value='levels']"),
      studio_copy_js
    ))
    path <- studio_wait_copy(app)
    studio_wait_map(app, since)
    expect_identical(path, "item")
    copied <- studio_copied(app)
    expect_match(copied[[1L]]$text, "layout = \"levels\"", fixed = TRUE)

    # With messages held, Copy stays busy until layout ack arrives
    hold_studio_messages(app)
    sent <- app$get_js(sprintf(
      "(() => { %s; %s; return Number(%s.dataset.smsSent); })()",
      studio_click_js("[data-sms-room-of='map'] input[type='radio'][value='grid']"),
      studio_copy_js,
      studio_root_js
    ))
    expect_identical(app$get_js("document.querySelector('[data-sms-copy]').getAttribute('aria-busy')"), "true")
    studio_wait_held(app, sent)
    release_studio_messages(app)
    expect_identical(studio_wait_copy(app), "item")
    copied2 <- studio_copied(app)
    expect_false(grepl("layout = \"levels\"", copied2[[length(copied2)]]$text, fixed = TRUE))
    expect_studio_clean(app)
  })

  it("supports keyboard navigation and opens Map from the header at 375px phone width", {
    app <- studio_driver("small")
    app$run_js("document.querySelector('.sms-block [data-sms-room=\"map\"]').focus()")
    studio_press(app, "Enter", key_code = 13L)
    app$wait_for_js("document.querySelector('[data-sms-room-of=\"map\"]').hidden === false")
    expect_identical(app$get_js("document.activeElement.id"), "studio-room-map-title")

    studio_press(app, "Escape", key_code = 27L)
    app$wait_for_js("document.querySelector('[data-sms-room-of=\"map\"]').hidden === true")
    expect_identical(app$get_js("document.activeElement.dataset.smsRoom"), "map")

    studio_emulate(app, "width", 375L)
    expect_identical(
      app$get_js("getComputedStyle(document.querySelector('.sms-block [data-sms-room=\"map\"]')).display"),
      "none"
    )
    expect_true(app$get_js("getComputedStyle(document.querySelector('.sms-phone-map')).display !== 'none'"))
    click_now(app, ".sms-phone-map")
    app$wait_for_js("document.querySelector('[data-sms-room-of=\"map\"]').hidden === false")
    expect_studio_clean(app)
  })
})
