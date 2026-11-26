# Studio documents: row keys, table extraction, and the five primitive operations.

delayedAssign("small", full_map(title = "A map"))

describe("studio_doc()", {
  it("adds .studio_uid in table order, converts id columns to text and stages$date to Date", {
    map <- stage_map(
      data.frame(id = c(1, 2), label = c("One", "Two"), stage = c(10, 20), lane = c("l1", "l1"), extra = c("x", "y")),
      data.frame(id = c(10, 20), label = c("S1", "S2"), date = c("2026-03-01", "2026-03-02")),
      data.frame(id = "l1", label = "L1")
    )
    doc <- studio_doc(map_parts(map))
    expect_identical(names(doc$tables), c("cards", "stages", "lanes"))
    expect_identical(doc$tables$cards$.studio_uid, c("u1", "u2"))
    expect_identical(doc$tables$stages$.studio_uid, c("u3", "u4"))
    expect_identical(doc$tables$lanes$.studio_uid, "u5")
    expect_identical(doc$next_uid, 6L)
    expect_identical(doc$tables$cards$id, c("1", "2"))
    expect_identical(doc$tables$cards$stage, c("10", "20"))
    expect_s3_class(doc$tables$stages$date, "Date")
    expect_identical(doc$tables$cards$extra, c("x", "y"))
  })

  it("refuses a table that already has a .studio_uid column", {
    parts <- map_parts(small)
    parts$tables$cards$.studio_uid <- paste0("x", seq_len(nrow(parts$tables$cards)))
    expect_error(studio_doc(parts), ".studio_uid", class = "stagemap_error_studio")
  })

  it("checks its arguments", {
    expect_error(studio_doc("parts"), "parts")
    expect_error(studio_doc(list(tables = list())), "must.include|names")
    expect_error(studio_doc(list(tables = list(unknown = data.frame()), args = list())), "subset")
  })
})

describe("studio_doc_tables() and studio_doc_parts()", {
  it("strip .studio_uid and keep extra columns and arguments", {
    doc <- studio_doc(map_parts(small))
    tables <- studio_doc_tables(doc)
    expect_false(any(vapply(tables, function(t) ".studio_uid" %in% names(t), logical(1))))
    expect_identical(tables$cards$owner, c("Ann", "Bo", "Cy", "Di"))
    expect_identical(studio_doc_parts(doc), list(tables = tables, args = doc$args))
  })
})

describe("studio_row(), studio_uid_of() and studio_free_id()", {
  it("look up rows by uid or id and allocate the next free id", {
    doc <- studio_doc(map_parts(small))
    expect_identical(studio_row(doc, "cards", "u1")$id, "a")
    expect_null(studio_row(doc, "cards", "missing"))
    expect_null(studio_row(doc, "steps", "u999"))
    expect_identical(studio_uid_of(doc, "cards", "b"), "u2")
    expect_null(studio_uid_of(doc, "cards", "missing"))
    expect_null(studio_uid_of(doc, "links", "a"))

    expect_identical(studio_free_id(doc, "cards"), "card")
    doc <- studio_doc_apply(
      doc,
      list(
        list(
          op = "insert",
          table = "cards",
          row = list(id = "card", label = "C", stage = "write", lane = "docs"),
          after = NULL
        ),
        list(
          op = "insert",
          table = "cards",
          row = list(id = "card-2", label = "C2", stage = "write", lane = "docs"),
          after = NULL
        )
      )
    )
    expect_identical(studio_free_id(doc, "cards"), "card-3")
  })

  it("check their arguments", {
    doc <- studio_doc(map_parts(small))
    expect_error(studio_row(doc, "", "u1"), "table")
    expect_error(studio_row(doc, "cards", ""), "uid")
    expect_error(studio_uid_of(doc, "", "a"), "table")
    expect_error(studio_uid_of(doc, "cards", ""), "id")
    expect_error(studio_free_id(doc, "links"), "table")
  })
})

describe("studio_doc_apply()", {
  it("applies set, turning factors to text, coercing by contract type and adding missing columns", {
    map <- stage_map(
      data.frame(
        id = c("a", "b"),
        label = c("A", "B"),
        stage = factor(c("s1", "s1")),
        lane = c("l1", "l1"),
        note = factor(c("first", "second")),
        score = c(10, 20)
      ),
      data.frame(id = "s1", label = "S1"),
      data.frame(id = "l1", label = "L1")
    )
    doc <- studio_doc(map_parts(map))
    doc <- studio_doc_apply(
      doc,
      list(
        list(op = "set", table = "cards", uid = "u1", field = "note", value = "updated"),
        list(op = "set", table = "cards", uid = "u1", field = "tone", value = "good"),
        list(op = "set", table = "cards", uid = "u1", field = "milestone", value = TRUE),
        list(op = "set", table = "cards", uid = "u1", field = "score", value = "text"),
        list(op = "set", table = "cards", uid = "u2", field = "tone", value = ""),
        list(op = "set", table = "stages", uid = "u3", field = "date", value = "2026-03-10"),
        list(op = "set", table = "stages", uid = "u3", field = "date", value = NULL)
      )
    )
    expect_type(doc$tables$cards$note, "character")
    expect_identical(doc$tables$cards$note[[1L]], "updated")
    expect_identical(doc$tables$cards$tone, c("good", NA_character_))
    expect_identical(doc$tables$cards$milestone, c(TRUE, NA))
    expect_identical(doc$tables$cards$score, c("text", "20"))
    expect_s3_class(doc$tables$stages$date, "Date")
    expect_true(is.na(doc$tables$stages$date[[1L]]))

    doc <- studio_doc_apply(
      doc,
      list(
        list(op = "set", table = "stages", uid = "u3", field = "date", value = as.Date("2026-04-01"))
      )
    )
    expect_identical(doc$tables$stages$date[[1L]], as.Date("2026-04-01"))

    tbl_raw <- data.frame(id = "s1", date = "2026-01-01", stringsAsFactors = FALSE)
    tbl_set <- studio_set_cell(tbl_raw, "stages", 1L, "date", "2026-01-02")
    expect_s3_class(tbl_set$date, "Date")
    expect_null(studio_field_spec("unknown", "x"))
    expect_identical(studio_coerce_cell("statuses", "icon", "lock"), "lock")
    expect_identical(studio_coerce_cell("options", "hosted", "details"), "details")
    expect_error(studio_coerce_cell("cards", "label", list()), class = "stagemap_error_studio")
  })

  it("applies insert after a key or at the end, and creates missing tables", {
    map <- stage_map(
      data.frame(
        id = "a",
        label = "A",
        stage = "s1",
        lane = "l1",
        note = factor("first"),
        tag = factor("t1"),
        score = 1,
        stringsAsFactors = FALSE
      ),
      data.frame(id = "s1", label = "S1", date = as.Date(NA_character_)),
      data.frame(id = "l1", label = "L1")
    )
    doc <- studio_doc(map_parts(map))
    doc <- studio_doc_apply(
      doc,
      list(
        list(
          op = "insert",
          table = "cards",
          row = list(id = "b", label = "B", stage = "s1", lane = "l1", tag = "t2"),
          after = NULL
        ),
        list(
          op = "insert",
          table = "cards",
          row = list(id = "mid", label = "Mid", stage = "s1", lane = "l1", tone = "teal", note = "second", score = "x"),
          after = "u1"
        ),
        list(op = "insert", table = "links", row = list(from = "a", to = "b"), after = NULL),
        list(op = "insert", table = "stages", row = list(id = "s2", label = "S2", date = "2026-05-01"), after = NULL),
        list(op = "delete", table = "links", uid = "u6"),
        list(op = "insert", table = "links", row = list(from = "a", to = "mid"), after = NULL)
      )
    )
    expect_identical(doc$tables$cards$id, c("a", "mid", "b"))
    expect_identical(doc$tables$cards$tone, c(NA_character_, "teal", NA_character_))
    expect_identical(doc$tables$cards$.studio_uid, c("u1", "u5", "u4"))
    expect_identical(doc$tables$links$from, "a")
    expect_identical(doc$tables$stages$date, as.Date(c(NA, "2026-05-01")))
    expect_type(doc$tables$cards$note, "character")

    doc$tables$stages$date <- as.character(doc$tables$stages$date)
    doc_d <- studio_doc_apply(
      doc,
      list(list(
        op = "insert",
        table = "stages",
        row = list(id = "s3", label = "S3", date = "2026-06-01"),
        after = NULL
      ))
    )
    expect_s3_class(doc_d$tables$stages$date, "Date")
  })

  it("preserves non-syntactic column names like 'owner name' when inserting rows", {
    cards <- data.frame(id = "a", label = "A", stage = "s", lane = "l", check.names = FALSE, stringsAsFactors = FALSE)
    cards[["owner name"]] <- "Ana"
    map <- stage_map(cards, data.frame(id = "s", label = "S"), data.frame(id = "l", label = "L"))
    doc <- studio_doc(map_parts(map))
    doc2 <- studio_doc_apply(
      doc,
      list(
        list(op = "insert", table = "cards", row = list(id = "b", label = "B", stage = "s", lane = "l"), after = NULL),
        list(op = "insert", table = "links", row = list(from = "a", to = "b", "link note" = "n1"), after = NULL)
      )
    )
    expect_true("owner name" %in% names(doc2$tables$cards))
    expect_identical(doc2$tables$cards[["owner name"]], c("Ana", NA_character_))
    expect_true("link note" %in% names(doc2$tables$links))
    expect_identical(doc2$tables$links[["link note"]], "n1")
  })

  it("applies delete, move and arg", {
    doc <- studio_doc(map_parts(small))
    doc <- studio_doc_apply(
      doc,
      list(
        list(op = "move", table = "stages", uid = "u5", by = 1L),
        list(op = "delete", table = "links", uid = "u10"),
        list(op = "arg", name = "title", value = "New title"),
        list(op = "arg", name = "target", value = NULL)
      )
    )
    expect_identical(doc$tables$stages$id, c("check", "write", "ship"))
    expect_identical(nrow(doc$tables$links), 2L)
    expect_identical(doc$args$title, "New title")
    expect_true("target" %in% names(doc$args))
    expect_null(doc$args$target)
  })

  it("refuses operations on missing rows/tables, past-end moves, bad types, or .studio_uid", {
    doc <- studio_doc(map_parts(small))
    expect_error(
      studio_doc_apply(doc, list(list(op = "set", table = "cards", uid = "u999", field = "label", value = "X"))),
      class = "stagemap_error_studio"
    )
    expect_error(
      studio_doc_apply(doc, list(list(op = "set", table = "cards", uid = "u1", field = ".studio_uid", value = "u9"))),
      class = "stagemap_error_studio"
    )
    expect_error(
      studio_doc_apply(doc, list(list(op = "set", table = "cards", uid = "u1", field = "tone", value = "neon"))),
      class = "stagemap_error_studio"
    )
    expect_error(
      studio_doc_apply(doc, list(list(op = "set", table = "cards", uid = "u1", field = "milestone", value = "yes"))),
      class = "stagemap_error_studio"
    )
    expect_error(
      studio_doc_apply(doc, list(list(op = "set", table = "stages", uid = "u5", field = "date", value = "bad-date"))),
      class = "stagemap_error_studio"
    )
    expect_error(
      studio_doc_apply(doc, list(list(op = "set", table = "stages", uid = "u5", field = "date", value = "2026-02-30"))),
      class = "stagemap_error_studio"
    )
    expect_error(
      studio_doc_apply(doc, list(list(op = "delete", table = "cards", uid = "u999"))),
      class = "stagemap_error_studio"
    )
    expect_error(
      studio_doc_apply(doc, list(list(op = "insert", table = "cards", row = list(id = "x"), after = "u999"))),
      class = "stagemap_error_studio"
    )
    expect_error(
      studio_doc_apply(
        doc,
        list(list(op = "insert", table = "steps", row = list(id = "x", label = "X"), after = "u1"))
      ),
      class = "stagemap_error_studio"
    )
    expect_error(
      studio_doc_apply(doc, list(list(op = "move", table = "stages", uid = "u5", by = -1L))),
      class = "stagemap_error_studio"
    )
    expect_error(
      studio_doc_apply(doc, list(list(op = "move", table = "stages", uid = "u999", by = 1L))),
      class = "stagemap_error_studio"
    )
    expect_error(
      studio_doc_apply(doc, list(list(op = "set", table = "none", uid = "u1", field = "label", value = "X"))),
      class = "stagemap_error_studio"
    )
    expect_error(
      studio_doc_apply(doc, list(list(op = "delete", table = "none", uid = "u1"))),
      class = "stagemap_error_studio"
    )
    expect_error(
      studio_doc_apply(doc, list(list(op = "move", table = "none", uid = "u1", by = 1L))),
      class = "stagemap_error_studio"
    )
    expect_error(
      studio_doc_apply(doc, list(list(op = "arg", name = "not_an_arg", value = "x"))),
      "name"
    )
  })
})
