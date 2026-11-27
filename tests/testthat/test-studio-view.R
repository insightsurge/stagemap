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
  it("lists stages and lanes with card counts, cards for hover hints, and target-aware add actions", {
    s <- studio_state_new(small)
    out0 <- studio_view_outline(s$doc, s$target)
    expect_length(out0$stages, 3L)
    expect_length(out0$lanes, 2L)
    expect_length(out0$cards, 4L)
    expect_identical(vapply(out0$stages, `[[`, integer(1), "cards"), c(1L, 2L, 1L))
    expect_identical(out0$actions[[1L]]$event$data, list(table = "cards"))

    s_card <- studio_step(s, list(seq = 1L, type = "target", data = list(kind = "card", uid = "u2"), rev = 0L))$state
    out_card <- studio_view_outline(s_card$doc, s_card$target)
    expect_identical(
      out_card$actions[[1L]]$event$data,
      list(
        table = "cards",
        stage = studio_uid_of(s_card$doc, "stages", "check"),
        lane = studio_uid_of(s_card$doc, "lanes", "docs")
      )
    )

    stage_uid <- studio_uid_of(s$doc, "stages", "ship")
    s_stage <- studio_step(
      s,
      list(seq = 1L, type = "target", data = list(kind = "stage", uid = stage_uid), rev = 0L)
    )$state
    out_stage <- studio_view_outline(s_stage$doc, s_stage$target)
    expect_identical(out_stage$actions[[1L]]$event$data, list(table = "cards", stage = stage_uid))

    # Blank labels fall back to id or "Untitled ...", and empty tables yield empty outline lists
    doc_blank <- s$doc
    doc_blank$tables$cards$label[[1L]] <- ""
    doc_blank$tables$cards$label[[2L]] <- ""
    doc_blank$tables$cards$id[[2L]] <- ""
    out_blank <- studio_view_outline(doc_blank, s$target)
    expect_identical(out_blank$cards[[1L]]$label, "a")
    expect_identical(out_blank$cards[[2L]]$label, "Untitled card")

    doc_empty <- s$doc
    doc_empty$tables$cards <- doc_empty$tables$cards[0L, , drop = FALSE]
    doc_empty$tables$stages <- doc_empty$tables$stages[0L, , drop = FALSE]
    out_empty <- studio_view_outline(doc_empty, s$target)
    expect_identical(out_empty$cards, list())
    expect_identical(out_empty$stages, list())
  })
})

describe("studio_view_inspector()", {
  it("returns NULL for none, unknown kind or missing row, and the head with Close action for valid rows", {
    s <- studio_state_new(small)
    expect_null(studio_view_inspector(s$doc, s$target))
    expect_null(studio_view_inspector(s$doc, list(kind = "zone", uid = "u1")))
    expect_null(studio_view_inspector(s$doc, list(kind = "card", uid = "u999")))

    doc_blank <- s$doc
    doc_blank$tables$cards$label[[1L]] <- ""
    blank_insp <- studio_view_inspector(doc_blank, list(kind = "card", uid = "u1"))
    expect_identical(blank_insp$title, "a")

    card_insp <- studio_view_inspector(s$doc, list(kind = "card", uid = "u1"))
    expect_identical(card_insp$kind, "card")
    expect_identical(card_insp$uid, "u1")
    expect_identical(card_insp$sub, "a")
    expect_identical(card_insp$actions[[1L]]$label, "Close")
    expect_identical(card_insp$actions[[1L]]$event, list(type = "target", data = list(kind = "none", uid = NULL)))

    lk_uid <- s$doc$tables$links$.studio_uid[[1L]]
    link_insp <- studio_view_inspector(s$doc, list(kind = "link", uid = lk_uid))
    expect_identical(link_insp$title, "a -> b")
    expect_identical(link_insp$sub, "hand")
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
