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

  it("keeps focus in menu trigger, Close button redraws, and returns to inspectorOpener on Close", {
    app <- studio_driver("small")
    # Pick Stages menu item via keyboard: trigger keeps focus until inspector focuses, Close returns to trigger
    app$run_js("document.querySelector('[data-sms-menu=\"stages\"]').focus()")
    studio_press(app, "Enter", key_code = 13L)
    studio_press(app, "ArrowDown", key_code = 40L)
    studio_press(app, "Enter", key_code = 13L)
    expect_identical(app$get_js("document.activeElement?.dataset?.smsMenu"), "stages")
    studio_wait_step(app)
    expect_identical(app$get_js("document.activeElement.id"), "studio-inspector-title")

    # Focus Close button while a message updates inspector title in place: Close stays focused
    app$run_js("document.querySelector('.sms-inspector [data-sms-action=\"Close\"]').focus()")
    app$run_js(sprintf(
      "{ const r = %s; r.dispatchEvent(new CustomEvent('stagemap-studio:deliver', { detail: {
          ns: r.dataset.smsNs, n: Number(r.dataset.smsN) + 0.5, ack: Number(r.dataset.smsAck), rev: Number(r.dataset.smsRev),
          sections: { inspector: { kind: 'stage', uid: 'u5', title: 'Updated label', sub: 'check',
            actions: [{ label: 'Close', event: { type: 'target', data: { kind: 'none', uid: null } }, style: 'plain', disabled: null, collect: false }]
          } } } })); }",
      studio_root_js
    ))
    expect_identical(app$get_js("document.activeElement?.dataset?.smsAction"), "Close")
    expect_identical(app$get_js("document.querySelector('#studio-inspector-title').textContent"), "Updated label")

    # Activate Close button -> focus returns to Stages trigger
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

  it("keeps inspector clear of header actions at 900px, above an open room at 375px, and inert after Done", {
    app <- studio_driver("small")
    app$run_js(
      "document.querySelector('#studio-map [data-card=\"b\"]').dispatchEvent(new MouseEvent('click', { bubbles: true, detail: 1 }))"
    )
    app$wait_for_js("document.querySelector('.sms-inspector').hidden === false")

    # 900px: header actions do not overlap inspector and Open map is directly clickable
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

    # 375px with open room: inspector sits above the room, not behind it
    app$set_window_size(width = 375L, height = 667L, wait = FALSE)
    app$wait_for_js("window.innerWidth === 375")
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

    # Done makes inspector and skip link inert too
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
