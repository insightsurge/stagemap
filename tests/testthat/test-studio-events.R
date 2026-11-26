# Document-changing events: checks, resolution, cascades and refusals.

delayedAssign(
  "small",
  full_map(title = "A map", target = "b") |>
    add_steps(
      data.frame(id = "step1", label = "Step 1", stage = "write"),
      changes = data.frame(step = "step1", card = "b", stage = "ship", status = "done")
    ) |>
    add_variants(data.frame(id = "v1", label = "Main"))
)

resolve <- function(doc, type, data) studio_resolve(doc, list(type = type, data = data))

describe("studio_resolve() for edit", {
  it("edits inspector fields and refuses kept or unknown fields and missing rows", {
    doc <- studio_doc(map_parts(small))
    ch <- resolve(doc, "edit", list(table = "cards", uid = "u1", field = "status", value = "running"))
    expect_identical(ch$key, "edit:cards:u1:status")
    expect_identical(ch$verb, "Edit")
    expect_identical(ch$text, "card a status: done > running")
    doc2 <- studio_doc_apply(doc, ch$ops)
    expect_identical(studio_row(doc2, "cards", "u1")$status, "running")

    # Same value produces no ops
    noop <- resolve(doc, "edit", list(table = "cards", uid = "u1", field = "status", value = "done"))
    expect_length(noop$ops, 0L)

    # Refusals
    expect_match(
      resolve(doc, "edit", list(table = "cards", uid = "u1", field = "hidden", value = TRUE))$refused,
      "cannot edit"
    )
    expect_match(
      resolve(doc, "edit", list(table = "cards", uid = "u999", field = "label", value = "X"))$refused,
      "no longer"
    )
    expect_match(
      resolve(doc, "edit", list(table = "cards", uid = "u1", field = "tone", value = "neon"))$refused,
      "not allowed"
    )
  })

  it("cascades card, stage, and kind id renames across joins, changes and args, and still builds", {
    doc <- studio_doc(map_parts(small))

    # Rename card "b" -> "b_new"
    ch_card <- resolve(doc, "edit", list(table = "cards", uid = "u2", field = "id", value = "b_new"))
    doc2 <- studio_doc_apply(doc, ch_card$ops)
    expect_identical(doc2$tables$links$to[[1L]], "b_new")
    expect_identical(doc2$tables$links$from[[2L]], "b_new")
    expect_identical(doc2$tables$changes$card[[1L]], "b_new")
    expect_identical(doc2$args$target, "b_new")
    expect_true(studio_build(doc2)$ok)

    # Rename stage "ship" -> "done_stage"
    ship_uid <- studio_uid_of(doc2, "stages", "ship")
    ch_stage <- resolve(doc2, "edit", list(table = "stages", uid = ship_uid, field = "id", value = "done_stage"))
    doc3 <- studio_doc_apply(doc2, ch_stage$ops)
    expect_identical(doc3$tables$cards$stage[[4L]], "done_stage")
    expect_true(studio_build(doc3)$ok)

    # Cascade helper for kind id ("hand" -> "passed") and split variants
    kind_ops <- c(
      list(list(
        op = "set",
        table = "kinds",
        uid = studio_uid_of(doc3, "kinds", "hand"),
        field = "id",
        value = "passed"
      )),
      studio_cascade_ops(doc3, "kinds", "hand", "passed")
    )
    doc4 <- studio_doc_apply(doc3, kind_ops)
    expect_identical(doc4$tables$links$kind[1:2], c("passed", "passed"))
    expect_true(studio_build(doc4)$ok)

    map_v <- stage_map(
      data.frame(id = "a", label = "A", stage = "s", lane = "l", variants = "v1, v2"),
      data.frame(id = "s", label = "S"),
      data.frame(id = "l", label = "L"),
      variant = "v1"
    ) |>
      add_variants(data.frame(id = c("v1", "v2"), label = c("V1", "V2")))
    doc_v <- studio_doc(map_parts(map_v))
    v_ops <- c(
      list(list(
        op = "set",
        table = "variants",
        uid = studio_uid_of(doc_v, "variants", "v1"),
        field = "id",
        value = "v_new"
      )),
      studio_cascade_ops(doc_v, "variants", "v1", "v_new")
    )
    doc_v2 <- studio_doc_apply(doc_v, v_ops)
    expect_identical(doc_v2$tables$cards$variants, "v_new, v2")
    expect_identical(doc_v2$args$variant, "v_new")
    expect_identical(studio_cascade_ops(doc_v, "links", "x", "y"), list())
    expect_identical(studio_fmt_val(""), "(blank)")
  })

  it("updates args$highlight ids and links when a highlighted card is renamed or removed", {
    map <- full_map(title = "A map") |>
      stage_map_highlight(
        c("a", "b", "c", "d"),
        links = data.frame(from = c("a", "c"), to = c("b", "d"))
      )
    doc <- studio_doc(map_parts(map))

    ch_ren <- resolve(doc, "edit", list(table = "cards", uid = "u2", field = "id", value = "b2"))
    doc2 <- studio_doc_apply(doc, ch_ren$ops)
    expect_identical(doc2$args$highlight$ids, c("a", "b2", "c", "d"))
    expect_identical(doc2$args$highlight$links$from, c("a", "c"))
    expect_identical(doc2$args$highlight$links$to, c("b2", "d"))
    expect_true(studio_build(doc2)$ok)

    ch_rm_b <- resolve(doc2, "remove", list(table = "cards", uid = "u2"))
    expect_identical(ch_rm_b$text, "Remove card b2")
    doc3 <- studio_doc_apply(doc2, ch_rm_b$ops)
    expect_identical(doc3$args$highlight$ids, c("a", "c", "d"))
    expect_identical(doc3$args$highlight$links, data.frame(from = "c", to = "d"))
    expect_true(studio_build(doc3)$ok)

    doc4 <- studio_doc_apply(doc3, resolve(doc3, "remove", list(table = "cards", uid = "u1"))$ops)
    doc5 <- studio_doc_apply(doc4, resolve(doc4, "remove", list(table = "cards", uid = "u4"))$ops)
    expect_null(doc5$args$highlight$links)
    doc5b <- studio_doc_apply(doc5, resolve(doc5, "add", list(table = "cards"))$ops)
    doc6 <- studio_doc_apply(doc5b, resolve(doc5b, "remove", list(table = "cards", uid = "u3"))$ops)
    expect_null(doc6$args$highlight)
    expect_true(studio_build(doc6)$ok)
  })

  it("edits a factor column cleanly via resolve", {
    map <- stage_map(
      data.frame(id = "a", label = factor("A"), stage = "s", lane = "l", stringsAsFactors = FALSE),
      data.frame(id = "s", label = "S"),
      data.frame(id = "l", label = "L")
    )
    doc <- studio_doc(map_parts(map))
    ch <- resolve(doc, "edit", list(table = "cards", uid = "u1", field = "label", value = "B"))
    expect_identical(studio_doc_apply(doc, ch$ops)$tables$cards$label, "B")
  })

  it("accepts blank or duplicate ids without cascading", {
    doc <- studio_doc(map_parts(small))
    blank <- resolve(doc, "edit", list(table = "cards", uid = "u1", field = "id", value = ""))
    doc_blank <- studio_doc_apply(doc, blank$ops)
    expect_true(is.na(doc_blank$tables$cards$id[[1L]]))
    expect_identical(doc_blank$tables$links$from[[1L]], "a")

    dup <- resolve(doc, "edit", list(table = "cards", uid = "u1", field = "id", value = "b"))
    doc_dup <- studio_doc_apply(doc, dup$ops)
    expect_identical(doc_dup$tables$cards$id[[1L]], "b")
    expect_identical(doc_dup$tables$links$from[[1L]], "a")

    # Renaming away from a duplicate id does not steal the other row's links
    back <- resolve(doc_dup, "edit", list(table = "cards", uid = "u2", field = "id", value = "b2"))
    doc_back <- studio_doc_apply(doc_dup, back$ops)
    expect_identical(doc_back$tables$links$to[[1L]], "b")
  })
})

describe("studio_resolve() for option", {
  it("changes offered header and map options and refuses kept or invalid values", {
    doc <- studio_doc(map_parts(small))
    ch <- resolve(doc, "option", list(name = "layout", value = "levels"))
    expect_identical(ch$key, "arg:layout")
    expect_identical(ch$text, "Set layout: grid > levels")
    doc2 <- studio_doc_apply(doc, ch$ops)
    expect_identical(doc2$args$layout, "levels")

    doc2 <- studio_doc_apply(doc2, resolve(doc2, "option", list(name = "cell_columns", value = 3))$ops)
    expect_identical(doc2$args$cell_columns, 3L)
    doc2 <- studio_doc_apply(doc2, resolve(doc2, "option", list(name = "cell_columns", value = "auto"))$ops)
    expect_identical(doc2$args$cell_columns, "auto")
    doc2 <- studio_doc_apply(doc2, resolve(doc2, "option", list(name = "target", value = ""))$ops)
    expect_null(doc2$args$target)

    expect_match(resolve(doc, "option", list(name = "motion", value = FALSE))$refused, "does not change")
    expect_match(resolve(doc, "option", list(name = "title", value = "  "))$refused, "cannot be blank")
    expect_match(resolve(doc, "option", list(name = "layout", value = "circle"))$refused, "Layout")
    expect_match(resolve(doc, "option", list(name = "target", value = "nope"))$refused, "Target")
    expect_match(resolve(doc, "option", list(name = "target", value = 1.5))$refused, "Target")
    doc_num <- studio_doc(map_parts(stage_map(data.frame(id = 7, label = "Seven", stage = "s", lane = "l"))))
    doc_num2 <- studio_doc_apply(doc_num, resolve(doc_num, "option", list(name = "target", value = 7))$ops)
    expect_identical(doc_num2$args$target, "7")
    expect_match(resolve(doc, "option", list(name = "legend", value = "yes"))$refused, "TRUE or FALSE")
    expect_match(resolve(doc, "option", list(name = "cell_columns", value = 9))$refused, "1 to 6")
    expect_match(resolve(doc, "option", list(name = "cell_columns", value = "wide"))$refused, "1 to 6")
  })
})

describe("studio_resolve() for add, remove and move", {
  it("adds cards, stages and lanes with free ids and sets target to the new row", {
    doc <- studio_doc(map_parts(small))
    ch_card <- resolve(doc, "add", list(table = "cards"))
    expect_identical(ch_card$text, "Add card card")
    expect_identical(ch_card$target$kind, "card")
    doc2 <- studio_doc_apply(doc, ch_card$ops)
    new_card <- studio_row(doc2, "cards", ch_card$target$uid)
    expect_identical(new_card$label, "New card")
    expect_identical(new_card$stage, "write")
    expect_identical(new_card$lane, "docs")

    ch_stage <- resolve(doc2, "add", list(table = "stages"))
    expect_identical(ch_stage$text, "Add stage stage")
    doc3 <- studio_doc_apply(doc2, ch_stage$ops)
    expect_identical(studio_row(doc3, "stages", ch_stage$target$uid)$label, "New stage")

    ch_lane <- resolve(doc3, "add", list(table = "lanes"))
    expect_identical(ch_lane$text, "Add lane lane")
    doc4 <- studio_doc_apply(doc3, ch_lane$ops)
    expect_identical(studio_row(doc4, "lanes", ch_lane$target$uid)$label, "New lane")

    expect_match(resolve(doc, "add", list(table = "cards", stage = "missing"))$refused, "stage")
    expect_match(resolve(doc, "add", list(table = "cards", lane = "missing"))$refused, "lane")

    doc_blank_s <- studio_doc_apply(
      doc,
      list(list(op = "set", table = "stages", uid = studio_uid_of(doc, "stages", "write"), field = "id", value = ""))
    )
    expect_match(resolve(doc_blank_s, "add", list(table = "cards"))$refused, "Give the stage and lane")
    doc_no_s <- doc
    doc_no_s$tables$stages <- doc_no_s$tables$stages[0, , drop = FALSE]
    expect_match(resolve(doc_no_s, "add", list(table = "cards"))$refused, "Add a stage")
  })

  it("removes cards with their links, changes and target, and refuses non-empty stages/lanes or last rows", {
    doc <- studio_doc(map_parts(small))
    ch_rm <- resolve(doc, "remove", list(table = "cards", uid = "u2"))
    doc2 <- studio_doc_apply(doc, ch_rm$ops)
    expect_null(studio_row(doc2, "cards", "u2"))
    expect_identical(nrow(doc2$tables$links), 1L)
    expect_identical(nrow(doc2$tables$changes), 0L)
    expect_null(doc2$args$target)

    expect_match(
      resolve(doc, "remove", list(table = "stages", uid = studio_uid_of(doc, "stages", "write")))$refused,
      "Move its 1 card first\\."
    )
    expect_match(
      resolve(doc, "remove", list(table = "lanes", uid = studio_uid_of(doc, "lanes", "docs")))$refused,
      "Move its 2 cards first\\."
    )

    doc_na_s <- studio_doc_apply(
      doc,
      list(list(op = "set", table = "stages", uid = studio_uid_of(doc, "stages", "ship"), field = "id", value = ""))
    )
    expect_length(
      resolve(doc_na_s, "remove", list(table = "stages", uid = studio_uid_of(doc, "stages", "ship")))$ops,
      1L
    )

    one <- studio_doc(map_parts(studio_template("blank")$map))
    expect_match(resolve(one, "remove", list(table = "cards", uid = "u1"))$refused, "last card")
    expect_match(resolve(one, "remove", list(table = "stages", uid = "u2"))$refused, "last stage")
    expect_match(resolve(one, "remove", list(table = "lanes", uid = "u3"))$refused, "last lane")
    expect_match(resolve(one, "remove", list(table = "cards", uid = "u99"))$refused, "no longer")
  })

  it("moves stages and lanes and refuses at either end", {
    doc <- studio_doc(map_parts(small))
    uid_write <- studio_uid_of(doc, "stages", "write")
    uid_ship <- studio_uid_of(doc, "stages", "ship")
    expect_match(resolve(doc, "move", list(table = "stages", uid = uid_write, by = -1L))$refused, "already first")
    expect_match(resolve(doc, "move", list(table = "stages", uid = uid_ship, by = 1L))$refused, "already last")
    expect_match(resolve(doc, "move", list(table = "stages", uid = "missing", by = 1L))$refused, "no longer")
    ch <- resolve(doc, "move", list(table = "stages", uid = uid_write, by = 1L))
    expect_identical(ch$text, "Move stage write down")
    doc2 <- studio_doc_apply(doc, ch$ops)
    expect_identical(doc2$tables$stages$id, c("check", "write", "ship"))
  })
})

describe("studio_resolve() for link_add, link_reverse and fix", {
  it("adds and reverses links and refuses self-links and duplicates", {
    doc <- studio_doc(map_parts(small))
    expect_match(resolve(doc, "link_add", list(from = "u1", to = "u1", kind = NULL))$refused, "itself")
    expect_match(resolve(doc, "link_add", list(from = "u1", to = "u999", kind = NULL))$refused, "no longer")
    doc_b <- studio_doc_apply(doc, list(list(op = "set", table = "cards", uid = "u1", field = "id", value = "")))
    expect_match(resolve(doc_b, "link_add", list(from = "u1", to = "u2", kind = NULL))$refused, "Give both cards")
    expect_match(resolve(doc, "link_add", list(from = "u1", to = "u2", kind = "hand"))$refused, "already")
    expect_match(resolve(doc, "link_add", list(from = "u1", to = "u2", kind = "nope"))$refused, "No link kind")

    ch_add <- resolve(doc, "link_add", list(from = "u1", to = "u4", kind = NULL))
    expect_identical(ch_add$text, "Link a -> d")
    doc2 <- studio_doc_apply(doc, ch_add$ops)
    expect_identical(nrow(doc2$tables$links), 4L)

    lk_uid <- doc2$tables$links$.studio_uid[[4L]]
    ch_rev <- resolve(doc2, "link_reverse", list(uid = lk_uid))
    expect_identical(ch_rev$text, "Reverse link a -> d")
    expect_length(ch_rev$ops, 2L)
    doc3 <- studio_doc_apply(doc2, ch_rev$ops)
    expect_identical(studio_row(doc3, "links", lk_uid)$from, "d")
    expect_identical(studio_row(doc3, "links", lk_uid)$to, "a")
    expect_match(resolve(doc3, "link_reverse", list(uid = "missing"))$refused, "no longer")
  })

  it("applies fixes and refuses when the problem is gone", {
    tpl <- studio_template("example")
    doc <- studio_doc_apply(studio_doc(map_parts(tpl$map)), tpl$then)
    fault <- studio_faults(doc)[1L, , drop = FALSE]
    expect_match(resolve(doc, "fix", list(fault = fault$id, fix = "missing"))$refused, "That problem is gone\\.")
    ch <- resolve(doc, "fix", list(fault = fault$id, fix = "use"))
    expect_identical(ch$verb, "Fix")
    expect_identical(ch$text, "Use card \"calc_dose\"")
    doc2 <- studio_doc_apply(doc, ch$ops)
    expect_identical(nrow(studio_faults(doc2)), 0L)
    expect_match(resolve(doc2, "fix", list(fault = fault$id, fix = "use"))$refused, "That problem is gone\\.")
  })

  it("checks every payload assertion", {
    doc <- studio_doc(map_parts(small))
    expect_error(studio_resolve(doc, list(type = "unknown", data = list())), "type")
    expect_error(
      studio_resolve(doc, list(type = "edit", data = list(table = "", uid = "u1", field = "id", value = "x"))),
      "table"
    )
    expect_error(studio_resolve(doc, list(type = "option", data = list(name = "", value = "x"))), "name")
    expect_error(studio_resolve(doc, list(type = "add", data = list(table = "links"))), "table")
    expect_error(studio_resolve(doc, list(type = "remove", data = list(table = "zones", uid = "u1"))), "table")
    expect_error(studio_resolve(doc, list(type = "move", data = list(table = "stages", uid = "u1", by = 2L))), "by")
    expect_error(studio_resolve(doc, list(type = "link_add", data = list(from = "", to = "u2", kind = NULL))), "from")
    expect_error(studio_resolve(doc, list(type = "link_reverse", data = list(uid = ""))), "uid")
    expect_error(studio_resolve(doc, list(type = "fix", data = list(fault = "", fix = "use"))), "fault")
  })
})
