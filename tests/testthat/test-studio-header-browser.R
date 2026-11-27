skip_without_chrome()

# Browser tests for the header actions (+ Card, + Stage, + Lane), facts count, and Stages/Lanes outline menus.

describe("the studio header and outline", {
  it("[SMS-026] updates facts counts when cards are added and undone", {
    app <- studio_driver("small")
    expect_identical(studio_section(app, "header")$facts, "4 cards in 3 stages and 2 lanes, 3 links")
    since <- studio_stamp(app)
    studio_do(app, studio_click_js("[data-sms-action='+ Card']"))
    studio_wait_map(app, since)
    expect_identical(studio_section(app, "header")$facts, "5 cards in 3 stages and 2 lanes, 3 links")

    since2 <- studio_stamp(app)
    studio_do(app, studio_click_js(".sms-undo"))
    studio_wait_map(app, since2)
    expect_identical(studio_section(app, "header")$facts, "4 cards in 3 stages and 2 lanes, 3 links")
    expect_studio_clean(app)
  })

  it("[SMS-027] flushes held title edits before + Card at once and keeps + Card busy while messages are held", {
    app <- studio_driver("small")
    since <- studio_stamp(app)
    sent <- studio_do(app, paste(studio_title_js("Added title"), studio_click_js("[data-sms-action='+ Card']")))
    expect_gt(sent, 1L)
    studio_wait_map(app, since)
    expect_identical(app$get_js("document.querySelectorAll('[data-card]').length"), 5L)
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-insp-sub').textContent"), "card")
    expect_identical(app$get_js("document.activeElement.id"), "studio-inspector-title")
    journal_text <- studio_section(app, "journal")$text
    expect_lt(regexpr("Added title", journal_text, fixed = TRUE), regexpr("Add card card", journal_text, fixed = TRUE))

    hold_studio_messages(app)
    held_sent <- app$get_js(paste(
      studio_title_js("Held title"),
      studio_click_js("[data-sms-action='+ Card']"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, held_sent)
    expect_identical(
      app$get_js("document.querySelector('[data-sms-action=\"+ Card\"]').getAttribute('aria-busy')"),
      "true"
    )
    expect_identical(
      app$get_js("document.querySelector('[data-sms-action=\"+ Card\"]').getAttribute('aria-disabled')"),
      "true"
    )
    release_studio_messages(app)
    studio_wait_step(app)
    expect_null(app$get_js("document.querySelector('[data-sms-action=\"+ Card\"]').getAttribute('aria-busy')"))
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-insp-sub').textContent"), "card-2")
    expect_studio_clean(app)
  })

  it("[SMS-028] adds a stage from the header and targets it", {
    app <- studio_driver("small")
    since <- studio_stamp(app)
    studio_do(app, studio_click_js("[data-sms-action='+ Stage']"))
    studio_wait_map(app, since)
    expect_identical(studio_section(app, "header")$facts, "4 cards in 4 stages and 2 lanes, 3 links")
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-kick').textContent"), "stage")
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-insp-sub').textContent"), "stage")
    expect_studio_clean(app)
  })

  it("[SMS-029] adds a lane from the header and targets it", {
    app <- studio_driver("small")
    since <- studio_stamp(app)
    studio_do(app, studio_click_js("[data-sms-action='+ Lane']"))
    studio_wait_map(app, since)
    expect_identical(studio_section(app, "header")$facts, "4 cards in 3 stages and 3 lanes, 3 links")
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-kick').textContent"), "lane")
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-insp-sub').textContent"), "lane")
    expect_studio_clean(app)
  })

  it("[SMS-030] opens the Stages outline menu, picks a stage onto the map, and closes on Escape", {
    app <- studio_driver("small")
    click_now(app, "[data-sms-menu='stages']")
    expect_identical(
      app$get_js("document.querySelector('[data-sms-menu=\"stages\"]').getAttribute('aria-expanded')"),
      "true"
    )
    expect_false(app$get_js("document.querySelector('#studio-menu-stages').hidden"))
    studio_press(app, "ArrowDown", key_code = 40L)
    expect_identical(app$get_js("document.activeElement.querySelector('.sms-menu-label')?.textContent"), "Check")

    studio_do(app, studio_click_js("#studio-menu-stages [role='menuitem']:nth-child(2)"))
    expect_true(app$get_js("document.querySelector('#studio-menu-stages').hidden"))
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-insp-sub').textContent"), "check")
    app$wait_for_js(
      "(() => { const t = document.getElementById('map_state')?.textContent;
         return t && JSON.parse(t).stage?.[0] === 'check'; })()"
    )

    click_now(app, "[data-sms-menu='stages']")
    studio_press(app, "Escape", key_code = 27L)
    expect_true(app$get_js("document.querySelector('#studio-menu-stages').hidden"))
    expect_identical(app$get_js("document.activeElement.dataset.smsMenu"), "stages")
    expect_studio_clean(app)
  })

  it("[SMS-031] opens the Lanes outline menu, picks a lane, and closes on Escape", {
    app <- studio_driver("small")
    click_now(app, "[data-sms-menu='lanes']")
    expect_identical(
      app$get_js("document.querySelector('[data-sms-menu=\"lanes\"]').getAttribute('aria-expanded')"),
      "true"
    )
    studio_do(app, studio_click_js("#studio-menu-lanes [role='menuitem']:first-child"))
    expect_true(app$get_js("document.querySelector('#studio-menu-lanes').hidden"))
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-kick').textContent"), "lane")

    click_now(app, "[data-sms-menu='lanes']")
    studio_press(app, "Escape", key_code = 27L)
    expect_true(app$get_js("document.querySelector('#studio-menu-lanes').hidden"))
    expect_identical(app$get_js("document.activeElement.dataset.smsMenu"), "lanes")
    expect_studio_clean(app)
  })

  it("keeps the card target in the inspector after add, Undo, add", {
    app <- studio_driver("small")
    since1 <- studio_stamp(app)
    studio_do(app, studio_click_js("[data-sms-action='+ Card']"))
    studio_wait_map(app, since1)

    since2 <- studio_stamp(app)
    studio_do(app, studio_click_js(".sms-undo"))
    studio_wait_map(app, since2)

    since3 <- studio_stamp(app)
    studio_do(app, studio_click_js("[data-sms-action='+ Card']"))
    studio_wait_map(app, since3)
    expect_false(app$get_js("document.querySelector('.sms-inspector').hidden"))
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-kick').textContent"), "card")
    expect_studio_clean(app)
  })
})
