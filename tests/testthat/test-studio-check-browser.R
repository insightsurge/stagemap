skip_without_chrome()

# Browser tests for the Check room: R's error lines, located fault cards, Show and Fix actions (at once and with
# messages held), title-block count, Done refusal opening Check, broken-map code note, keyboard and phone layout.

open_example_from_start <- function(app) {
  click_now(app, ".sms-start .sms-opt")
  app$wait_for_js(
    "document.querySelector('.sms-start').hidden === true &&
     document.querySelector('.sms-stamp').textContent.includes('1 problem')"
  )
  studio_wait_step(app)
  invisible(app)
}

open_check_room <- function(app) {
  click_now(app, "[data-sms-room='check']")
  app$wait_for_js(
    "document.querySelector('[data-sms-room-of=\"check\"]').hidden === false &&
     getComputedStyle(document.querySelector('.sms-tray')).transform === 'none'"
  )
  invisible(app)
}

# Opens the inspector of the example's card `calc_dose` and blanks its label, which gives the map a second fault.
# `send` flushes the held text at once (blur); without it the text stays held until a click flushes it.
blank_calc_dose_label_js <- function(send = TRUE) {
  paste(
    studio_type_js(".sms-inspector [data-sms-field='label'] input", ""),
    if (send) "document.querySelector('.sms-inspector [data-sms-field=\"label\"] input').blur();"
  )
}

open_calc_dose <- function(app) {
  app$run_js(
    "document.querySelector('#studio-map [data-card=\"calc_dose\"]').dispatchEvent(new MouseEvent('click', { bubbles: true, detail: 1 }))"
  )
  app$wait_for_js("document.querySelector('.sms-inspector [data-sms-field=\"label\"] input') !== null")
  invisible(app)
}

# JavaScript that finds the element `selector` (quoted safely), for the lines of a test that need it more than once.
find_js <- function(selector) {
  sprintf("document.querySelector(%s)", jsonlite::toJSON(selector, auto_unbox = TRUE))
}

# Delivers the oldest held message only (hold_studio_messages() keeps the rest held).
deliver_one_held_message_js <- paste0(
  "{ const m = window.__sms.held.shift();
     ",
  studio_root_js,
  ".dispatchEvent(new CustomEvent('stagemap-studio:deliver', { detail: m })); }"
)

describe("the Check room", {
  it("[SMS-058] [SMS-059] [SMS-061] shows R's lines and fault cards, fixes the example problem and turns clean", {
    app <- studio_driver("none")
    open_example_from_start(app)

    expect_identical(app$get_js("document.querySelector('[data-sms-room=\"check\"]').dataset.smsState"), "bad")
    expect_match(app$get_js("document.querySelector('[data-sms-room=\"check\"] .sms-val').textContent"), "1 problem")

    open_check_room(app)
    check_info <- app$get_js(
      "(() => {
        const body = document.querySelector('[data-sms-room-of=\"check\"] .sms-room-body');
        const rBox = body.querySelector('.sms-check-r');
        const fault = body.querySelector('.sms-chk');
        const srMarks = [...body.querySelectorAll('.sms-check-line .sms-sr')].map((n) => n.textContent);
        const order = rBox && fault ? Boolean(rBox.compareDocumentPosition(fault) & Node.DOCUMENT_POSITION_FOLLOWING) : false;
        return {
          head: body.querySelector('.sms-check-r-title')?.textContent ?? '',
          linesText: body.querySelector('.sms-check-lines')?.textContent ?? '',
          srMarks,
          faultText: body.querySelector('.sms-chk-text')?.textContent ?? '',
          order
        };
      })()"
    )
    expect_true(check_info$order)
    expect_match(check_info$head, "do not agree", fixed = TRUE)
    expect_match(check_info$linesText, "calc_does", fixed = TRUE)
    expect_true("Error: " %in% unlist(check_info$srMarks))
    expect_true("Info: " %in% unlist(check_info$srMarks))
    expect_match(check_info$faultText, "calc_does", fixed = TRUE)

    since <- studio_stamp(app)
    studio_do(app, studio_click_js("[data-sms-room-of='check'] [data-sms-action='Use \"calc_dose\"']"))
    studio_wait_map(app, since)

    expect_identical(app$get_js("document.querySelector('.sms-stamp').textContent"), "")
    expect_identical(app$get_js("document.querySelector('[data-sms-room=\"check\"]').dataset.smsState"), "good")
    expect_identical(app$get_js("document.querySelector('[data-sms-room=\"check\"] .sms-val').textContent"), "Clean")
    expect_identical(
      app$get_js("document.querySelector('[data-sms-room-of=\"check\"] .sms-check-clean-text').textContent"),
      "stage_map() accepts this map."
    )
    expect_identical(app$get_js("document.querySelectorAll('[data-sms-room-of=\"check\"] .sms-chk').length"), 0L)
    expect_match(app$get_js("document.querySelector('.sms-journal').textContent"), "Fix", fixed = TRUE)
    expect_match(app$get_js("document.querySelector('.sms-code').textContent"), "calc_dose", fixed = TRUE)
    expect_studio_clean(app)
  })

  it("[SMS-060] applies a fix at once after held typing and keeps the button busy while messages are held", {
    # At once: type a title and click a fix in one run_js() call
    app <- studio_driver("none")
    open_example_from_start(app)
    open_check_room(app)
    since1 <- studio_stamp(app)
    studio_do(
      app,
      paste(
        studio_title_js("Checked map"),
        studio_click_js("[data-sms-room-of='check'] [data-sms-action='Use \"calc_dose\"']")
      )
    )
    studio_wait_map(app, since1)
    expect_identical(app$get_js("document.querySelector('.sms-title').value"), "Checked map")
    expect_identical(app$get_js("document.querySelector('.sms-stamp').textContent"), "")
    expect_studio_clean(app)

    # On a fresh broken map, apply a fix at once after held typing with messages held
    app2 <- studio_driver("none")
    open_example_from_start(app2)
    open_check_room(app2)
    hold_studio_messages(app2)
    since2 <- studio_stamp(app2)
    sent <- app2$get_js(sprintf(
      "(() => { %s; %s; return Number(%s.dataset.smsSent); })()",
      studio_title_js("Held checked map"),
      studio_click_js("[data-sms-room-of='check'] .sms-chk .sms-pri"),
      studio_root_js
    ))
    expect_identical(
      app2$get_js("document.querySelector('[data-sms-room-of=\"check\"] .sms-chk .sms-pri').getAttribute('aria-busy')"),
      "true"
    )
    expect_identical(
      app2$get_js(
        "document.querySelector('[data-sms-room-of=\"check\"] .sms-chk .sms-pri').getAttribute('aria-disabled')"
      ),
      "true"
    )
    studio_wait_held(app2, sent)
    release_studio_messages(app2)
    studio_wait_step(app2)
    studio_wait_map(app2, since2)
    expect_identical(app2$get_js("document.querySelector('.sms-title').value"), "Held checked map")
    expect_identical(app2$get_js("document.querySelector('.sms-stamp').textContent"), "")
    expect_studio_clean(app2)
  })

  it("locates a duplicate id typed right before opening Check in one run_js() call", {
    app <- studio_driver("small")
    app$run_js(
      "document.querySelector('#studio-map [data-card=\"a\"]').dispatchEvent(new MouseEvent('click', { bubbles: true, detail: 1 }))"
    )
    app$wait_for_js("document.querySelector('.sms-inspector').hidden === false")

    studio_do(
      app,
      paste(
        studio_type_js(".sms-inspector [data-sms-field='id'] input", "b"),
        studio_click_js("[data-sms-room='check']")
      )
    )
    app$wait_for_js("document.querySelector('[data-sms-room-of=\"check\"]').hidden === false")
    expect_match(app$get_js("document.querySelector('.sms-stamp').textContent"), "problems")
    expect_match(
      app$get_js("document.querySelector('[data-sms-room-of=\"check\"] .sms-room-body').textContent"),
      "Another card also has the id \"b\"",
      fixed = TRUE
    )
    expect_studio_clean(app)
  })

  it("handles two quick fix clicks at once: applied once, second reports the problem is gone", {
    app <- studio_driver("none")
    open_example_from_start(app)
    open_check_room(app)

    # Clicking the same button twice in one JS call is gated by aria-disabled
    record_studio_events(app)
    since1 <- studio_stamp(app)
    studio_do(
      app,
      paste(
        studio_click_js("[data-sms-room-of='check'] [data-sms-action='Use \"calc_dose\"']"),
        studio_click_js("[data-sms-room-of='check'] [data-sms-action='Use \"calc_dose\"']")
      )
    )
    studio_wait_map(app, since1)
    fix_events <- Filter(function(e) identical(e$type, "fix"), studio_sent(app))
    expect_length(fix_events, 1L)

    # Undo and send two distinct fixes on the same fault card in one JS call with events held
    studio_do(app, studio_click_js(".sms-undo"))
    expect_match(app$get_js("document.querySelector('.sms-stamp').textContent"), "1 problem")

    hold_studio_events(app)
    app$run_js(paste(
      studio_click_js("[data-sms-room-of='check'] [data-sms-action='Use \"calc_dose\"']"),
      studio_click_js("[data-sms-room-of='check'] [data-sms-action='Remove link']")
    ))
    wait_studio_held(app, "events", 2L)
    release_studio_events(app)
    studio_wait_step(app)
    expect_match(
      app$get_js("document.querySelector('.sms-toast-text').textContent"),
      "That problem is gone",
      fixed = TRUE
    )
    expect_identical(app$get_js("document.querySelector('.sms-stamp').textContent"), "")
    expect_studio_clean(app)
  })

  it("Show targets the faulty row and marks its field in the inspector", {
    app <- studio_driver("none")
    open_example_from_start(app)
    open_check_room(app)

    studio_do(app, studio_click_js("[data-sms-room-of='check'] [data-sms-action='Show']"))
    expect_false(app$get_js("document.querySelector('.sms-inspector').hidden"))
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-kick').textContent"), "link")
    expect_identical(
      app$get_js(
        "document.querySelector('.sms-inspector [data-sms-field=\"to\"] select').getAttribute('aria-invalid')"
      ),
      "true"
    )
    expect_match(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"to\"] .sms-err').textContent"),
      "calc_does",
      fixed = TRUE
    )
    expect_studio_clean(app)
  })

  it("[SMS-062] refuses Done on a broken map and opens Check", {
    app <- studio_driver("none")
    open_example_from_start(app)
    expect_true(app$get_js("document.querySelector('[data-sms-room-of=\"check\"]').hidden"))

    studio_do(app, studio_click_js(".sms-done"))
    expect_false(studio_section(app, "status")$closed)
    expect_match(
      app$get_js("document.querySelector('.sms-toast-text').textContent"),
      "Fix the problems in Check",
      fixed = TRUE
    )
    expect_false(app$get_js("document.querySelector('[data-sms-room-of=\"check\"]').hidden"))
    expect_false(app$get_js("document.querySelector('[data-sms-room-of=\"check\"]').inert"))
    expect_studio_clean(app)
  })

  it("[SMS-063] marks the R code view when the map has a fault", {
    skip_if(is.null(studio_room_code_view(studio_state_new())$problem), "code room problem note waits for PR 9")
    app <- studio_driver("none")
    open_example_from_start(app)
    studio_open_code(app)
    expect_match(
      app$get_js("document.querySelector('.sms-code-note').textContent"),
      "stage_map() stops on this map: see Check",
      fixed = TRUE
    )
    expect_studio_clean(app)
  })

  it("operates Check with keyboard only and at 375px phone width", {
    app <- studio_driver("none")
    open_example_from_start(app)
    app$run_js("document.querySelector('[data-sms-room=\"check\"]').focus()")
    studio_press(app, "Enter", key_code = 13L)
    app$wait_for_js("document.querySelector('[data-sms-room-of=\"check\"]').hidden === false")
    expect_identical(app$get_js("document.activeElement.id"), "studio-room-check-title")

    studio_press(app, "Escape", key_code = 27L)
    app$wait_for_js("document.querySelector('[data-sms-room-of=\"check\"]').hidden === true")
    expect_identical(app$get_js("document.activeElement.dataset.smsRoom"), "check")

    studio_emulate(app, "width", 375L)
    open_check_room(app)
    overflow <- app$get_js(
      "(() => { const b = document.querySelector('[data-sms-room-of=\"check\"] .sms-room-body');
         return b.scrollWidth > b.clientWidth; })()"
    )
    expect_false(overflow)
    expect_studio_clean(app)
  })
  it("keeps one status line across renders that says the count and the clean line", {
    app <- studio_driver("none")
    open_example_from_start(app)
    open_check_room(app)
    status_js <- "document.querySelector('[data-sms-room-of=\"check\"] [role=\"status\"]')"
    expect_identical(
      app$get_js(sprintf("document.querySelectorAll('[data-sms-room-of=\"check\"] [role=\"status\"]').length")),
      1L
    )
    expect_identical(app$get_js(sprintf("%s.textContent", status_js)), "1 problem")
    # Nothing in the room's rebuilt content is a live region, so a redraw does not read every card again
    expect_identical(
      app$get_js(
        "document.querySelectorAll('[data-sms-room-of=\"check\"] .sms-check-body [aria-live], [data-sms-room-of=\"check\"] .sms-check-body [role=\"status\"]').length"
      ),
      0L
    )
    app$run_js(sprintf("window.__smsStatusNode = %s;", status_js))

    use <- "[data-sms-room-of='check'] [data-sms-action='Use \"calc_dose\"']"
    studio_do(app, paste0(find_js(use), ".focus();", studio_click_js(use)))
    # The only fault goes with the focused button: focus lands on the room's heading
    expect_identical(app$get_js("document.activeElement.id"), "studio-room-check-title")
    expect_true(app$get_js(sprintf("%s === window.__smsStatusNode && window.__smsStatusNode.isConnected", status_js)))
    expect_identical(app$get_js(sprintf("%s.textContent", status_js)), "stage_map() accepts this map.")

    # A new problem arriving while the room is open is announced through the same line
    open_calc_dose(app)
    studio_do(app, blank_calc_dose_label_js())
    expect_true(app$get_js(sprintf("%s === window.__smsStatusNode", status_js)))
    expect_identical(app$get_js(sprintf("%s.textContent", status_js)), "1 problem")
    expect_studio_clean(app)
  })

  it("moves focus to the next fault's first control after a fix", {
    app <- studio_driver("none")
    open_example_from_start(app)
    open_calc_dose(app)
    studio_do(app, blank_calc_dose_label_js())
    open_check_room(app)
    expect_identical(app$get_js("document.querySelectorAll('[data-sms-room-of=\"check\"] .sms-chk').length"), 2L)

    use <- "[data-sms-room-of='check'] [data-sms-action='Use \"calc_dose\"']"
    studio_do(app, paste0(find_js(use), ".focus();", studio_click_js(use)))
    expect_identical(app$get_js("document.querySelectorAll('[data-sms-room-of=\"check\"] .sms-chk').length"), 1L)
    expect_identical(
      app$get_js("document.activeElement.closest('.sms-chk')?.dataset.smsFaultId ?? null"),
      app$get_js("document.querySelector('[data-sms-room-of=\"check\"] .sms-chk').dataset.smsFaultId")
    )
    expect_identical(app$get_js("document.activeElement.dataset.smsAction"), "Show")

    expect_studio_clean(app)
  })

  it("names every fault card and describes each of its buttons by the fault's text", {
    app <- studio_driver("none")
    open_example_from_start(app)
    open_calc_dose(app)
    studio_do(app, blank_calc_dose_label_js())
    open_check_room(app)
    info <- app$get_js(
      "(() => [...document.querySelectorAll('[data-sms-room-of=\"check\"] .sms-chk')].map((card) => {
         const name = document.getElementById(card.getAttribute('aria-labelledby'))?.textContent ?? null;
         const buttons = [...card.querySelectorAll('button')];
         return {
           name,
           text: card.querySelector('.sms-chk-text').textContent,
           described: buttons.map((b) => document.getElementById(b.getAttribute('aria-describedby'))?.textContent ?? null),
           buttons: buttons.length
         };
       }))()"
    )
    expect_length(info, 2L)
    names <- vapply(info, function(card) card$name, "")
    expect_false(anyDuplicated(names) > 0L)
    for (card in info) {
      expect_identical(card$name, card$text)
      expect_gt(card$buttons, 0L)
      expect_true(all(unlist(card$described) == card$text))
    }
    ids <- unlist(app$get_js(
      "[...document.querySelectorAll('[data-sms-room-of=\"check\"] .sms-chk-text')].map((n) => n.id)"
    ))
    expect_false(anyDuplicated(ids) > 0L)
    expect_studio_clean(app)
  })

  it("keeps a clicked fix busy and the focused button put when an earlier answer changes the check section", {
    app <- studio_driver("none")
    open_example_from_start(app)
    open_calc_dose(app)
    open_check_room(app)
    use <- "[data-sms-room-of='check'] [data-sms-action='Use \"calc_dose\"']"
    remove_btn <- "[data-sms-room-of='check'] [data-sms-action='Remove link']"
    app$run_js(sprintf("window.__smsUse = %s;", find_js(use)))

    # The blanked label goes out first and its answer is held; then the fix is clicked and its answer is held too. The
    # first answer changes the check section (a second card), the second answers the fix.
    hold_studio_messages(app)
    app$run_js(paste(
      blank_calc_dose_label_js(),
      paste0(find_js(remove_btn), ".focus();")
    ))
    wait_studio_held(app, "messages", 1L)
    sent <- app$get_js(sprintf(
      "(() => { %s; return Number(%s.dataset.smsSent); })()",
      studio_click_js(use),
      studio_root_js
    ))
    expect_identical(app$get_js("window.__smsUse.getAttribute('aria-busy')"), "true")
    wait_studio_held(app, "messages", 2L)
    studio_wait_held(app, sent)

    app$run_js(deliver_one_held_message_js)
    # The first answer drew a second card; the clicked button is still the same busy node, and focus did not move
    expect_identical(app$get_js("document.querySelectorAll('[data-sms-room-of=\"check\"] .sms-chk').length"), 2L)
    expect_true(app$get_js(sprintf("%s === window.__smsUse", find_js(use))))
    expect_identical(app$get_js("window.__smsUse.getAttribute('aria-busy')"), "true")
    expect_identical(app$get_js("window.__smsUse.getAttribute('aria-disabled')"), "true")
    expect_true(app$get_js(sprintf("document.activeElement === %s", find_js(remove_btn))))

    release_studio_messages(app)
    studio_wait_step(app)
    expect_identical(app$get_js(sprintf("%s.querySelectorAll('[data-sms-wait-seq]').length", studio_root_js)), 0L)
    expect_studio_clean(app)
  })

  it("writes its words from the boot labels, not from the script", {
    app <- studio_driver("none")
    out <- app$get_js(
      "(async () => {
         const src = document.querySelector('script[src*=\"studio.js\"]').src;
         const mod = await import(new URL('js/room-check.js', src));
         const labels = { clean: 'L-clean', info: 'L-info:', error: 'L-error:', show: 'L-show', fix_prefix: 'L-fix:',
           r_message: 'L-rmsg', notes: 'L-notes', problem_one: 'L-one', problem_many: 'L-many' };
         const run = (check) => {
           const el = document.createElement('div');
           document.body.append(el);
           mod.render(el, check, { labels });
           const out = {
             text: el.textContent,
             status: el.querySelector('[role=\"status\"]').textContent,
             box: el.querySelector('.sms-check-r')?.getAttribute('aria-label') ?? null,
             buttons: [...el.querySelectorAll('button')].map((b) => b.textContent)
           };
           el.remove();
           return out;
         };
         const fault = { id: 'f', text: 'Broken.', where: { kind: 'link', uid: 'u1', field: 'to' },
           fixes: [{ label: 'Do it', style: 'primary', event: { type: 'fix', data: {} } }] };
         return {
           bad: run({ ok: false, head: 'Head.', lines: [{ mark: 'x', text: 'A' }, { mark: 'i', text: 'B' }],
                      faults: [fault], notes: ['N'] }),
           clean: run({ ok: true, head: 'All fine.', lines: [], faults: [], notes: [] })
         };
       })()"
    )
    expect_match(out$bad$text, "L-error: A", fixed = TRUE)
    expect_match(out$bad$text, "L-info: B", fixed = TRUE)
    expect_match(out$bad$text, "L-notes", fixed = TRUE)
    expect_match(out$bad$text, "L-fix:", fixed = TRUE)
    expect_identical(out$bad$box, "L-rmsg")
    expect_identical(unlist(out$bad$buttons), c("L-show", "Do it"))
    expect_identical(out$bad$status, "1 L-one")
    expect_identical(out$clean$status, "All fine.")
    expect_false(grepl("Show|Fix:|Notes|Error|Info|Problems found|stage_map", out$bad$text))
    expect_false(grepl("Clean|stage_map", out$clean$text))
    expect_studio_clean(app)
  })
})
