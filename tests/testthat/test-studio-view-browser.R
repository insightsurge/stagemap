skip_without_chrome()

# Browser tests for target selection, inspector head, hover hints, and keyboard-only actions.

describe("the studio target, inspector head, hint bar and keyboard", {
  it("[SMS-037] opens the inspector on card click and closes on second click, Close button or Escape", {
    app <- studio_driver("small")
    expect_true(studio_section(app, "inspector")$hidden)

    app$run_js(
      "document.querySelector('#studio-map [data-card=\"b\"]').dispatchEvent(new MouseEvent('click', { bubbles: true, detail: 1 }))"
    )
    app$wait_for_js("document.querySelector('.sms-inspector').hidden === false")
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-insp-sub').textContent"), "b")

    # Second click on same card clears target
    app$run_js(
      "document.querySelector('#studio-map [data-card=\"b\"]').dispatchEvent(new MouseEvent('click', { bubbles: true, detail: 1 }))"
    )
    app$wait_for_js("document.querySelector('.sms-inspector').hidden === true")

    # Close action button clears target
    app$run_js(
      "document.querySelector('#studio-map [data-card=\"a\"]').dispatchEvent(new MouseEvent('click', { bubbles: true, detail: 1 }))"
    )
    app$wait_for_js("document.querySelector('.sms-inspector').hidden === false")
    studio_do(app, studio_click_js(".sms-inspector .sms-insp-acts button"))
    expect_true(studio_section(app, "inspector")$hidden)

    # Escape from inside inspector clears target
    app$run_js(
      "document.querySelector('#studio-map [data-card=\"a\"]').dispatchEvent(new MouseEvent('click', { bubbles: true, detail: 1 }))"
    )
    app$wait_for_js("document.querySelector('.sms-inspector').hidden === false")
    app$run_js("document.querySelector('#studio-inspector-title').focus()")
    studio_press(app, "Escape", key_code = 27L)
    app$wait_for_js("document.querySelector('.sms-inspector').hidden === true")
    expect_studio_clean(app)
  })

  it("shows the hovered card or stage label from R in the hint bar", {
    app <- studio_driver("small")
    expect_true(app$get_js("document.querySelector('.sms-hint').hidden"))

    app$run_js(
      "document.querySelector('#studio-map').dispatchEvent(new CustomEvent('stagemap:hover', { bubbles: true, detail: { kind: 'card', id: 'b' } }))"
    )
    expect_false(app$get_js("document.querySelector('.sms-hint').hidden"))
    expect_match(app$get_js("document.querySelector('.sms-hint').textContent"), "Review", fixed = TRUE)

    app$run_js(
      "document.querySelector('#studio-map').dispatchEvent(new CustomEvent('stagemap:hover', { bubbles: true, detail: { kind: 'stage', id: 'ship' } }))"
    )
    expect_match(app$get_js("document.querySelector('.sms-hint').textContent"), "Ship", fixed = TRUE)

    app$run_js(
      "document.querySelector('#studio-map').dispatchEvent(new CustomEvent('stagemap:hover', { bubbles: true, detail: { kind: 'card', id: null } }))"
    )
    expect_true(app$get_js("document.querySelector('.sms-hint').hidden"))
    expect_studio_clean(app)
  })

  it("operates + Card, Stages menu and Undo with keyboard presses only", {
    app <- studio_driver("small")
    # Focus + Card and press Enter
    app$run_js("document.querySelector('[data-sms-action=\"+ Card\"]').focus()")
    since1 <- studio_stamp(app)
    studio_press(app, "Enter", key_code = 13L)
    studio_wait_step(app)
    studio_wait_map(app, since1)
    expect_identical(app$get_js("document.querySelectorAll('[data-card]').length"), 5L)

    # Focus Stages menu, open with Enter, ArrowDown, pick with Enter
    app$run_js("document.querySelector('[data-sms-menu=\"stages\"]').focus()")
    studio_press(app, "Enter", key_code = 13L)
    expect_false(app$get_js("document.querySelector('#studio-menu-stages').hidden"))
    studio_press(app, "ArrowDown", key_code = 40L)
    studio_press(app, "Enter", key_code = 13L)
    studio_wait_step(app)
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-insp-sub').textContent"), "check")

    # Undo via Ctrl+Z outside a text field
    app$run_js("document.querySelector('.sms-undo').focus()")
    since2 <- studio_stamp(app)
    studio_press(app, "z", modifiers = "ctrl", code = "KeyZ", key_code = 90L)
    studio_wait_step(app)
    studio_wait_map(app, since2)
    expect_identical(app$get_js("document.querySelectorAll('[data-card]').length"), 4L)
    expect_studio_clean(app)
  })
})
