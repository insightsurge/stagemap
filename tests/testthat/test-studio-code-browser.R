skip_without_chrome()

# Browser checks for the R code room (SMS-063, SMS-069..SMS-073): syntax tokens and line numbers, changed lines
# against opening base, last question call, problem note above code, at-once Copy / .R / CSV downloads with held
# messages, unsuspended downloads before opening the room, light/dark token contrast, and phone-width scrolling.

# Opens card "a" in the inspector by clicking it on the map.
code_pick_card_a <- function(app) {
  app$run_js(
    "document.querySelector('#studio-map [data-card=\"a\"]').dispatchEvent(new MouseEvent('click', { bubbles: true, detail: 1 }))"
  )
  app$wait_for_js("document.querySelector('.sms-inspector').hidden === false")
  studio_wait_step(app)
}

# Installs a capture listener on the hidden download link `link_id` that records each click's ack, sent, and drawn
# code, and optionally prevents browser file saving while recording order.
code_record_link <- function(app, link_id, prevent = TRUE) {
  app$run_js(sprintf(
    "window.__sms = window.__sms || {};
     window.__sms.linkClicks = window.__sms.linkClicks || [];
     const key = 'linkHooked_' + %s;
     if (!window.__sms[key]) {
       window.__sms[key] = true;
       document.getElementById(%s).addEventListener('click', (e) => {
         if (%s) e.preventDefault();
         const r = %s;
         window.__sms.linkClicks.push({
           id: %s,
           ack: Number(r.dataset.smsAck),
           sent: Number(r.dataset.smsSent),
           code: [...r.querySelectorAll('.sms-code .sms-l')].map((el) => el.textContent).join('\\n')
         });
       });
     }
     window.__sms.linkClicks = [];",
    jsonlite::toJSON(link_id, auto_unbox = TRUE),
    jsonlite::toJSON(link_id, auto_unbox = TRUE),
    tolower(prevent),
    studio_root_js,
    jsonlite::toJSON(link_id, auto_unbox = TRUE)
  ))
}

describe("the R code room", {
  it("[SMS-069] renders tokenised lines, line numbers, .R and CSV controls, and sends seen on open", {
    app <- studio_driver("small")
    record_studio_events(app)
    studio_open_code(app)
    studio_wait_step(app)

    # Opening the R code room sends `seen` with `what = "code"`
    sent <- studio_sent(app)
    expect_true(any(vapply(
      sent,
      function(ev) identical(ev$type, "seen") && identical(ev$data$what, "code"),
      logical(1)
    )))

    sec <- studio_section(app, "code")
    expected <- unclass(stage_map_code(studio_small()))
    expect_identical(vapply(sec$lines, `[[`, "", "text"), expected)
    expect_false(any(vapply(sec$lines, `[[`, logical(1), "changed")))

    # Syntax token spans and CSS counter line numbers are present
    tokens <- app$get_js(
      "({ fn: document.querySelectorAll('.sms-code .sms-tok-fn').length,
          str: document.querySelectorAll('.sms-code .sms-tok-str').length,
          arg: document.querySelectorAll('.sms-code .sms-tok-arg').length,
          op: document.querySelectorAll('.sms-code .sms-tok-op').length,
          name: document.querySelectorAll('.sms-code .sms-tok-name').length,
          reset: getComputedStyle(document.querySelector('.sms-code')).counterReset,
          line1Before: getComputedStyle(document.querySelector('.sms-code .sms-l'), '::before').content,
          rBtn: document.querySelector('[data-sms-download=\"download_r\"]')?.textContent ?? null,
          csvItems: [...document.querySelectorAll('[role=\"menuitem\"][data-sms-download]')].map((b) => b.textContent) })"
    )
    expect_gt(tokens$fn, 0L)
    expect_gt(tokens$str, 0L)
    expect_gt(tokens$arg, 0L)
    expect_gt(tokens$op, 0L)
    expect_gt(tokens$name, 0L)
    expect_match(tokens$reset, "sms-line", fixed = TRUE)
    expect_match(tokens$line1Before, "counter", fixed = TRUE)
    expect_identical(tokens$rBtn, ".R")
    expect_identical(
      unlist(tokens$csvItems),
      c("cards.csv", "stages.csv", "lanes.csv", "links.csv", "kinds.csv", "zones.csv")
    )
    expect_studio_clean(app)
  })

  it("[SMS-070] marks only changed lines against the opening base, with visible changed label", {
    app <- studio_driver("small")
    code_pick_card_a(app)
    studio_do(
      app,
      paste(
        studio_type_js(".sms-inspector [data-sms-field='label'] input", "Edited Draft"),
        "document.querySelector('.sms-inspector [data-sms-field=\"label\"] input').blur();"
      )
    )
    studio_open_code(app)
    studio_wait_step(app)

    sec <- studio_section(app, "code")
    changed_idx <- which(vapply(sec$lines, `[[`, logical(1), "changed"))
    expect_length(changed_idx, 1L)
    expect_match(sec$lines[[changed_idx]]$text, "Edited Draft", fixed = TRUE)
    expect_identical(
      app$get_js("getComputedStyle(document.querySelector('.sms-code .sms-l[data-sms-changed]'), '::after').content"),
      "\"changed\""
    )

    # Undoing clears all changed marks
    studio_do(app, studio_click_js(".sms-undo"))
    sec_after <- studio_section(app, "code")
    expect_false(any(vapply(sec_after$lines, `[[`, logical(1), "changed")))
    expect_studio_clean(app)
  })

  it("copies the edited card label when edited and Copy is clicked at once", {
    app <- studio_driver("small")
    code_pick_card_a(app)
    studio_open_code(app)
    studio_wait_step(app)
    stub_studio_clipboard(app)

    app$run_js(paste(
      studio_type_js(".sms-inspector [data-sms-field='label'] input", "Copied Card"),
      studio_copy_js
    ))
    expect_identical(studio_wait_copy(app), "item")
    studio_wait_step(app)
    copied <- studio_copied(app)
    expect_length(copied, 1L)
    expect_match(copied[[1L]]$text, "Copied Card", fixed = TRUE)
    expect_studio_clean(app)
  })

  it("[SMS-072] downloads .R only after ack on at-once edit and stays busy while messages are held", {
    app <- studio_driver("small")
    code_pick_card_a(app)
    studio_open_code(app)
    studio_wait_step(app)
    code_record_link(app, "studio-download_r", prevent = TRUE)

    # At once: edit card label and click .R in one run_js() call
    sent_at_once <- app$get_js(paste(
      studio_type_js(".sms-inspector [data-sms-field='label'] input", "Scripted Card"),
      studio_click_js("[data-sms-download='download_r']"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    app$wait_for_js("(window.__sms.linkClicks || []).length >= 1")
    studio_wait_step(app)
    click1 <- app$get_js("window.__sms.linkClicks[0]")
    expect_gte(click1$ack, sent_at_once)
    expect_gte(click1$ack, click1$sent)
    expect_match(click1$code, "Scripted Card", fixed = TRUE)

    dl_path1 <- app$get_download("studio-download_r")
    dl_text1 <- paste(readLines(dl_path1, encoding = "UTF-8", warn = FALSE), collapse = "\n")
    expect_match(dl_text1, "Scripted Card", fixed = TRUE)
    expect_no_error(parse(text = dl_text1, encoding = "UTF-8"))

    # With messages held: button stays busy and link is not clicked until release
    code_record_link(app, "studio-download_r", prevent = TRUE)
    hold_studio_messages(app)
    sent_held <- app$get_js(paste(
      studio_type_js(".sms-inspector [data-sms-field='label'] input", "Held R Card"),
      studio_click_js("[data-sms-download='download_r']"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, sent_held)
    expect_identical(
      app$get_js("document.querySelector('[data-sms-download=\"download_r\"]').getAttribute('aria-busy')"),
      "true"
    )
    expect_identical(
      app$get_js("document.querySelector('[data-sms-download=\"download_r\"]').getAttribute('aria-disabled')"),
      "true"
    )
    expect_null(app$get_js("document.querySelector('[data-sms-download=\"download_r\"]').getAttribute('disabled')"))
    expect_identical(app$get_js("window.__sms.linkClicks.length"), 0L)

    release_studio_messages(app)
    app$wait_for_js("(window.__sms.linkClicks || []).length >= 1")
    studio_wait_step(app)
    click2 <- app$get_js("window.__sms.linkClicks[0]")
    expect_gte(click2$ack, sent_held)
    expect_match(click2$code, "Held R Card", fixed = TRUE)
    expect_null(app$get_js("document.querySelector('[data-sms-download=\"download_r\"]').getAttribute('aria-busy')"))

    dl_path2 <- app$get_download("studio-download_r")
    dl_text2 <- paste(readLines(dl_path2, encoding = "UTF-8", warn = FALSE), collapse = "\n")
    expect_match(dl_text2, "Held R Card", fixed = TRUE)
    expect_studio_clean(app)
  })

  it("[SMS-073] downloads table CSV only after ack on at-once edit and stays busy while messages are held", {
    app <- studio_driver("small")
    code_pick_card_a(app)
    studio_open_code(app)
    studio_wait_step(app)
    code_record_link(app, "studio-download_csv_cards", prevent = TRUE)

    # At once: edit card label, open CSV menu, and click cards.csv in one run_js() call
    sent_at_once <- app$get_js(paste(
      studio_type_js(".sms-inspector [data-sms-field='label'] input", "CSV Card One"),
      studio_click_js("[data-sms-menu='csv']"),
      studio_click_js("[data-sms-download='download_csv_cards']"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    app$wait_for_js("(window.__sms.linkClicks || []).length >= 1")
    studio_wait_step(app)
    click1 <- app$get_js("window.__sms.linkClicks[0]")
    expect_gte(click1$ack, sent_at_once)
    expect_match(click1$code, "CSV Card One", fixed = TRUE)

    csv_path1 <- app$get_download("studio-download_csv_cards")
    tbl1 <- utils::read.csv(csv_path1, stringsAsFactors = FALSE)
    expect_false(".studio_uid" %in% names(tbl1))
    expect_identical(tbl1$label[[1L]], "CSV Card One")

    # With messages held: menu item button stays busy and link is not clicked until release
    code_record_link(app, "studio-download_csv_cards", prevent = TRUE)
    hold_studio_messages(app)
    sent_held <- app$get_js(paste(
      studio_type_js(".sms-inspector [data-sms-field='label'] input", "CSV Card Held"),
      studio_click_js("[data-sms-menu='csv']"),
      studio_click_js("[data-sms-download='download_csv_cards']"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, sent_held)
    expect_identical(
      app$get_js("document.querySelector('[data-sms-download=\"download_csv_cards\"]').getAttribute('aria-busy')"),
      "true"
    )
    expect_identical(
      app$get_js("document.querySelector('[data-sms-download=\"download_csv_cards\"]').getAttribute('aria-disabled')"),
      "true"
    )
    expect_identical(app$get_js("window.__sms.linkClicks.length"), 0L)

    release_studio_messages(app)
    app$wait_for_js("(window.__sms.linkClicks || []).length >= 1")
    studio_wait_step(app)
    expect_null(
      app$get_js("document.querySelector('[data-sms-download=\"download_csv_cards\"]').getAttribute('aria-busy')")
    )

    csv_path2 <- app$get_download("studio-download_csv_cards")
    tbl2 <- utils::read.csv(csv_path2, stringsAsFactors = FALSE)
    expect_identical(tbl2$label[[1L]], "CSV Card Held")
    expect_studio_clean(app)
  })

  it("says it could not download, and is not busy, when the answer is held longer than a download waits", {
    app <- studio_driver("small", copy_wait_ms = 300L)
    studio_open_code(app)
    studio_wait_step(app)
    code_record_link(app, "studio-download_r", prevent = TRUE)
    hold_studio_messages(app)
    app$run_js(paste(studio_title_js("Too late"), studio_click_js("[data-sms-download='download_r']")))
    app$wait_for_js("document.querySelector('.sms-toast-text')?.textContent.includes('did not answer in time')")
    toast <- app$get_js("document.querySelector('.sms-toast-text').textContent")
    expect_match(toast, "Could not download", fixed = TRUE)
    expect_no_match(toast, "copy", ignore.case = TRUE)
    expect_identical(app$get_js("window.__sms.linkClicks.length"), 0L)
    expect_null(app$get_js("document.querySelector('[data-sms-download=\"download_r\"]').getAttribute('aria-busy')"))
    release_studio_messages(app)
    studio_wait_step(app)
    expect_studio_clean(app)
  })

  it("sends seen each time the code room is opened", {
    app <- studio_driver("small")
    record_studio_events(app)
    seen_count <- function() {
      sum(vapply(
        studio_sent(app),
        function(ev) identical(ev$type, "seen") && identical(ev$data$what, "code"),
        logical(1)
      ))
    }
    studio_open_code(app)
    studio_wait_step(app)
    expect_identical(seen_count(), 1L)
    click_now(app, "[data-sms-room='code']")
    app$wait_for_js("document.querySelector('[data-sms-room-of=\"code\"]').hidden === true")
    studio_open_code(app)
    studio_wait_step(app)
    expect_identical(seen_count(), 2L)
    expect_studio_clean(app)
  })

  it("[SMS-071] displays the last question call under the code and drops it after an edit", {
    app <- studio_driver("small")
    studio_open_code(app)
    studio_wait_step(app)

    s <- studio_state_new(studio_small())
    s$ask <- list(question = "trace", call = "sm_trace(map, \"a\")", rev = s$rev, stale = FALSE, error = NULL)
    code_with_ask <- studio_room_code_view(s)
    payload <- jsonlite::toJSON(
      list(sections = list(code = code_with_ask)),
      auto_unbox = TRUE,
      null = "null"
    )
    app$run_js(sprintf(
      "{ const r = %s; r.dispatchEvent(new CustomEvent('stagemap-studio:deliver', { detail: {
          ns: r.dataset.smsNs, n: Number(r.dataset.smsN) + 0.5, ack: Number(r.dataset.smsAck), rev: 0,
          sections: (%s).sections } })); }",
      studio_root_js,
      payload
    ))
    app$wait_for_js("document.querySelector('.sms-code').textContent.includes('# The last question')")
    code_text <- paste(vapply(studio_section(app, "code")$lines, `[[`, "", "text"), collapse = "\n")
    expect_match(code_text, "map <- stage_map(", fixed = TRUE)
    expect_match(code_text, "# The last question\nsm_trace(map, \"a\")", fixed = TRUE)

    # An edit rebuilds code on the server without the stale question call
    studio_do(app, paste(studio_title_js("After question"), "document.querySelector('.sms-title').blur();"))
    after_text <- paste(vapply(studio_section(app, "code")$lines, `[[`, "", "text"), collapse = "\n")
    expect_false(grepl("# The last question", after_text, fixed = TRUE))
    expect_false(grepl("map <- stage_map(", after_text, fixed = TRUE))
    expect_studio_clean(app)
  })

  it("[SMS-063] shows the problem note above the code on a broken map and prepends it to Copy and .R", {
    app <- studio_driver("none")
    studio_do(app, studio_click_js("[data-sms-open='example']"))
    studio_open_code(app)
    studio_wait_step(app)
    stub_studio_clipboard(app)

    pos <- app$get_js(
      "(() => { const n = document.querySelector('.sms-code-note'); const c = document.querySelector('.sms-code');
         const nb = n.getBoundingClientRect(); const cb = c.getBoundingClientRect();
         return { text: n.textContent, above: nb.bottom <= cb.top + 1,
           domBefore: Boolean(n.compareDocumentPosition(c) & Node.DOCUMENT_POSITION_FOLLOWING) }; })()"
    )
    expect_identical(pos$text, "stage_map() stops on this map: see Check.")
    expect_true(pos$above)
    expect_true(pos$domBefore)

    app$run_js(studio_copy_js)
    expect_identical(studio_wait_copy(app), "item")
    expect_true(startsWith(studio_copied(app)[[1L]]$text, "# stage_map() stops on this map: see Check.\n"))

    dl_path <- app$get_download("studio-download_r")
    dl_text <- paste(readLines(dl_path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
    expect_true(startsWith(dl_text, "# stage_map() stops on this map: see Check.\n"))
    expect_studio_clean(app)
  })

  it("serves .R and CSV downloads while the code room has never been opened", {
    app <- studio_driver("small")
    expect_true(app$get_js("document.querySelector('[data-sms-room-of=\"code\"]').hidden"))
    app$wait_for_js(
      "Boolean(document.getElementById('studio-download_r')?.getAttribute('href')) &&
       Boolean(document.getElementById('studio-download_csv_cards')?.getAttribute('href'))"
    )
    dl_r <- app$get_download("studio-download_r")
    r_text <- paste(readLines(dl_r, encoding = "UTF-8", warn = FALSE), collapse = "\n")
    expect_match(r_text, "A small piece of work", fixed = TRUE)

    dl_csv <- app$get_download("studio-download_csv_cards")
    tbl <- utils::read.csv(dl_csv, stringsAsFactors = FALSE)
    expect_identical(nrow(tbl), 4L)
    expect_false(".studio_uid" %in% names(tbl))

    # Missing table yields header-only CSV
    dl_steps <- app$get_download("studio-download_csv_steps")
    steps <- utils::read.csv(dl_steps, stringsAsFactors = FALSE)
    expect_identical(nrow(steps), 0L)
    expect_identical(names(steps), names(sm_spec()$fields$steps$fields))
    expect_studio_clean(app)
  })

  it("changes code colours between light and dark, differentiates token styles, and scrolls inside phone width", {
    app <- studio_driver("small")
    studio_do(app, paste(studio_title_js("Theme Check"), "document.querySelector('.sms-title').blur();"))
    studio_open_code(app)
    studio_wait_step(app)

    # String, function name and comment differ by weight or style (not colour alone)
    styles <- app$get_js(
      "(() => {
         const cs = (sel) => { const el = document.querySelector(sel); if (!el) return null;
           const s = getComputedStyle(el); return { color: s.color, weight: s.fontWeight, style: s.fontStyle }; };
         return { fn: cs('.sms-code .sms-tok-fn'), str: cs('.sms-code .sms-tok-str'),
           name: cs('.sms-code .sms-tok-name'), boxBg: getComputedStyle(document.querySelector('.sms-code')).backgroundColor,
           changedShadow: getComputedStyle(document.querySelector('.sms-code .sms-l[data-sms-changed]')).boxShadow };
       })()"
    )
    expect_false(identical(styles$fn$weight, styles$str$weight))
    expect_false(identical(styles$str$weight, styles$name$weight))
    expect_identical(
      app$get_js(
        "(() => { const s = document.createElement('span'); s.className = 'sms-tok-com';
           document.querySelector('.sms-code').append(s); const style = getComputedStyle(s).fontStyle; s.remove(); return style; })()"
      ),
      "italic"
    )

    click_now(app, ".sms-theme")
    app$wait_for_js(sprintf("%s.dataset.theme === 'dark'", studio_root_js))
    dark_styles <- app$get_js(
      "({ boxBg: getComputedStyle(document.querySelector('.sms-code')).backgroundColor,
          nameColor: getComputedStyle(document.querySelector('.sms-code .sms-tok-name')).color,
          changedShadow: getComputedStyle(document.querySelector('.sms-code .sms-l[data-sms-changed]')).boxShadow })"
    )
    expect_false(identical(dark_styles$boxBg, styles$boxBg))
    expect_false(identical(dark_styles$nameColor, styles$name$color))
    expect_false(identical(dark_styles$changedShadow, styles$changedShadow))

    # Phone width: code room and its head fit 375px without widening the page; code scrolls inside its box
    studio_emulate(app, "width", 375L)
    phone <- app$get_js(
      "(() => {
         const room = document.querySelector('[data-sms-room-of=\"code\"]');
         const head = room.querySelector('.sms-room-head');
         const box = document.querySelector('.sms-code');
         return {
           roomFits: room.getBoundingClientRect().right <= window.innerWidth && room.scrollWidth <= room.clientWidth,
           headFits: head.scrollWidth <= head.clientWidth,
           boxFits: box.getBoundingClientRect().right <= window.innerWidth,
           codeScrolls: box.scrollWidth > box.clientWidth,
           rootSw: document.querySelector('.sms').scrollWidth,
           rootRight: document.querySelector('.sms').getBoundingClientRect().right
         };
       })()"
    )
    expect_true(phone$roomFits)
    expect_true(phone$headFits)
    expect_true(phone$boxFits)
    expect_true(phone$codeScrolls)
    # The studio's own box: nothing inside it pokes past the phone's width (the page around it is the test app's, which
    # prints the map state in a wide line, so the page's scrollWidth is not the studio's)
    expect_lte(phone$rootSw, 375L)
    expect_lte(phone$rootRight, 375L)
    expect_studio_clean(app)
  })
})
