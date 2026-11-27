skip_without_chrome()

# Browser tests for server wiring: what a redraw keeps (player step, chosen stage, card pick), repeated identical
# refusals, and large-fixture message size and edit round-trip timing.

describe("what a studio redraw keeps", {
  it("[SMS-041] keeps the player step, chosen stage and picked card across map redraws", {
    app <- studio_driver("steps")
    app$wait_for_js("Boolean(document.getElementById('map_state')?.textContent)")

    # Move player to step 2 and add a card: step stays 2
    app$run_js("document.querySelector('#studio-map [data-k=\"step-1\"]').click()")
    app$wait_for_js("JSON.parse(document.getElementById('map_state').textContent).step?.[0] === 2")
    since1 <- studio_stamp(app)
    studio_do(app, studio_click_js("[data-sms-action='+ Card']"))
    studio_wait_map(app, since1)
    expect_identical(
      app$get_js("JSON.parse(document.getElementById('map_state').textContent).step?.[0]"),
      2L
    )

    # Choose stage "check" and add a card: stage stays "check"
    click_now(app, "[data-sms-menu='stages']")
    studio_do(app, studio_click_js("#studio-menu-stages [role='menuitem']:nth-child(2)"))
    app$wait_for_js("JSON.parse(document.getElementById('map_state').textContent).stage?.[0] === 'check'")
    since2 <- studio_stamp(app)
    studio_do(app, studio_click_js("[data-sms-action='+ Card']"))
    studio_wait_map(app, since2)
    expect_identical(
      app$get_js("JSON.parse(document.getElementById('map_state').textContent).stage?.[0]"),
      "check"
    )

    # Pick card "b" and edit the title: card "b" stays picked
    app$run_js(
      "document.querySelector('#studio-map [data-card=\"b\"]').dispatchEvent(new MouseEvent('click', { bubbles: true, detail: 1 }))"
    )
    app$wait_for_js("JSON.parse(document.getElementById('map_state').textContent).selected?.[0] === 'b'")
    since3 <- studio_stamp(app)
    studio_do(app, paste(studio_title_js("New title"), "document.querySelector('.sms-title').blur();"))
    studio_wait_map(app, since3)
    expect_identical(
      app$get_js("JSON.parse(document.getElementById('map_state').textContent).selected?.[0]"),
      "b"
    )
    expect_studio_clean(app)
  })
})

describe("repeated refusals and large fixture performance", {
  it("shows a repeated identical refusal again after an accepted change", {
    app <- studio_driver("small")
    studio_do(app, paste(studio_title_js(""), "document.querySelector('.sms-title').blur();"))
    expect_true(studio_section(app, "notice")$on)

    # Accepted change clears notice; wait until toast closes or send another refusal right after
    studio_do(app, paste(studio_title_js("Valid"), "document.querySelector('.sms-title').blur();"))
    app$run_js("delete document.querySelector('.sms-toast').dataset.smsOn;")
    studio_do(app, paste(studio_title_js(""), "document.querySelector('.sms-title').blur();"))
    notice <- studio_section(app, "notice")
    expect_true(notice$on)
    expect_match(notice$text, "cannot be blank")
    expect_studio_clean(app)
  })

  it("measures the first message size and edit round-trip time on studio_large()", {
    app <- studio_driver("large")
    session <- app$get_chromote_session()
    session$Page$addScriptToEvaluateOnNewDocument(
      source = paste(
        "window.__smsBench = { bytes: null };",
        "document.addEventListener('stagemap-studio:message', (e) => {",
        "  if (window.__smsBench.bytes === null) window.__smsBench.bytes = new Blob([JSON.stringify(e.detail)]).size;",
        "});"
      )
    )
    app$run_js("window.__smsBefore = true; location.reload();")
    app$wait_for_js("window.__smsBefore === undefined")
    studio_wait_drawn(app)
    bytes <- app$get_js("window.__smsBench.bytes")

    t0 <- proc.time()[["elapsed"]]
    studio_do(app, paste(studio_title_js("Large edited"), "document.querySelector('.sms-title').blur();"))
    elapsed_ms <- round((proc.time()[["elapsed"]] - t0) * 1000)

    cat(sprintf("\nstudio_large first message: %d bytes; title edit round-trip: %d ms\n", bytes, elapsed_ms))
    expect_gt(bytes, 0L)
    expect_studio_clean(app)
  })
})
