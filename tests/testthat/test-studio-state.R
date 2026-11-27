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
    expect_identical(state$good$serial, 1L)
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
    expect_identical(state$good$serial, 1L)
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
    s$ask <- list(question = "orphans")
    s <- studio_step(s, ev("seen", list(what = "code"), seq = 1L))$state
    s <- studio_step(s, ev("open", list(template = "blank", confirm = FALSE), seq = 2L))$state
    expect_identical(s$template, "blank")
    expect_identical(s$rev, 1L)
    expect_identical(s$good$serial, 2L)
    expect_false(s$start_open)
    expect_null(s$ask)
    expect_identical(s$seen, character())
    expect_identical(nrow(s$doc$tables$cards), 1L)

    # Edit and undo after open returns to blank base
    s <- studio_step(s, ev("option", list(name = "title", value = "Edited"), seq = 3L))$state
    s_undone <- studio_step(s, ev("undo", seq = 4L))$state
    expect_identical(s_undone$doc, s_undone$base)
    expect_identical(studio_doc_parts(s_undone$doc), map_parts(studio_template("blank")$map))
    expect_gt(s_undone$doc$next_uid, length(unlist(lapply(s$base$tables, nrow))))

    # Make a change so opening again needs confirm = TRUE
    s <- studio_step(s, ev("option", list(name = "title", value = "Edited 2"), seq = 5L))$state
    refused <- studio_step(s, ev("open", list(template = "example", confirm = FALSE), seq = 6L))
    expect_match(refused$state$notice$text, "lose your changes")
    expect_identical(refused$state$confirm_open, "example")
    expect_identical(refused$state$template, "blank")

    # Opening broken example from a valid map bumps good$serial even when good$rev <= rev
    before_serial <- refused$state$good$serial
    confirmed <- studio_step(refused$state, ev("open", list(template = "example", confirm = TRUE), seq = 7L))
    expect_identical(confirmed$state$template, "example")
    expect_null(confirmed$state$confirm_open)
    expect_length(confirmed$state$journal, 0L)
    expect_identical(confirmed$state$good$serial, before_serial + 1L)
    expect_lt(confirmed$state$good$rev, confirmed$state$rev)
    expect_identical(studio_step(confirmed$state, ev("done", seq = 8L))$state$notice$room, "check")

    # Mark tour steps and seen, switch to blank, then reopen example: seen and tour progress reset
    ex <- confirmed$state
    ex <- studio_step(ex, ev("seen", list(what = "code"), seq = 9L))$state
    uid_round <- studio_uid_of(ex$doc, "cards", "round_dose")
    ex <- studio_step(
      ex,
      ev("edit", list(table = "cards", uid = uid_round, field = "status", value = "done"), seq = 10L)
    )$state
    expect_true(all(ex$tour$done[c(1L, 2L, 4L)]))
    bl <- studio_step(ex, ev("open", list(template = "blank", confirm = TRUE), seq = 11L))$state
    reopened <- studio_step(bl, ev("open", list(template = "example", confirm = FALSE), seq = 12L))$state
    expect_identical(reopened$seen, character())
    expect_identical(reopened$tour$done, c(TRUE, FALSE, FALSE, FALSE, FALSE, FALSE))

    back <- studio_step(reopened, ev("open", list(template = "given", confirm = FALSE), seq = 13L))$state
    expect_identical(back$template, "given")
    expect_identical(back$doc$args$title, "A map")

    # Unknown template, invalid confirm and missing given map are refused
    expect_match(
      studio_step(back, ev("open", list(template = "other", confirm = FALSE), seq = 14L))$state$notice$text,
      "Unknown"
    )
    expect_match(
      studio_step(back, ev("open", list(template = "blank", confirm = "yes"), seq = 15L))$state$notice$text,
      "Invalid"
    )
    expect_match(
      studio_step(
        studio_state_new(),
        ev("open", list(template = "given", confirm = FALSE), seq = 16L)
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

  it("decides select effects against good$map, re-selects when good$serial rises, and covers stage renames", {
    ex <- studio_state_new()
    ex_add <- studio_step(ex, ev("add", list(table = "cards"), seq = 1L))
    expect_identical(ex_add$state$target$kind, "card")
    expect_length(ex_add$effects, 0L)

    fault_id <- ex_add$state$check$faults$id[[1L]]
    ex_fix <- studio_step(ex_add$state, ev("fix", list(fault = fault_id, fix = "use"), seq = 2L))
    expect_true(ex_fix$state$check$ok)
    expect_identical(ex_fix$effects, list(list(type = "select", kind = "card", id = "card")))

    # Renaming a targeted stage emits select for the new stage id
    s <- studio_state_new(small)
    stage_uid <- studio_uid_of(s$doc, "stages", "check")
    st_t <- studio_step(s, ev("target", list(kind = "stage", uid = stage_uid), seq = 1L))
    expect_identical(st_t$effects, list(list(type = "select", kind = "stage", id = "check")))
    st_rn <- studio_step(
      st_t$state,
      ev("edit", list(table = "stages", uid = stage_uid, field = "id", value = "review"), seq = 2L)
    )
    expect_identical(st_rn$effects, list(list(type = "select", kind = "stage", id = "review")))
  })

  it("refuses page-sent picked events and handles server picks through studio_pick()", {
    s <- studio_state_new(small)
    bad_p1 <- studio_step(s, list(seq = 1L, type = "picked", data = list(kind = 1:3, id = "b"), rev = 0L))
    expect_identical(bad_p1$state$ack, 1L)
    expect_match(bad_p1$state$notice$text, "not an event the studio knows")
    bad_p2 <- studio_step(s, list(type = "picked", data = "bad"))
    expect_match(bad_p2$state$notice$text, "has no seq, rev")

    pk <- studio_pick(s, "card", "b")
    expect_identical(pk$state$target, list(kind = "card", uid = "u2"))
    expect_length(pk$effects, 0L)

    pk_clear <- studio_pick(pk$state, "all", NULL)
    expect_identical(pk_clear$state$target, list(kind = "none", uid = NULL))
    expect_length(pk_clear$effects, 0L)

    expect_error(studio_pick(s, c("card", "stage"), "b"), "kind")
    expect_error(studio_pick(s, "card", c("a", "b")), "id")

    tg <- studio_step(pk$state, ev("target", list(kind = "none", uid = NULL), seq = 1L))
    expect_identical(tg$state$target, list(kind = "none", uid = NULL))
    expect_identical(tg$effects, list(list(type = "select", kind = "none", id = NULL)))

    bad_t <- studio_step(s, ev("target", list(kind = "card", uid = "missing"), seq = 1L))
    expect_match(bad_t$state$notice$text, "no longer")
    bad_k <- studio_step(s, ev("target", list(kind = "zone", uid = "u1"), seq = 1L))
    expect_match(bad_k$state$notice$text, "Unknown")
    expect_identical(studio_select_effect(s, s$target, s$doc, "picked"), list())
  })

  it("resolves stale-map picks per drawn position, restores map selection on refusal, and keeps added rows clickable", {
    # Example template is stale on links only: card ids match good$map, even after + Card adds a row at the end
    ex <- studio_state_new()
    pk_ex <- studio_pick(ex, "card", "round_dose")
    expect_identical(pk_ex$state$target, list(kind = "card", uid = studio_uid_of(ex$doc, "cards", "round_dose")))
    expect_null(pk_ex$state$notice)
    expect_length(pk_ex$effects, 0L)

    ex_add <- studio_step(ex, ev("add", list(table = "cards"), seq = 1L))$state
    expect_lt(ex_add$good$rev, ex_add$rev)
    pk_ex_after_add <- studio_pick(ex_add, "card", "round_dose")
    expect_identical(
      pk_ex_after_add$state$target,
      list(kind = "card", uid = studio_uid_of(ex_add$doc, "cards", "round_dose"))
    )
    expect_null(pk_ex_after_add$state$notice)
    expect_length(pk_ex_after_add$effects, 0L)

    # Duplicate card id leaves drawn map stale: clicking duplicated "b" refuses and clears selection when target u1 is
    # not drawn, while clicking unchanged card "c" still succeeds and puts selection back to "c" on a later refusal
    s <- studio_state_new(small)
    s_t <- studio_step(s, ev("target", list(kind = "card", uid = "u1"), seq = 1L))$state
    res_dup <- studio_step(s_t, ev("edit", list(table = "cards", uid = "u1", field = "id", value = "b"), seq = 2L))
    expect_length(res_dup$effects, 0L)
    s_dup <- res_dup$state
    expect_lt(s_dup$good$rev, s_dup$rev)
    pk_dup <- studio_pick(s_dup, "card", "b")
    expect_identical(pk_dup$state$target, s_dup$target)
    expect_identical(pk_dup$state$notice$tone, "problem")
    expect_identical(pk_dup$state$notice$room, "check")
    expect_match(pk_dup$state$notice$text, "out of date")
    expect_identical(pk_dup$effects, list(list(type = "select", kind = "none", id = NULL)))

    pk_c <- studio_pick(s_dup, "card", "c")
    expect_identical(pk_c$state$target, list(kind = "card", uid = "u3"))
    expect_null(pk_c$state$notice)
    expect_length(pk_c$effects, 0L)

    pk_dup_on_c <- studio_pick(pk_c$state, "card", "b")
    expect_identical(pk_dup_on_c$state$target, list(kind = "card", uid = "u3"))
    expect_identical(pk_dup_on_c$state$notice$tone, "problem")
    expect_identical(pk_dup_on_c$effects, list(list(type = "select", kind = "card", id = "c")))

    # Unknown clicked id also restores the current drawn target, or clears when target is none
    pk_ghost_c <- studio_pick(pk_c$state, "card", "ghost")
    expect_identical(pk_ghost_c$state$target, list(kind = "card", uid = "u3"))
    expect_identical(pk_ghost_c$effects, list(list(type = "select", kind = "card", id = "c")))
    pk_ghost_none <- studio_pick(s, "card", "ghost")
    expect_identical(pk_ghost_none$state$target, list(kind = "none", uid = NULL))
    expect_identical(pk_ghost_none$effects, list(list(type = "select", kind = "none", id = NULL)))

    # Swapping ids while broken must not target the wrong row either, and restores none for blank-id target u1
    s_swap <- studio_step(
      s_t,
      ev("edit", list(table = "cards", uid = "u1", field = "id", value = ""), seq = 2L)
    )$state
    s_swap <- studio_step(
      s_swap,
      ev("edit", list(table = "cards", uid = "u2", field = "id", value = "a"), seq = 3L)
    )$state
    pk_swap <- studio_pick(s_swap, "card", "a")
    expect_identical(pk_swap$state$target, s_swap$target)
    expect_identical(pk_swap$state$notice$tone, "problem")
    expect_identical(pk_swap$effects, list(list(type = "select", kind = "none", id = NULL)))

    # An edit flushed after a pick updates its own row and journal entry without overwriting the picked target
    pk_b <- studio_pick(s_t, "card", "b")$state
    ed_a <- studio_step(
      pk_b,
      ev("edit", list(table = "cards", uid = "u1", field = "label", value = "Edited A"), seq = 2L, rev = pk_b$rev)
    )$state
    expect_identical(ed_a$target, list(kind = "card", uid = "u2"))
    expect_identical(studio_row(ed_a$doc, "cards", "u1")$label, "Edited A")
    expect_identical(ed_a$journal[[1L]]$target, list(kind = "card", uid = "u1"))
  })

  it("decides + Card stage and lane on the server from the current target", {
    s <- studio_state_new(small)
    # Target card u2 (stage check, lane docs), then switch to u4 (stage ship, lane code) before adding a card
    s1 <- studio_step(s, ev("target", list(kind = "card", uid = "u2"), seq = 1L))$state
    s2 <- studio_step(s1, ev("target", list(kind = "card", uid = "u4"), seq = 2L))$state
    added_c <- studio_step(s2, ev("add", list(table = "cards"), seq = 3L))$state
    row_c <- studio_row(added_c$doc, "cards", added_c$target$uid)
    expect_identical(row_c$stage, "ship")
    expect_identical(row_c$lane, "code")

    # Target stage "check": new card lands in stage "check" and first lane
    u_check <- studio_uid_of(s$doc, "stages", "check")
    s_st <- studio_step(s, ev("target", list(kind = "stage", uid = u_check), seq = 1L))$state
    added_st <- studio_step(s_st, ev("add", list(table = "cards"), seq = 2L))$state
    row_st <- studio_row(added_st$doc, "cards", added_st$target$uid)
    expect_identical(row_st$stage, "check")
    expect_identical(row_st$lane, "docs")

    # Target lane "code": new card lands in first stage and lane "code"
    u_code <- studio_uid_of(s$doc, "lanes", "code")
    s_ln <- studio_step(s, ev("target", list(kind = "lane", uid = u_code), seq = 1L))$state
    added_ln <- studio_step(s_ln, ev("add", list(table = "cards"), seq = 2L))$state
    row_ln <- studio_row(added_ln$doc, "cards", added_ln$target$uid)
    expect_identical(row_ln$stage, "write")
    expect_identical(row_ln$lane, "code")

    # Explicit stage from "Add a card here" wins over the server target
    added_exp <- studio_step(s2, ev("add", list(table = "cards", stage = u_check), seq = 3L))$state
    row_exp <- studio_row(added_exp$doc, "cards", added_exp$target$uid)
    expect_identical(row_exp$stage, "check")
    expect_identical(row_exp$lane, "code")
  })

  it("rebuilds check and good$serial on fix and undo, and blocks Done after undo", {
    s <- studio_state_new()
    s1 <- studio_step(s, ev("option", list(name = "title", value = "Edited"), seq = 1L))$state
    expect_identical(s1$rev, 1L)
    expect_identical(s1$good$serial, 1L)

    fault_id <- s1$check$faults$id[[1L]]
    s2 <- studio_step(s1, ev("fix", list(fault = fault_id, fix = "use"), seq = 2L))$state
    expect_identical(s2$rev, 2L)
    expect_true(s2$check$ok)
    expect_identical(nrow(s2$check$faults), 0L)
    expect_identical(s2$good$rev, 2L)
    expect_identical(s2$good$serial, 2L)

    s3 <- studio_step(s2, ev("undo", seq = 3L))$state
    expect_identical(s3$rev, 3L)
    expect_false(s3$check$ok)
    expect_identical(nrow(s3$check$faults), 1L)
    expect_lt(s3$good$rev, s3$rev)
    expect_identical(s3$good$serial, 2L)
    expect_identical(s3$notice$text, "Undone: Use card \"calc_dose\"")
    expect_identical(studio_step(s3, ev("done", seq = 4L))$state$notice$room, "check")
  })

  it("adds a card to a map with a non-syntactic column name, undoes and replays", {
    cards <- data.frame(id = "a", label = "A", stage = "s", lane = "l", check.names = FALSE, stringsAsFactors = FALSE)
    cards[["owner name"]] <- "Ana"
    map <- stage_map(cards, data.frame(id = "s", label = "S"), data.frame(id = "l", label = "L"))
    s <- studio_state_new(map)
    s1 <- studio_step(s, ev("add", list(table = "cards"), seq = 1L))$state
    expect_identical(s1$doc$tables$cards[["owner name"]], c("Ana", NA_character_))
    s2 <- studio_step(s1, ev("undo", seq = 2L))$state
    expect_identical(studio_doc_parts(s2$doc), studio_doc_parts(s2$base))
    expect_identical(studio_journal_replay(s2$base, s2$journal), s2$doc)
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
    late_pk <- studio_pick(done$state, "card", "a")
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

  it("keeps notice$n rising across accepted changes and repeated identical refusals", {
    s <- studio_state_new(small)
    r1 <- studio_step(s, ev("option", list(name = "title", value = ""), seq = 1L))$state
    expect_identical(r1$notice$n, 1L)
    ok <- studio_step(r1, ev("option", list(name = "title", value = "Valid"), seq = 2L, rev = r1$rev))$state
    expect_null(ok$notice)
    r2 <- studio_step(ok, ev("option", list(name = "title", value = ""), seq = 3L, rev = ok$rev))$state
    expect_identical(r2$notice$n, 2L)
    expect_identical(r2$notice$text, r1$notice$text)
    r3 <- studio_step(r2, ev("option", list(name = "title", value = ""), seq = 4L, rev = r2$rev))$state
    expect_identical(r3$notice$n, 3L)
  })

  it("turns a malformed event payload into a short plain notice without swallowing internal bugs", {
    s <- studio_state_new(small)
    bad_payload <- studio_step(s, ev("add", list(table = "links"), seq = 1L))
    expect_identical(bad_payload$state$rev, 0L)
    expect_identical(bad_payload$state$notice$tone, "problem")
    expect_false(grepl("Assertion on", bad_payload$state$notice$text, fixed = TRUE))

    local_mocked_bindings(
      studio_resolve = function(...) stop("unexpected internal bug")
    )
    expect_error(
      studio_step(s, ev("add", list(table = "cards"), seq = 2L)),
      "unexpected internal bug"
    )
  })

  it("never reuses row keys after Undo or open within one session", {
    s <- studio_state_new(small)
    s1 <- studio_step(s, ev("add", list(table = "cards"), seq = 1L))$state
    uid_first <- s1$target$uid
    s2 <- studio_step(s1, ev("undo", seq = 2L, rev = s1$rev))$state
    s3 <- studio_step(s2, ev("add", list(table = "cards"), seq = 3L, rev = s2$rev))$state
    uid_second <- s3$target$uid
    expect_identical(s3$target$kind, "card")
    expect_match(uid_second, "^u[0-9]+$")
    expect_false(is.null(studio_row(s3$doc, "cards", uid_second)))
    expect_false(identical(uid_second, uid_first))

    seen_uids <- c(unlist(lapply(s$doc$tables, `[[`, ".studio_uid")), uid_first, uid_second)
    s4 <- studio_step(s3, ev("open", list(template = "blank", confirm = TRUE), seq = 4L, rev = s3$rev))$state
    opened_uids <- unlist(lapply(s4$doc$tables, `[[`, ".studio_uid"))
    expect_length(intersect(opened_uids, seen_uids), 0L)
    s5 <- studio_step(s4, ev("add", list(table = "cards"), seq = 5L, rev = s4$rev))$state
    expect_identical(s5$target$kind, "card")
    expect_false(is.null(studio_row(s5$doc, "cards", s5$target$uid)))
    expect_false(s5$target$uid %in% c(seen_uids, opened_uids))
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
    run("undo")
    run("edit", list(table = "cards", uid = u_log, field = "label", value = "Log calls 2"))
    run("option", list(name = "legend", value = TRUE))
    run("option", list(name = "cell_columns", value = "auto"))
    run("edit", list(table = "cards", uid = u_round, field = "status", value = "running"))

    expect_gte(seq_n - 1L, 40L)
    expect_identical(studio_row(s$doc, "cards", u_calc)$id, "calc_dose_4")
    expect_identical(s$doc$args$target, "calc_dose_4")

    # Undoing every remaining entry returns base tables and args, and replay matches doc
    while (studio_journal_can_undo(s$journal)) {
      res <- studio_step(s, ev("undo", seq = seq_n, rev = s$rev))
      seq_n <- seq_n + 1L
      s <- res$state
      expect_match(s$notice$text, "^Undone: ")
      expect_identical(studio_journal_replay(s$base, s$journal), s$doc)
    }
    expect_identical(studio_doc_parts(s$doc), studio_doc_parts(s$base))
  })

  it("keeps doc identical to replay when clearing a newly added column or returning a factor cell", {
    cards <- data.frame(
      id = c("a", "b"),
      label = factor(c("A", "B")),
      stage = "s",
      lane = "l"
    )
    map <- stage_map(cards, data.frame(id = "s", label = "S"), data.frame(id = "l", label = "L"))
    s <- studio_state_new(map)
    expect_null(s$doc$tables$cards$tone)
    expect_null(s$doc$tables$stages$date)
    expect_true(is.factor(s$doc$tables$cards$label))

    # Add new tone and date columns then clear them back to NULL/NA
    s <- studio_step(s, ev("edit", list(table = "cards", uid = "u1", field = "tone", value = "good"), seq = 1L))$state
    expect_identical(s$doc$tables$cards$tone, c("good", NA_character_))
    s <- studio_step(
      s,
      ev("edit", list(table = "cards", uid = "u1", field = "tone", value = ""), seq = 2L, rev = s$rev)
    )$state
    expect_length(s$journal, 0L)
    expect_identical(studio_journal_replay(s$base, s$journal), s$doc)
    expect_null(s$doc$tables$cards$tone)

    uid_s <- s$doc$tables$stages$.studio_uid[[1L]]
    s <- studio_step(
      s,
      ev("edit", list(table = "stages", uid = uid_s, field = "date", value = "2026-05-01"), seq = 3L, rev = s$rev)
    )$state
    s <- studio_step(
      s,
      ev("edit", list(table = "stages", uid = uid_s, field = "date", value = ""), seq = 4L, rev = s$rev)
    )$state
    expect_identical(studio_journal_replay(s$base, s$journal), s$doc)
    expect_null(s$doc$tables$stages$date)

    # Factor column turned text on first edit returns to factor when edited back
    s <- studio_step(
      s,
      ev("edit", list(table = "cards", uid = "u1", field = "label", value = "Edited"), seq = 5L, rev = s$rev)
    )$state
    expect_false(is.factor(s$doc$tables$cards$label))
    s <- studio_step(
      s,
      ev("edit", list(table = "cards", uid = "u1", field = "label", value = "A"), seq = 6L, rev = s$rev)
    )$state
    expect_true(is.factor(s$doc$tables$cards$label))
    expect_identical(studio_journal_replay(s$base, s$journal), s$doc)
  })

  it("preserves full rename cascades when an id edit passes through blank or duplicate values", {
    map <- full_map(title = "A map", target = "b") |>
      add_steps(
        data.frame(id = "step1", label = "Step 1", stage = "write"),
        changes = data.frame(step = "step1", card = "b", stage = "ship", status = "done")
      ) |>
      stage_map_highlight(c("a", "b"), links = data.frame(from = "a", to = "b"))

    # Round trip a rename through blank back to the starting id: b -> b2 -> "" -> b
    s <- studio_state_new(map)
    s <- studio_step(s, ev("edit", list(table = "cards", uid = "u2", field = "id", value = "b2"), seq = 1L))$state
    s <- studio_step(
      s,
      ev("edit", list(table = "cards", uid = "u2", field = "id", value = ""), seq = 2L, rev = s$rev)
    )$state
    expect_identical(studio_journal_replay(s$base, s$journal), s$doc)
    expect_identical(s$doc$args$target, "b")
    expect_identical(s$doc$tables$links$to[[1L]], "b")
    s <- studio_step(
      s,
      ev("edit", list(table = "cards", uid = "u2", field = "id", value = "b"), seq = 3L, rev = s$rev)
    )$state
    expect_length(s$journal, 0L)
    expect_identical(s$doc, s$base)
    expect_true(s$check$ok)

    # Passing through blank or duplicate to a new id keeps all cascades: b -> b2 -> "" -> a -> b_final
    s <- studio_step(s, ev("edit", list(table = "cards", uid = "u2", field = "id", value = "b2"), seq = 4L))$state
    s <- studio_step(
      s,
      ev("edit", list(table = "cards", uid = "u2", field = "id", value = ""), seq = 5L, rev = s$rev)
    )$state
    s <- studio_step(
      s,
      ev("edit", list(table = "cards", uid = "u2", field = "id", value = "a"), seq = 6L, rev = s$rev)
    )$state
    s <- studio_step(
      s,
      ev("edit", list(table = "cards", uid = "u2", field = "id", value = "b_final"), seq = 7L, rev = s$rev)
    )$state
    expect_true(s$check$ok)
    expect_identical(s$doc$tables$links$to[[1L]], "b_final")
    expect_identical(s$doc$tables$changes$card[[1L]], "b_final")
    expect_identical(s$doc$args$target, "b_final")
    expect_identical(s$doc$args$highlight$ids, c("a", "b_final"))
    expect_identical(s$doc$args$highlight$links$to, "b_final")
    expect_identical(studio_journal_replay(s$base, s$journal), s$doc)
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
    expect_null(studio_drawn_uid(s, "lane", "docs"))
    expect_null(studio_drawn_uid(s, "card", ""))
    expect_error(studio_drawn_uid(list(1), "card", "a"), "state")
    expect_error(studio_target_select_effect(list(1)), "state")
  })
})
