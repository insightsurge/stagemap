# Checking, building, locating faults and offering fixes.

delayedAssign(
  "small",
  full_map(title = "A map") |>
    add_steps(data.frame(id = "s1", label = "Step 1", stage = "write")) |>
    add_variants(data.frame(id = "v1", label = "V1"))
)

describe("studio_try()", {
  it("captures converter, cross-table and checkmate errors and muffles warnings", {
    ok <- studio_try({
      warning("be careful")
      42L
    })
    expect_true(ok$ok)
    expect_identical(ok$value, 42L)
    expect_null(ok$error)
    expect_identical(ok$warnings, "be careful")

    conv <- studio_try(stage_map(data.frame(id = "", label = "A", stage = "s", lane = "l")))
    expect_false(conv$ok)
    expect_true(length(conv$error$lines) >= 1L)
    expect_identical(conv$error$lines[[1L]]$mark, "x")

    cross <- studio_try(stage_map(data.frame(id = c("a", "a"), label = c("A", "B"), stage = "s", lane = "l")))
    expect_false(cross$ok)
    expect_true(any(vapply(cross$error$lines, function(l) identical(l$mark, "x"), logical(1))))
    expect_true(any(vapply(cross$error$lines, function(l) identical(l$mark, "i"), logical(1))))

    cm <- studio_try(stage_map("not a data frame"))
    expect_false(cm$ok)
    expect_length(cm$error$lines, 0L)
    expect_match(cm$error$head, "data\\.frame")

    unnamed <- studio_try(cli::cli_abort(c("Head", "detail line")))
    expect_false(unnamed$ok)
    expect_identical(unnamed$error$lines, list(list(mark = "x", text = "detail line")))
  })
})

describe("studio_build() with statuses table and highlight", {
  it("builds a document that has custom statuses and stage_map_highlight()", {
    map <- stage_map(
      data.frame(id = c("a", "b"), label = c("A", "B"), stage = "s", lane = "l", status = "blocked"),
      data.frame(id = "s", label = "S"),
      data.frame(id = "l", label = "L"),
      statuses = data.frame(id = "blocked", label = "Blocked", tone = "bad")
    ) |>
      stage_map_highlight("a")
    doc <- studio_doc(map_parts(map))
    built <- studio_build(doc)
    expect_true(built$ok)
    expect_identical(stage_map_tables(built$value)$statuses$id, "blocked")
    expect_identical(map_parts(built$value)$args$highlight$ids, "a")
  })

  it("handles zero-row optional tables and absent non-kind target tables in studio_faults()", {
    doc <- studio_doc(map_parts(small))
    doc <- studio_doc_apply(
      doc,
      list(
        list(op = "delete", table = "links", uid = doc$tables$links$.studio_uid[[1L]]),
        list(op = "delete", table = "links", uid = doc$tables$links$.studio_uid[[2L]]),
        list(op = "delete", table = "links", uid = doc$tables$links$.studio_uid[[3L]]),
        list(op = "delete", table = "kinds", uid = doc$tables$kinds$.studio_uid[[1L]])
      )
    )
    expect_identical(nrow(studio_faults(doc)), 0L)

    map_no_zones <- stage_map(data.frame(id = "a", label = "A", stage = "s", lane = "l", zone = "z1"))
    expect_identical(nrow(studio_faults(studio_doc(map_parts(map_no_zones)))), 0L)
  })

  it("locates the exact uid, value and fault set when non-first rows are broken", {
    map <- full_map(title = "A map") |>
      add_variants(data.frame(id = c("v1", "v2"), label = c("V1", "V2")))
    base <- studio_doc(map_parts(map))
    base <- studio_doc_apply(
      base,
      list(list(op = "set", table = "cards", uid = "u3", field = "variants", value = "v1, v2"))
    )

    cases <- list(
      list(
        name = "card 3 blank id",
        ops = list(list(op = "set", table = "cards", uid = "u3", field = "id", value = "")),
        expected_ids = c("cards:u3:id:blank", "links:u12:from:join", "links:u11:to:join"),
        target_id = "cards:u3:id:blank",
        target_uid = "u3",
        target_value = NA_character_
      ),
      list(
        name = "stage 2 blank label",
        ops = list(list(op = "set", table = "stages", uid = "u6", field = "label", value = "")),
        expected_ids = "stages:u6:label:blank",
        target_id = "stages:u6:label:blank",
        target_uid = "u6",
        target_value = NA_character_
      ),
      list(
        name = "lane 2 duplicate id",
        ops = list(list(op = "set", table = "lanes", uid = "u9", field = "id", value = "docs")),
        expected_ids = c("lanes:u8:id:duplicate", "lanes:u9:id:duplicate", "cards:u3:lane:join", "cards:u4:lane:join"),
        target_id = "lanes:u9:id:duplicate",
        target_uid = "u9",
        target_value = "docs"
      ),
      list(
        name = "link 2 bad to",
        ops = list(list(op = "set", table = "links", uid = "u11", field = "to", value = "zz")),
        expected_ids = "links:u11:to:join",
        target_id = "links:u11:to:join",
        target_uid = "u11",
        target_value = "zz"
      ),
      list(
        name = "card 3 split variants join",
        ops = list(list(op = "set", table = "cards", uid = "u3", field = "variants", value = "v1, v_bad")),
        expected_ids = "cards:u3:variants:join",
        target_id = "cards:u3:variants:join",
        target_uid = "u3",
        target_value = "v_bad"
      )
    )

    for (case in cases) {
      doc <- studio_doc_apply(base, case$ops)
      faults <- studio_faults(doc)
      expect_setequal(faults$id, case$expected_ids)
      expect_identical(nrow(faults), length(case$expected_ids), info = case$name)
      hit <- faults[faults$id == case$target_id, , drop = FALSE]
      expect_identical(hit$uid, case$target_uid, info = case$name)
      expect_identical(hit$value, case$target_value, info = case$name)
    }
  })
})

describe("studio_faults() and studio_fixes()", {
  it("agrees with studio_build() across blank, duplicate and join faults in every table", {
    base <- studio_doc(map_parts(small))
    expect_true(studio_build(base)$ok)
    expect_identical(nrow(studio_faults(base)), 0L)

    # Builds one broken doc by applying `ops`, expecting build to fail and faults to contain `expect_type`
    broken_cases <- list(
      list(
        table = "cards",
        field = "id",
        type = "blank",
        ops = list(list(op = "set", table = "cards", uid = "u1", field = "id", value = ""))
      ),
      list(
        table = "cards",
        field = "label",
        type = "blank",
        ops = list(list(op = "set", table = "cards", uid = "u1", field = "label", value = ""))
      ),
      list(
        table = "stages",
        field = "id",
        type = "blank",
        ops = list(list(op = "set", table = "stages", uid = "u5", field = "id", value = ""))
      ),
      list(
        table = "stages",
        field = "label",
        type = "blank",
        ops = list(list(op = "set", table = "stages", uid = "u5", field = "label", value = ""))
      ),
      list(
        table = "lanes",
        field = "id",
        type = "blank",
        ops = list(list(op = "set", table = "lanes", uid = "u8", field = "id", value = ""))
      ),
      list(
        table = "lanes",
        field = "label",
        type = "blank",
        ops = list(list(op = "set", table = "lanes", uid = "u8", field = "label", value = ""))
      ),
      list(
        table = "kinds",
        field = "id",
        type = "blank",
        ops = list(list(op = "set", table = "kinds", uid = "u13", field = "id", value = ""))
      ),
      list(
        table = "kinds",
        field = "label",
        type = "blank",
        ops = list(list(op = "set", table = "kinds", uid = "u13", field = "label", value = ""))
      ),
      list(
        table = "zones",
        field = "id",
        type = "blank",
        ops = list(list(op = "set", table = "zones", uid = "u14", field = "id", value = ""))
      ),
      list(
        table = "zones",
        field = "label",
        type = "blank",
        ops = list(list(op = "set", table = "zones", uid = "u14", field = "label", value = ""))
      ),
      list(
        table = "steps",
        field = "id",
        type = "blank",
        ops = list(list(op = "set", table = "steps", uid = "u15", field = "id", value = ""))
      ),
      list(
        table = "steps",
        field = "label",
        type = "blank",
        ops = list(list(op = "set", table = "steps", uid = "u15", field = "label", value = ""))
      ),
      list(
        table = "variants",
        field = "id",
        type = "blank",
        ops = list(list(op = "set", table = "variants", uid = "u16", field = "id", value = ""))
      ),
      list(
        table = "variants",
        field = "label",
        type = "blank",
        ops = list(list(op = "set", table = "variants", uid = "u16", field = "label", value = ""))
      ),

      list(
        table = "cards",
        field = "id",
        type = "duplicate",
        ops = list(list(op = "set", table = "cards", uid = "u1", field = "id", value = "b"))
      ),
      list(
        table = "stages",
        field = "id",
        type = "duplicate",
        ops = list(list(op = "set", table = "stages", uid = "u5", field = "id", value = "check"))
      ),
      list(
        table = "lanes",
        field = "id",
        type = "duplicate",
        ops = list(list(op = "set", table = "lanes", uid = "u8", field = "id", value = "code"))
      ),
      list(
        table = "kinds",
        field = "id",
        type = "duplicate",
        ops = list(list(op = "insert", table = "kinds", row = list(id = "hand", label = "H2"), after = NULL))
      ),
      list(
        table = "zones",
        field = "id",
        type = "duplicate",
        ops = list(list(op = "insert", table = "zones", row = list(id = "sign", label = "S2"), after = NULL))
      ),
      list(
        table = "steps",
        field = "id",
        type = "duplicate",
        ops = list(list(op = "insert", table = "steps", row = list(id = "s1", label = "Step 2"), after = NULL))
      ),
      list(
        table = "variants",
        field = "id",
        type = "duplicate",
        ops = list(list(op = "insert", table = "variants", row = list(id = "v1", label = "V2"), after = NULL))
      ),

      list(
        table = "cards",
        field = "stage",
        type = "join",
        ops = list(list(op = "set", table = "cards", uid = "u1", field = "stage", value = "wrte"))
      ),
      list(
        table = "cards",
        field = "lane",
        type = "join",
        ops = list(list(op = "set", table = "cards", uid = "u1", field = "lane", value = "docz"))
      ),
      list(
        table = "cards",
        field = "zone",
        type = "join",
        ops = list(list(op = "set", table = "cards", uid = "u1", field = "zone", value = "sgn"))
      ),
      list(
        table = "cards",
        field = "variants",
        type = "join",
        ops = list(list(op = "set", table = "cards", uid = "u1", field = "variants", value = "v2"))
      ),
      list(
        table = "links",
        field = "from",
        type = "join",
        ops = list(list(op = "set", table = "links", uid = "u10", field = "from", value = "missing"))
      ),
      list(
        table = "links",
        field = "to",
        type = "join",
        ops = list(list(op = "set", table = "links", uid = "u10", field = "to", value = "bb"))
      ),
      list(
        table = "links",
        field = "kind",
        type = "join",
        ops = list(list(op = "set", table = "links", uid = "u10", field = "kind", value = "hnd"))
      ),
      list(
        table = "links",
        field = "step",
        type = "join",
        ops = list(list(op = "set", table = "links", uid = "u10", field = "step", value = "s2"))
      ),
      list(
        table = "links",
        field = "variants",
        type = "join",
        ops = list(list(op = "set", table = "links", uid = "u10", field = "variants", value = "v2"))
      ),
      list(
        table = "steps",
        field = "stage",
        type = "join",
        ops = list(list(op = "set", table = "steps", uid = "u15", field = "stage", value = "wrte"))
      )
    )

    for (case in broken_cases) {
      doc <- studio_doc_apply(base, case$ops)
      built <- studio_build(doc)
      faults <- studio_faults(doc)
      expect_false(built$ok, info = paste(case$table, case$field, case$type))
      hit <- faults[faults$table == case$table & faults$field == case$field & faults$type == case$type, , drop = FALSE]
      expect_gte(nrow(hit), 1L, label = paste(case$table, case$field, case$type))
      if (case$type %in% c("duplicate", "join")) {
        full_err <- paste(c(built$error$head, vapply(built$error$lines, function(l) l$text, "")), collapse = "\n")
        for (val in unique(hit$value)) {
          expect_true(grepl(val, full_err, fixed = TRUE), info = paste(case$table, case$field, val))
        }
      }
      fixes <- studio_fixes(doc, hit[1L, , drop = FALSE])
      for (fix_name in names(fixes)) {
        fixed <- studio_doc_apply(doc, fixes[[fix_name]]$ops)
        after <- studio_faults(fixed)
        expect_false(hit$id[[1L]] %in% after$id, info = paste(case$table, case$field, case$type, fix_name))
      }
    }
  })

  it("catches a link with a kind when the document has no kinds table", {
    map <- stage_map(data.frame(id = c("a", "b"), label = c("A", "B"), stage = "s", lane = "l"))
    doc <- studio_doc(map_parts(map))
    doc <- studio_doc_apply(
      doc,
      list(
        list(op = "insert", table = "links", row = list(from = "a", to = "b", kind = "hand"), after = NULL)
      )
    )
    expect_false(studio_build(doc)$ok)
    faults <- studio_faults(doc)
    expect_identical(nrow(faults), 1L)
    expect_identical(faults$to, "kinds")
    expect_named(studio_fixes(doc, faults), "remove")
  })

  it("offers add for missing stage/lane and drops use when distance exceeds 2", {
    doc <- studio_doc(map_parts(small))
    doc <- studio_doc_apply(
      doc,
      list(list(op = "set", table = "cards", uid = "u1", field = "stage", value = "faraway"))
    )
    fault <- studio_faults(doc)[1L, , drop = FALSE]
    fixes <- studio_fixes(doc, fault)
    expect_named(fixes, "add")
    fixed <- studio_doc_apply(doc, fixes$add$ops)
    expect_identical(nrow(studio_faults(fixed)), 0L)
  })

  it("catches broken changes rows and dangling args target, variant and highlight references", {
    map <- full_map(title = "A map", target = "b", variant = "v1") |>
      add_steps(
        data.frame(id = "s1", label = "Step 1", stage = "write"),
        changes = data.frame(step = "s1", card = "b", stage = "ship", status = "done")
      ) |>
      add_variants(data.frame(id = c("v1", "v2"), label = c("V1", "V2"))) |>
      stage_map_highlight(c("a", "b", "c"), links = data.frame(from = "a", to = "b"))
    base <- studio_doc(map_parts(map))

    cases <- list(
      list(
        table = "changes",
        field = "card",
        ops = list(list(
          op = "set",
          table = "changes",
          uid = base$tables$changes$.studio_uid[[1L]],
          field = "card",
          value = "bb"
        )),
        expected_fixes = c("use", "remove")
      ),
      list(
        table = "changes",
        field = "stage",
        ops = list(list(
          op = "set",
          table = "changes",
          uid = base$tables$changes$.studio_uid[[1L]],
          field = "stage",
          value = "shp"
        )),
        expected_fixes = c("use", "add", "remove")
      ),
      list(
        table = "changes",
        field = "step",
        ops = list(list(
          op = "set",
          table = "changes",
          uid = base$tables$changes$.studio_uid[[1L]],
          field = "step",
          value = "s2"
        )),
        expected_fixes = c("use", "remove")
      ),
      list(
        table = "args",
        field = "target",
        ops = list(list(op = "arg", name = "target", value = "bb")),
        expected_fixes = c("use", "clear")
      ),
      list(
        table = "args",
        field = "variant",
        ops = list(list(op = "arg", name = "variant", value = "v3")),
        expected_fixes = c("use", "clear")
      ),
      list(
        table = "args",
        field = "ids",
        ops = list(list(
          op = "arg",
          name = "highlight",
          value = list(ids = c("a", "bb"), links = data.frame(from = "a", to = "bb"))
        )),
        expected_fixes = c("use", "clear")
      ),
      list(
        table = "args",
        field = "ids",
        ops = list(list(op = "arg", name = "highlight", value = list(ids = "bb", links = NULL))),
        expected_fixes = c("use", "clear")
      ),
      list(
        table = "args",
        field = "ids",
        ops = list(list(op = "arg", name = "highlight", value = list(ids = c("a", "bb"), links = NULL))),
        expected_fixes = c("use", "clear")
      ),
      list(
        table = "args",
        field = "links",
        ops = list(list(
          op = "arg",
          name = "highlight",
          value = list(ids = c("a", "b"), links = data.frame(from = "a", to = "bb"))
        )),
        expected_fixes = c("use", "clear")
      ),
      list(
        table = "args",
        field = "links",
        ops = list(list(
          op = "arg",
          name = "highlight",
          value = list(ids = c("a", "b"), links = data.frame(from = c("a", "a"), to = c("b", "faraway")))
        )),
        expected_fixes = "clear"
      )
    )

    for (case in cases) {
      doc <- studio_doc_apply(base, case$ops)
      expect_false(studio_build(doc)$ok, info = paste(case$table, case$field))
      faults <- studio_faults(doc)
      hit <- faults[faults$table == case$table & faults$field == case$field, , drop = FALSE]
      expect_identical(nrow(hit), 1L, info = paste(case$table, case$field))
      fixes <- studio_fixes(doc, hit)
      expect_setequal(names(fixes), case$expected_fixes)
      for (fix_name in names(fixes)) {
        fixed <- studio_doc_apply(doc, fixes[[fix_name]]$ops)
        expect_identical(nrow(studio_faults(fixed)), 0L, info = paste(case$table, case$field, fix_name))
        expect_true(studio_build(fixed)$ok, info = paste(case$table, case$field, fix_name))
      }
    }
  })

  it("checks its arguments", {
    expect_error(studio_build("doc"), "doc")
    expect_error(studio_faults("doc"), "doc")
    doc <- studio_doc(map_parts(small))
    expect_error(studio_fixes(doc, "fault"), "fault")
  })
})
