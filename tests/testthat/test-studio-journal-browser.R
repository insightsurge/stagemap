skip_without_chrome()

# Browser tests for the journal ribbon and Undo: visibility, coalescing, at-once and held Undo, and entry targeting.

describe("the studio journal and undo", {
  it("[SMS-032] stays hidden until the first change, then shows numbered entries in order", {
    app <- studio_driver("small")
    expect_true(studio_section(app, "journal")$hidden)
    studio_do(app, paste(studio_title_js("First change"), "document.querySelector('.sms-title').blur();"))
    studio_do(app, studio_click_js("[data-sms-action='+ Card']"))
    j <- studio_section(app, "journal")
    expect_false(j$hidden)
    items <- unlist(app$get_js("[...document.querySelectorAll('.sms-ev-n')].map((n) => n.textContent)"))
    expect_identical(items, c("#1", "#2"))
    expect_studio_clean(app)
  })

  it("[SMS-033] joins consecutive edits of the same field and drops the entry when reverted", {
    app <- studio_driver("small")
    studio_do(app, paste(studio_title_js("Step one"), "document.querySelector('.sms-title').blur();"))
    studio_do(app, paste(studio_title_js("Step two"), "document.querySelector('.sms-title').blur();"))
    expect_identical(app$get_js("document.querySelectorAll('.sms-ev').length"), 1L)
    expect_match(studio_section(app, "journal")$text, "A small piece of work > Step two", fixed = TRUE)

    studio_do(app, paste(studio_title_js("A small piece of work"), "document.querySelector('.sms-title').blur();"))
    expect_true(studio_section(app, "journal")$hidden)
    expect_studio_clean(app)
  })

  it("[SMS-034] flushes a held edit before Undo at once and marks the undone entry", {
    app <- studio_driver("small")
    studio_do(app, studio_click_js("[data-sms-action='+ Card']"))
    studio_do(app, paste(studio_title_js("Held before undo"), studio_click_js(".sms-undo")))
    expect_identical(studio_section(app, "header")$map_name, "A small piece of work")
    app$run_js("document.querySelector('.sms-title').blur()")
    expect_identical(app$get_js("document.querySelector('.sms-title').value"), "A small piece of work")
    states <- unlist(app$get_js("[...document.querySelectorAll('.sms-ev')].map((n) => n.dataset.smsState)"))
    expect_identical(states, c("done", "undone"))
    expect_match(studio_section(app, "journal")$text, "undone", fixed = TRUE)
    expect_studio_clean(app)
  })

  it("[SMS-035] keeps Undo busy and disabled while server messages are held", {
    app <- studio_driver("small")
    studio_do(app, paste(studio_title_js("Before held undo"), "document.querySelector('.sms-title').blur();"))
    hold_studio_messages(app)
    sent <- app$get_js(paste(
      studio_click_js(".sms-undo"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, sent)
    expect_identical(app$get_js("document.querySelector('.sms-undo').getAttribute('aria-busy')"), "true")
    expect_identical(app$get_js("document.querySelector('.sms-undo').getAttribute('aria-disabled')"), "true")
    release_studio_messages(app)
    studio_wait_step(app)
    expect_null(app$get_js("document.querySelector('.sms-undo').getAttribute('aria-busy')"))
    expect_identical(app$get_js("document.querySelector('.sms-title').value"), "A small piece of work")
    expect_studio_clean(app)
  })

  it("[SMS-036] targets an earlier entry's row when clicked in the journal ribbon", {
    app <- studio_driver("small")
    studio_do(app, studio_click_js("[data-sms-action='+ Card']"))
    studio_do(app, studio_click_js("[data-sms-action='+ Stage']"))
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-kick').textContent"), "stage")

    studio_do(app, studio_click_js(".sms-ev-btn"))
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-kick').textContent"), "card")
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-insp-sub').textContent"), "card")
    expect_studio_clean(app)
  })
})
