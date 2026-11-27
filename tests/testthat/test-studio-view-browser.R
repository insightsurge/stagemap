skip_without_chrome()

# Browser tests for the inspector forms, target selection, hover hints, keyboard flow, phone sheet,
# and at-once / held-message behaviour for every inspector action.

pick_card_js <- function(id) {
  sprintf(
    "document.querySelector('#studio-map [data-card=\"%s\"]').dispatchEvent(new MouseEvent('click', { bubbles: true, detail: 1 }))",
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
    studio_do(
      app,
      paste(
        studio_type_js(".sms-inspector [data-sms-field='sub'] input", "By stage edit"),
        studio_click_js(".sms-inspector [data-sms-field='stage'] [data-sms-action='Edit']")
      )
    )
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-kick').textContent"), "stage")
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-insp-sub').textContent"), "ship")
    expect_match(studio_section(app, "journal")$text, "By stage edit", fixed = TRUE)

    # Trace from here (at once + held) on card "a"
    app$run_js(pick_card_js("a"))
    app$wait_for_js("document.querySelector('.sms-inspector .sms-kick')?.textContent === 'card'")
    hold_studio_messages(app)
    tr_seq <- app$get_js(paste(
      studio_type_js(".sms-inspector [data-sms-field='sub'] input", "Before trace"),
      studio_click_js(".sms-inspector [data-sms-action='Trace from here']"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, tr_seq)
    expect_identical(
      app$get_js(
        "document.querySelector('.sms-inspector [data-sms-action=\"Trace from here\"]').getAttribute('aria-busy')"
      ),
      "true"
    )
    release_studio_messages(app)
    studio_wait_step(app)
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
    studio_do(
      app,
      paste(
        studio_type_js(".sms-inspector [data-sms-field='label'] input", "Before remove"),
        studio_click_js(".sms-inspector [data-sms-action='Remove card']")
      )
    )
    studio_wait_map(app, since)
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

  it("[SMS-050] shows inline problem and fix on duplicate id, refuses stale map click, and clears all three", {
    app <- studio_driver("small")
    # Add an unlinked card so duplicating its id produces only the 2 duplicate faults (no broken link)
    since_add <- studio_stamp(app)
    studio_do(app, studio_click_js("[data-sms-action='+ Card']"))
    studio_wait_map(app, since_add)

    stamp_before <- studio_stamp(app)
    studio_do(
      app,
      paste(
        studio_type_js(".sms-inspector [data-sms-field='id'] input", "b"),
        "document.querySelector('.sms-inspector [data-sms-field=\"id\"] input').blur();"
      )
    )
    # Problem beside Id, stamp counts 2 duplicate faults, drawn map stays on last working version
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"id\"] input').getAttribute('aria-invalid')"),
      "true"
    )
    expect_match(
      app$get_js("document.querySelector('.sms-inspector [data-sms-field=\"id\"] .sms-err').textContent"),
      "Another card"
    )
    expect_match(studio_section(app, "status")$stamp, "2 problems", fixed = TRUE)
    expect_identical(studio_stamp(app), stamp_before)

    # Clicking card "b" on the stale drawn map refuses with a notice instead of targeting the wrong row
    app$run_js(pick_card_js("b"))
    app$wait_for_js("document.querySelector('.sms-toast').dataset.smsOn !== undefined")
    expect_match(studio_section(app, "notice")$text, "out of date")

    # Apply inline fix (at once + held) -> clears problem, stamp, and rebuilds map
    hold_studio_messages(app)
    fix_seq <- app$get_js(paste(
      studio_type_js(".sms-inspector [data-sms-field='label'] input", "Fixed draft"),
      studio_click_js(".sms-inspector [data-sms-field='id'] .sms-prob-fixes button"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, fix_seq)
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
    expect_identical(studio_section(app, "status")$stamp, "")
    expect_identical(app$get_js("document.querySelector('.sms-inspector .sms-insp-sub').textContent"), "card")
    expect_match(studio_section(app, "journal")$text, "Fixed draft", fixed = TRUE)
    expect_studio_clean(app)
  })
})

describe("links, stages and lanes inspector forms", {
  it("[SMS-042] [SMS-043] connects, inspects, changes kind, swaps ends and removes links (at once and held)", {
    app <- studio_driver("small")
    app$run_js(pick_card_js("a"))
    app$wait_for_js("document.querySelector('.sms-inspector [data-sms-list=\"out\"] .sms-add') !== null")

    # Connect a -> d with kind "hand" (at once after typing + held)
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

    since_sw <- studio_stamp(app)
    hold_studio_messages(app)
    swap_seq <- app$get_js(paste(
      studio_type_js(".sms-inspector [data-sms-field='label'] input", "Direct"),
      studio_click_js(".sms-inspector [data-sms-action='Swap ends']"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, swap_seq)
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-action=\"Swap ends\"]').getAttribute('aria-busy')"),
      "true"
    )
    release_studio_messages(app)
    studio_wait_step(app)
    studio_wait_map(app, since_sw)
    expect_identical(app$get_js("document.querySelector('#studio-inspector-title').textContent"), "d -> a")
    expect_match(studio_section(app, "journal")$text, "Direct", fixed = TRUE)

    # Remove link from Link form (at once + held)
    since_rm <- studio_stamp(app)
    hold_studio_messages(app)
    rm_seq <- app$get_js(paste(
      studio_type_js(".sms-inspector [data-sms-field='label'] input", "Gone"),
      studio_click_js(".sms-inspector [data-sms-action='Remove link']"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, rm_seq)
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
    since_mv <- studio_stamp(app)
    hold_studio_messages(app)
    mv_seq <- app$get_js(paste(
      studio_type_js(".sms-inspector [data-sms-field='kicker'] input", "Phase 1"),
      studio_click_js(".sms-inspector [data-sms-action='Earlier']"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, mv_seq)
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-action=\"Earlier\"]').getAttribute('aria-busy')"),
      "true"
    )
    release_studio_messages(app)
    studio_wait_step(app)
    studio_wait_map(app, since_mv)
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
    since_add <- studio_stamp(app)
    hold_studio_messages(app)
    add_seq <- app$get_js(paste(
      studio_type_js(".sms-inspector [data-sms-field='flag'] input", "Ready"),
      studio_click_js(".sms-inspector [data-sms-action='Add a card here']"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, add_seq)
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

    # Add an empty stage, then remove it (at once + held)
    since_s <- studio_stamp(app)
    studio_do(app, studio_click_js("[data-sms-action='+ Stage']"))
    studio_wait_map(app, since_s)
    expect_null(
      app$get_js(
        "document.querySelector('.sms-inspector [data-sms-action=\"Remove stage\"]').getAttribute('aria-disabled')"
      )
    )
    since_rms <- studio_stamp(app)
    hold_studio_messages(app)
    rms_seq <- app$get_js(paste(
      studio_type_js(".sms-inspector [data-sms-field='label'] input", "Temp stage"),
      studio_click_js(".sms-inspector [data-sms-action='Remove stage']"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, rms_seq)
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
    since_mv <- studio_stamp(app)
    hold_studio_messages(app)
    mv_seq <- app$get_js(paste(
      studio_type_js(".sms-inspector [data-sms-field='text'] textarea", "Lane note"),
      studio_click_js(".sms-inspector [data-sms-action='Lower']"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, mv_seq)
    expect_identical(
      app$get_js("document.querySelector('.sms-inspector [data-sms-action=\"Lower\"]').getAttribute('aria-busy')"),
      "true"
    )
    release_studio_messages(app)
    studio_wait_step(app)
    studio_wait_map(app, since_mv)
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
    since_rml <- studio_stamp(app)
    hold_studio_messages(app)
    rml_seq <- app$get_js(paste(
      studio_type_js(".sms-inspector [data-sms-field='label'] input", "Temp lane"),
      studio_click_js(".sms-inspector [data-sms-action='Remove lane']"),
      sprintf("Number(%s.dataset.smsSent)", studio_root_js)
    ))
    studio_wait_held(app, rml_seq)
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

    # 375px with open room: inspector sits above the room
    studio_open_code(app)
    app$wait_for_js(
      "(() => { const t = getComputedStyle(document.querySelector('.sms-tray')).transform;
         return t === 'none' || t === 'matrix(1, 0, 0, 1, 0, 0)'; })()"
    )
    phone <- app$get_js(
      "(() => {
         const insp = document.querySelector('.sms-inspector');
         const ir = insp.getBoundingClientRect();
         const rr = document.querySelector('[data-sms-room-of=\"code\"]').getBoundingClientRect();
         const btn = insp.querySelector('[data-sms-action=\"Close\"]');
         const br = btn.getBoundingClientRect();
         const hit = document.elementFromPoint(br.left + br.width / 2, br.top + br.height / 2);
         return { inspBottom: ir.bottom, roomTop: rr.top, hitClose: btn.contains(hit) };
       })()"
    )
    expect_lte(phone$inspBottom, phone$roomTop + 1)
    expect_true(phone$hitClose)

    # Done makes inspector and skip link inert
    app$set_window_size(width = 1280L, height = 800L, wait = FALSE)
    app$wait_for_js("window.innerWidth === 1280")
    click_now(app, "[data-sms-close='code']")
    app$run_js(studio_click_js(".sms-done"))
    app$wait_for_js(sprintf("%s.dataset.smsClosed !== undefined", studio_root_js))
    expect_true(app$get_js("document.querySelector('.sms-inspector').inert"))
    expect_true(app$get_js("document.querySelector('.sms-skip').inert"))
    expect_studio_clean(app, closed = TRUE)
  })
})
