# Plain tests for the Ask room: step, clear, view, link direction resolution, call evaluation, errors and assertions.

delayedAssign("small_map", studio_small())

ev_ask <- function(seq, data, rev = 0L) {
  list(seq = seq, type = "ask", data = data, rev = rev)
}

eval_ask_call <- function(call_text, map) {
  env <- list2env(list(map = map), parent = asNamespace("stagemap"))
  eval(parse(text = call_text, encoding = "UTF-8"), envir = env)
}

describe("studio_room_ask_step() and studio_room_ask_clear()", {
  it("runs sm_trace() on studio_small() across directions, kinds and max_distance, matching direct calls and eval(call)", {
    s <- studio_state_new(small_map)
    u_a <- studio_uid_of(s$doc, "cards", "a")
    u_c <- studio_uid_of(s$doc, "cards", "c")

    # Downstream default
    res_d <- studio_room_ask_step(s, list(question = "trace", ids = u_a, direction = "downstream"))
    direct_d <- sm_trace(small_map, "a")
    expect_identical(res_d$state$ask$rows[, names(direct_d)], direct_d)
    expect_identical(res_d$state$ask$rows$uid, c("u1", "u2", "u3", "u4"))
    expect_identical(res_d$state$ask$call, 'sm_trace(map, "a")')
    expect_identical(eval_ask_call(res_d$state$ask$call, s$good$map), direct_d)
    expect_identical(res_d$effects[[1L]]$type, "highlight")
    expect_identical(res_d$effects[[1L]]$ids, c("a", "b", "c", "d"))
    expect_identical(res_d$effects[[1L]]$links$from, c("a", "b", "c"))
    expect_identical(res_d$effects[[1L]]$links$to, c("b", "c", "d"))
    expect_no_error(stage_map_highlight(s$good$map, res_d$effects[[1L]]$ids, links = res_d$effects[[1L]]$links))

    # Upstream with kinds and max_distance
    res_u <- studio_room_ask_step(
      s,
      list(question = "trace", ids = list(u_c), direction = "upstream", kinds = "hand", max_distance = 1)
    )
    direct_u <- sm_trace(small_map, "c", direction = "upstream", kinds = "hand", max_distance = 1)
    expect_identical(res_u$state$ask$rows[, names(direct_u)], direct_u)
    expect_identical(eval_ask_call(res_u$state$ask$call, s$good$map), direct_u)
    expect_identical(res_u$effects[[1L]]$ids, c("c", "b"))
    expect_identical(res_u$effects[[1L]]$links$from, "b")
    expect_identical(res_u$effects[[1L]]$links$to, "c")
    expect_no_error(stage_map_highlight(s$good$map, res_u$effects[[1L]]$ids, links = res_u$effects[[1L]]$links))

    # Both directions with a loop so `both` cards resolve forward and backward links accurately
    loop_map <- stage_map(
      data.frame(id = c("a", "b", "c"), label = c("A", "B", "C"), stage = "s", lane = "l"),
      data.frame(id = "s", label = "S"),
      data.frame(id = "l", label = "L")
    ) |>
      add_links(data.frame(from = c("a", "b", "c"), to = c("b", "c", "a")))
    s_loop <- studio_state_new(loop_map)
    res_b <- studio_room_ask_step(s_loop, list(question = "trace", ids = "u1", direction = "both"))
    direct_b <- sm_trace(loop_map, "a", direction = "both")
    expect_identical(res_b$state$ask$rows[, names(direct_b)], direct_b)
    expect_identical(eval_ask_call(res_b$state$ask$call, loop_map), direct_b)
    expect_identical(res_b$effects[[1L]]$links$from, c("a", "c"))
    expect_identical(res_b$effects[[1L]]$links$to, c("b", "a"))
    expect_no_error(stage_map_highlight(loop_map, res_b$effects[[1L]]$ids, links = res_b$effects[[1L]]$links))

    # Trace with max_distance = 0 (no links), string max_distance = "1", and NULL/empty-list ids (0 rows -> unlight)
    res_zero <- studio_room_ask_step(s, list(question = "trace", ids = u_a, max_distance = 0))
    expect_null(res_zero$state$ask$links)
    expect_identical(res_zero$effects[[1L]]$ids, "a")

    res_str <- studio_room_ask_step(s, list(question = "trace", ids = u_a, max_distance = "1"))
    expect_identical(nrow(res_str$state$ask$rows), 2L)

    res_empty <- studio_room_ask_step(s, list(question = "trace", ids = list()))
    expect_identical(nrow(res_empty$state$ask$rows), 0L)
    expect_identical(res_empty$effects, list(list(type = "highlight", ids = character(), links = NULL)))

    # View on loop_map covers `direction == "both"` distance formatting ("1 both")
    v_loop <- studio_room_ask_view(res_b$state)$answer
    expect_true(any(vapply(v_loop$rows, function(r) grepl("both", r$cells[[3L]]$text, fixed = TRUE), logical(1))))
  })

  it("runs sm_orphans() and sm_missing() matching direct calls and eval(call)", {
    # Map with an orphan card and a gap
    m <- stage_map(
      data.frame(
        id = c("r1", "r2", "t1", "x1"),
        label = c("Req 1", "Req 2", "Test 1", "Loose"),
        stage = c("req", "req", "test", "req"),
        lane = "l"
      ),
      data.frame(id = c("req", "test"), label = c("Requirement", "Test")),
      data.frame(id = "l", label = "Main")
    ) |>
      add_links(
        data.frame(from = c("r1", "r2"), to = "t1", kind = c("verifies", "other")),
        kinds = data.frame(id = c("verifies", "other"), label = c("Verifies", "Other"))
      )
    s <- studio_state_new(m)

    # Loose ends
    res_o <- studio_room_ask_step(s, list(question = "orphans"))
    direct_o <- sm_orphans(m)
    expect_identical(res_o$state$ask$rows[, names(direct_o)], direct_o)
    expect_identical(eval_ask_call(res_o$state$ask$call, m), direct_o)
    expect_null(res_o$state$ask$links)
    expect_identical(res_o$effects[[1L]]$ids, "x1")

    # Loose ends with none found -> unlight
    s_all_linked <- studio_state_new(small_map)
    res_none <- studio_room_ask_step(s_all_linked, list(question = "orphans"))
    expect_identical(nrow(res_none$state$ask$rows), 0L)
    expect_identical(res_none$effects, list(list(type = "highlight", ids = character(), links = NULL)))

    # Missing with kinds
    u_req <- studio_uid_of(s$doc, "stages", "req")
    u_test <- studio_uid_of(s$doc, "stages", "test")
    res_m <- studio_room_ask_step(s, list(question = "missing", stage = u_req, linked_to = u_test, kinds = "verifies"))
    direct_m <- sm_missing(m, "req", "test", kinds = "verifies")
    expect_identical(res_m$state$ask$rows[, names(direct_m)], direct_m)
    expect_identical(eval_ask_call(res_m$state$ask$call, m), direct_m)
    expect_identical(res_m$effects[[1L]]$ids, c("r2", "x1"))
    expect_match(res_m$state$ask$call, 'kinds = "verifies"', fixed = TRUE)

    # The kinds filter changes the answer: r2 is linked, but not by a "verifies" link
    res_m_all <- studio_room_ask_step(s, list(question = "missing", stage = u_req, linked_to = u_test))
    direct_m_all <- sm_missing(m, "req", "test")
    expect_identical(res_m_all$state$ask$rows[, names(direct_m_all)], direct_m_all)
    expect_identical(res_m_all$effects[[1L]]$ids, "x1")
    expect_false(grepl("kinds", res_m_all$state$ask$call, fixed = TRUE))
    expect_identical(res_m_all$state$ask$kinds, NULL)
    expect_identical(res_m$state$ask$kinds, "verifies")

    # The head sentence says which kind the answer is about, and so does the "no gaps" one
    expect_identical(
      studio_room_ask_view(res_m$state)$answer$head,
      "2 cards in Requirement with no direct Verifies link to Test"
    )
    expect_identical(
      studio_room_ask_view(res_m_all$state)$answer$head,
      "1 card in Requirement with no direct link to Test"
    )
    res_m_two <- studio_room_ask_step(
      s,
      list(question = "missing", stage = u_req, linked_to = u_test, kinds = list("verifies", "other"))
    )
    expect_match(
      studio_room_ask_view(res_m_two$state)$answer$head,
      "no direct Verifies or Other link to Test",
      fixed = TRUE
    )
    res_m_none <- studio_room_ask_step(
      s,
      list(question = "missing", stage = u_test, linked_to = u_req, kinds = "other")
    )
    expect_identical(
      studio_room_ask_view(res_m_none$state)$answer$head,
      "No gaps: every Test card has a Other link to Requirement"
    )

    # Missing with no gaps -> unlight
    res_m_clean <- studio_room_ask_step(s, list(question = "missing", stage = u_test, linked_to = u_req))
    expect_identical(nrow(res_m_clean$state$ask$rows), 0L)
    expect_identical(res_m_clean$effects, list(list(type = "highlight", ids = character(), links = NULL)))
  })

  it("keeps the kinds filter of sm_trace() in the answer, the call text and the head sentence", {
    m <- stage_map(
      data.frame(id = c("a", "b", "c"), label = c("A", "B", "C"), stage = "s", lane = "l"),
      data.frame(id = "s", label = "S"),
      data.frame(id = "l", label = "L")
    ) |>
      add_links(
        data.frame(from = c("a", "a"), to = c("b", "c"), kind = c("x", "y")),
        kinds = data.frame(id = c("x", "y"), label = c("Ex", "Why"))
      )
    s <- studio_state_new(m)

    res_k <- studio_room_ask_step(s, list(question = "trace", ids = "u1", kinds = "x"))
    direct_k <- sm_trace(m, "a", kinds = "x")
    expect_identical(res_k$state$ask$rows[, names(direct_k)], direct_k)
    expect_identical(res_k$effects[[1L]]$ids, c("a", "b"))
    expect_identical(res_k$state$ask$call, 'sm_trace(map, "a", kinds = "x")')
    expect_identical(eval_ask_call(res_k$state$ask$call, m), direct_k)

    res_all <- studio_room_ask_step(s, list(question = "trace", ids = "u1"))
    expect_identical(res_all$effects[[1L]]$ids, c("a", "b", "c"))
    expect_false(grepl("kinds", res_all$state$ask$call, fixed = TRUE))

    # A distance limit is in the call and in the head sentence
    res_d <- studio_room_ask_step(s, list(question = "trace", ids = "u1", max_distance = 1))
    expect_match(res_d$state$ask$call, "max_distance = 1", fixed = TRUE)
    expect_identical(studio_room_ask_view(res_d$state)$answer$head, "2 cards downstream of A within 1 step")
    res_d2 <- studio_room_ask_step(s, list(question = "trace", ids = "u1", max_distance = "3"))
    expect_identical(studio_room_ask_view(res_d2$state)$answer$head, "2 cards downstream of A within 3 steps")
    expect_identical(studio_room_ask_view(res_all$state)$answer$head, "2 cards downstream of A")
  })

  it("numbers every answer so a repeated question is a new value, and unlights an open map after a lit answer", {
    s <- studio_state_new(small_map)
    first <- studio_step(s, ev_ask(3L, list(question = "trace", ids = "u1")))$state
    again <- studio_step(first, ev_ask(4L, list(question = "trace", ids = "u1"), rev = first$rev))$state
    expect_identical(first$ask$run, 3L)
    expect_identical(again$ask$run, 4L)
    v_first <- studio_room_ask_view(first)
    v_again <- studio_room_ask_view(again)
    expect_identical(v_first$answer$run, 3L)
    expect_false(identical(v_first, v_again))
    expect_false(identical(studio_message(v_first, v_again), list(sections = structure(list(), names = character()))))
    # An error answer is numbered too
    err <- studio_step(s, ev_ask(5L, list(question = "trace", ids = "u999")))$state
    expect_identical(studio_room_ask_view(err)$answer$run, 5L)

    # Opening a map after a lit answer clears the answer and unlights, so no card stays lit without a way to clear it
    expect_true(first$ask$lit)
    for (template in c("blank", "example", "given")) {
      opened <- studio_step(
        first,
        list(seq = 4L, type = "open", data = list(template = template, confirm = FALSE), rev = first$rev)
      )
      expect_null(opened$state$ask)
      expect_identical(opened$effects[[1L]], list(type = "highlight", ids = character(), links = NULL))
    }
    # No lit answer, nothing to unlight
    quiet <- studio_step(
      s,
      list(seq = 1L, type = "open", data = list(template = "blank", confirm = FALSE), rev = s$rev)
    )
    expect_false(any(vapply(quiet$effects, function(e) identical(e$type, "highlight"), logical(1))))
  })

  it("handles errors from unknown keys, bad max_distance, bad types and broken documents with unlight only", {
    s <- studio_state_new(small_map)

    # Unknown card key
    bad_key <- studio_room_ask_step(s, list(question = "trace", ids = "u999"))
    expect_type(bad_key$state$ask$error$head, "character")
    expect_identical(bad_key$effects, list(list(type = "highlight", ids = character(), links = NULL)))

    # Bad max_distance (negative, fractional, non-numeric text, wrong type)
    for (bad_dist in list(-1, 1.5, "abc", list(1))) {
      bad_d <- studio_room_ask_step(s, list(question = "trace", ids = "u1", max_distance = bad_dist))
      expect_type(bad_d$state$ask$error$head, "character")
      expect_identical(bad_d$effects, list(list(type = "highlight", ids = character(), links = NULL)))
    }

    # Unknown kind triggers R's stagemap_error_id with head and lines
    bad_k <- studio_room_ask_step(s, list(question = "trace", ids = "u1", kinds = "no_such_kind"))
    expect_match(bad_k$state$ask$error$head, "link kind")
    expect_gt(length(bad_k$state$ask$error$lines), 0L)
    expect_identical(bad_k$effects, list(list(type = "highlight", ids = character(), links = NULL)))

    # Invalid unwrap inputs and missing required stage keys
    expect_match(studio_room_ask_step(s, list(question = "missing"))$state$ask$error$head, "missing")
    expect_match(
      studio_room_ask_step(s, list(question = "missing", stage = list(), linked_to = "u5"))$state$ask$error$head,
      "empty"
    )
    expect_match(
      studio_room_ask_step(s, list(question = "missing", stage = list(1), linked_to = "u5"))$state$ask$error$head,
      "text"
    )
    expect_match(
      studio_room_ask_step(s, list(question = "missing", stage = NA_character_, linked_to = "u5"))$state$ask$error$head,
      "NA"
    )
    expect_match(
      studio_room_ask_step(s, list(question = "missing", stage = 123, linked_to = "u5"))$state$ask$error$head,
      "text"
    )
    expect_match(
      studio_room_ask_step(s, list(question = "missing", stage = "", linked_to = "u5"))$state$ask$error$head,
      "Choose"
    )
    expect_match(
      studio_room_ask_step(s, list(question = "missing", stage = "  ", linked_to = "u5"))$state$ask$error$head,
      "blank"
    )
    expect_match(
      studio_room_ask_step(s, list(question = "missing", stage = c("u5", "u6"), linked_to = "u5"))$state$ask$error$head,
      "one"
    )

    # Card with blank id gives a clean ask$error
    s_blank <- studio_step(
      s,
      list(seq = 1L, type = "edit", data = list(table = "cards", uid = "u1", field = "id", value = ""), rev = 0L)
    )$state
    # Manually simulate blank id on valid rev to cover the blank-id guard
    s_tmp <- s
    s_tmp$doc$tables$cards$id[[1L]] <- ""
    expect_match(studio_room_ask_step(s_tmp, list(question = "trace", ids = "u1"))$state$ask$error$head, "no id")

    # Broken document refuses to run and points to Check
    broken <- studio_state_new()
    ref <- studio_room_ask_step(broken, list(question = "trace", ids = "u1"))
    expect_match(ref$state$ask$error$head, "Fix the problems under Check first")
    expect_identical(ref$state$notice$room, "check")
    expect_identical(ref$effects, list(list(type = "highlight", ids = character(), links = NULL)))

    # Unknown question name
    unk_q <- studio_room_ask_step(s, list(question = "unknown"))
    expect_match(unk_q$state$notice$text, "Unknown question")

    # Any document change marks the answer stale and unlights
    ran <- studio_step(s, ev_ask(1L, list(question = "trace", ids = "u1")))$state
    expect_false(studio_room_ask_view(ran)$answer$stale)
    edited <- studio_step(ran, list(seq = 2L, type = "option", data = list(name = "title", value = "New"), rev = 0L))
    expect_true(edited$state$ask$stale)
    expect_identical(edited$effects, list(list(type = "highlight", ids = character(), links = NULL)))
    expect_true(studio_room_ask_view(edited$state)$answer$stale)

    # ask_clear clears ask and emits unlight
    cleared <- studio_step(ran, list(seq = 2L, type = "ask_clear", data = list(), rev = 0L))
    expect_null(cleared$state$ask)
    expect_identical(cleared$effects, list(list(type = "highlight", ids = character(), links = NULL)))
  })

  it("builds question specs and answer views across states", {
    # Target card preselected, kinds included when present, omitted when absent
    s <- studio_state_new(small_map)
    s_t <- studio_step(s, list(seq = 1L, type = "target", data = list(kind = "card", uid = "u2"), rev = 0L))$state
    v <- studio_room_ask_view(s_t)
    expect_named(v, c("questions", "answer"))
    expect_null(v$answer)
    expect_identical(vapply(v$questions, `[[`, "", "id"), c("trace", "orphans", "missing"))
    expect_identical(v$questions[[1L]]$fields[[1L]]$value, "u2")
    expect_identical(vapply(v$questions[[1L]]$fields, `[[`, "", "name"), c("ids", "direction", "kinds", "max_distance"))
    expect_length(v$questions[[2L]]$fields, 0L)
    expect_identical(vapply(v$questions[[3L]]$fields, `[[`, "", "name"), c("stage", "linked_to", "kinds"))

    # Blank map has no kinds field and 1 stage
    s_blank <- studio_state_new()
    s_blank <- studio_step(
      s_blank,
      list(seq = 1L, type = "open", data = list(template = "blank", confirm = FALSE), rev = 0L)
    )$state
    vb <- studio_room_ask_view(s_blank)
    expect_identical(vapply(vb$questions[[1L]]$fields, `[[`, "", "name"), c("ids", "direction", "max_distance"))
    expect_identical(vb$questions[[3L]]$fields[[1L]]$value, vb$questions[[3L]]$fields[[2L]]$value)

    # Links with `kind` column even without `kinds` table still offer kind choices; blank/duplicate kinds skipped
    sk <- s
    sk$doc$tables$kinds <- NULL
    expect_identical(vapply(studio_ask_kind_choices(sk$doc), `[[`, "", "value"), c("", "hand"))
    sk2 <- s
    sk2$doc$tables$kinds <- rbind(
      sk2$doc$tables$kinds,
      data.frame(
        id = c("", "hand"),
        label = c("Blank", "Dup"),
        line = "solid",
        .studio_uid = c("u98", "u99"),
        stringsAsFactors = FALSE
      )
    )
    expect_identical(vapply(studio_ask_kind_choices(sk2$doc), `[[`, "", "value"), c("", "hand"))

    # Answer view after trace, orphans, missing and deleted-card stale state
    s_tr <- studio_step(s, ev_ask(1L, list(question = "trace", ids = "u1", direction = "downstream")))$state
    va <- studio_room_ask_view(s_tr)$answer
    expect_identical(va$head, "3 cards downstream of Draft")
    expect_identical(va$columns, list("Card", "Stage", "Distance"))
    expect_identical(va$count, 4L)
    expect_identical(va$rows[[1L]]$cells[[3L]]$text, "start")
    expect_identical(va$rows[[2L]]$cells[[3L]]$text, "1 down")

    # Upstream & both head sentences
    s_up <- studio_step(s, ev_ask(1L, list(question = "trace", ids = "u2", direction = "upstream")))$state
    expect_identical(studio_room_ask_view(s_up)$answer$head, "1 card upstream of Review")
    s_bo <- studio_step(s, ev_ask(1L, list(question = "trace", ids = "u2", direction = "both")))$state
    expect_identical(studio_room_ask_view(s_bo)$answer$head, "3 cards either side of Review")

    # Delete a card after running trace -> stale row drops target event safely
    s_del <- studio_step(
      s_tr,
      list(seq = 2L, type = "remove", data = list(table = "cards", uid = "u4"), rev = 0L)
    )$state
    v_del <- studio_room_ask_view(s_del)$answer
    expect_true(v_del$stale)
    expect_null(v_del$rows[[4L]]$event)

    # Orphans and missing heads
    s_o0 <- studio_step(s, ev_ask(1L, list(question = "orphans")))$state
    expect_identical(studio_room_ask_view(s_o0)$answer$head, "Every card has a link")
    s_add <- studio_step(s, list(seq = 1L, type = "add", data = list(table = "cards"), rev = 0L))$state
    s_o1 <- studio_step(s_add, ev_ask(2L, list(question = "orphans"), rev = s_add$rev))$state
    expect_identical(studio_room_ask_view(s_o1)$answer$head, "1 card with no link")
    s_m0 <- studio_step(s, ev_ask(1L, list(question = "missing", stage = "u5", linked_to = "u6")))$state
    expect_identical(studio_room_ask_view(s_m0)$answer$head, "No gaps: every Write card links to Check")
    s_m1 <- studio_step(s, ev_ask(1L, list(question = "missing", stage = "u5", linked_to = "u7")))$state
    expect_identical(studio_room_ask_view(s_m1)$answer$head, "1 card in Write with no direct link to Ship")

    # Error answer view
    s_err <- studio_step(s, ev_ask(1L, list(question = "trace", ids = "u999")))$state
    v_err <- studio_room_ask_view(s_err)$answer
    expect_null(v_err$head)
    expect_match(v_err$error$head, "Unknown card key")

    # Fallback when tables have no rows (defensive) and when a stale stage is missing from stages
    s_empty <- s
    s_empty$doc$tables$cards <- s_empty$doc$tables$cards[0L, , drop = FALSE]
    s_empty$doc$tables$stages <- s_empty$doc$tables$stages[0L, , drop = FALSE]
    v_empty <- studio_room_ask_view(s_empty)
    expect_identical(v_empty$questions[[1L]]$fields[[1L]]$choices[[1L]]$label, "No cards")
    expect_identical(v_empty$questions[[3L]]$fields[[1L]]$choices[[1L]]$label, "No stages")
    s_tr_empty_ids <- studio_step(s, ev_ask(1L, list(question = "trace", ids = "")))$state
    expect_identical(studio_room_ask_view(s_tr_empty_ids)$answer$head, "0 cards traced")
    expect_identical(studio_ask_head(s_m1$ask, s_empty$doc), "1 card in write with no direct link to ship")
    expect_identical(
      studio_ask_head(list(question = "missing", rows = data.frame(), stage_id = NULL, linked_to_id = ""), s_empty$doc),
      "No gaps: every  card links to "
    )
    s_stale_stage <- s_tr
    s_stale_stage$doc$tables$stages <- s_stale_stage$doc$tables$stages[0L, , drop = FALSE]
    expect_identical(studio_room_ask_view(s_stale_stage)$answer$rows[[1L]]$cells[[2L]]$text, "write")
  })

  it("checks all arguments with checkmate", {
    s <- studio_state_new(small_map)
    expect_error(studio_ask_unwrap(NULL, ""), "arg_name")
    expect_error(studio_ask_unwrap(NULL, "a", allow_empty = "yes"), "allow_empty")
    expect_error(studio_ask_resolve_uids(list(1), "cards", NULL, "ids", "card"), "doc")
    expect_error(studio_ask_resolve_uids(s$doc, "", NULL, "ids", "card"), "table")
    expect_error(studio_ask_call_text("", list()), "fn")
    expect_error(studio_ask_trace_links("bad", small_map), "rows")
    expect_error(studio_ask_trace_links(data.frame(), "bad"), "map")
    expect_error(studio_ask_error(list(1), "trace", list(), "h"), "state")
    expect_error(studio_room_ask_step(list(1), list(question = "trace")), "state")
    expect_error(studio_room_ask_step(s, list(1)), "data")
    expect_error(studio_room_ask_clear(list(1)), "state")
    expect_error(studio_ask_kind_choices(list(1)), "doc")
    expect_error(studio_ask_head(list(1), s$doc), "ask")
    expect_error(studio_room_ask_view(list(1)), "state")
  })
})
