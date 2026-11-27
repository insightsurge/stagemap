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

    journal_nodes <- function() {
      app$get_js("document.querySelectorAll('.sms-journal-list *').length")
    }
    before <- studio_counts(app)
    before_journal <- journal_nodes()
    expect_gt(before$listeners, 0L)
    expect_gt(before$observers, 0L)
    expect_gt(before$nodes, 0L)

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

      # Map redraw round: add a card and undo it
      since_add <- studio_stamp(app)
      studio_do(app, studio_click_js("[data-sms-action='+ Card']"))
      studio_wait_map(app, since_add)
      since_undo <- studio_stamp(app)
      studio_do(app, studio_click_js(".sms-undo"))
      studio_wait_map(app, since_undo)

      # Target round: pick a card and close inspector
      app$run_js(
        "document.querySelector('#studio-map [data-card=\"a\"]').dispatchEvent(new MouseEvent('click', { bubbles: true, detail: 1 }))"
      )
      app$wait_for_js("document.querySelector('.sms-inspector').hidden === false")
      studio_do(app, studio_click_js(".sms-inspector .sms-insp-acts button"))

      # Start card round: open from header and close
      click_now(app, "[data-sms-start='open']")
      app$wait_for_js("document.querySelector('.sms-start').hidden === false")
      click_now(app, "[data-sms-start='close']")
      app$wait_for_js("document.querySelector('.sms-start').hidden === true")
    }

    studio_wait_step(app)
    # Wait for the toast timer from any action to finish so pending timers settle to baseline.
    app$wait_for_js("document.querySelector('.sms-toast').dataset.smsOn === undefined")
    after <- studio_counts(app)
    after_journal <- journal_nodes()

    expect_identical(after$listeners, before$listeners)
    expect_identical(after$observers, before$observers)
    expect_identical(after$timers, before$timers)
    expect_identical(after$nodes - after_journal, before$nodes - before_journal)
    expect_lte(app$get_js("document.querySelectorAll('.sms-ev').length"), 50L)
    expect_studio_clean(app)
  })

  it("keeps listener, observer, timer and node counts flat across 30 inspector targets, edits and add-form opens", {
    app <- studio_driver("small")
    target_js <- function(kind, uid) {
      sprintf(
        "{ const b = document.createElement('button');
           b.type = 'button'; b.dataset.smsEvent = %s;
           document.querySelector('.sms-outline').append(b); b.click(); b.remove(); }",
        jsonlite::toJSON(
          jsonlite::toJSON(
            list(type = "target", data = list(kind = kind, uid = uid)),
            auto_unbox = TRUE,
            null = "null"
          ),
          auto_unbox = TRUE
        )
      )
    }
    # Warm-up across all 4 kinds (card u2, stage u5, lane u8, link u10) and an edit
    studio_do(app, target_js("card", "u2"))
    studio_do(
      app,
      paste(
        studio_type_js(".sms-inspector [data-sms-field='sub'] input", "Warm"),
        "document.querySelector('.sms-inspector [data-sms-field=\"sub\"] input').blur();"
      )
    )
    studio_do(app, target_js("stage", "u5"))
    studio_do(app, target_js("lane", "u8"))
    studio_do(app, target_js("link", "u10"))
    studio_do(app, studio_click_js(".sms-inspector .sms-insp-acts button"))
    studio_wait_step(app)
    app$wait_for_js("document.querySelector('.sms-toast').dataset.smsOn === undefined")

    journal_nodes <- function() {
      app$get_js("document.querySelectorAll('.sms-journal-list *').length")
    }
    # A pending timer (the held-text timer or a toast timeout) is not a leak: count once none is pending.
    app$wait_for_js("window.__smsCounts().timers === 0")
    before <- studio_counts(app)
    before_journal <- journal_nodes()

    targets <- list(c("card", "u2"), c("stage", "u5"), c("lane", "u8"), c("link", "u10"))
    for (i in seq_len(30L)) {
      t <- targets[[((i - 1L) %% length(targets)) + 1L]]
      studio_do(app, target_js(t[[1L]], t[[2L]]))
      # Open card add forms (Comes from & Goes to) and edit a field each round
      if (!identical(t[[1L]], "card")) {
        studio_do(app, target_js("card", "u2"))
      }
      studio_do(
        app,
        paste(
          studio_type_js(".sms-inspector [data-sms-field='sub'] input", sprintf("Edit %d", i)),
          "document.querySelector('.sms-inspector [data-sms-field=\"sub\"] input').blur();"
        )
      )
      app$run_js(
        "{ const s1 = document.querySelector('.sms-inspector [data-sms-list=\"in\"] [data-sms-field=\"from\"] select');
           const s2 = document.querySelector('.sms-inspector [data-sms-list=\"out\"] [data-sms-field=\"to\"] select');
           if (s1) { s1.focus(); s1.dispatchEvent(new Event('change', { bubbles: true })); }
           if (s2) { s2.focus(); s2.dispatchEvent(new Event('change', { bubbles: true })); } }"
      )
      studio_do(app, studio_click_js(".sms-inspector .sms-insp-acts button"))
    }

    studio_wait_step(app)
    app$wait_for_js("document.querySelector('.sms-toast').dataset.smsOn === undefined")
    app$wait_for_js("window.__smsCounts().timers === 0")
    after <- studio_counts(app)
    after_journal <- journal_nodes()

    expect_identical(after$listeners, before$listeners)
    expect_identical(after$observers, before$observers)
    expect_identical(after$timers, before$timers)
    expect_identical(after$nodes - after_journal, before$nodes - before_journal)
    expect_studio_clean(app)
  })

  it("[SMS-085] counts a synthetic listener, MutationObserver, pending timer and node when added and drops them when removed", {
    app <- studio_driver()
    base <- studio_counts(app)
    app$run_js(
      "{ const node = document.createElement('div');
         const fn = () => {};
         const obs = new MutationObserver(() => {});
         document.body.append(node);
         node.addEventListener('click', fn);
         obs.observe(node, { childList: true });
         const timer = setTimeout(() => {}, 60000);
         window.__smsCanary = { node, fn, obs, timer }; }"
    )
    added <- studio_counts(app)
    expect_identical(added$listeners, base$listeners + 1L)
    expect_identical(added$observers, base$observers + 1L)
    expect_identical(added$timers, base$timers + 1L)
    expect_identical(added$nodes, base$nodes + 1L)

    app$run_js(
      "{ const { node, fn, obs, timer } = window.__smsCanary;
         node.removeEventListener('click', fn);
         obs.disconnect();
         clearTimeout(timer);
         node.remove();
         delete window.__smsCanary; }"
    )
    removed <- studio_counts(app)
    expect_identical(removed$listeners, base$listeners)
    expect_identical(removed$observers, base$observers)
    expect_identical(removed$timers, base$timers)
    expect_identical(removed$nodes, base$nodes)
    expect_studio_clean(app)
  })

  it("keeps listener, observer, timer and node counts flat across 30 layout switches and 30 fixes and undos", {
    journal_nodes <- function(app) {
      app$get_js("document.querySelectorAll('.sms-journal-list *').length")
    }

    # 30 layout switches on a clean map
    app1 <- studio_driver("small")
    click_now(app1, ".sms-block [data-sms-room='map']")
    app1$wait_for_js("document.querySelector('[data-sms-room-of=\"map\"]').hidden === false")
    s0 <- studio_stamp(app1)
    studio_do(app1, studio_click_js("[data-sms-room-of='map'] input[type='radio'][value='levels']"))
    studio_wait_map(app1, s0)
    s1 <- studio_stamp(app1)
    studio_do(app1, studio_click_js("[data-sms-room-of='map'] input[type='radio'][value='grid']"))
    studio_wait_map(app1, s1)
    click_now(app1, "[data-sms-close='map']")
    studio_wait_step(app1)
    app1$wait_for_js("document.querySelector('.sms-toast').dataset.smsOn === undefined")

    app1$wait_for_js("window.__smsCounts().timers === 0")
    before1 <- studio_counts(app1)
    before_j1 <- journal_nodes(app1)
    for (i in seq_len(30L)) {
      click_now(app1, ".sms-block [data-sms-room='map']")
      app1$wait_for_js("document.querySelector('[data-sms-room-of=\"map\"]').hidden === false")
      sa <- studio_stamp(app1)
      studio_do(app1, studio_click_js("[data-sms-room-of='map'] input[type='radio'][value='levels']"))
      studio_wait_map(app1, sa)
      sb <- studio_stamp(app1)
      studio_do(app1, studio_click_js("[data-sms-room-of='map'] input[type='radio'][value='grid']"))
      studio_wait_map(app1, sb)
      click_now(app1, "[data-sms-close='map']")
    }
    studio_wait_step(app1)
    app1$wait_for_js("document.querySelector('.sms-toast').dataset.smsOn === undefined")
    app1$wait_for_js("window.__smsCounts().timers === 0")
    after1 <- studio_counts(app1)
    after_j1 <- journal_nodes(app1)
    expect_identical(after1$listeners, before1$listeners)
    expect_identical(after1$observers, before1$observers)
    expect_identical(after1$timers, before1$timers)
    expect_identical(after1$nodes - after_j1, before1$nodes - before_j1)
    expect_studio_clean(app1)
    app1$stop()

    # 30 fixes and undos on the broken example map
    app2 <- studio_driver("none")
    click_now(app2, ".sms-start .sms-opt")
    app2$wait_for_js(
      "document.querySelector('.sms-start').hidden === true &&
       document.querySelector('.sms-stamp').textContent.includes('1 problem')"
    )
    studio_wait_step(app2)
    click_now(app2, "[data-sms-room='check']")
    app2$wait_for_js("document.querySelector('[data-sms-room-of=\"check\"]').hidden === false")
    s2 <- studio_stamp(app2)
    studio_do(app2, studio_click_js("[data-sms-room-of='check'] .sms-chk .sms-pri"))
    studio_wait_map(app2, s2)
    studio_do(app2, studio_click_js(".sms-undo"))
    click_now(app2, "[data-sms-close='check']")
    studio_wait_step(app2)
    app2$wait_for_js("document.querySelector('.sms-toast').dataset.smsOn === undefined")

    app2$wait_for_js("window.__smsCounts().timers === 0")
    before2 <- studio_counts(app2)
    before_j2 <- journal_nodes(app2)
    for (i in seq_len(30L)) {
      click_now(app2, "[data-sms-room='check']")
      app2$wait_for_js("document.querySelector('[data-sms-room-of=\"check\"]').hidden === false")
      sc <- studio_stamp(app2)
      fix_sel <- if (i %% 2L == 1L) {
        "[data-sms-room-of='check'] .sms-danger"
      } else {
        "[data-sms-room-of='check'] .sms-chk .sms-pri"
      }
      studio_do(app2, studio_click_js(fix_sel))
      studio_wait_map(app2, sc)
      studio_do(app2, studio_click_js(".sms-undo"))
      click_now(app2, "[data-sms-close='check']")
    }

    studio_wait_step(app2)
    app2$wait_for_js("document.querySelector('.sms-toast').dataset.smsOn === undefined")
    app2$wait_for_js("window.__smsCounts().timers === 0")
    after2 <- studio_counts(app2)
    after_j2 <- journal_nodes(app2)

    expect_identical(after2$listeners, before2$listeners)
    expect_identical(after2$observers, before2$observers)
    expect_identical(after2$timers, before2$timers)
    expect_identical(after2$nodes - after_j2, before2$nodes - before_j2)
    expect_studio_clean(app2)
  })

  it("keeps listener, observer, timer and node counts flat across 30 code room opens, closes and copies", {
    app <- studio_driver("small")
    stub_studio_clipboard(app)
    studio_open_code(app)
    app$run_js(studio_copy_js)
    expect_identical(studio_wait_copy(app), "item")
    click_now(app, "[data-sms-close='code']")
    studio_wait_step(app)
    app$wait_for_js("document.querySelector('.sms-toast').dataset.smsOn === undefined")

    before <- studio_counts(app)
    for (i in seq_len(30L)) {
      studio_open_code(app)
      app$run_js(studio_copy_js)
      expect_identical(studio_wait_copy(app), "item")
      click_now(app, "[data-sms-close='code']")
    }

    studio_wait_step(app)
    app$wait_for_js("document.querySelector('.sms-toast').dataset.smsOn === undefined")
    after <- studio_counts(app)

    expect_identical(after$listeners, before$listeners)
    expect_identical(after$observers, before$observers)
    expect_identical(after$timers, before$timers)
    expect_identical(after$nodes, before$nodes)
    expect_studio_clean(app)
  })

  it("keeps listener, observer, timer and node counts flat across 30 Ask runs and clears", {
    app <- studio_driver("small")
    open_ask <- function() {
      click_now(app, "[data-sms-room='ask']")
      app$wait_for_js(
        "document.querySelector('[data-sms-room-of=\"ask\"]').hidden === false &&
         getComputedStyle(document.querySelector('.sms-tray')).transform === 'none'"
      )
    }
    close_ask <- function() {
      click_now(app, "[data-sms-close='ask']")
      app$wait_for_js("document.querySelector('[data-sms-room-of=\"ask\"]').hidden === true")
    }

    # Warm-up across all three questions and Clear
    open_ask()
    studio_do(app, studio_click_js("[data-sms-q='trace'] button[data-sms-collect]"))
    app$run_js("document.querySelector('.sms-ask-switch input[value=\"orphans\"]').click()")
    studio_do(app, studio_click_js("[data-sms-q='orphans'] button[data-sms-collect]"))
    app$run_js("document.querySelector('.sms-ask-switch input[value=\"missing\"]').click()")
    studio_do(app, studio_click_js("[data-sms-q='missing'] button[data-sms-collect]"))
    studio_do(app, studio_click_js(".sms-ask-ans [data-sms-action='Clear']"))
    app$run_js("document.querySelector('.sms-ask-switch input[value=\"trace\"]').click()")
    close_ask()
    studio_wait_step(app)
    app$wait_for_js("document.querySelector('.sms-toast').dataset.smsOn === undefined")

    before <- studio_counts(app)

    questions <- c("trace", "orphans", "missing")
    for (i in seq_len(30L)) {
      q <- questions[[((i - 1L) %% length(questions)) + 1L]]
      open_ask()
      app$run_js(sprintf("document.querySelector('.sms-ask-switch input[value=\"%s\"]').click()", q))
      studio_do(app, studio_click_js(sprintf("[data-sms-q='%s'] button[data-sms-collect]", q)))
      studio_do(app, studio_click_js(".sms-ask-ans [data-sms-action='Clear']"))
      close_ask()
    }

    studio_wait_step(app)
    app$wait_for_js("document.querySelector('.sms-toast').dataset.smsOn === undefined")
    after <- studio_counts(app)

    expect_identical(after$listeners, before$listeners)
    expect_identical(after$observers, before$observers)
    expect_identical(after$timers, before$timers)
    expect_identical(after$nodes, before$nodes)
    expect_studio_clean(app)
  })
  it("keeps listener, observer, timer and node counts flat across 30 rounds of the guide, hints, rooms and phone width", {
    app <- studio_driver("none")
    click_now(app, ".sms-start [data-sms-open='example']")
    app$wait_for_js("document.querySelector('.sms-start').hidden === true")
    studio_wait_step(app)
    hover_js <- function(id) {
      sprintf(
        "document.querySelector('#studio-map').dispatchEvent(new CustomEvent('stagemap:hover', { bubbles: true, detail: { kind: 'card', id: %s } }))",
        jsonlite::toJSON(id, auto_unbox = TRUE, null = "null")
      )
    }
    round <- function() {
      click_now(app, ".sms-try-btn")
      app$run_js(hover_js("round_dose"))
      app$run_js(hover_js(NULL))
      click_now(app, ".sms-try-btn")
      for (room in c("ask", "check", "code", "map")) {
        click_now(app, sprintf(".sms-block [data-sms-room='%s']", room))
        click_now(app, sprintf("[data-sms-close='%s']", room))
      }
      studio_emulate(app, "width", 390L)
      click_now(app, ".sms-block [data-sms-room='ask']")
      click_now(app, ".sms-block [data-sms-room='check']")
      click_now(app, "[data-sms-close='check']")
      studio_emulate(app, "width", 1280L)
    }
    round()
    studio_wait_step(app)
    app$wait_for_js("document.querySelector('.sms-toast').dataset.smsOn === undefined")
    app$wait_for_js("window.__smsCounts().timers === 0")
    before <- studio_counts(app)

    for (i in seq_len(30L)) {
      round()
    }

    studio_wait_step(app)
    app$wait_for_js("document.querySelector('.sms-toast').dataset.smsOn === undefined")
    app$wait_for_js("window.__smsCounts().timers === 0")
    after <- studio_counts(app)
    expect_identical(after$listeners, before$listeners)
    expect_identical(after$observers, before$observers)
    expect_identical(after$timers, before$timers)
    expect_identical(after$nodes, before$nodes)
    expect_studio_clean(app)
  })
})
