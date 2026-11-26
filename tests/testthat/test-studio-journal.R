# Studio journal: recording, joining consecutive cell edits, dropping returned values, undo and replay.

delayedAssign("small", full_map(title = "A map"))

describe("studio_journal_add(), undo(), replay() and can_undo()", {
  it("joins consecutive edits of one cell and keeps separate cells separate", {
    base <- studio_doc(map_parts(small))
    j <- list()

    c1 <- studio_resolve(
      base,
      list(type = "edit", data = list(table = "cards", uid = "u1", field = "label", value = "Draft 2"))
    )
    d1 <- studio_doc_apply(base, c1$ops)
    j <- studio_journal_add(j, c1)

    c2 <- studio_resolve(
      d1,
      list(type = "edit", data = list(table = "cards", uid = "u1", field = "label", value = "Draft 3"))
    )
    d2 <- studio_doc_apply(d1, c2$ops)
    j <- studio_journal_add(j, c2)

    expect_length(j, 1L)
    expect_match(j[[1L]]$text, "Draft > Draft 3", fixed = TRUE)
    expect_identical(studio_journal_replay(base, j), d2)

    # A different cell does not join
    c3 <- studio_resolve(
      d2,
      list(type = "edit", data = list(table = "cards", uid = "u2", field = "label", value = "Review 2"))
    )
    d3 <- studio_doc_apply(d2, c3$ops)
    j <- studio_journal_add(j, c3)
    expect_length(j, 2L)
    expect_identical(studio_journal_replay(base, j), d3)
  })

  it("drops the joined entry when the cell returns to its first value", {
    base <- studio_doc(map_parts(small))
    c1 <- studio_resolve(
      base,
      list(type = "edit", data = list(table = "cards", uid = "u1", field = "label", value = "Temp"))
    )
    d1 <- studio_doc_apply(base, c1$ops)
    j <- studio_journal_add(list(), c1)
    expect_true(studio_journal_can_undo(j))

    c2 <- studio_resolve(
      d1,
      list(type = "edit", data = list(table = "cards", uid = "u1", field = "label", value = "Draft"))
    )
    j <- studio_journal_add(j, c2)
    expect_length(j, 0L)
    expect_false(studio_journal_can_undo(j))
    expect_identical(studio_journal_replay(base, j), base)
  })

  it("marks undone entries and replays only done entries", {
    base <- studio_doc(map_parts(small))
    c1 <- studio_resolve(base, list(type = "option", data = list(name = "title", value = "Next")))
    d1 <- studio_doc_apply(base, c1$ops)
    j <- studio_journal_add(list(), c1)
    c2 <- studio_resolve(d1, list(type = "add", data = list(table = "cards")))
    j <- studio_journal_add(j, c2)

    j_undone <- studio_journal_undo(j)
    expect_identical(j_undone[[1L]]$state, "done")
    expect_identical(j_undone[[2L]]$state, "undone")
    expect_identical(studio_journal_replay(base, j_undone), d1)

    j_all_undone <- studio_journal_undo(j_undone)
    expect_false(studio_journal_can_undo(j_all_undone))
    expect_identical(studio_journal_replay(base, j_all_undone), base)
    expect_identical(studio_journal_undo(j_all_undone), j_all_undone)
  })

  it("ignores empty-op changes and joins plain changes without join metadata", {
    base <- studio_doc(map_parts(small))
    empty_c <- list(verb = "Edit", text = "", key = NA_character_, target = NULL, ops = list())
    expect_identical(studio_journal_add(list(), empty_c), list())

    plain1 <- list(
      verb = "Edit",
      text = "First",
      key = "k1",
      target = NULL,
      ops = list(list(op = "arg", name = "title", value = "One"))
    )
    plain2 <- list(
      verb = "Edit",
      text = "Second",
      key = "k1",
      target = NULL,
      ops = list(list(op = "arg", name = "title", value = "Two"))
    )
    j <- studio_journal_add(list(), plain1)
    j <- studio_journal_add(j, plain2)
    expect_length(j, 1L)
    expect_identical(j[[1L]]$text, "Second")
    expect_identical(studio_journal_replay(base, j)$args$title, "Two")
  })

  it("checks its arguments", {
    base <- studio_doc(map_parts(small))
    expect_error(studio_journal_add("j", list()), "journal")
    expect_error(studio_journal_add(list(), list(1)), "change")
    expect_error(studio_journal_can_undo("j"), "journal")
    expect_error(studio_journal_undo("j"), "journal")
    expect_error(studio_journal_replay("base", list()), "base")
    expect_error(studio_journal_replay(base, "j"), "journal")
  })
})
