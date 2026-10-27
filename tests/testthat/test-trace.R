# Shared synthetic requirements, tests and results, with one isolated requirement.
trace_map <- function() {
  stagemap(
    data.frame(
      id = c("R1", "R2", "T1", "T2", "X1", "R3"),
      label = c("First requirement", "Second requirement", "First test", "Second test", "Result", "Isolated"),
      stage = c("Requirement", "Requirement", "Test", "Test", "Result", "Requirement"),
      extra = seq_len(6L)
    ),
    data.frame(
      from = c("R1", "R2", "T1", "T2"),
      to = c("T1", "T2", "X1", "X1"),
      kind = c("verifies", "verifies", "produces", "produces")
    )
  )
}

describe("sm_trace()", {
  it("follows each direction and orders rows by distance then node order", {
    map <- trace_map()
    down <- sm_trace(map, "R1")
    expect_identical(down$id, c("R1", "T1", "X1"))
    expect_identical(down$label, c("First requirement", "First test", "Result"))
    expect_identical(down$stage, c("Requirement", "Test", "Result"))
    expect_identical(down$distance, 0:2)
    expect_identical(down$kind, c(NA_character_, "verifies", "produces"))
    expect_identical(sm_trace(map, "R1", "down"), down)
    expect_identical(sm_trace(map, "R1", c("down", "up", "both")), down)
    up <- sm_trace(map, "X1", "up")
    expect_identical(up$id, c("X1", "T1", "T2", "R1", "R2"))
    expect_identical(up$distance, c(0L, 1L, 1L, 2L, 2L))
    both <- sm_trace(map, "T1", "both")
    expect_identical(both$id, c("T1", "R1", "X1", "T2", "R2"))
    expect_identical(both$distance, c(0L, 1L, 1L, 2L, 3L))
    expect_identical(names(both), c("id", "label", "stage", "distance", "kind"))
    expect_identical(class(both), "data.frame")
    expect_identical(rownames(both), as.character(seq_len(5L)))
  })

  it("reaches X1, T1 and T2 going up through produces links", {
    map <- trace_map()
    expect_identical(sm_trace(map, "X1", "up", kinds = "produces")$id, c("X1", "T1", "T2"))
  })

  it("reaches T1, R1 and X1 going both ways at depth one", {
    map <- trace_map()
    expect_identical(sm_trace(map, "T1", "both", depth = 1)$id, c("T1", "R1", "X1"))
  })

  it("stops at A and B partway round an A to B to C to A cycle", {
    map <- stagemap(
      data.frame(id = c("A", "B", "C"), stage = c("Requirement", "Test", "Result")),
      data.frame(from = c("A", "B", "C"), to = c("B", "C", "A"))
    )
    result <- sm_trace(map, "A", depth = 1)
    expect_identical(result$id, c("A", "B"))
    expect_identical(result$distance, 0:1)
    expect_identical(sm_trace(map, "A")$id, c("A", "B", "C"))
  })

  it("limits link kinds and depth, including an isolated start", {
    map <- trace_map()
    expect_identical(sm_trace(map, "R1", kinds = "verifies")$id, c("R1", "T1"))
    expect_identical(sm_trace(map, "R1", kinds = "produces")$id, "R1")
    expect_identical(sm_trace(map, "R1", kinds = c("verifies", "produces")), sm_trace(map, "R1"))
    expect_identical(sm_trace(map, "R1", kinds = character())$id, "R1")
    expect_identical(sm_trace(map, "R1", depth = 1)$id, c("R1", "T1"))
    expect_identical(sm_trace(map, "R1", depth = 2), sm_trace(map, "R1"))
    start <- sm_trace(map, "R1", depth = 0)
    expect_identical(start$id, "R1")
    expect_identical(start$distance, 0L)
    expect_identical(start$kind, NA_character_)
    expect_identical(sm_trace(map, "R3")$id, "R3")
    expect_identical(sm_trace(stagemap(map$nodes), "R1")$id, "R1")
    expect_warning(configured <- sm_kinds(map, unused = sm_kind()), "unused")
    expect_identical(sm_trace(configured, "R1", kinds = "unused")$id, "R1")
  })

  it("ends cycles and follows links towards an earlier stage", {
    map <- stagemap(
      data.frame(id = c("A", "B", "C"), stage = c("Requirement", "Test", "Result")),
      data.frame(from = c("A", "B", "C"), to = c("B", "A", "B"))
    )
    expect_identical(sm_trace(map, "A")$id, c("A", "B"))
    expect_identical(sm_trace(map, "C")$id, c("C", "B", "A"))
    expect_identical(sm_trace(map, "A", "both")$id, c("A", "B", "C"))
    expect_identical(sm_trace(map, "A", "up")$id, c("A", "B", "C"))
  })

  it("uses the first link for ties across parents regardless of node order", {
    map <- stagemap(
      data.frame(id = c("A", "B", "C", "D"), stage = c("Requirement", "Test", "Test", "Result")),
      data.frame(
        from = c("A", "A", "C", "B", "A"),
        to = c("B", "C", "D", "D", "B"),
        kind = c("first", "first", "winner", "later", "later")
      )
    )
    result <- sm_trace(map, "A")
    expect_identical(result$id, c("A", "B", "C", "D"))
    expect_identical(result$distance, c(0L, 1L, 1L, 2L))
    expect_identical(result$kind, c(NA_character_, "first", "first", "winner"))
    expect_identical(sm_trace(map, "D", "up")$kind, c(NA_character_, "later", "winner", "first"))
    expect_identical(sm_trace(map, "A", "both")$kind, result$kind)
  })

  it("rejects invalid maps, nodes, directions, kinds and depths", {
    map <- trace_map()
    expect_error(sm_trace(NULL, "R1"), "map", class = "stagemap_error")
    for (bad in list(NULL, 1, NA_character_, "", c("R1", "R2"))) {
      expect_error(sm_trace(map, bad), "node", class = "stagemap_error")
    }
    expect_error(sm_trace(), "map.*is missing", class = "stagemap_error")
    expect_error(sm_trace(node = "R1"), "map.*is missing", class = "stagemap_error")
    expect_error(sm_trace(map), "node.*is missing", class = "stagemap_error")
    expect_error(sm_trace(map, "unknown-node"), "unknown-node", class = "stagemap_error")
    for (bad in list(NULL, 1, NA_character_, "", c("down", "up"))) {
      expect_error(sm_trace(map, "R1", direction = bad), "direction", class = "stagemap_error")
    }
    expect_error(sm_trace(map, "R1", "sideways"), "sideways", class = "stagemap_error")
    for (bad in list(1, NA_character_, "", c("verifies", NA_character_))) {
      expect_error(sm_trace(map, "R1", kinds = bad), "kinds", class = "stagemap_error")
    }
    error <- expect_error(sm_trace(map, "R1", kinds = "unknown-kind"), "unknown-kind", class = "stagemap_error")
    expect_match(conditionMessage(error), "Unknown `kinds`:", fixed = TRUE)
    expect_identical(deparse(conditionCall(error))[1], 'sm_trace(map, "R1", kinds = "unknown-kind")')
    expect_match(conditionMessage(error), "Known kinds")
    expect_match(conditionMessage(error), "verifies")
    expect_match(conditionMessage(error), "produces")
    for (bad in list(NULL, NA_real_, NaN, "one", c(1, 2), -1, -Inf)) {
      expect_error(sm_trace(map, "R1", depth = bad), "depth", class = "stagemap_error")
    }
    expect_error(sm_trace(map, "R1", depth = 1.5), "1.5", class = "stagemap_error")
    expect_error(sm_trace(map, "R1", extra = TRUE), "extra")
    expect_error(sm_trace(map, "R1", "down", NULL, Inf, TRUE), "unused argument")
    expect_error(check_trace_kinds(NULL, NULL, "kinds", environment()), "map")
    expect_error(check_trace_kinds(map, 1, "kinds", environment()), "kinds")
    expect_error(check_trace_kinds(map, NULL, "", environment()), "arg")
    expect_error(check_trace_kinds(map, NULL, "kinds", NULL), "call")
  })

  it("explains when a map has no known link kinds", {
    map <- stagemap(trace_map()$nodes)
    error <- expect_error(sm_trace(map, "R1", kinds = "unknown-kind"), "unknown-kind", class = "stagemap_error")
    expect_match(conditionMessage(error), "Unknown `kinds`:", fixed = TRUE)
    expect_match(conditionMessage(error), "The map has no link kinds.", fixed = TRUE)
    expect_identical(deparse(conditionCall(error))[1], 'sm_trace(map, "R1", kinds = "unknown-kind")')
  })
})

describe("sm_orphans()", {
  it("returns only nodes at neither end of a link in node order", {
    map <- trace_map()
    expect_identical(sm_orphans(map), data.frame(id = "R3", label = "Isolated", stage = "Requirement"))
    expect_identical(sm_orphans(stagemap(map$nodes)), map$nodes[c("id", "label", "stage")])
  })

  it("checks the map and rejects extra arguments", {
    expect_error(sm_orphans(NULL), "map", class = "stagemap_error")
    expect_error(sm_orphans(trace_map(), extra = TRUE), "extra")
    expect_error(sm_orphans(trace_map(), TRUE), "unused argument")
  })
})

describe("sm_missing()", {
  it("counts direct links in either direction and filters by kind", {
    map <- trace_map()
    expect_identical(sm_missing(map, "Requirement", "Test")$id, "R3")
    expect_identical(sm_missing(map, "Test", "Requirement")$id, character())
    expect_identical(sm_missing(map, "Requirement", "Result")$id, c("R1", "R2", "R3"))
    expect_identical(sm_missing(map, "Requirement", "Test", "verifies")$id, "R3")
    expect_identical(sm_missing(map, "Requirement", "Test", "produces")$id, c("R1", "R2", "R3"))
    expect_identical(sm_missing(map, "Test", "Requirement", "verifies")$id, character())
    expect_warning(configured <- sm_kinds(map, unused = sm_kind()), "unused")
    expect_identical(sm_missing(configured, "Requirement", "Test", "unused")$id, c("R1", "R2", "R3"))
  })

  it("accepts the same stage and empty configured stages", {
    map <- stagemap(
      data.frame(id = c("A", "B", "C"), stage = rep("Requirement", 3L)),
      data.frame(from = "B", to = "A")
    )
    expect_identical(sm_missing(map, "Requirement", "Requirement")$id, "C")
    map <- sm_stages(map, c("Requirement", "Empty"))
    expect_identical(sm_missing(map, "Empty", "Requirement")$id, character())
    expect_identical(sm_missing(map, "Requirement", "Empty")$id, c("A", "B", "C"))
    expect_identical(sm_missing(stagemap(map$nodes), "Requirement", "Requirement")$id, c("A", "B", "C"))
  })

  it("rejects invalid maps, stages and kinds and names unknown values", {
    map <- trace_map()
    expect_error(sm_missing(NULL, "Requirement", "Test"), "map", class = "stagemap_error")
    for (bad in list(NULL, 1, NA_character_, "", c("Requirement", "Test"))) {
      expect_error(sm_missing(map, bad, "Test"), "from", class = "stagemap_error")
      expect_error(sm_missing(map, "Requirement", bad), "to", class = "stagemap_error")
    }
    expect_error(sm_missing(), "map.*is missing", class = "stagemap_error")
    expect_error(sm_missing(from = "Requirement", to = "Test"), "map.*is missing", class = "stagemap_error")
    expect_error(sm_missing(map), "from.*is missing", class = "stagemap_error")
    expect_error(sm_missing(map, to = "Test"), "from.*is missing", class = "stagemap_error")
    expect_error(sm_missing(map, "Requirement"), "to.*is missing", class = "stagemap_error")
    expect_error(sm_missing(map, "unknown-from", "Test"), "unknown-from", class = "stagemap_error")
    expect_error(sm_missing(map, "Requirement", "unknown-to"), "unknown-to", class = "stagemap_error")
    for (bad in list(1, NA_character_, "", c("verifies", "produces"))) {
      expect_error(sm_missing(map, "Requirement", "Test", bad), "kind", class = "stagemap_error")
    }
    error <- expect_error(
      sm_missing(map, "Requirement", "Test", "unknown-kind"),
      "unknown-kind",
      class = "stagemap_error"
    )
    expect_match(conditionMessage(error), "Unknown `kind`:", fixed = TRUE)
    expect_identical(deparse(conditionCall(error))[1], 'sm_missing(map, "Requirement", "Test", "unknown-kind")')
    expect_match(conditionMessage(error), "Known kinds")
    expect_match(conditionMessage(error), "verifies")
    expect_match(conditionMessage(error), "produces")
    expect_error(sm_missing(map, "Requirement", "Test", extra = TRUE), "extra")
    expect_error(sm_missing(map, "Requirement", "Test", NULL, TRUE), "unused argument")
  })

  it("explains when a map has no known link kinds", {
    map <- stagemap(trace_map()$nodes)
    error <- expect_error(
      sm_missing(map, "Requirement", "Test", "unknown-kind"),
      "unknown-kind",
      class = "stagemap_error"
    )
    expect_match(conditionMessage(error), "Unknown `kind`:", fixed = TRUE)
    expect_match(conditionMessage(error), "The map has no link kinds.", fixed = TRUE)
    expect_identical(deparse(conditionCall(error))[1], 'sm_missing(map, "Requirement", "Test", "unknown-kind")')
  })
})

describe("question result types", {
  it("keeps factor levels, column types and consecutive row names", {
    nodes <- data.frame(
      id = c("A", "B", "C"),
      label = c("Requirement", "Test", "Other requirement"),
      stage = factor(c("Requirement", "Test", "Requirement"), levels = c("Requirement", "Test", "Empty"))
    )
    map <- stagemap(nodes, data.frame(from = "A", to = "B"))
    for (result in list(sm_trace(map, "A"), sm_orphans(map), sm_missing(map, "Requirement", "Test"))) {
      expect_identical(class(result), "data.frame")
      expect_type(result$id, "character")
      expect_type(result$label, "character")
      expect_identical(levels(result$stage), levels(nodes$stage))
      expect_s3_class(result$stage, "factor")
      expect_identical(rownames(result), as.character(seq_len(nrow(result))))
    }
    # A trace always includes its start, so cannot have zero rows.
    expect_identical(sm_trace(map, "C", depth = 0)$distance, 0L)
    expect_identical(sm_missing(map, "Empty", "Test"), nodes[FALSE, ])
    connected <- stagemap(nodes, data.frame(from = c("A", "C"), to = c("B", "B")))
    for (result in list(sm_orphans(connected), sm_missing(connected, "Requirement", "Test"))) {
      expect_identical(result, nodes[FALSE, ])
    }
    plain <- trace_map()
    empty <- plain$nodes[FALSE, c("id", "label", "stage")]
    expect_identical(sm_missing(plain, "Test", "Result"), empty)
    expect_identical(sm_orphans(stagemap(plain$nodes[1:5, ], plain$links)), empty)
  })
})
