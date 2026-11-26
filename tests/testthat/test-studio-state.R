# The studio's state and its pure reducer, studio_step().

delayedAssign("small", full_map(title = "A map"))

ev <- function(type, data = structure(list(), names = character()), seq = 1L, rev = 0L) {
  list(seq = seq, type = type, data = data, rev = rev)
}

describe("studio_state_new()", {
  it("opens on the given map with its title, valid build, empty journal and closed start card", {
    state <- studio_state_new(small)
    expect_identical(state$template, "given")
    expect_false(state$start_open)
    expect_identical(state$doc$args$title, "A map")
    expect_identical(state[c("rev", "ack", "closed")], list(rev = 0L, ack = 0L, closed = FALSE))
    expect_true(state$check$ok)
    expect_identical(state$good$rev, 0L)
    expect_null(state$tour)
    expect_null(state$notice)
  })

  it("opens on the example template with the start card open when given NULL", {
    state <- studio_state_new()
    expect_identical(state$template, "example")
    expect_true(state$start_open)
    expect_false(state$check$ok)
    expect_identical(nrow(state$check$faults), 1L)
    expect_identical(state$good$rev, -1L)
    expect_identical(state$tour$done[[1L]], TRUE)
  })

  it("refuses what is not a stagemap widget", {
    expect_error(studio_state_new(list()), "map")
  })
})

describe("studio_step()", {
  it("acknowledges ready and ticks the tour", {
    state <- studio_state_new(small)
    res <- studio_step(state, ev("ready", seq = 4L))
    expect_identical(res$state$ack, 4L)
    expect_identical(res$effects, list())
  })

  it("handles open with confirmation when changes exist, and loads example, blank or given", {
    s <- studio_state_new(small)
    s <- studio_step(s, ev("open", list(template = "blank", confirm = FALSE), seq = 1L))$state
    expect_identical(s$template, "blank")
    expect_identical(s$rev, 1L)
    expect_identical(nrow(s$doc$tables$cards), 1L)

    # Make a change so opening again needs confirm = TRUE
    s <- studio_step(s, ev("option", list(name = "title", value = "Edited"), seq = 2L))$state
    refused <- studio_step(s, ev("open", list(template = "example", confirm = FALSE), seq = 3L))
    expect_match(refused$state$notice$text, "lose your changes")
    expect_identical(refused$state$confirm_open, "example")
    expect_identical(refused$state$template, "blank")

    confirmed <- studio_step(refused$state, ev("open", list(template = "example", confirm = TRUE), seq = 4L))
    expect_identical(confirmed$state$template, "example")
    expect_null(confirmed$state$confirm_open)
    expect_length(confirmed$state$journal, 0L)

    back <- studio_step(confirmed$state, ev("open", list(template = "given", confirm = FALSE), seq = 5L))$state
    expect_identical(back$template, "given")
    expect_identical(back$doc$args$title, "A map")

    # Unknown template, invalid confirm and missing given map are refused
    expect_match(
      studio_step(back, ev("open", list(template = "other", confirm = FALSE), seq = 6L))$state$notice$text,
      "Unknown"
    )
    expect_match(
      studio_step(back, ev("open", list(template = "blank", confirm = "yes"), seq = 7L))$state$notice$text,
      "Invalid"
    )
    expect_match(
      studio_step(
        studio_state_new(),
        ev("open", list(template = "given", confirm = FALSE), seq = 8L)
      )$state$notice$text,
      "No map"
    )
  })

  it("applies option, edit, add, remove, move, link_add, link_reverse and fix with effects", {
    s <- studio_state_new(small)

    # Target a card and rename its id: emits select with the new id
    s_t <- studio_step(s, ev("target", list(kind = "card", uid = "u1"), seq = 1L))
    expect_identical(s_t$effects, list(list(type = "select", kind = "card", id = "a")))
    s_rn <- studio_step(
      s_t$state,
      ev("edit", list(table = "cards", uid = "u1", field = "id", value = "a_one"), seq = 2L)
    )
    expect_identical(s_rn$effects, list(list(type = "select", kind = "card", id = "a_one")))

    # Add card sets target and emits select
    s_add <- studio_step(s_rn$state, ev("add", list(table = "cards"), seq = 3L))
    expect_identical(s_add$state$target$kind, "card")
    expect_identical(s_add$effects[[1L]]$type, "select")

    # Remove targeted card clears target and emits select none
    new_uid <- s_add$state$target$uid
    s_rm <- studio_step(s_add$state, ev("remove", list(table = "cards", uid = new_uid), seq = 4L))
    expect_identical(s_rm$state$target, list(kind = "none", uid = NULL))
    expect_identical(s_rm$effects, list(list(type = "select", kind = "none", id = NULL)))

    # Undo of an add while the added card is still targeted resets target to none
    s_add2 <- studio_step(s_rm$state, ev("add", list(table = "cards"), seq = 5L))$state
    s_u2 <- studio_step(s_add2, ev("undo", seq = 6L))$state
    expect_identical(s_u2$target, list(kind = "none", uid = NULL))

    # Remove a targeted link clears target to none
    lk_uid <- s_u2$doc$tables$links$.studio_uid[[1L]]
    s_tl <- studio_step(s_u2, ev("target", list(kind = "link", uid = lk_uid), seq = 7L))$state
    s_rl <- studio_step(s_tl, ev("remove", list(table = "links", uid = lk_uid), seq = 8L))$state
    expect_identical(s_rl$target, list(kind = "none", uid = NULL))

    # Renaming targeted card to blank does not emit select; targeting a blank-id card emits no select
    s_tc <- studio_step(s_rl, ev("target", list(kind = "card", uid = "u1"), seq = 9L))$state
    s_blank <- studio_step(s_tc, ev("edit", list(table = "cards", uid = "u1", field = "id", value = ""), seq = 10L))
    expect_length(s_blank$effects, 0L)
    s_none_t <- studio_step(s_blank$state, ev("target", list(kind = "none", uid = NULL), seq = 11L))$state
    expect_length(studio_step(s_none_t, ev("target", list(kind = "card", uid = "u1"), seq = 12L))$effects, 0L)

    # Undo when nothing is done is refused
    expect_match(studio_step(s, ev("undo", seq = 1L))$state$notice$text, "Nothing to undo")

    # Refused event produces notice and does not bump rev
    bad <- studio_step(
      s_rm$state,
      ev("move", list(table = "stages", uid = studio_uid_of(s_rm$state$doc, "stages", "write"), by = -1L), seq = 11L)
    )
    expect_identical(bad$state$rev, s_rm$state$rev)
    expect_identical(bad$state$notice$tone, "problem")
  })

  it("handles target and server-made picked without echoing select for picked", {
    s <- studio_state_new(small)
    pk <- studio_step(s, list(type = "picked", data = list(kind = "card", id = "b")))
    expect_identical(pk$state$target, list(kind = "card", uid = "u2"))
    expect_length(pk$effects, 0L)

    pk_clear <- studio_step(pk$state, list(type = "picked", data = list(kind = "all", id = NULL)))
    expect_identical(pk_clear$state$target, list(kind = "none", uid = NULL))
    expect_length(pk_clear$effects, 0L)

    tg <- studio_step(pk$state, ev("target", list(kind = "none", uid = NULL), seq = 1L))
    expect_identical(tg$state$target, list(kind = "none", uid = NULL))
    expect_identical(tg$effects, list(list(type = "select", kind = "none", id = NULL)))

    bad_t <- studio_step(s, ev("target", list(kind = "card", uid = "missing"), seq = 1L))
    expect_match(bad_t$state$notice$text, "no longer")
    bad_k <- studio_step(s, ev("target", list(kind = "zone", uid = "u1"), seq = 1L))
    expect_match(bad_k$state$notice$text, "Unknown")
    expect_identical(studio_select_effect(s, s$target, s$doc, "picked"), list())
  })

  it("marks stale ask and emits highlight clear when rev moves", {
    s <- studio_state_new(small)
    s$ask <- list(question = "trace", stale = FALSE, lit = TRUE)
    res <- studio_step(s, ev("option", list(name = "title", value = "Updated"), seq = 1L))
    expect_true(res$state$ask$stale)
    expect_false(res$state$ask$lit)
    expect_identical(res$effects, list(list(type = "highlight", ids = character(), links = NULL)))
  })

  it("acknowledges ask and ask_clear with Not available yet and records seen", {
    s <- studio_state_new(small)
    a <- studio_step(s, ev("ask", list(question = "orphans"), seq = 1L))
    expect_match(a$state$notice$text, "Not available yet")
    ac <- studio_step(a$state, ev("ask_clear", seq = 2L))
    expect_match(ac$state$notice$text, "Not available yet")
    sn <- studio_step(ac$state, ev("seen", list(what = "code"), seq = 3L))
    expect_identical(sn$state$seen, "code")
    expect_match(studio_step(sn$state, ev("seen", list(what = ""), seq = 4L))$state$notice$text, "Unknown")
  })

  it("handles done when valid and refuses with room check when broken", {
    # Broken example refuses Done and points to Check
    ex <- studio_state_new()
    refused <- studio_step(ex, ev("done", seq = 1L))
    expect_false(refused$state$closed)
    expect_identical(refused$state$notice$room, "check")
    expect_length(refused$effects, 0L)

    # Fix and Done succeeds
    fault_id <- ex$check$faults$id[[1L]]
    fixed <- studio_step(ex, ev("fix", list(fault = fault_id, fix = "use"), seq = 2L))$state
    done <- studio_step(fixed, ev("done", seq = 3L))
    expect_true(done$state$closed)
    expect_identical(done$effects[[1L]]$type, "done")
    expect_s3_class(done$effects[[1L]]$map, "stagemap_widget")

    # Once closed, events other than ready are refused
    late <- studio_step(done$state, ev("option", list(name = "title", value = "Late"), seq = 4L))
    expect_match(late$state$notice$text, "gone back to R")
    late_pk <- studio_step(done$state, list(type = "picked", data = list(kind = "card", id = "a")))
    expect_match(late_pk$state$notice$text, "gone back to R")
    expect_identical(studio_step(done$state, ev("ready", seq = 5L))$state$ack, 5L)
  })

  it("refuses unreadable events and records ack when seq is valid", {
    s <- studio_state_new(small)
    res <- studio_step(s, list(seq = 6L, type = "ready", data = list()))
    expect_identical(res$state$ack, 6L)
    expect_match(res$state$notice$text, "has no rev")
    expect_identical(studio_step(s, "bad")$state$ack, 0L)
  })
})

describe("replay and row key stability across 40 mixed events", {
  it("keeps studio_journal_replay(base, journal) equal to doc and returns base on full undo", {
    s <- studio_state_new()
    seq_n <- 1L
    run <- function(type, data = structure(list(), names = character())) {
      res <- studio_step(s, ev(type, data, seq = seq_n, rev = s$rev))
      seq_n <<- seq_n + 1L
      s <<- res$state
      expect_identical(studio_journal_replay(s$base, s$journal), s$doc)
    }

    # Fix initial broken link first, then run mixed edits, adds, moves, links, reverses, removes and undos
    run("fix", list(fault = s$check$faults$id[[1L]], fix = "use"))
    u_calc <- studio_uid_of(s$doc, "cards", "calc_dose")
    u_log <- studio_uid_of(s$doc, "cards", "log_calls")
    u_round <- studio_uid_of(s$doc, "cards", "round_dose")
    u_req <- studio_uid_of(s$doc, "stages", "req")
    u_stat <- studio_uid_of(s$doc, "lanes", "stat")

    run("option", list(name = "title", value = "Dose v2"))
    run("option", list(name = "title", value = "Dose v3"))
    run("option", list(name = "layout", value = "grid"))
    run("option", list(name = "legend", value = FALSE))
    run("option", list(name = "cell_columns", value = 2))
    run("option", list(name = "bundle_links", value = TRUE))
    run("edit", list(table = "cards", uid = u_round, field = "status", value = "done"))
    run("edit", list(table = "cards", uid = u_round, field = "tone", value = "good"))
    run("edit", list(table = "cards", uid = u_round, field = "milestone", value = TRUE))
    run("edit", list(table = "cards", uid = u_calc, field = "id", value = "calc_dose_2"))
    run("edit", list(table = "cards", uid = u_calc, field = "id", value = "calc_dose_3"))
    run("edit", list(table = "stages", uid = u_req, field = "date", value = "2026-04-01"))
    run("edit", list(table = "stages", uid = u_req, field = "flag", value = "Checked"))
    run("edit", list(table = "lanes", uid = u_stat, field = "tone", value = "teal"))
    run("move", list(table = "stages", uid = u_req, by = 1L))
    run("move", list(table = "lanes", uid = u_stat, by = 1L))
    run("add", list(table = "stages"))
    new_stage_uid <- s$target$uid
    run("add", list(table = "lanes"))
    new_lane_uid <- s$target$uid
    run("add", list(table = "cards", stage = new_stage_uid, lane = new_lane_uid))
    new_card_uid <- s$target$uid
    run("edit", list(table = "cards", uid = new_card_uid, field = "label", value = "Custom card"))
    run("link_add", list(from = u_log, to = new_card_uid, kind = "tested"))
    new_link_uid <- s$doc$tables$links$.studio_uid[[nrow(s$doc$tables$links)]]
    run("link_reverse", list(uid = new_link_uid))
    run("edit", list(table = "links", uid = new_link_uid, field = "label", value = "Check link"))
    run("undo")
    run("undo")
    run("link_add", list(from = u_log, to = u_calc, kind = NULL))
    run("remove", list(table = "cards", uid = new_card_uid))
    run("remove", list(table = "stages", uid = new_stage_uid))
    run("remove", list(table = "lanes", uid = new_lane_uid))
    run("add", list(table = "cards"))
    c2 <- s$target$uid
    run("edit", list(table = "cards", uid = c2, field = "sub", value = "QA"))
    run("edit", list(table = "cards", uid = c2, field = "text", value = "Note"))
    run("option", list(name = "target", value = "calc_dose_3"))
    run("edit", list(table = "cards", uid = u_calc, field = "id", value = "calc_dose_4"))
    run("move", list(table = "stages", uid = u_req, by = -1L))
    run("edit", list(table = "cards", uid = u_log, field = "label", value = "Log calls"))
    run("option", list(name = "legend", value = TRUE))
    run("option", list(name = "cell_columns", value = "auto"))
    run("edit", list(table = "cards", uid = u_round, field = "status", value = "running"))

    expect_gte(seq_n - 1L, 40L)
    expect_identical(studio_row(s$doc, "cards", u_calc)$id, "calc_dose_4")
    expect_identical(s$doc$args$target, "calc_dose_4")

    # Undoing every remaining entry returns base with identical keys
    while (studio_journal_can_undo(s$journal)) {
      res <- studio_step(s, ev("undo", seq = seq_n, rev = s$rev))
      seq_n <- seq_n + 1L
      s <- res$state
      expect_match(s$notice$text, "^Undone: ")
      expect_identical(studio_journal_replay(s$base, s$journal), s$doc)
    }
    expect_identical(s$doc, s$base)
  })
})

describe("the eight state-core R files", {
  it("contain no shiny:: call and no reactive symbol", {
    files <- file.path(
      test_path("..", "..", "R"),
      paste0(
        "studio-",
        c("doc", "events", "journal", "check", "templates", "tour", "state", "args"),
        ".R"
      )
    )
    skip_if(!all(file.exists(files)), "the R sources are not beside the tests")
    for (path in files) {
      text <- paste(readLines(path, warn = FALSE), collapse = "\n")
      expect_false(grepl("shiny::", text, fixed = TRUE), info = path)
      expect_false(grepl("reactive", text, fixed = TRUE), info = path)
    }
  })

  it("check arguments on helpers", {
    s <- studio_state_new(small)
    expect_error(studio_step(list(1), ev("ready")), "state")
    expect_error(studio_refuse(s, ""), "text")
    expect_error(studio_step_open(s, list(1)), "data")
    expect_error(studio_step_target(s, list(1)), "data")
    expect_error(studio_step_picked(s, list(1)), "data")
    expect_error(studio_select_effect(s, s$target, s$doc, ""), "event_type")
    expect_error(studio_state_build(s$doc, -1L), "rev")
    expect_null(studio_target_table("none"))
  })
})
