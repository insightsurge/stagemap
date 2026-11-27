# The studio's view: the sections the page draws, computed from the state.

delayedAssign("small", full_map(title = "A map"))

describe("studio_view()", {
  it("returns every core section and every registered room section", {
    view <- studio_view(studio_state_new(small))
    expect_named(
      view,
      c("header", "outline", "inspector", "journal", "start", "status", "notice", names(studio_rooms))
    )
    expect_identical(
      view$header,
      list(title = "A map", facts = "4 cards in 3 stages and 2 lanes, 3 links", template = "given")
    )
    expect_identical(view$status, list(drawn_rev = 0L, problems = 0L, closed = FALSE))
    expect_null(view$inspector)
    expect_identical(view$journal, list(entries = list(), can_undo = FALSE))
    expect_false(view$start$open)
    expect_null(view$notice)
  })

  it("shows the notice and the closed state of the state", {
    state <- studio_state_new(small)
    state$notice <- list(n = 1L, text = "No.", tone = "problem", room = NULL)
    state$closed <- TRUE
    view <- studio_view(state)
    expect_identical(view$notice$text, "No.")
    expect_true(view$status$closed)
  })

  it("checks the state", {
    expect_error(studio_view(list(1)), "state")
  })
})

describe("studio_facts()", {
  it("counts cards, stages, lanes and links, in the singular for one", {
    expect_identical(
      studio_facts(studio_template("blank")$map),
      "1 card in 1 stage and 1 lane, 0 links"
    )
    expect_identical(
      studio_facts(studio_state_new(small)$doc),
      "4 cards in 3 stages and 2 lanes, 3 links"
    )
  })

  it("checks the input", {
    expect_error(studio_facts("map"), "x")
  })
})

describe("studio_view_outline()", {
  it("lists menus with neutral counts, hover hints by kind/id, and target-free add actions", {
    s <- studio_state_new(small)
    out0 <- studio_view_outline(s$doc)
    expect_identical(vapply(out0$menus, `[[`, "", "id"), c("stages", "lanes"))
    expect_length(out0$menus[[1L]]$items, 3L)
    expect_length(out0$menus[[2L]]$items, 2L)
    expect_length(out0$hints$card, 4L)
    expect_identical(out0$hints$card[["b"]], "Card: Review")
    expect_identical(out0$hints$stage[["ship"]], "Stage: Ship")
    expect_identical(vapply(out0$menus[[1L]]$items, `[[`, integer(1), "count"), c(1L, 2L, 1L))
    expect_identical(out0$actions[[1L]]$event$data, list(table = "cards"))
    expect_identical(out0$actions[[2L]]$event$data, list(table = "stages"))
    expect_identical(out0$actions[[3L]]$event$data, list(table = "lanes"))

    # Blank labels fall back to id or "Untitled ...", and empty/blank-id tables yield empty menu/hint lists
    doc_blank <- s$doc
    doc_blank$tables$cards$label[[1L]] <- ""
    doc_blank$tables$cards$label[[2L]] <- ""
    doc_blank$tables$cards$id[[2L]] <- ""
    doc_blank$tables$stages$label <- rep("", nrow(doc_blank$tables$stages))
    doc_blank$tables$stages$id <- rep("", nrow(doc_blank$tables$stages))
    out_blank <- studio_view_outline(doc_blank)
    expect_identical(out_blank$hints$card[["a"]], "Card: a")
    expect_length(out_blank$hints$card, 3L)
    expect_identical(out_blank$menus[[1L]]$items[[1L]]$label, "Untitled stage")
    expect_identical(out_blank$hints$stage, structure(list(), names = character()))

    doc_empty <- s$doc
    doc_empty$tables$cards <- doc_empty$tables$cards[0L, , drop = FALSE]
    doc_empty$tables$stages <- doc_empty$tables$stages[0L, , drop = FALSE]
    out_empty <- studio_view_outline(doc_empty)
    expect_identical(out_empty$hints$card, structure(list(), names = character()))
    expect_identical(out_empty$hints$stage, structure(list(), names = character()))
    expect_identical(out_empty$menus[[1L]]$items, list())
  })
})

describe("studio_view_inspector()", {
  field_by <- function(form, name) {
    idx <- match(name, vapply(form$fields, `[[`, "", "name"))
    if (is.na(idx)) NULL else form$fields[[idx]]
  }
  action_by <- function(form, label) {
    idx <- match(label, vapply(form$actions, `[[`, "", "label"))
    if (is.na(idx)) NULL else form$actions[[idx]]
  }
  # Checks every event template emitted by an inspector form passes studio_event_check() once values are filled.
  expect_valid_form_events <- function(insp) {
    check_ev <- function(ev) {
      checked <- studio_event_check(list(seq = 1L, type = ev$type, data = ev$data, rev = 0L))
      expect_identical(checked$type, ev$type)
    }
    for (f in insp$fields) {
      if (!is.null(f$event)) {
        val <- if (identical(f$type, "toggle")) FALSE else "x"
        check_ev(list(type = f$event$type, data = c(f$event$data, list(value = val))))
      }
      if (!is.null(f$action)) {
        check_ev(f$action$event)
      }
      if (!is.null(f$problem)) {
        for (fx in f$problem$fixes) {
          check_ev(fx$event)
        }
      }
    }
    for (lst in insp$lists) {
      for (r in lst$rows) {
        for (a in r$actions) {
          check_ev(a$event)
        }
      }
      if (!is.null(lst$add)) {
        drafts <- stats::setNames(
          lapply(lst$add$fields, function(df) if (nzchar(df$value)) df$value else "u1"),
          vapply(lst$add$fields, `[[`, "", "name")
        )
        act_ev <- lst$add$action$event
        merged <- utils::modifyList(act_ev$data, drafts, keep.null = TRUE)
        check_ev(list(type = act_ev$type, data = merged))
      }
    }
    for (a in insp$actions) {
      check_ev(a$event)
    }
  }

  it("returns NULL for none, unknown kind or missing row, and builds the full card form", {
    s <- studio_state_new(small)
    expect_null(studio_view_inspector(s$doc, s$target))
    expect_null(studio_view_inspector(s$doc, list(kind = "zone", uid = "u1")))
    expect_null(studio_view_inspector(s$doc, list(kind = "card", uid = "u999")))

    doc_blank <- s$doc
    doc_blank$tables$cards$label[[1L]] <- ""
    expect_identical(studio_view_inspector(doc_blank, list(kind = "card", uid = "u1"))$title, "a")

    card_insp <- studio_view_inspector(s$doc, list(kind = "card", uid = "u2"))
    expect_identical(card_insp$kind, "card")
    expect_identical(card_insp$uid, "u2")
    expect_identical(card_insp$title, "Review")
    expect_identical(card_insp$sub, "b")
    expect_identical(
      vapply(card_insp$fields, `[[`, "", "name"),
      c("label", "id", "stage", "lane", "status", "sub", "tone", "zone", "milestone", "text")
    )
    expect_identical(
      vapply(card_insp$fields, `[[`, "", "type"),
      c("text", "id", "select", "select", "radio", "text", "select", "select", "toggle", "textarea")
    )
    expect_identical(field_by(card_insp, "stage")$action$label, "Edit")
    expect_identical(field_by(card_insp, "stage")$action$event$data$kind, "stage")
    expect_identical(field_by(card_insp, "lane")$action$label, "Edit")
    expect_identical(field_by(card_insp, "lane")$action$event$data$kind, "lane")
    expect_identical(field_by(card_insp, "text")$hint, "Markdown")

    # Tones and statuses come from sm_spec(), plus None
    expect_identical(
      vapply(field_by(card_insp, "tone")$choices, `[[`, "", "value"),
      c("", sm_spec()$fields$cards$fields$tone$values)
    )
    expect_identical(
      vapply(field_by(card_insp, "status")$choices, `[[`, "", "value"),
      c(names(sm_spec()$fields$options$fields$statuses$fields), "")
    )
    expect_identical(vapply(card_insp$lists, `[[`, "", "name"), c("in", "out"))
    expect_length(card_insp$lists[[1L]]$rows, 1L)
    expect_identical(card_insp$lists[[1L]]$rows[[1L]]$text, "Draft")
    expect_identical(card_insp$lists[[1L]]$rows[[1L]]$sub, "Handed over")
    expect_length(card_insp$lists[[2L]]$rows, 1L)
    expect_identical(card_insp$lists[[2L]]$rows[[1L]]$text, "Publish")
    expect_true(card_insp$lists[[1L]]$add$action$collect)
    expect_identical(vapply(card_insp$lists[[1L]]$add$fields, `[[`, "", "name"), c("from", "kind"))
    expect_identical(vapply(card_insp$actions, `[[`, "", "label"), c("Trace from here", "Remove card"))
    expect_null(action_by(card_insp, "Remove card")$disabled)
    expect_valid_form_events(card_insp)

    # Without zones or kinds, Zone and link-kind drafts are omitted; last card disables Remove & Connect
    s_blank <- studio_state_new(studio_template("blank")$map)
    blank_card <- studio_view_inspector(s_blank$doc, list(kind = "card", uid = "u1"))
    expect_false("zone" %in% vapply(blank_card$fields, `[[`, "", "name"))
    expect_identical(vapply(blank_card$lists[[1L]]$add$fields, `[[`, "", "name"), "from")
    expect_match(blank_card$lists[[1L]]$add$action$disabled, "another card")
    expect_match(action_by(blank_card, "Remove card")$disabled, "last card")
    expect_valid_form_events(blank_card)

    # Custom status words (character vector) and custom status table rows appear in Status choices
    m_words <- stage_map(
      data.frame(id = "a", label = "A", stage = "s", lane = "l", status = "done"),
      statuses = c(done = "Passed")
    )
    f_words <- field_by(studio_view_inspector(studio_state_new(m_words)$doc, list(kind = "card", uid = "u1")), "status")
    expect_identical(f_words$choices[[1L]]$label, "Passed")

    m_tbl <- stage_map(
      data.frame(id = "a", label = "A", stage = "s", lane = "l", status = "hold"),
      statuses = data.frame(id = c("done", "hold"), label = c("Complete", "On hold"), tone = c("good", "warn"))
    )
    f_tbl <- field_by(studio_view_inspector(studio_state_new(m_tbl)$doc, list(kind = "card", uid = "u1")), "status")
    vals <- vapply(f_tbl$choices, `[[`, "", "value")
    labs <- vapply(f_tbl$choices, `[[`, "", "label")
    expect_true("hold" %in% vals)
    expect_identical(labs[vals == "done"], "Complete")
    expect_identical(labs[vals == "hold"], "On hold")
  })

  it("builds stage, lane and link forms with order and removal disabled reasons", {
    s <- studio_state_new(small)
    u_write <- studio_uid_of(s$doc, "stages", "write")
    u_ship <- studio_uid_of(s$doc, "stages", "ship")
    u_docs <- studio_uid_of(s$doc, "lanes", "docs")
    u_code <- studio_uid_of(s$doc, "lanes", "code")
    u_link <- s$doc$tables$links$.studio_uid[[1L]]

    st_first <- studio_view_inspector(s$doc, list(kind = "stage", uid = u_write))
    expect_identical(
      vapply(st_first$fields, `[[`, "", "name"),
      c("label", "id", "kicker", "text", "date", "flag", "tone")
    )
    expect_identical(field_by(st_first, "date")$type, "date")
    expect_length(st_first$lists[[1L]]$rows, 1L)
    expect_match(action_by(st_first, "Earlier")$disabled, "first stage")
    expect_null(action_by(st_first, "Later")$disabled)
    expect_match(action_by(st_first, "Remove stage")$disabled, "Move its 1 card first\\.")
    expect_valid_form_events(st_first)

    st_last <- studio_view_inspector(s$doc, list(kind = "stage", uid = u_ship))
    expect_null(action_by(st_last, "Earlier")$disabled)
    expect_match(action_by(st_last, "Later")$disabled, "last stage")
    expect_valid_form_events(st_last)

    ln_first <- studio_view_inspector(s$doc, list(kind = "lane", uid = u_docs))
    expect_identical(vapply(ln_first$fields, `[[`, "", "name"), c("label", "id", "tone", "text"))
    expect_length(ln_first$lists[[1L]]$rows, 2L)
    expect_match(action_by(ln_first, "Higher")$disabled, "first lane")
    expect_null(action_by(ln_first, "Lower")$disabled)
    expect_match(action_by(ln_first, "Remove lane")$disabled, "Move its 2 cards first\\.")
    expect_valid_form_events(ln_first)

    ln_last <- studio_view_inspector(s$doc, list(kind = "lane", uid = u_code))
    expect_match(action_by(ln_last, "Lower")$disabled, "last lane")

    # Last stage / lane on blank map carries last-row removal reason
    s_blank <- studio_state_new(studio_template("blank")$map)
    expect_match(
      action_by(studio_view_inspector(s_blank$doc, list(kind = "stage", uid = "u2")), "Remove stage")$disabled,
      "last stage"
    )
    expect_match(
      action_by(studio_view_inspector(s_blank$doc, list(kind = "lane", uid = "u3")), "Remove lane")$disabled,
      "last lane"
    )

    # Link form: From, To, Kind (with line style in words + glyph + None), Label, Swap ends, Remove link
    lk_insp <- studio_view_inspector(s$doc, list(kind = "link", uid = u_link))
    expect_identical(lk_insp$title, "a -> b")
    expect_identical(lk_insp$sub, "hand")
    expect_identical(vapply(lk_insp$fields, `[[`, "", "name"), c("from", "to", "kind", "label"))
    kind_choices <- field_by(lk_insp, "kind")$choices
    expect_identical(kind_choices[[1L]]$label, "Handed over (dashed)")
    expect_identical(kind_choices[[1L]]$glyph, "line-dashed")
    expect_identical(kind_choices[[length(kind_choices)]]$label, "None")

    # Kind without explicit line defaults to solid in words and glyph
    doc_solid <- s$doc
    doc_solid$tables$kinds$line[[1L]] <- NA_character_
    expect_identical(studio_kind_choices(doc_solid, include_line = TRUE)[[1L]]$label, "Handed over (solid)")
    expect_identical(studio_kind_choices(doc_solid, include_line = TRUE)[[1L]]$glyph, "line-solid")
    expect_identical(vapply(lk_insp$actions, `[[`, "", "label"), c("Swap ends", "Remove link"))
    expect_valid_form_events(lk_insp)

    # Link form without kinds omits Kind
    s_nk <- studio_state_new(
      stage_map(data.frame(id = c("a", "b"), label = c("A", "B"), stage = "s", lane = "l")) |>
        add_links(data.frame(from = "a", to = "b"))
    )
    lk_nk <- studio_view_inspector(s_nk$doc, list(kind = "link", uid = s_nk$doc$tables$links$.studio_uid[[1L]]))
    expect_identical(vapply(lk_nk$fields, `[[`, "", "name"), c("from", "to", "label"))
    expect_identical(lk_nk$sub, "plain")
    expect_valid_form_events(lk_nk)
  })

  it("omits fields marked kept by studio_args()", {
    s <- studio_state_new(small)
    orig <- studio_arg_where
    local_mocked_bindings(
      studio_arg_where = function(what, name) {
        if (identical(what, "cards") && identical(name, "tone")) "kept" else orig(what, name)
      }
    )
    card_insp <- studio_view_inspector(s$doc, list(kind = "card", uid = "u1"))
    expect_false("tone" %in% vapply(card_insp$fields, `[[`, "", "name"))
  })

  it("adds missing choices and inline problems with fixes for broken joins and duplicate ids", {
    # Broken link join on example template
    ex <- studio_state_new()
    bad_lk_uid <- ex$doc$tables$links$.studio_uid[[nrow(ex$doc$tables$links)]]
    lk <- studio_view_inspector(ex$doc, list(kind = "link", uid = bad_lk_uid), faults = ex$check$faults)
    to_f <- field_by(lk, "to")
    missing_ch <- Filter(function(c) isTRUE(c$missing), to_f$choices)
    expect_length(missing_ch, 1L)
    expect_match(missing_ch[[1L]]$label, "no such card")
    expect_match(to_f$problem$text, "calc_does")
    expect_gte(length(to_f$problem$fixes), 2L)
    expect_valid_form_events(lk)

    # Card linking to a missing card id displays "(no such card)" in Goes to
    from_uid <- studio_uid_of(ex$doc, "cards", "test_round")
    from_card <- studio_view_inspector(ex$doc, list(kind = "card", uid = from_uid), faults = ex$check$faults)
    expect_identical(from_card$lists[[2L]]$rows[[1L]]$text, "calc_does (no such card)")

    # Duplicate card id shows problem + free-id fix beside Id
    s <- studio_state_new(small)
    s_dup <- studio_step(
      s,
      list(seq = 1L, type = "edit", data = list(table = "cards", uid = "u1", field = "id", value = "b"), rev = 0L)
    )$state
    dup_card <- studio_view_inspector(s_dup$doc, list(kind = "card", uid = "u1"), faults = s_dup$check$faults)
    id_f <- field_by(dup_card, "id")
    expect_match(id_f$problem$text, "Another card")
    expect_identical(id_f$problem$fixes[[1L]]$event$type, "fix")
    expect_valid_form_events(dup_card)

    # Duplicate card ids do not show each other's links, disable Connect, and label links to a duplicate id clearly
    expect_length(dup_card$lists[[1L]]$rows, 0L)
    expect_length(dup_card$lists[[2L]]$rows, 0L)
    expect_match(dup_card$lists[[1L]]$add$action$disabled, "unique id")
    dup_b <- studio_view_inspector(s_dup$doc, list(kind = "card", uid = "u2"), faults = s_dup$check$faults)
    expect_length(dup_b$lists[[1L]]$rows, 0L)
    expect_length(dup_b$lists[[2L]]$rows, 0L)
    card_c <- studio_view_inspector(s_dup$doc, list(kind = "card", uid = "u3"), faults = s_dup$check$faults)
    expect_identical(card_c$lists[[1L]]$rows[[1L]]$text, "b (duplicate id)")

    # Broken stage on card adds missing choice, drops Edit side action, and attaches fixes
    doc_bad <- studio_doc_apply(
      s$doc,
      list(list(op = "set", table = "cards", uid = "u1", field = "stage", value = "writ"))
    )
    bad_card <- studio_view_inspector(doc_bad, list(kind = "card", uid = "u1"))
    st_f <- field_by(bad_card, "stage")
    expect_null(st_f$action)
    expect_true(any(vapply(st_f$choices, function(c) isTRUE(c$missing) && grepl("no such stage", c$label), logical(1))))
    expect_match(st_f$problem$text, "No stage")
    expect_gte(length(st_f$problem$fixes), 1L)
    expect_valid_form_events(bad_card)

    # Blank card id disables Connect and shows blank-id problem; blank stage id disables Add a card here
    doc_blank_id <- studio_doc_apply(
      s$doc,
      list(
        list(op = "set", table = "cards", uid = "u1", field = "id", value = ""),
        list(op = "set", table = "stages", uid = studio_uid_of(s$doc, "stages", "write"), field = "id", value = "")
      )
    )
    b_card <- studio_view_inspector(doc_blank_id, list(kind = "card", uid = "u1"))
    expect_match(b_card$lists[[1L]]$add$action$disabled, "Give this card an id")
    expect_match(field_by(b_card, "id")$problem$text, "needs an id")
    b_stage <- studio_view_inspector(
      doc_blank_id,
      list(kind = "stage", uid = studio_uid_of(s$doc, "stages", "write"))
    )
    expect_match(action_by(b_stage, "Add a card here")$disabled, "Give this stage an id")
  })

  it("checks arguments on form helpers", {
    expect_error(studio_action("", list(type = "undo")), "label")
    expect_error(studio_action("Ok", list(type = "undo"), style = "bad"), "style")
    expect_error(studio_choice("a", ""), "label")
    expect_error(studio_field("", "L", "text", "", NULL), "name")
    expect_error(studio_field("n", "L", "bad", "", NULL), "type")
    expect_identical(studio_cell_text(data.frame(d = as.Date("2026-04-01")), "d"), "2026-04-01")
    expect_identical(studio_cell_text(data.frame(a = 1), "missing"), "")
    expect_identical(studio_ensure_choice(list(), "", "stage")[[1L]]$label, "No stage")

    # Edge cases: absent choice table, blank custom status/kind ids, link to blank card or unknown kind
    s <- studio_state_new(small)
    expect_identical(studio_table_choices(s$doc, "steps"), list())
    doc_edge <- s$doc
    doc_edge$tables$statuses <- data.frame(
      id = c(NA_character_, "hold"),
      label = c("Bad", "Hold"),
      .studio_uid = c("u90", "u91")
    )
    expect_true("hold" %in% vapply(studio_status_choices(doc_edge), `[[`, "", "value"))
    doc_edge$tables$kinds <- rbind(
      doc_edge$tables$kinds,
      data.frame(id = NA_character_, label = "Skip", line = "solid", .studio_uid = "u92")
    )
    expect_length(studio_kind_choices(doc_edge, include_line = FALSE), 2L)
    doc_edge$tables$links$to[[1L]] <- NA_character_
    doc_edge$tables$links$kind[[1L]] <- "mystery"
    edge_card <- studio_view_inspector(doc_edge, list(kind = "card", uid = "u1"))
    expect_identical(edge_card$lists[[2L]]$rows[[1L]]$text, "(no card)")
    expect_identical(edge_card$lists[[2L]]$rows[[1L]]$sub, "mystery (no such kind)")
  })
})

describe("studio_view_journal()", {
  it("keeps only the listed page fields on journal entries, caps at 50 and clears gone targets", {
    s <- studio_state_new(small)
    s <- studio_step(
      s,
      list(
        seq = 1L,
        type = "edit",
        data = list(table = "cards", uid = "u1", field = "label", value = "Edited"),
        rev = 0L
      )
    )$state
    entries <- studio_view_journal(s$journal)
    expect_length(entries, 1L)
    expect_named(entries[[1L]], c("n", "verb", "text", "state", "target"))
    expect_identical(entries[[1L]]$verb, "Edit")
    expect_identical(entries[[1L]]$state, "done")

    s_rm <- studio_step(
      s,
      list(seq = 2L, type = "remove", data = list(table = "cards", uid = "u1"), rev = s$rev)
    )$state
    view_entries <- studio_view_journal(s_rm$journal, doc = s_rm$doc)
    expect_null(view_entries[[1L]]$target)

    many <- lapply(seq_len(60L), function(i) {
      list(n = i, verb = "Edit", text = paste("Item", i), state = "done", target = NULL)
    })
    capped <- studio_view_journal(many)
    expect_length(capped, 50L)
    expect_identical(capped[[1L]]$n, 11L)
    expect_error(studio_view_journal("bad"), "journal")
  })
})

describe("studio_view_start()", {
  it("opens for example/blank when map was NULL, offers Your map when given, and switches to confirm on refusal", {
    s_null <- studio_state_new()
    st_null <- studio_view_start(s_null)
    expect_true(st_null$open)
    expect_identical(vapply(st_null$options, `[[`, "", "id"), c("example", "blank"))

    s_given <- studio_state_new(small)
    st_given <- studio_view_start(s_given)
    expect_false(st_given$open)
    expect_identical(vapply(st_given$options, `[[`, "", "id"), c("example", "blank", "given"))

    s_edit <- studio_step(
      s_given,
      list(seq = 1L, type = "option", data = list(name = "title", value = "Changed"), rev = 0L)
    )$state
    s_refused <- studio_step(
      s_edit,
      list(seq = 2L, type = "open", data = list(template = "blank", confirm = FALSE), rev = s_edit$rev)
    )$state
    st_conf <- studio_view_start(s_refused)
    blank_opt <- st_conf$options[[2L]]
    expect_identical(blank_opt$text, "Click again to replace your changes")
    expect_true(blank_opt$event$data$confirm)
  })
})
