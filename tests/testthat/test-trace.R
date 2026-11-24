# Shared synthetic requirements, tests and results, with one isolated requirement.
trace_map <- function() {
  stage_map(
    cards = data.frame(
      id = c("R1", "R2", "T1", "T2", "X1", "R3"),
      label = c("First requirement", "Second requirement", "First test", "Second test", "Result", "Isolated"),
      stage = c("Requirement", "Requirement", "Test", "Test", "Result", "Requirement"),
      lane = c("L1", "L2", "L1", "L2", "L1", "L2"),
      extra = seq_len(6L)
    )
  ) |>
    add_links(
      data.frame(
        from = c("R1", "R2", "T1", "T2"),
        to = c("T1", "T2", "X1", "X1"),
        kind = c("verifies", "verifies", "produces", "produces")
      ),
      kinds = data.frame(
        id = c("verifies", "produces"),
        label = c("Verifies", "Produces")
      )
    )
}

describe("sm_trace()", {
  it("follows downstream and upstream walks and orders rows by distance then card order", {
    map <- trace_map()
    down <- sm_trace(map, "R1")
    expect_identical(down$id, c("R1", "T1", "X1"))
    expect_identical(down$label, c("First requirement", "First test", "Result"))
    expect_identical(down$stage, c("Requirement", "Test", "Result"))
    expect_identical(down$lane, c("L1", "L1", "L1"))
    expect_identical(down$direction, c("start", "downstream", "downstream"))
    expect_identical(down$distance, 0:2)
    expect_identical(down$through, c(NA_character_, "R1", "T1"))
    expect_identical(down$kind, c(NA_character_, "verifies", "produces"))
    expect_identical(sm_trace(map, "R1", direction = "downstream"), down)
    expect_identical(sm_trace(map, "R1", direction = c("downstream", "upstream", "both")), down)

    up <- sm_trace(map, "X1", direction = "upstream")
    expect_identical(up$id, c("X1", "T1", "T2", "R1", "R2"))
    expect_identical(up$direction, c("start", "upstream", "upstream", "upstream", "upstream"))
    expect_identical(up$distance, c(0L, 1L, 1L, 2L, 2L))
    expect_identical(up$through, c(NA_character_, "X1", "X1", "T1", "T2"))
    expect_identical(up$kind, c(NA_character_, "produces", "produces", "verifies", "verifies"))
    expect_identical(
      names(up),
      c("id", "label", "stage", "lane", "direction", "distance", "through", "kind")
    )
    expect_identical(class(up), "data.frame")
    expect_identical(rownames(up), as.character(seq_len(5L)))
  })

  it("runs upstream and downstream walks apart for direction = 'both' without zigzagging", {
    map <- trace_map()
    both <- sm_trace(map, "T1", direction = "both")
    expect_identical(both$id, c("T1", "R1", "X1"))
    expect_identical(both$direction, c("start", "upstream", "downstream"))
    expect_identical(both$distance, c(0L, 1L, 1L))
    expect_identical(both$through, c(NA_character_, "T1", "T1"))
    expect_identical(both$kind, c(NA_character_, "verifies", "produces"))
  })

  it("handles several start ids, keeping card order at distance 0 and preferring start over link distance", {
    map <- trace_map()
    multi <- sm_trace(map, c("X1", "R1"))
    expect_identical(multi$id, c("R1", "X1", "T1"))
    expect_identical(multi$direction, c("start", "start", "downstream"))
    expect_identical(multi$distance, c(0L, 0L, 1L))
    expect_identical(multi$through, c(NA_character_, NA_character_, "R1"))
    expect_identical(sm_trace(map, c("R1", "R1")), sm_trace(map, "R1"))

    # A card between two start cards gets both walks: tie on distance favours downstream.
    between <- sm_trace(map, c("R1", "X1"), direction = "both")
    expect_identical(between$id, c("R1", "X1", "T1", "T2", "R2"))
    expect_identical(between$direction, c("start", "start", "both", "upstream", "upstream"))
    expect_identical(between$distance, c(0L, 0L, 1L, 1L, 2L))
    expect_identical(between$through, c(NA_character_, NA_character_, "R1", "X1", "T2"))
    expect_identical(between$kind, c(NA_character_, NA_character_, "verifies", "produces", "verifies"))

    # Asymmetric distance between two start cards picks the shorter walk for through and kind.
    chain <- stage_map(
      cards = data.frame(
        id = c("S1", "M1", "M2", "S2"),
        label = c("S1", "M1", "M2", "S2"),
        stage = "S",
        lane = "L"
      )
    ) |>
      add_links(
        data.frame(
          from = c("S1", "M1", "M2"),
          to = c("M1", "M2", "S2"),
          kind = c("k1", "k2", "k3")
        ),
        kinds = data.frame(id = c("k1", "k2", "k3"), label = c("K1", "K2", "K3"))
      )
    asym <- sm_trace(chain, c("S1", "S2"), direction = "both")
    expect_identical(asym$id, c("S1", "S2", "M1", "M2"))
    expect_identical(asym$direction, c("start", "start", "both", "both"))
    expect_identical(asym$distance, c(0L, 0L, 1L, 1L))
    expect_identical(asym$through, c(NA_character_, NA_character_, "S1", "S2"))
    expect_identical(asym$kind, c(NA_character_, NA_character_, "k1", "k3"))
  })

  it("handles loops in single-direction and both-direction walks", {
    loop <- stage_map(
      cards = data.frame(
        id = c("A", "B", "C"),
        label = c("A", "B", "C"),
        stage = c("S1", "S2", "S3"),
        lane = "L"
      )
    ) |>
      add_links(
        data.frame(
          from = c("A", "B", "C"),
          to = c("B", "C", "A"),
          kind = c("ab", "bc", "ca")
        ),
        kinds = data.frame(id = c("ab", "bc", "ca"), label = c("AB", "BC", "CA"))
      )
    expect_identical(sm_trace(loop, "A", max_distance = 1)$id, c("A", "B"))
    expect_identical(sm_trace(loop, "A")$id, c("A", "B", "C"))
    expect_identical(sm_trace(loop, "A")$direction, c("start", "downstream", "downstream"))
    expect_identical(sm_trace(loop, "A")$distance, 0:2)

    both <- sm_trace(loop, "A", direction = "both")
    expect_identical(both$id, c("A", "B", "C"))
    expect_identical(both$direction, c("start", "both", "both"))
    expect_identical(both$distance, c(0L, 1L, 1L))
    expect_identical(both$through, c(NA_character_, "A", "A"))
    expect_identical(both$kind, c(NA_character_, "ab", "ca"))

    # Max distance 1 stops each walk before it reaches the other card.
    near <- sm_trace(loop, "A", direction = "both", max_distance = 1)
    expect_identical(near$direction, c("start", "downstream", "upstream"))

    # Two-node loop and side branch.
    two_loop <- stage_map(
      cards = data.frame(id = c("A", "B", "C"), label = c("A", "B", "C"), stage = "S", lane = "L")
    ) |>
      add_links(data.frame(from = c("A", "B", "C"), to = c("B", "A", "B")))
    expect_identical(sm_trace(two_loop, "A")$id, c("A", "B"))
    expect_identical(sm_trace(two_loop, "C")$id, c("C", "B", "A"))
    expect_identical(sm_trace(two_loop, "A", direction = "upstream")$id, c("A", "B", "C"))
    both_two <- sm_trace(two_loop, "A", direction = "both")
    expect_identical(both_two$id, c("A", "B", "C"))
    expect_identical(both_two$direction, c("start", "both", "upstream"))
  })

  it("limits link kinds and max_distance, handles empty ids and maps without links", {
    map <- trace_map()
    expect_identical(sm_trace(map, "R1", kinds = "verifies")$id, c("R1", "T1"))
    expect_identical(sm_trace(map, "R1", kinds = "produces")$id, "R1")
    expect_identical(sm_trace(map, "R1", kinds = c("verifies", "produces")), sm_trace(map, "R1"))
    expect_identical(sm_trace(map, "R1", kinds = character())$id, "R1")
    expect_identical(sm_trace(map, "R1", max_distance = 1)$id, c("R1", "T1"))
    expect_identical(sm_trace(map, "R1", max_distance = 2), sm_trace(map, "R1"))

    start <- sm_trace(map, "R1", max_distance = 0)
    expect_identical(start$id, "R1")
    expect_identical(start$direction, "start")
    expect_identical(start$distance, 0L)
    expect_identical(start$through, NA_character_)
    expect_identical(start$kind, NA_character_)

    expect_identical(sm_trace(map, "R3")$id, "R3")

    unlinked <- stage_map(cards = sm_widget_data(map)$cards)
    expect_identical(sm_trace(unlinked, "R1")$id, "R1")
    expect_identical(sm_trace(unlinked, c("R1", "R2"))$id, c("R1", "R2"))

    with_unused <- stage_map(cards = sm_widget_data(map)$cards) |>
      add_links(
        data.frame(from = c("R1", "T1"), to = c("T1", "X1"), kind = c("only", NA)),
        kinds = data.frame(id = c("only", "unused"), label = c("Only", "Unused"))
      )
    expect_identical(sm_trace(with_unused, "R1", kinds = "unused")$id, "R1")
    expect_identical(sm_trace(with_unused, "R1", kinds = "only")$id, c("R1", "T1"))
    expect_identical(sm_trace(with_unused, "R1")$kind, c(NA_character_, "only", NA_character_))

    empty_map <- stage_map(
      cards = data.frame(id = character(), label = character(), stage = character(), lane = character())
    )
    expect_identical(nrow(sm_trace(empty_map, NULL)), 0L)
    expect_identical(nrow(sm_orphans(empty_map)), 0L)

    # NULL and zero-length ids return an empty result with the same columns and types.
    empty_null <- sm_trace(map, NULL)
    empty_char <- sm_trace(map, character(0))
    expect_identical(nrow(empty_null), 0L)
    expect_identical(empty_null, empty_char)
    expect_identical(sm_trace(map, integer(0)), empty_null)
    expect_identical(
      names(empty_null),
      c("id", "label", "stage", "lane", "direction", "distance", "through", "kind")
    )
    expect_type(empty_null$distance, "integer")
    expect_type(empty_null$through, "character")
    expect_identical(rownames(empty_null), character(0))
  })

  it("uses the first link in links order for ties regardless of card order", {
    map <- stage_map(
      cards = data.frame(id = c("A", "B", "C", "D"), label = c("A", "B", "C", "D"), stage = "S", lane = "L")
    ) |>
      add_links(
        data.frame(
          from = c("A", "A", "C", "B", "A"),
          to = c("B", "C", "D", "D", "B"),
          kind = c("first", "first", "winner", "later", "later")
        ),
        kinds = data.frame(id = c("first", "winner", "later"), label = c("First", "Winner", "Later"))
      )
    result <- sm_trace(map, "A")
    expect_identical(result$id, c("A", "B", "C", "D"))
    expect_identical(result$distance, c(0L, 1L, 1L, 2L))
    expect_identical(result$through, c(NA_character_, "A", "A", "C"))
    expect_identical(result$kind, c(NA_character_, "first", "first", "winner"))
    up <- sm_trace(map, "D", direction = "upstream")
    expect_identical(up$through, c(NA_character_, "D", "D", "B"))
    expect_identical(up$kind, c(NA_character_, "later", "winner", "first"))
    expect_identical(sm_trace(map, "A", direction = "both")$kind, result$kind)
  })

  it("accepts numeric ids and compares them as text", {
    map <- stage_map(
      cards = data.frame(id = c(1, 2, 100000), label = c(10, 20, 30), stage = c(1, 2, 2), lane = c(1, 1, 2))
    ) |>
      add_links(
        data.frame(from = c(1, 2), to = c(2, 100000), kind = c(7, 8)),
        kinds = data.frame(id = c(7, 8), label = c("Seven", "Eight"))
      )
    res_num <- sm_trace(map, 1, kinds = c(7, 8))
    res_txt <- sm_trace(map, "1", kinds = c("7", "8"))
    expect_identical(res_num, res_txt)
    expect_identical(res_num$id, c("1", "2", "100000"))
    expect_identical(res_num$label, c("10", "20", "30"))
    expect_identical(res_num$stage, c("1", "2", "2"))
    expect_identical(res_num$lane, c("1", "1", "2"))
    expect_identical(res_num$through, c(NA_character_, "1", "2"))
    expect_identical(res_num$kind, c(NA_character_, "7", "8"))
  })

  it("rejects invalid maps, ids, directions, kinds and max_distance", {
    map <- trace_map()
    expect_error(sm_trace(), "map", class = "stagemap_error_widget")
    expect_error(sm_trace(ids = "R1"), "map", class = "stagemap_error_widget")
    expect_error(sm_trace(NULL, "R1"), "map", class = "stagemap_error_widget")
    expect_error(sm_trace(list(), "R1"), "map", class = "stagemap_error_widget")
    expect_error(sm_trace(map), "ids.*is missing", class = "stagemap_error")

    for (bad in list(NA, NA_character_, NA_integer_, "", c("R1", NA), c("R1", ""), 1.5, Inf, TRUE, list("R1"))) {
      expect_error(sm_trace(map, bad), "ids")
    }
    err_id <- expect_error(sm_trace(map, "unknown-card"), "unknown-card", class = "stagemap_error_id")
    expect_match(conditionMessage(err_id), "Known card ids")

    empty_map <- stage_map(
      cards = data.frame(id = character(), label = character(), stage = character(), lane = character())
    )
    err_empty <- expect_error(sm_trace(empty_map, "R1"), "R1", class = "stagemap_error_id")
    expect_match(conditionMessage(err_empty), "The map has no cards.", fixed = TRUE)

    for (bad in list(NULL, 1, NA_character_, "", c("downstream", "upstream"))) {
      expect_error(sm_trace(map, "R1", direction = bad), "direction")
    }
    expect_error(sm_trace(map, "R1", direction = "sideways"), "direction")

    for (bad in list(NA, NA_character_, "", c("verifies", NA_character_), 1.5, TRUE)) {
      expect_error(sm_trace(map, "R1", kinds = bad), "kinds")
    }
    err_kind <- expect_error(sm_trace(map, "R1", kinds = "unknown-kind"), "unknown-kind", class = "stagemap_error_id")
    expect_match(conditionMessage(err_kind), "Known link kinds")
    expect_match(conditionMessage(err_kind), "verifies")
    expect_match(conditionMessage(err_kind), "produces")
    # Empty ids still validates kinds.
    expect_error(sm_trace(map, NULL, kinds = "unknown-kind"), "unknown-kind", class = "stagemap_error_id")

    for (bad in list(NULL, NA_real_, NaN, "one", c(1, 2), -1, -Inf)) {
      expect_error(sm_trace(map, "R1", max_distance = bad), "max_distance")
    }
    expect_error(sm_trace(map, "R1", max_distance = 1.5), "1.5", class = "stagemap_error")
    expect_error(sm_trace(map, "R1", extra = TRUE), "extra", class = "stagemap_error_dots")
    expect_error(sm_trace(map, "R1", "downstream"), "unnamed value", class = "stagemap_error_dots")
  })

  it("explains when a map has no known link kinds", {
    map <- stage_map(cards = sm_widget_data(trace_map())$cards)
    err <- expect_error(sm_trace(map, "R1", kinds = "unknown-kind"), "unknown-kind", class = "stagemap_error_id")
    expect_match(conditionMessage(err), "The map has no link kinds.", fixed = TRUE)
  })
})

describe("sm_orphans()", {
  it("returns only cards at neither end of any link in card order", {
    map <- trace_map()
    orphans <- sm_orphans(map)
    expect_identical(
      orphans,
      data.frame(id = "R3", label = "Isolated", stage = "Requirement", lane = "L2")
    )

    unlinked <- stage_map(cards = sm_widget_data(map)$cards)
    expect_identical(
      sm_orphans(unlinked),
      trace_cards_df(sm_widget_data(map)$cards, seq_len(6L))
    )

    self_loop <- stage_map(
      cards = data.frame(id = c(1, 2), label = c("One", "Two"), stage = "S", lane = "L")
    ) |>
      add_links(data.frame(from = 1, to = 1))
    expect_identical(sm_orphans(self_loop), data.frame(id = "2", label = "Two", stage = "S", lane = "L"))
  })

  it("checks the map and rejects extra arguments", {
    expect_error(sm_orphans(), "map", class = "stagemap_error_widget")
    expect_error(sm_orphans(NULL), "map", class = "stagemap_error_widget")
    expect_error(sm_orphans(list()), "map", class = "stagemap_error_widget")
    expect_error(sm_orphans(trace_map(), extra = TRUE), "extra")
    expect_error(sm_orphans(trace_map(), TRUE), "unused argument")
  })
})

describe("sm_missing()", {
  it("counts direct links in either direction and filters by kinds", {
    map <- trace_map()
    expect_identical(sm_missing(map, "Requirement", "Test")$id, "R3")
    expect_identical(sm_missing(map, "Test", "Requirement")$id, character())
    expect_identical(sm_missing(map, "Requirement", "Result")$id, c("R1", "R2", "R3"))
    expect_identical(sm_missing(map, "Requirement", "Test", kinds = "verifies")$id, "R3")
    expect_identical(sm_missing(map, "Requirement", "Test", kinds = "produces")$id, c("R1", "R2", "R3"))
    expect_identical(
      sm_missing(map, "Requirement", "Test", kinds = c("verifies", "produces"))$id,
      "R3"
    )
    expect_identical(sm_missing(map, "Requirement", "Test", kinds = character())$id, c("R1", "R2", "R3"))
    expect_identical(sm_missing(map, "Test", "Requirement", kinds = "verifies")$id, character())

    with_unused <- stage_map(cards = sm_widget_data(map)$cards) |>
      add_links(
        data.frame(from = c("R1", "R2"), to = c("T1", "T2"), kind = c("verifies", NA)),
        kinds = data.frame(id = c("verifies", "unused"), label = c("Verifies", "Unused"))
      )
    expect_identical(sm_missing(with_unused, "Requirement", "Test", kinds = "unused")$id, c("R1", "R2", "R3"))
    expect_identical(sm_missing(with_unused, "Requirement", "Test", kinds = "verifies")$id, c("R2", "R3"))
    expect_identical(sm_missing(with_unused, "Requirement", "Test")$id, "R3")
  })

  it("accepts the same stage, numeric stages, empty stages and maps without links", {
    map <- stage_map(
      cards = data.frame(id = c(1, 2, 3), label = c("A", "B", "C"), stage = 10, lane = 1),
      stages = data.frame(id = c(10, 20), label = c("Ten", "Twenty"))
    ) |>
      add_links(data.frame(from = 2, to = 1))
    expect_identical(sm_missing(map, 10, 10)$id, "3")
    expect_identical(sm_missing(map, "10", "10")$id, "3")
    expect_identical(sm_missing(map, 20, 10)$id, character())
    expect_identical(sm_missing(map, 10, 20)$id, c("1", "2", "3"))

    # Empty stage from factor levels when `stages` is omitted.
    factor_map <- stage_map(
      cards = data.frame(
        id = c("A", "B"),
        label = c("A", "B"),
        stage = factor("Requirement", levels = c("Requirement", "Empty")),
        lane = "L"
      )
    )
    expect_identical(sm_missing(factor_map, "Empty", "Requirement")$id, character())
    expect_identical(sm_missing(factor_map, "Requirement", "Empty")$id, c("A", "B"))

    # Empty `kinds` ignores links even when `links` has no `kind` column.
    no_kind <- stage_map(
      cards = data.frame(id = c("A", "B"), label = c("A", "B"), stage = c("S1", "S2"), lane = "L")
    ) |>
      add_links(data.frame(from = "A", to = "B"))
    expect_identical(sm_missing(no_kind, "S1", "S2", kinds = character())$id, "A")
    expect_identical(sm_trace(no_kind, "A", kinds = character())$id, "A")
  })

  it("rejects invalid maps, stages, kinds and extra arguments", {
    map <- trace_map()
    expect_error(sm_missing(), "map", class = "stagemap_error_widget")
    expect_error(sm_missing(stage = "Requirement", linked_to = "Test"), "map", class = "stagemap_error_widget")
    expect_error(sm_missing(NULL, "Requirement", "Test"), "map", class = "stagemap_error_widget")
    expect_error(sm_missing(map), "stage.*is missing", class = "stagemap_error")
    expect_error(sm_missing(map, linked_to = "Test"), "stage.*is missing", class = "stagemap_error")
    expect_error(sm_missing(map, "Requirement"), "linked_to.*is missing", class = "stagemap_error")

    for (bad in list(NULL, 1.5, NA, NA_character_, "", c("Requirement", "Test"), TRUE)) {
      expect_error(sm_missing(map, bad, "Test"), "stage")
      expect_error(sm_missing(map, "Requirement", bad), "linked_to")
    }
    expect_error(sm_missing(map, "unknown-from", "Test"), "unknown-from", class = "stagemap_error_id")
    expect_error(sm_missing(map, "Requirement", "unknown-to"), "unknown-to", class = "stagemap_error_id")

    empty_map <- stage_map(
      cards = data.frame(id = character(), label = character(), stage = character(), lane = character())
    )
    err_empty <- expect_error(sm_missing(empty_map, "Req", "Test"), "Req", class = "stagemap_error_id")
    expect_match(conditionMessage(err_empty), "The map has no stages.", fixed = TRUE)

    for (bad in list(NA, NA_character_, "", 1.5, TRUE, c("verifies", NA_character_))) {
      expect_error(sm_missing(map, "Requirement", "Test", kinds = bad), "kinds")
    }
    err_kind <- expect_error(
      sm_missing(map, "Requirement", "Test", kinds = "unknown-kind"),
      "unknown-kind",
      class = "stagemap_error_id"
    )
    expect_match(conditionMessage(err_kind), "Known link kinds")
    expect_match(conditionMessage(err_kind), "verifies")
    expect_match(conditionMessage(err_kind), "produces")
    expect_error(sm_missing(map, "Requirement", "Test", extra = TRUE), "extra", class = "stagemap_error_dots")
    expect_error(sm_missing(map, "Requirement", "Test", "verifies"), "unnamed value", class = "stagemap_error_dots")
  })

  it("explains when a map has no known link kinds", {
    map <- stage_map(cards = sm_widget_data(trace_map())$cards)
    err <- expect_error(
      sm_missing(map, "Requirement", "Test", kinds = "unknown-kind"),
      "unknown-kind",
      class = "stagemap_error_id"
    )
    expect_match(conditionMessage(err), "The map has no link kinds.", fixed = TRUE)
  })
})

describe("trace result types", {
  it("returns plain data frames with character columns, integer distance, 1..n row names and no extra columns", {
    cards <- data.frame(
      id = c("A", "B", "C"),
      label = factor(c("Requirement", "Test", "Other requirement")),
      stage = factor(c("Requirement", "Test", "Requirement"), levels = c("Requirement", "Test", "Empty")),
      lane = factor("L1"),
      extra = c("x", "y", "z")
    )
    map <- stage_map(cards = cards) |>
      add_links(data.frame(from = "A", to = "B"))

    trace_res <- sm_trace(map, "A")
    orphans_res <- sm_orphans(map)
    missing_res <- sm_missing(map, "Requirement", "Test")
    for (result in list(trace_res, orphans_res, missing_res)) {
      expect_identical(class(result), "data.frame")
      expect_type(result$id, "character")
      expect_type(result$label, "character")
      expect_type(result$stage, "character")
      expect_type(result$lane, "character")
      expect_identical(rownames(result), as.character(seq_len(nrow(result))))
    }
    expect_identical(names(orphans_res), c("id", "label", "stage", "lane"))
    expect_identical(names(missing_res), c("id", "label", "stage", "lane"))
    expect_identical(
      names(trace_res),
      c("id", "label", "stage", "lane", "direction", "distance", "through", "kind")
    )
    expect_type(trace_res$direction, "character")
    expect_type(trace_res$distance, "integer")
    expect_type(trace_res$through, "character")
    expect_type(trace_res$kind, "character")

    # Zero-row results retain exact column names and types.
    empty_trace <- sm_trace(map, character(0))
    empty_missing <- sm_missing(map, "Empty", "Test")
    connected <- stage_map(cards = cards) |>
      add_links(data.frame(from = c("A", "C"), to = c("B", "B")))
    empty_orphans <- sm_orphans(connected)
    for (empty in list(empty_trace, empty_missing, empty_orphans)) {
      expect_identical(class(empty), "data.frame")
      expect_identical(nrow(empty), 0L)
      expect_identical(rownames(empty), character(0))
      expect_type(empty$id, "character")
      expect_type(empty$label, "character")
      expect_type(empty$stage, "character")
      expect_type(empty$lane, "character")
    }
    expect_type(empty_trace$direction, "character")
    expect_type(empty_trace$distance, "integer")
    expect_type(empty_trace$through, "character")
    expect_type(empty_trace$kind, "character")
  })
})
