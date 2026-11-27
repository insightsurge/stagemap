skip_without_chrome()

# Browser tests for the inspector forms, target selection, hover hints, keyboard flow, phone sheet,
# and at-once / held-message behaviour for every inspector action.

pick_card_js <- function(id) {
  sprintf(
    "document.querySelector('#studio-map [data-card=\"%s\"]').dispatchEvent(new MouseEvent('click', { bubbles: true, detail: 1 }));",
    id
  )
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

set_input_change_js <- function(selector, value) {
  sprintf(
    "{ const el = document.querySelector(%s); if (!el) throw new Error('Missing input: ' + %s);
       el.value = %s; el.dispatchEvent(new Event('change', { bubbles: true })); }",
    jsonlite::toJSON(selector, auto_unbox = TRUE),
    jsonlite::toJSON(selector, auto_unbox = TRUE),
    jsonlite::toJSON(value, auto_unbox = TRUE)
  )
}

describe("the studio target, inspector head, hint bar and keyboard", {
  it("[SMS-037] opens the inspector on card click and closes on second click, Close button or Escape", {
    app <- studio_driver("small")
    expect_true(studio_section(app, "inspector")$hidden)
    expect_true(app$get_js("document.querySelector('.sms-inspector').inert"))

    app$run_js(pick_card_js("b"))
    app$wait_for_js("document.querySelector('.sms-inspector').hidden === false")
    expect_false(app$get_js("document.querySelector('.sms-inspector').inert"))
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-insp-sub').textContent"), "b")

    # Second click on same card clears target
    app$run_js(pick_card_js("b"))
    app$wait_for_js("document.querySelector('.sms-inspector').hidden === true")
    expect_true(app$get_js("document.querySelector('.sms-inspector').inert"))

    # Close action button clears target
    app$run_js(pick_card_js("a"))
    app$wait_for_js("document.querySelector('.sms-inspector').hidden === false")
    studio_do(app, studio_click_js(".sms-inspector .sms-insp-acts button"))
    expect_true(studio_section(app, "inspector")$hidden)

    # Escape from inside inspector clears target
    app$run_js(pick_card_js("a"))
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
    app$run_js("document.querySelector('[data-sms-action=\"+ Card\"]').focus()")
    since1 <- studio_stamp(app)
    studio_press(app, "Enter", key_code = 13L)
    studio_wait_step(app)
    studio_wait_map(app, since1)
    expect_identical(app$get_js("document.querySelectorAll('[data-card]').length"), 5L)

    app$run_js("document.querySelector('[data-sms-menu=\"stages\"]').focus()")
    studio_press(app, "Enter", key_code = 13L)
    expect_false(app$get_js("document.querySelector('#studio-menu-stages').hidden"))
    studio_press(app, "ArrowDown", key_code = 40L)
    studio_press(app, "Enter", key_code = 13L)
    studio_wait_step(app)
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-insp-sub').textContent"), "check")

    app$run_js("document.querySelector('.sms-undo').focus()")
    since2 <- studio_stamp(app)
    studio_press(app, "z", modifiers = "ctrl", code = "KeyZ", key_code = 90L)
    studio_wait_step(app)
    studio_wait_map(app, since2)
    expect_identical(app$get_js("document.querySelectorAll('[data-card]').length"), 4L)
    expect_studio_clean(app)
  })

  it("keeps focus in menu trigger, Close button redraws, clears stale focus requests, and returns to opener", {
    app <- studio_driver("small")
    app$run_js("document.querySelector('[data-sms-menu=\"stages\"]').focus()")
    studio_press(app, "Enter", key_code = 13L)
    studio_press(app, "ArrowDown", key_code = 40L)
    studio_press(app, "Enter", key_code = 13L)
    expect_identical(app$get_js("document.activeElement?.dataset?.smsMenu"), "stages")
    studio_wait_step(app)
    expect_identical(app$get_js("document.activeElement.id"), "studio-inspector-title")

    # Re-picking the same stage leaves inspector unchanged and must clear pendingInspectorSeq
    click_now(app, "[data-sms-menu='stages']")
    studio_do(app, studio_click_js("#studio-menu-stages [role='menuitem']:nth-child(2)"))
    # Pointer click on card "a" must NOT steal focus to the inspector heading
    app$run_js(
      "document.querySelector('.sms-title').focus();
       document.querySelector('.sms').dispatchEvent(new PointerEvent('pointerdown', { bubbles: true }));"
    )
    app$run_js(pick_card_js("a"))
    app$wait_for_js("document.querySelector('.sms-inspector .sms-insp-sub')?.textContent === 'a'")
    expect_false(identical(app$get_js("document.activeElement?.id"), "studio-inspector-title"))

    # Focus Close button while a message updates inspector title in place: Close stays focused
    app$run_js("document.querySelector('.sms-inspector [data-sms-action=\"Close\"]').focus()")
    app$run_js(sprintf(
      "{ const r = %s; r.dispatchEvent(new CustomEvent('stagemap-studio:deliver', { detail: {
          ns: r.dataset.smsNs, n: Number(r.dataset.smsN) + 0.5, ack: Number(r.dataset.smsAck), rev: Number(r.dataset.smsRev),
          sections: { inspector: { kind: 'card', uid: 'u1', title: 'Updated label', sub: 'a',
            fields: [], lists: [], actions: []
          } } } })); }",
      studio_root_js
    ))
    expect_identical(app$get_js("document.activeElement?.dataset?.smsAction"), "Close")
    expect_identical(app$get_js("document.querySelector('#studio-inspector-title').textContent"), "Updated label")

    # Close returns focus to the opener (Stages menu trigger)
    studio_press(app, "Enter", key_code = 13L)
    studio_wait_step(app)
    expect_true(app$get_js("document.querySelector('.sms-inspector').hidden"))
    expect_identical(app$get_js("document.activeElement?.dataset?.smsMenu"), "stages")
    expect_studio_clean(app)
  })

  it("reads neutral outline menus, counts and hints from R without hardcoded table or kind names", {
    app <- studio_driver("small")
    app$run_js(sprintf(
      "{ const r = %s; r.dispatchEvent(new CustomEvent('stagemap-studio:deliver', { detail: {
          ns: r.dataset.smsNs, n: Number(r.dataset.smsN) + 0.5, ack: Number(r.dataset.smsAck), rev: Number(r.dataset.smsRev),
          sections: { outline: {
            menus: [{ id: 'zones', label: 'Zones', items: [{ uid: 'z1', id: 'z1', label: 'Zone 1', count: 7, event: { type: 'target', data: { kind: 'none', uid: null } } }] }],
            hints: { zone: { z1: 'Zone: Review zone' } },
            actions: []
          } } } })); }",
      studio_root_js
    ))
    expect_identical(
      app$get_js("document.querySelector('.sms-menu[data-sms-menu-box=\"zones\"] .sms-menu-count').textContent"),
      "7"
    )
    app$run_js(
      "document.querySelector('#studio-map').dispatchEvent(new CustomEvent('stagemap:hover', { bubbles: true, detail: { kind: 'zone', id: 'z1' } }))"
    )
    expect_false(app$get_js("document.querySelector('.sms-hint').hidden"))
    expect_identical(app$get_js("document.querySelector('.sms-hint').textContent"), "Zone: Review zone")
    expect_studio_clean(app)
  })
})

describe("the card inspector form", {
  it("[SMS-038] edits every card field type, coalesces held text, flushes on Enter/blur, and never echoes", {
    app <- studio_driver("small")
    app$run_js(pick_card_js("b"))
    app$wait_for_js("document.querySelector('.sms-inspector [data-sms-field=\"label\"] input') !== null")

    # Held text: three quick key presses send one event after hold_ms; Enter sends at once
    record_studio_events(app)
    app$run_js(
      "{ const f = document.querySelector('.sms-inspector [data-sms-field=\"label\"] input');
         f.focus(); f.value = 'R';
         f.dispatchEvent(new InputEvent('input', { bubbles: true, data: 'R', inputType: 'insertText' }));
         f.value = 'Re';
         f.dispatchEvent(new InputEvent('input', { bubbles: true, data: 'e', inputType: 'insertText' }));
         f.value = 'Rev';
         f.dispatchEvent(new InputEvent('input', { bubbles: true, data: 'v', inputType: 'insertText' })); }"
    )
    expect_length(studio_sent(app), 0L)
    studio_wait_step(app)
    sent1 <- studio_sent(app)
    expect_length(sent1, 1L)
    expect_identical(sent1[[1L]]$data$value, "Rev")

    # Enter sends held text at once without waiting for hold_ms
    app$run_js(
      "window.__sms.sent = [];
       const f = document.querySelector('.sms-inspector [data-sms-field=\"sub\"] input');
       f.focus(); f.value = 'Owner 1';
       f.dispatchEvent(new InputEvent('input', { bubbles: true, data: '1', inputType: 'insertText' }));"
    )
    studio_press(app, "Enter", key_code = 13L)
    studio_wait_step(app)
    expect_length(studio_sent(app), 1L)
    expect_identical(studio_sent(app)[[1L]]$data$field, "sub")

    # No echo: hold messages, edit Label, blur, type more while focused, release: field keeps newly typed text
    hold_studio_messages(app)
    seq_edit <- app$get_js(paste(
      studio_type_js(".sms-inspector [data-sms-field='label'] input", "Server copy"),
      "document.querySelector('.sms-inspector [data-sms-field=\"label\"] input').blur();",
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, seq_edit)
    studio_type(app, ".sms-inspector [data-sms-field='label'] input", "Still typing")
    release_studio_messages(app)
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"label\"] input').value"),
      "Still typing"
    )
    app$run_js("document.querySelector('.sms-inspector [data-sms-field=\"label\"] input').blur()")
    studio_wait_step(app)
    expect_identical(app$get_js("document.querySelector('#studio-inspector-title').textContent"), "Still typing")

    # Status radio, Stage/Lane/Tone/Zone selects, Milestone toggle, Note textarea
    since_st <- studio_stamp(app)
    studio_do(app, studio_click_js(".sms-inspector [data-sms-field='status'] input[value='done']"))
    studio_wait_map(app, since_st)
    expect_match(studio_section(app, "journal")$text, "status: running > done", fixed = TRUE)

    since_s <- studio_stamp(app)
    studio_do(app, set_select_js(".sms-inspector [data-sms-field='stage'] select", "ship"))
    studio_wait_map(app, since_s)
    expect_match(studio_section(app, "journal")$text, "stage: check > ship", fixed = TRUE)

    since_l <- studio_stamp(app)
    studio_do(app, set_select_js(".sms-inspector [data-sms-field='lane'] select", "code"))
    studio_wait_map(app, since_l)
    expect_match(studio_section(app, "journal")$text, "lane: docs > code", fixed = TRUE)

    since_t <- studio_stamp(app)
    studio_do(app, set_select_js(".sms-inspector [data-sms-field='tone'] select", "good"))
    studio_wait_map(app, since_t)
    expect_match(studio_section(app, "journal")$text, "tone: (none) > good", fixed = TRUE)

    since_z <- studio_stamp(app)
    studio_do(app, set_select_js(".sms-inspector [data-sms-field='zone'] select", ""))
    studio_wait_map(app, since_z)
    expect_match(studio_section(app, "journal")$text, "zone: sign > (none)", fixed = TRUE)

    since_m <- studio_stamp(app)
    studio_do(app, studio_click_js(".sms-inspector [data-sms-field='milestone'] input[type='checkbox']"))
    studio_wait_map(app, since_m)
    expect_match(studio_section(app, "journal")$text, "milestone: (none) > TRUE", fixed = TRUE)

    studio_do(
      app,
      paste(
        studio_type_js(".sms-inspector [data-sms-field='text'] textarea", "A **bold** note"),
        "document.querySelector('.sms-inspector [data-sms-field=\"text\"] textarea').blur();"
      )
    )
    expect_match(studio_section(app, "journal")$text, "A **bold** note", fixed = TRUE)

    # Side "Edit" action beside Stage (at once after typing)
    app$run_js("window.__sms.sent = [];")
    studio_do(
      app,
      paste(
        studio_type_js(".sms-inspector [data-sms-field='sub'] input", "By stage edit"),
        studio_click_js(".sms-inspector [data-sms-field='stage'] [data-sms-action='Edit']")
      )
    )
    sent_ed <- vapply(studio_sent(app), `[[`, character(1L), "type")
    expect_lt(match("edit", sent_ed), match("target", sent_ed))
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-kick').textContent"), "stage")
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-insp-sub').textContent"), "ship")
    expect_match(studio_section(app, "journal")$text, "By stage edit", fixed = TRUE)

    # Trace from here (at once + held) on card "a"
    app$run_js(pick_card_js("a"))
    app$wait_for_js("document.querySelector('.sms-inspector .sms-kick')?.textContent === 'card'")
    app$run_js("window.__sms.sent = [];")
    hold_studio_messages(app)
    tr_seq <- app$get_js(paste(
      studio_type_js(".sms-inspector [data-sms-field='sub'] input", "Before trace"),
      studio_click_js(".sms-inspector [data-sms-action='Trace from here']"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, tr_seq)
    sent_tr <- vapply(studio_sent(app), `[[`, character(1L), "type")
    expect_lt(match("edit", sent_tr), match("ask", sent_tr))
    expect_identical(
      app$get_js(
        "document.querySelector('.sms-inspector [data-sms-action=\"Trace from here\"]').getAttribute('aria-busy')"
      ),
      "true"
    )
    release_studio_messages(app)
    studio_wait_step(app)
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"sub\"] input').value"),
      "Before trace"
    )
    expect_match(studio_section(app, "journal")$text, "Before trace", fixed = TRUE)
    expect_studio_clean(app)
  })

  it("[SMS-039] [SMS-041] renames a card id, keeps the form open, re-picks the renamed card, and cascades links", {
    app <- studio_driver("small")
    app$run_js(pick_card_js("b"))
    app$wait_for_js("document.querySelector('.sms-inspector [data-sms-field=\"id\"] input') !== null")

    since <- studio_stamp(app)
    studio_do(
      app,
      paste(
        studio_type_js(".sms-inspector [data-sms-field='id'] input", "b_renamed"),
        "document.querySelector('.sms-inspector [data-sms-field=\"id\"] input').blur();"
      )
    )
    studio_wait_map(app, since)
    expect_false(studio_section(app, "inspector")$hidden)
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-insp-sub').textContent"), "b_renamed")
    app$wait_for_js("JSON.parse(document.getElementById('map_state').textContent).selected?.[0] === 'b_renamed'")

    # Links still show on the card's lists and map has 0 problems
    expect_identical(
      app$get_js("document.querySelectorAll('.sms-inspector [data-sms-list=\"in\"] .sms-row').length"),
      1L
    )
    expect_identical(
      app$get_js("document.querySelectorAll('.sms-inspector [data-sms-list=\"out\"] .sms-row').length"),
      1L
    )
    expect_identical(studio_section(app, "status")$stamp, "")
    expect_studio_clean(app)
  })

  it("[SMS-040] flushes a held label edit to the first card when picking another card in one call", {
    app <- studio_driver("small")
    app$run_js(pick_card_js("a"))
    app$wait_for_js("document.querySelector('.sms-inspector [data-sms-field=\"label\"] input') !== null")

    since <- studio_stamp(app)
    app$run_js(paste(
      studio_type_js(".sms-inspector [data-sms-field='label'] input", "Draft edited"),
      pick_card_js("b")
    ))
    studio_wait_step(app)
    studio_wait_map(app, since)
    app$wait_for_js("document.querySelector('.sms-inspector .sms-insp-sub')?.textContent === 'b'")
    expect_identical(app$get_js("document.querySelector('#studio-inspector-title').textContent"), "Review")
    expect_match(
      app$get_js("document.querySelector('#studio-map [data-card=\"a\"]').textContent"),
      "Draft edited",
      fixed = TRUE
    )
    expect_match(studio_section(app, "journal")$text, "Draft > Draft edited", fixed = TRUE)
    expect_studio_clean(app)
  })

  it("[SMS-044] flushes a held edit before Remove card at once and keeps Remove busy while held", {
    app <- studio_driver("small")
    app$run_js(pick_card_js("a"))
    app$wait_for_js("document.querySelector('.sms-inspector [data-sms-action=\"Remove card\"]') !== null")

    since <- studio_stamp(app)
    record_studio_events(app)
    studio_do(
      app,
      paste(
        studio_type_js(".sms-inspector [data-sms-field='label'] input", "Before remove"),
        studio_click_js(".sms-inspector [data-sms-action='Remove card']")
      )
    )
    studio_wait_map(app, since)
    sent_rm <- vapply(studio_sent(app), `[[`, character(1L), "type")
    expect_lt(match("edit", sent_rm), match("remove", sent_rm))
    expect_true(studio_section(app, "inspector")$hidden)
    expect_identical(app$get_js("document.querySelectorAll('#studio-map [data-card]').length"), 3L)
    j <- studio_section(app, "journal")$text
    expect_lt(regexpr("Before remove", j, fixed = TRUE), regexpr("Remove card a", j, fixed = TRUE))

    # Held messages on Remove card
    app$run_js(pick_card_js("d"))
    app$wait_for_js("document.querySelector('.sms-inspector [data-sms-action=\"Remove card\"]') !== null")
    hold_studio_messages(app)
    rm_seq <- app$get_js(paste(
      studio_click_js(".sms-inspector [data-sms-action='Remove card']"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, rm_seq)
    expect_identical(
      app$get_js(
        "document.querySelector('.sms-inspector [data-sms-action=\"Remove card\"]').getAttribute('aria-busy')"
      ),
      "true"
    )
    release_studio_messages(app)
    studio_wait_step(app)
    expect_true(studio_section(app, "inspector")$hidden)
    expect_identical(app$get_js("document.querySelectorAll('#studio-map [data-card]').length"), 2L)
    expect_studio_clean(app)
  })

  it("[SMS-050] announces inline problem in a persistent live region, restores selection on stale refusal, and allows unchanged stale picks", {
    app <- studio_driver("small")
    # Add an unlinked card so duplicating its id produces only the 2 duplicate faults (no broken link)
    since_add <- studio_stamp(app)
    studio_do(app, studio_click_js("[data-sms-action='+ Card']"))
    studio_wait_map(app, since_add)

    # Persistent polite live region exists on the field before any problem appears
    live_before <- app$get_js(
      "(() => {
         const l = document.querySelector('.sms-inspector [data-sms-field=\"id\"] .sms-fld-live');
         return l ? {
           live: l.getAttribute('aria-live'),
           atomic: l.getAttribute('aria-atomic'),
           children: l.children.length,
           display: getComputedStyle(l).display
         } : null;
       })()"
    )
    expect_identical(live_before$live, "polite")
    expect_identical(live_before$atomic, "true")
    expect_identical(live_before$children, 0L)
    expect_false(identical(live_before$display, "none"))

    stamp_before <- studio_stamp(app)
    studio_do(
      app,
      paste(
        studio_type_js(".sms-inspector [data-sms-field='id'] input", "b"),
        "document.querySelector('.sms-inspector [data-sms-field=\"id\"] input').blur();"
      )
    )
    # Problem appears inside the persistent live region, stamp counts 2 duplicate faults, drawn map stays on last good
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"id\"] input').getAttribute('aria-invalid')"),
      "true"
    )
    expect_match(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"id\"] .sms-fld-live .sms-err').textContent"),
      "Another card"
    )
    expect_match(studio_section(app, "status")$stamp, "2 problems", fixed = TRUE)
    expect_identical(studio_stamp(app), stamp_before)

    # Clicking duplicated "b" on the stale drawn map refuses and clears the widget selection (target u5 is not drawn)
    app$run_js(pick_card_js("b"))
    app$wait_for_js("document.querySelector('.sms-toast').dataset.smsOn !== undefined")
    expect_match(studio_section(app, "notice")$text, "out of date")
    app$wait_for_js("JSON.parse(document.getElementById('map_state').textContent).selected.length === 0")

    # Clicking unchanged card "c" on the stale map succeeds and selects "c"
    app$run_js(pick_card_js("c"))
    app$wait_for_js("document.querySelector('.sms-inspector .sms-insp-sub')?.textContent === 'c'")
    app$wait_for_js("JSON.parse(document.getElementById('map_state').textContent).selected?.[0] === 'c'")

    # Clicking duplicated "b" while targeting "c" refuses and puts the map selection back to "c"
    app$run_js(pick_card_js("b"))
    app$wait_for_js("document.querySelector('.sms-toast').dataset.smsOn !== undefined")
    expect_match(studio_section(app, "notice")$text, "out of date")
    app$wait_for_js("JSON.parse(document.getElementById('map_state').textContent).selected?.[0] === 'c'")
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-insp-sub').textContent"), "c")

    # Re-open the duplicated card from the journal chip and apply inline fix (at once + held)
    studio_do(app, studio_click_js(".sms-journal-list .sms-ev:last-child .sms-ev-btn"))
    app$wait_for_js("document.querySelector('.sms-inspector [data-sms-field=\"id\"] .sms-prob-fixes button') !== null")
    record_studio_events(app)
    hold_studio_messages(app)
    fix_seq <- app$get_js(paste(
      studio_type_js(".sms-inspector [data-sms-field='label'] input", "Fixed draft"),
      studio_click_js(".sms-inspector [data-sms-field='id'] .sms-prob-fixes button"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, fix_seq)
    sent_fix <- vapply(studio_sent(app), `[[`, character(1L), "type")
    expect_lt(match("edit", sent_fix), match("fix", sent_fix))
    expect_identical(
      app$get_js(
        "document.querySelector('.sms-inspector [data-sms-field=\"id\"] .sms-prob-fixes button').getAttribute('aria-busy')"
      ),
      "true"
    )
    release_studio_messages(app)
    studio_wait_step(app)
    studio_wait_map(app, stamp_before)
    expect_null(app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"id\"] .sms-err')"))
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"id\"] .sms-fld-live').children.length"),
      0L
    )
    expect_identical(studio_section(app, "status")$stamp, "")
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-insp-sub').textContent"), "card")
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"label\"] input').value"),
      "Fixed draft"
    )
    j_fix <- studio_section(app, "journal")$text
    expect_lt(regexpr("Fixed draft", j_fix, fixed = TRUE), regexpr("Set card id to card", j_fix, fixed = TRUE))
    expect_studio_clean(app)
  })
})

describe("links, stages and lanes inspector forms", {
  it("[SMS-042] [SMS-043] connects, inspects, changes kind, swaps ends and removes links (at once and held)", {
    app <- studio_driver("small")
    app$run_js(pick_card_js("a"))
    app$wait_for_js("document.querySelector('.sms-inspector [data-sms-list=\"out\"] .sms-add') !== null")

    # Connect a -> d with kind "hand" (at once after typing + held)
    record_studio_events(app)
    since_c <- studio_stamp(app)
    hold_studio_messages(app)
    conn_seq <- app$get_js(paste(
      studio_type_js(".sms-inspector [data-sms-field='sub'] input", "Before connect"),
      set_select_js(".sms-inspector [data-sms-list='out'] [data-sms-field='to'] select", "u4"),
      set_select_js(".sms-inspector [data-sms-list='out'] [data-sms-field='kind'] select", "hand"),
      studio_click_js(".sms-inspector [data-sms-list='out'] [data-sms-action='Connect']"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, conn_seq)
    sent_c <- vapply(studio_sent(app), `[[`, character(1L), "type")
    expect_lt(match("edit", sent_c), match("link_add", sent_c))
    expect_identical(
      app$get_js(
        "document.querySelector('.sms-inspector [data-sms-list=\"out\"] [data-sms-action=\"Connect\"]').getAttribute('aria-busy')"
      ),
      "true"
    )
    release_studio_messages(app)
    studio_wait_step(app)
    studio_wait_map(app, since_c)
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"sub\"] input').value"),
      "Before connect"
    )
    j_c <- studio_section(app, "journal")$text
    expect_lt(regexpr("Before connect", j_c, fixed = TRUE), regexpr("Link a", j_c, fixed = TRUE))
    expect_identical(
      app$get_js("document.querySelectorAll('.sms-inspector [data-sms-list=\"out\"] .sms-row').length"),
      2L
    )
    expect_match(studio_section(app, "header")$facts, "4 links", fixed = TRUE)

    # Open the new link (row 2) with Edit, edit label, change kind to None, swap ends (at once + held)
    studio_do(
      app,
      studio_click_js(".sms-inspector [data-sms-list='out'] .sms-row:nth-child(2) [data-sms-action='Edit']")
    )
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-kick').textContent"), "link")
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector #studio-inspector-title').textContent"),
      "a -> d"
    )

    since_k <- studio_stamp(app)
    studio_do(app, studio_click_js(".sms-inspector [data-sms-field='kind'] input[value='']"))
    studio_wait_map(app, since_k)
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-insp-sub').textContent"), "plain")

    app$run_js("window.__sms.sent = [];")
    since_sw <- studio_stamp(app)
    hold_studio_messages(app)
    swap_seq <- app$get_js(paste(
      studio_type_js(".sms-inspector [data-sms-field='label'] input", "Direct"),
      studio_click_js(".sms-inspector [data-sms-action='Swap ends']"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, swap_seq)
    sent_sw <- vapply(studio_sent(app), `[[`, character(1L), "type")
    expect_lt(match("edit", sent_sw), match("link_reverse", sent_sw))
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-action=\"Swap ends\"]').getAttribute('aria-busy')"),
      "true"
    )
    release_studio_messages(app)
    studio_wait_step(app)
    studio_wait_map(app, since_sw)
    expect_identical(app$get_js("document.querySelector('#studio-inspector-title').textContent"), "d -> a")
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"label\"] input').value"),
      "Direct"
    )
    j_sw <- studio_section(app, "journal")$text
    expect_lt(regexpr("Direct", j_sw, fixed = TRUE), regexpr("Reverse", j_sw, fixed = TRUE))

    # Remove link from Link form (at once + held)
    app$run_js("window.__sms.sent = [];")
    since_rm <- studio_stamp(app)
    hold_studio_messages(app)
    rm_seq <- app$get_js(paste(
      studio_type_js(".sms-inspector [data-sms-field='label'] input", "Gone"),
      studio_click_js(".sms-inspector [data-sms-action='Remove link']"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, rm_seq)
    sent_rml <- vapply(studio_sent(app), `[[`, character(1L), "type")
    expect_lt(match("edit", sent_rml), match("remove", sent_rml))
    expect_identical(
      app$get_js(
        "document.querySelector('.sms-inspector [data-sms-action=\"Remove link\"]').getAttribute('aria-busy')"
      ),
      "true"
    )
    release_studio_messages(app)
    studio_wait_step(app)
    studio_wait_map(app, since_rm)
    expect_true(studio_section(app, "inspector")$hidden)
    j_rm <- studio_section(app, "journal")$text
    expect_lt(regexpr("Gone", j_rm, fixed = TRUE), regexpr("Remove link", j_rm, fixed = TRUE))
    expect_match(studio_section(app, "header")$facts, "3 links", fixed = TRUE)

    # Remove link directly from a card's list row
    app$run_js(pick_card_js("a"))
    app$wait_for_js("document.querySelector('.sms-inspector [data-sms-list=\"out\"] .sms-row') !== null")
    since_r2 <- studio_stamp(app)
    studio_do(app, studio_click_js(".sms-inspector [data-sms-list='out'] .sms-row [data-sms-action='Remove']"))
    studio_wait_map(app, since_r2)
    expect_match(studio_section(app, "header")$facts, "2 links", fixed = TRUE)
    expect_studio_clean(app)
  })

  it("[SMS-045] [SMS-046] [SMS-047] [SMS-048] edits stage fields (including date on map), reorders, adds card, refuses non-empty remove and removes empty stage", {
    app <- studio_driver("small")
    click_now(app, "[data-sms-menu='stages']")
    studio_do(app, studio_click_js("#studio-menu-stages [role='menuitem']:nth-child(2)"))
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-insp-sub').textContent"), "check")

    # Edit stage date: in Dates layout the formatted date draws under the stage's head on the map
    since_lay <- studio_stamp(app)
    studio_do(
      app,
      "{ const b = document.createElement('button'); b.type = 'button';
         b.dataset.smsEvent = JSON.stringify({ type: 'option', data: { name: 'layout', value: 'dates' } });
         document.querySelector('.sms-outline').append(b); b.click(); b.remove(); }"
    )
    studio_wait_map(app, since_lay)
    since_d <- studio_stamp(app)
    studio_do(app, set_input_change_js(".sms-inspector [data-sms-field='date'] input", "2026-04-01"))
    studio_wait_map(app, since_d)
    expect_match(
      app$get_js("document.querySelector('#studio-map [data-stage=\"check\"]').textContent"),
      "1 Apr",
      fixed = TRUE
    )

    since_id <- studio_stamp(app)
    studio_do(
      app,
      paste(
        studio_type_js(".sms-inspector [data-sms-field='id'] input", "verify"),
        "document.querySelector('.sms-inspector [data-sms-field=\"id\"] input').blur();"
      )
    )
    studio_wait_map(app, since_id)
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-insp-sub').textContent"), "verify")

    # Remove is disabled with visible reason while cards remain
    expect_identical(
      app$get_js(
        "document.querySelector('.sms-inspector [data-sms-action=\"Remove stage\"]').getAttribute('aria-disabled')"
      ),
      "true"
    )
    expect_match(
      app$get_js(
        "document.querySelector('.sms-inspector [data-sms-action-wrap=\"Remove stage\"] .sms-act-reason').textContent"
      ),
      "Move its 2 cards first\\."
    )

    # Earlier (at once + held) reorders stage to first and disables Earlier with reason
    record_studio_events(app)
    since_mv <- studio_stamp(app)
    hold_studio_messages(app)
    mv_seq <- app$get_js(paste(
      studio_type_js(".sms-inspector [data-sms-field='kicker'] input", "Phase 1"),
      studio_click_js(".sms-inspector [data-sms-action='Earlier']"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, mv_seq)
    sent_mv <- vapply(studio_sent(app), `[[`, character(1L), "type")
    expect_lt(match("edit", sent_mv), match("move", sent_mv))
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-action=\"Earlier\"]').getAttribute('aria-busy')"),
      "true"
    )
    release_studio_messages(app)
    studio_wait_step(app)
    studio_wait_map(app, since_mv)
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"kicker\"] input').value"),
      "Phase 1"
    )
    j_mv <- studio_section(app, "journal")$text
    expect_lt(regexpr("Phase 1", j_mv, fixed = TRUE), regexpr("Move stage", j_mv, fixed = TRUE))
    expect_identical(
      app$get_js(
        "document.querySelector('.sms-inspector [data-sms-action=\"Earlier\"]').getAttribute('aria-disabled')"
      ),
      "true"
    )
    expect_match(
      app$get_js(
        "document.querySelector('.sms-inspector [data-sms-action-wrap=\"Earlier\"] .sms-act-reason').textContent"
      ),
      "first stage"
    )

    # Add a card here (at once + held) places card in this stage
    app$run_js("window.__sms.sent = [];")
    since_add <- studio_stamp(app)
    hold_studio_messages(app)
    add_seq <- app$get_js(paste(
      studio_type_js(".sms-inspector [data-sms-field='flag'] input", "Ready"),
      studio_click_js(".sms-inspector [data-sms-action='Add a card here']"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, add_seq)
    sent_add <- vapply(studio_sent(app), `[[`, character(1L), "type")
    expect_lt(match("edit", sent_add), match("add", sent_add))
    expect_identical(
      app$get_js(
        "document.querySelector('.sms-inspector [data-sms-action=\"Add a card here\"]').getAttribute('aria-busy')"
      ),
      "true"
    )
    release_studio_messages(app)
    studio_wait_step(app)
    studio_wait_map(app, since_add)
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-kick').textContent"), "card")
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"stage\"] select').value"),
      "verify"
    )
    j_add <- studio_section(app, "journal")$text
    expect_lt(regexpr("Ready", j_add, fixed = TRUE), regexpr("Add card", j_add, fixed = TRUE))
    studio_do(app, studio_click_js(".sms-inspector [data-sms-field='stage'] [data-sms-action='Edit']"))
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"flag\"] input').value"),
      "Ready"
    )

    # Add an empty stage, then remove it (at once + held)
    since_s <- studio_stamp(app)
    studio_do(app, studio_click_js("[data-sms-action='+ Stage']"))
    studio_wait_map(app, since_s)
    expect_null(
      app$get_js(
        "document.querySelector('.sms-inspector [data-sms-action=\"Remove stage\"]').getAttribute('aria-disabled')"
      )
    )
    app$run_js("window.__sms.sent = [];")
    since_rms <- studio_stamp(app)
    hold_studio_messages(app)
    rms_seq <- app$get_js(paste(
      studio_type_js(".sms-inspector [data-sms-field='label'] input", "Temp stage"),
      studio_click_js(".sms-inspector [data-sms-action='Remove stage']"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, rms_seq)
    sent_rms <- vapply(studio_sent(app), `[[`, character(1L), "type")
    expect_lt(match("edit", sent_rms), match("remove", sent_rms))
    expect_identical(
      app$get_js(
        "document.querySelector('.sms-inspector [data-sms-action=\"Remove stage\"]').getAttribute('aria-busy')"
      ),
      "true"
    )
    release_studio_messages(app)
    studio_wait_step(app)
    studio_wait_map(app, since_rms)
    expect_true(studio_section(app, "inspector")$hidden)
    j_rms <- studio_section(app, "journal")$text
    expect_lt(regexpr("Temp stage", j_rms, fixed = TRUE), regexpr("Remove stage", j_rms, fixed = TRUE))
    expect_studio_clean(app)
  })

  it("[SMS-049] edits and reorders a lane, refuses non-empty remove, and removes an empty lane", {
    app <- studio_driver("small")
    click_now(app, "[data-sms-menu='lanes']")
    studio_do(app, studio_click_js("#studio-menu-lanes [role='menuitem']:first-child"))
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-kick').textContent"), "lane")

    # Rename lane id -> cascades to cards
    since_id <- studio_stamp(app)
    studio_do(
      app,
      paste(
        studio_type_js(".sms-inspector [data-sms-field='id'] input", "writing"),
        "document.querySelector('.sms-inspector [data-sms-field=\"id\"] input').blur();"
      )
    )
    studio_wait_map(app, since_id)
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-insp-sub').textContent"), "writing")
    expect_identical(studio_section(app, "status")$stamp, "")

    # Higher disabled on first lane; Remove disabled with cards reason
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-action=\"Higher\"]').getAttribute('aria-disabled')"),
      "true"
    )
    expect_match(
      app$get_js(
        "document.querySelector('.sms-inspector [data-sms-action-wrap=\"Remove lane\"] .sms-act-reason').textContent"
      ),
      "Move its 2 cards first\\."
    )

    # Lower (at once + held) reorders lanes and enables Higher, disables Lower
    record_studio_events(app)
    since_mv <- studio_stamp(app)
    hold_studio_messages(app)
    mv_seq <- app$get_js(paste(
      studio_type_js(".sms-inspector [data-sms-field='text'] textarea", "Lane note"),
      studio_click_js(".sms-inspector [data-sms-action='Lower']"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, mv_seq)
    sent_mv <- vapply(studio_sent(app), `[[`, character(1L), "type")
    expect_lt(match("edit", sent_mv), match("move", sent_mv))
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-action=\"Lower\"]').getAttribute('aria-busy')"),
      "true"
    )
    release_studio_messages(app)
    studio_wait_step(app)
    studio_wait_map(app, since_mv)
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"text\"] textarea').value"),
      "Lane note"
    )
    j_mv <- studio_section(app, "journal")$text
    expect_lt(regexpr("Lane note", j_mv, fixed = TRUE), regexpr("Move lane", j_mv, fixed = TRUE))
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-action=\"Lower\"]').getAttribute('aria-disabled')"),
      "true"
    )
    expect_null(
      app$get_js("document.querySelector('.sms-inspector [data-sms-action=\"Higher\"]').getAttribute('aria-disabled')")
    )

    # Add an empty lane and remove it (at once + held)
    since_l <- studio_stamp(app)
    studio_do(app, studio_click_js("[data-sms-action='+ Lane']"))
    studio_wait_map(app, since_l)
    app$run_js("window.__sms.sent = [];")
    since_rml <- studio_stamp(app)
    hold_studio_messages(app)
    rml_seq <- app$get_js(paste(
      studio_type_js(".sms-inspector [data-sms-field='label'] input", "Temp lane"),
      studio_click_js(".sms-inspector [data-sms-action='Remove lane']"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, rml_seq)
    sent_rml <- vapply(studio_sent(app), `[[`, character(1L), "type")
    expect_lt(match("edit", sent_rml), match("remove", sent_rml))
    expect_identical(
      app$get_js(
        "document.querySelector('.sms-inspector [data-sms-action=\"Remove lane\"]').getAttribute('aria-busy')"
      ),
      "true"
    )
    release_studio_messages(app)
    studio_wait_step(app)
    studio_wait_map(app, since_rml)
    expect_true(studio_section(app, "inspector")$hidden)
    j_rml <- studio_section(app, "journal")$text
    expect_lt(regexpr("Temp lane", j_rml, fixed = TRUE), regexpr("Remove lane", j_rml, fixed = TRUE))
    expect_studio_clean(app)
  })
})

describe("keyboard-only inspector flow and layout at narrow and phone widths", {
  it("opens a card with Enter on the map, focuses heading, changes status with arrow keys, closes with Escape back to map", {
    app <- studio_driver("small")
    app$run_js("document.querySelector('#studio-map [data-card=\"b\"]').focus()")
    studio_press(app, "Enter", key_code = 13L)
    app$wait_for_js("document.querySelector('.sms-inspector').hidden === false")
    app$wait_for_js("document.activeElement?.id === 'studio-inspector-title'")

    # Focus the checked status radio ("running") and move with ArrowRight to "waiting"
    app$run_js("document.querySelector('.sms-inspector [data-sms-field=\"status\"] input:checked').focus()")
    since <- studio_stamp(app)
    studio_press(app, "ArrowRight", key_code = 39L)
    studio_wait_step(app)
    studio_wait_map(app, since)
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"status\"] input:checked').value"),
      "waiting"
    )

    # Escape closes inspector and puts focus back inside the map
    studio_press(app, "Escape", key_code = 27L)
    app$wait_for_js("document.querySelector('.sms-inspector').hidden === true")
    expect_true(app$get_js("document.getElementById('studio-map').contains(document.activeElement)"))
    expect_studio_clean(app)
  })

  it("keeps inspector clear of header actions at 900px, reachable map above bottom sheet at 375px, and inert after Done", {
    app <- studio_driver("small")
    app$run_js(pick_card_js("b"))
    app$wait_for_js("document.querySelector('.sms-inspector').hidden === false")

    # 900px: header actions do not overlap inspector
    app$set_window_size(width = 900L, height = 700L, wait = FALSE)
    app$wait_for_js("window.innerWidth === 900")
    mid <- app$get_js(
      "(() => {
         const insp = document.querySelector('.sms-inspector').getBoundingClientRect();
         const acts = [...document.querySelectorAll('.sms-acts > button, .sms-outline > button, .sms-menu > [data-sms-menu]')]
           .filter((b) => getComputedStyle(b).display !== 'none')
           .map((b) => {
             const r = b.getBoundingClientRect();
             const hit = document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2);
             return { right: r.right, top: r.top, bottom: r.bottom, hitInside: b.contains(hit) };
           });
         return { inspLeft: insp.left, inspBottom: insp.bottom, acts };
       })()"
    )
    expect_length(mid$acts, 6L)
    for (a in mid$acts) {
      expect_true(a$hitInside)
      expect_true(a$right <= mid$inspLeft || a$top >= mid$inspBottom)
    }

    # 375px: inspector is a bottom sheet, map stays reachable above it when scrolled, no horizontal overflow
    app$set_window_size(width = 375L, height = 667L, wait = FALSE)
    app$wait_for_js("window.innerWidth === 375")
    app$run_js("document.getElementById('studio-map').scrollIntoView({ block: 'start' })")
    sheet <- app$get_js(
      "(() => {
         const insp = document.querySelector('.sms-inspector');
         const ir = insp.getBoundingClientRect();
         const map = document.getElementById('studio-map');
         const mr = map.getBoundingClientRect();
         const hit = document.elementFromPoint(mr.left + mr.width / 2, Math.max(8, mr.top + 12));
         return {
           inspTop: ir.top,
           mapTop: mr.top,
           hitMap: map.contains(hit),
           overflow: insp.scrollWidth > insp.clientWidth
         };
       })()"
    )
    expect_gt(sheet$inspTop, 150)
    expect_lt(sheet$mapTop, sheet$inspTop)
    expect_true(sheet$hitMap)
    expect_false(sheet$overflow)

    # Phone form controls are 16px (no iOS focus zoom) and at least 44px tall
    phone_controls <- app$get_js(
      "(() => [...document.querySelectorAll('.sms-inspector .sms-in')].map((el) => ({
         tag: el.tagName,
         fontSize: getComputedStyle(el).fontSize,
         height: el.getBoundingClientRect().height
       })))()"
    )
    expect_gt(length(phone_controls), 0L)
    for (ctrl in phone_controls) {
      expect_identical(ctrl$fontSize, "16px")
      expect_gte(ctrl$height, 44)
    }

    # 375px with an open room: one sheet at a time, so the room covers the form (hidden and inert) until it closes
    studio_open_code(app)
    app$wait_for_js("document.getAnimations().length === 0")
    phone <- app$get_js(
      "(() => {
         const insp = document.querySelector('.sms-inspector');
         const rr = document.querySelector('[data-sms-room-of=\"code\"]').getBoundingClientRect();
         return { display: getComputedStyle(insp).display, inert: insp.inert, roomTop: rr.top, vh: window.innerHeight,
                  target: insp.dataset.smsUid !== undefined };
       })()"
    )
    expect_identical(phone$display, "none")
    expect_true(phone$inert)
    expect_true(phone$target)
    expect_lt(phone$roomTop, phone$vh)
    click_now(app, "[data-sms-close='code']")
    app$wait_for_js("document.getAnimations().length === 0")
    expect_identical(app$get_js("getComputedStyle(document.querySelector('.sms-inspector')).display"), "flex")
    expect_false(app$get_js("document.querySelector('.sms-inspector').inert"))

    # Done makes inspector and skip link inert
    app$set_window_size(width = 1280L, height = 800L, wait = FALSE)
    app$wait_for_js("window.innerWidth === 1280")
    app$run_js(studio_click_js(".sms-done"))
    app$wait_for_js(sprintf("%s.dataset.smsClosed !== undefined", studio_root_js))
    expect_true(app$get_js("document.querySelector('.sms-inspector').inert"))
    expect_true(app$get_js("document.querySelector('.sms-skip').inert"))
    expect_studio_clean(app, closed = TRUE)
  })
})

describe("inspector form edge cases: at-once + Card, broken example picks, focusout revert, in-flight guards and forced-colors", {
  it("places a new card in the picked card's stage when pick and + Card fire in one call, and keeps broken example cards clickable after + Card", {
    app <- studio_driver("small")
    since <- studio_stamp(app)
    app$run_js(paste(
      pick_card_js("b"),
      studio_click_js("[data-sms-action='+ Card']")
    ))
    studio_wait_step(app)
    studio_wait_map(app, since)
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-kick').textContent"), "card")
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-insp-sub').textContent"), "card")
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"stage\"] select').value"),
      "check"
    )
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"lane\"] select').value"),
      "docs"
    )
    expect_studio_clean(app)

    # Example template starts broken on a link: + Card leaves the drawn map stale, yet unchanged cards remain clickable
    app_ex <- studio_driver("none")
    studio_do(app_ex, studio_click_js("[data-sms-open='example']"))
    studio_do(app_ex, studio_click_js("[data-sms-action='+ Card']"))
    app_ex$run_js(pick_card_js("round_dose"))
    app_ex$wait_for_js("document.querySelector('.sms-inspector .sms-insp-sub')?.textContent === 'round_dose'")
    expect_null(app_ex$get_js("document.querySelector('.sms-toast').dataset.smsOn ?? null"))
    expect_studio_clean(app_ex)
  })

  it("reverts refused select and date edits on focusout with no further server message", {
    app <- studio_driver("small")
    app$run_js(pick_card_js("b"))
    app$wait_for_js("document.querySelector('.sms-inspector [data-sms-field=\"tone\"] select') !== null")

    # Select: focus, pick an unallowed value so server refuses while focused, then blur with no further server message
    studio_do(
      app,
      "{ const sel = document.querySelector('.sms-inspector [data-sms-field=\"tone\"] select');
         const opt = document.createElement('option'); opt.value = 'nope'; opt.textContent = 'Nope';
         sel.append(opt); sel.focus(); sel.value = 'nope';
         sel.dispatchEvent(new Event('change', { bubbles: true })); }"
    )
    expect_match(studio_section(app, "notice")$text, "not allowed")
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"tone\"] select').value"),
      "nope"
    )
    n_before <- app$get_js(sprintf("Number(%s.dataset.smsN)", studio_root_js))
    app$run_js("document.querySelector('.sms-inspector [data-sms-field=\"tone\"] select').blur()")
    app$wait_for_js("document.querySelector('.sms-inspector [data-sms-field=\"tone\"] select').value === ''")
    expect_identical(app$get_js(sprintf("Number(%s.dataset.smsN)", studio_root_js)), n_before)

    # Date input on a stage: focus, send a refused edit while focused, then blur with no further server message
    click_now(app, "[data-sms-menu='stages']")
    studio_do(app, studio_click_js("#studio-menu-stages [role='menuitem']:nth-child(2)"))
    app$wait_for_js("document.querySelector('.sms-inspector [data-sms-field=\"date\"] input') !== null")
    studio_do(
      app,
      "{ const el = document.querySelector('.sms-inspector [data-sms-field=\"date\"] input');
         const ev = JSON.parse(el.getAttribute('data-sms-event'));
         ev.data.field = 'unknown';
         el.setAttribute('data-sms-event', JSON.stringify(ev));
         el.focus(); el.value = '2026-04-01';
         el.dispatchEvent(new Event('change', { bubbles: true })); }"
    )
    expect_match(studio_section(app, "notice")$text, "cannot edit")
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"date\"] input').value"),
      "2026-04-01"
    )
    n_date <- app$get_js(sprintf("Number(%s.dataset.smsN)", studio_root_js))
    app$run_js("document.querySelector('.sms-inspector [data-sms-field=\"date\"] input').blur()")
    app$wait_for_js("document.querySelector('.sms-inspector [data-sms-field=\"date\"] input').value === ''")
    expect_identical(app$get_js(sprintf("Number(%s.dataset.smsN)", studio_root_js)), n_date)
    expect_studio_clean(app)
  })

  it("protects in-flight select, radio and toggle edits, ignores out-of-order answers, and preserves Connect drafts across redraws", {
    app <- studio_driver("small")
    # Snapshot the real initial card "b" server message (stage=check, status=running, milestone=FALSE)
    app$run_js(sprintf(
      "window.__sms = window.__sms || {}; window.__sms.snap = null;
       %s.addEventListener('stagemap-studio:message', (e) => {
         if (!window.__sms.snap && e.detail?.sections?.inspector?.uid === 'u2') {
           window.__sms.snap = structuredClone(e.detail);
         }
       });",
      studio_root_js
    ))
    app$run_js(pick_card_js("b"))
    app$wait_for_js(
      "window.__sms.snap !== null && document.querySelector('.sms-inspector [data-sms-field=\"stage\"] select') !== null"
    )

    # (a) In-flight guards on select, radio and toggle against an older message carrying old values
    hold_studio_messages(app)
    old_ack <- app$get_js(sprintf("Number(%s.dataset.smsAck)", studio_root_js))
    last_seq <- app$get_js(paste(
      set_select_js(".sms-inspector [data-sms-field='stage'] select", "ship"),
      "document.querySelector('.sms-inspector [data-sms-field=\"stage\"] select').blur();",
      studio_click_js(".sms-inspector [data-sms-field='status'] input[value='done']"),
      studio_click_js(".sms-inspector [data-sms-field='milestone'] input[type='checkbox']"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, last_seq)
    app$run_js(sprintf(
      "{ const r = %s;
         const oldMsg = structuredClone(window.__sms.snap);
         oldMsg.n = Number(r.dataset.smsN) + 0.5;
         oldMsg.ack = %d;
         r.dispatchEvent(new CustomEvent('stagemap-studio:deliver', { detail: oldMsg })); }",
      studio_root_js,
      as.integer(old_ack)
    ))
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"stage\"] select').value"),
      "ship"
    )
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"status\"] input:checked').value"),
      "done"
    )
    expect_true(
      app$get_js(
        "document.querySelector('.sms-inspector [data-sms-field=\"milestone\"] input[type=\"checkbox\"]').checked"
      )
    )
    release_studio_messages(app)
    studio_wait_step(app)
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"stage\"] select').value"),
      "ship"
    )
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"status\"] input:checked').value"),
      "done"
    )
    expect_true(
      app$get_js(
        "document.querySelector('.sms-inspector [data-sms-field=\"milestone\"] input[type=\"checkbox\"]').checked"
      )
    )

    # (b) Reverse-order message delivery on two tone edits ends on the newer value
    hold_studio_messages(app)
    app$run_js(set_select_js(".sms-inspector [data-sms-field='tone'] select", "good"))
    wait_studio_held(app, "messages", 1L)
    app$run_js(paste(
      set_select_js(".sms-inspector [data-sms-field='tone'] select", "warn"),
      "document.querySelector('.sms-inspector [data-sms-field=\"tone\"] select').blur();"
    ))
    wait_studio_held(app, "messages", 2L)
    release_studio_messages(app, reverse = TRUE)
    studio_wait_step(app)
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"tone\"] select').value"),
      "warn"
    )

    # (c) Connect draft selects survive an unrelated edit that redraws the inspector
    app$run_js(pick_card_js("a"))
    app$wait_for_js(
      "document.querySelector('.sms-inspector .sms-insp-sub')?.textContent === 'a' &&
       document.querySelector('.sms-inspector [data-sms-list=\"out\"] [data-sms-field=\"to\"] select') !== null"
    )
    app$run_js(paste(
      set_select_js(".sms-inspector [data-sms-list='out'] [data-sms-field='to'] select", "u4"),
      set_select_js(".sms-inspector [data-sms-list='out'] [data-sms-field='kind'] select", "hand")
    ))
    studio_do(app, set_select_js(".sms-inspector [data-sms-field='tone'] select", "good"))
    expect_identical(
      app$get_js(
        "document.querySelector('.sms-inspector [data-sms-list=\"out\"] [data-sms-field=\"to\"] select').value"
      ),
      "u4"
    )
    expect_identical(
      app$get_js(
        "document.querySelector('.sms-inspector [data-sms-list=\"out\"] [data-sms-field=\"kind\"] select').value"
      ),
      "hand"
    )
    expect_studio_clean(app)
  })

  it("puts radio aria-invalid on radio inputs (not fieldset) and keeps focus outlines distinct in forced-colors mode", {
    app <- studio_driver("small")
    app$run_js(pick_card_js("b"))
    app$wait_for_js("document.querySelector('.sms-inspector [data-sms-field=\"status\"] fieldset') !== null")

    # Deliver a radio field problem: aria-invalid goes on each radio input, never on fieldset; text lands in .sms-fld-live
    app$run_js(sprintf(
      "{ const r = %s; r.dispatchEvent(new CustomEvent('stagemap-studio:deliver', { detail: {
          ns: r.dataset.smsNs, n: Number(r.dataset.smsN) + 0.5, ack: Number(r.dataset.smsAck), rev: Number(r.dataset.smsRev),
          sections: { inspector: {
            kind: 'link', uid: 'u9', title: 'a -> b', sub: 'unknown',
            fields: [{
              name: 'kind', label: 'Kind', type: 'radio', value: 'bad',
              choices: [
                { value: '', label: 'None', glyph: null, missing: false },
                { value: 'bad', label: 'bad (missing)', glyph: null, missing: true }
              ],
              event: { type: 'edit', data: { table: 'links', uid: 'u9', field: 'kind' } },
              problem: { text: 'Kind \"bad\" is not in kinds.', fixes: [] }
            }],
            lists: [], actions: []
          } } } })); }",
      studio_root_js
    ))
    radio_aria <- app$get_js(
      "(() => {
         const fld = document.querySelector('.sms-inspector [data-sms-field=\"kind\"]');
         const fs = fld.querySelector('fieldset');
         const inputs = [...fld.querySelectorAll('input[type=\"radio\"]')];
         const live = fld.querySelector('.sms-fld-live');
         return {
           fsInvalid: fs.hasAttribute('aria-invalid'),
           fsDesc: fs.getAttribute('aria-describedby'),
           allInvalid: inputs.length > 0 && inputs.every((i) => i.getAttribute('aria-invalid') === 'true'),
           liveText: live?.querySelector('.sms-err')?.textContent ?? ''
         };
       })()"
    )
    expect_false(radio_aria$fsInvalid)
    expect_match(radio_aria$fsDesc, "-prob$", fixed = FALSE)
    expect_true(radio_aria$allInvalid)
    expect_match(radio_aria$liveText, "not in kinds", fixed = TRUE)

    # Restore real card "b" view and emulate forced-colors: active
    app$run_js(pick_card_js("a"))
    app$wait_for_js("document.querySelector('.sms-inspector .sms-insp-sub')?.textContent === 'a'")
    app$run_js(pick_card_js("b"))
    app$wait_for_js("document.querySelector('.sms-inspector .sms-insp-sub')?.textContent === 'b'")
    studio_emulate(app, "forced-colors", "active")

    # Focus status radio via keyboard so :focus-visible matches, check distinct focus outline vs checked border
    app$run_js("document.querySelector('.sms-inspector [data-sms-field=\"status\"] input:checked').focus()")
    studio_press(app, "ArrowRight", key_code = 39L)
    studio_wait_step(app)
    radio_fc <- app$get_js(
      "(() => {
         const input = document.querySelector('.sms-inspector [data-sms-field=\"status\"] input:checked');
         const face = input.nextElementSibling;
         const cs = getComputedStyle(face);
         return {
           focusVisible: input.matches(':focus-visible'),
           outlineStyle: cs.outlineStyle,
           outlineWidth: cs.outlineWidth,
           outlineOffset: cs.outlineOffset,
           borderWidth: cs.borderTopWidth
         };
       })()"
    )
    expect_true(radio_fc$focusVisible)
    expect_identical(radio_fc$outlineStyle, "solid")
    expect_identical(radio_fc$outlineWidth, "2px")
    expect_identical(radio_fc$outlineOffset, "2px")
    expect_identical(radio_fc$borderWidth, "2px")

    # Make Id invalid (duplicate "a"): unfocused has dashed border; focused adds distinct solid outline
    studio_do(
      app,
      paste(
        studio_type_js(".sms-inspector [data-sms-field='id'] input", "a"),
        "document.querySelector('.sms-inspector [data-sms-field=\"id\"] input').blur();"
      )
    )
    unfocused_fc <- app$get_js(
      "(() => {
         const cs = getComputedStyle(document.querySelector('.sms-inspector [data-sms-field=\"id\"] input'));
         return { borderStyle: cs.borderTopStyle, borderWidth: cs.borderTopWidth, outlineStyle: cs.outlineStyle };
       })()"
    )
    expect_identical(unfocused_fc$borderStyle, "dashed")
    expect_identical(unfocused_fc$borderWidth, "2px")
    expect_identical(unfocused_fc$outlineStyle, "none")

    app$run_js("document.querySelector('.sms-inspector [data-sms-field=\"id\"] input').focus()")
    focused_fc <- app$get_js(
      "(() => {
         const el = document.querySelector('.sms-inspector [data-sms-field=\"id\"] input');
         const cs = getComputedStyle(el);
         return {
           focusVisible: el.matches(':focus-visible'),
           borderStyle: cs.borderTopStyle,
           outlineStyle: cs.outlineStyle,
           outlineWidth: cs.outlineWidth,
           outlineOffset: cs.outlineOffset
         };
       })()"
    )
    expect_true(focused_fc$focusVisible)
    expect_identical(focused_fc$borderStyle, "dashed")
    expect_identical(focused_fc$outlineStyle, "solid")
    expect_identical(focused_fc$outlineWidth, "2px")
    expect_identical(focused_fc$outlineOffset, "2px")
    expect_studio_clean(app)
  })
})
