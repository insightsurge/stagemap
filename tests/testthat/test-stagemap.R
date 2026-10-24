describe("stagemap()", {
  it("builds the example map in the agreed order with plain tables", {
    nodes <- data.frame(
      id = c("REQ-1", "REQ-2", "TST-1", "RES-1"),
      stage = c("Requirement", "Requirement", "Test", "Result"),
      lane = c("Safety", "Usability", "Safety", "Safety"),
      group = c("Safety", "Usability", "Safety", "Safety"),
      status = c("pass", "missing", "pass", "fail")
    )
    links <- data.frame(from = c("REQ-1", "TST-1"), to = c("TST-1", "RES-1"), kind = c("verifies", "produces"))
    map <- stagemap(nodes, links)
    expect_identical(class(map), "stagemap")
    expect_identical(names(map), c("nodes", "links", "stages", "lanes", "kinds", "groups", "status", "options"))
    expect_identical(map[3:7], list(stages = NULL, lanes = NULL, kinds = NULL, groups = NULL, status = NULL))
    expect_identical(map$options, list())
    expect_identical(names(map$nodes), c("id", "stage", "label", "lane", "group", "status"))
    expect_identical(names(map$links), c("from", "to", "kind", "label"))
    expect_identical(class(map$nodes), "data.frame")
    expect_identical(class(map$links), "data.frame")
    expect_identical(map$nodes$label, nodes$id)
    expect_identical(map$links$label, rep(NA_character_, 2))
    expect_true(all(vapply(map$nodes, is.character, logical(1))))
    expect_true(all(vapply(map$links, is.character, logical(1))))
    expect_identical(rownames(map$nodes), as.character(1:4))
    expect_identical(rownames(map$links), as.character(1:2))
    expect_identical(
      format(map),
      c(
        "<stagemap> 4 nodes, 2 links",
        "Stages (3): Requirement, Test, Result",
        "Lanes (2): Safety, Usability",
        "Kinds (2): verifies, produces"
      )
    )
    output <- capture.output(visible <- withVisible(print(map)))
    expect_identical(output, format(map))
    expect_identical(visible$value, map)
    expect_false(visible$visible)
  })

  it("keeps factor ordering and extra columns while filling defaults", {
    nodes <- data.frame(
      extra = I(list(1, 2)),
      status = factor(c(NA, "pass")),
      group = factor(c("g", NA)),
      lane = factor(c("B", "A"), levels = c("A", "B", "C")),
      label = factor(c(NA, "Bee")),
      stage = factor(c("Z", "Y"), levels = c("Y", "Z")),
      id = factor(c("a", "b")),
      row.names = c("x", "y")
    )
    links <- data.frame(extra = 12L, label = factor(NA_character_), to = factor("b"), from = factor("a"))
    map <- stagemap(nodes, links)
    expect_identical(map$nodes$stage, nodes$stage)
    expect_identical(map$nodes$lane, nodes$lane)
    expect_identical(map$nodes$extra, nodes$extra)
    expect_identical(map$nodes$label, c("a", "Bee"))
    expect_identical(map$nodes$id, c("a", "b"))
    expect_identical(map$nodes$group, c("g", NA_character_))
    expect_identical(map$nodes$status, c(NA_character_, "pass"))
    expect_identical(names(map$nodes), c("id", "stage", "label", "lane", "group", "status", "extra"))
    expect_identical(names(map$links), c("from", "to", "kind", "label", "extra"))
    expect_identical(map$links$extra, 12L)
    expect_identical(map$links$kind, "link")
    expect_identical(map$links$from, "a")
    expect_identical(map$links$to, "b")
    expect_identical(map$links$label, NA_character_)
    expect_identical(
      format(map),
      c("<stagemap> 2 nodes, 1 link", "Stages (2): Y, Z", "Lanes (3): A, B, C", "Kinds (1): link")
    )
    expect_identical(
      format(stagemap(data.frame(id = "a", stage = "S"))),
      c("<stagemap> 1 node, 0 links", "Stages (1): S")
    )
    empty <- stagemap(nodes)$links
    expect_identical(empty, data.frame(from = character(), to = character(), kind = character(), label = character()))
    expect_identical(stagemap(nodes, empty)$links, empty)
    expect_identical(stagemap(nodes, links[FALSE, c("from", "to")])$links, empty)
    links$kind <- factor("verifies")
    expect_identical(stagemap(nodes, links)$links$kind, "verifies")
  })

  it("checks table arguments and rejects extras", {
    nodes <- data.frame(id = "a", stage = "S")
    expect_error(stagemap(), "nodes", class = "stagemap_error")
    expect_error(stagemap(1), "nodes", class = "stagemap_error")
    expect_error(stagemap(nodes[FALSE, ]), "nodes", class = "stagemap_error")
    expect_error(stagemap(nodes, 1), "links", class = "stagemap_error")
    expect_error(stagemap(nodes, NULL, "x"), "unnamed argument", class = "stagemap_error_dots")
    expect_error(stagemap(nodes, NULL, foo = 1), "foo", class = "stagemap_error_dots")
  })

  it("names every missing required column", {
    expect_error(stagemap(data.frame(other = "a")), "nodes.*id.*stage", class = "stagemap_error_data")
    expect_error(
      stagemap(data.frame(id = "a", stage = "S"), data.frame(other = "a")),
      "links.*from.*to",
      class = "stagemap_error_data"
    )
  })

  it("rejects non-string fixed columns including empty link columns", {
    nodes <- data.frame(id = c("a", "b"), stage = "S")
    for (column in c("id", "stage", "label", "lane", "group", "status")) {
      for (value in list(1:2, c(TRUE, FALSE), list("a", "b"))) {
        bad <- nodes
        bad[[column]] <- value
        expect_error(
          stagemap(bad),
          paste0("Column.*", column, ".*nodes.*character or factor"),
          class = "stagemap_error_data"
        )
      }
    }
    for (column in c("from", "to", "kind", "label")) {
      bad <- data.frame(from = "a", to = "b")
      bad[[column]] <- 1
      expect_error(
        stagemap(nodes, bad),
        paste0("Column.*", column, ".*links.*character or factor"),
        class = "stagemap_error_data"
      )
    }
    expect_error(
      stagemap(nodes, data.frame(from = integer(), to = character())),
      "Column.*from.*links.*a number",
      class = "stagemap_error_data"
    )
  })

  it("reports missing, empty and duplicated node values by row", {
    nodes <- data.frame(id = c("a", "b", "c", "d"), stage = "S", lane = "L")
    for (column in c("id", "stage", "lane")) {
      bad <- nodes
      bad[[column]][c(2, 4)] <- NA_character_
      expect_error(stagemap(bad), paste0("Rows 2 and 4.*nodes.*missing.*", column), class = "stagemap_error_data")
    }
    bad <- nodes
    bad$id[c(2, 4)] <- ""
    expect_error(stagemap(bad), "Rows 2 and 4.*empty.*id", class = "stagemap_error_data")
    bad$id[c(2, 4)] <- "dup"
    expect_error(
      stagemap(bad),
      "(?s)Rows 2 and 4.*duplicated.*id.*Duplicated ids:.*dup",
      perl = TRUE,
      class = "stagemap_error_data"
    )
    expect_error(
      stagemap(data.frame(id = rep(NA_character_, 7), stage = "S")),
      "Rows 1, 2, 3, 4, 5 and 2 more",
      class = "stagemap_error_data"
    )
  })

  it("checks link endpoints, self-links and missing kinds", {
    nodes <- data.frame(id = c("a", "b"), stage = "S")
    links <- data.frame(from = c("a", "a"), to = c("b", "b"), kind = c("one", "two"))
    for (column in c("from", "to")) {
      bad <- links
      bad[[column]][2] <- NA_character_
      expect_error(stagemap(nodes, bad), paste0("Row 2.*links.*missing.*", column), class = "stagemap_error_data")
      bad[[column]][2] <- "unknown"
      expect_error(
        stagemap(nodes, bad),
        paste0("(?s)Row 2.*links.*", column, ".*Unknown ids:.*unknown"),
        perl = TRUE,
        class = "stagemap_error_data"
      )
    }
    bad <- links
    bad$to[2] <- "a"
    expect_error(
      stagemap(nodes, bad),
      "(?s)Row 2.*joins a node to itself.*Node ids:.*a",
      perl = TRUE,
      class = "stagemap_error_data"
    )
    links$kind[2] <- NA_character_
    expect_error(stagemap(nodes, links), "Row 2.*missing.*kind", class = "stagemap_error_data")
  })

  it("warns once and keeps the first of each directed typed link", {
    nodes <- data.frame(id = c("a", "b"), stage = "S")
    links <- data.frame(
      from = c("a", "a", "a", "b"),
      to = c("b", "b", "b", "a"),
      kind = c("one", "one", "two", "one"),
      extra = 1:4
    )
    expect_warning(map <- stagemap(nodes, links), "Row 2", class = "stagemap_warning_duplicate")
    expect_identical(map$links$extra, c(1L, 3L, 4L))
    expect_identical(rownames(map$links), as.character(1:3))
    links <- data.frame(from = rep("a", 8), to = "b")
    expect_warning(stagemap(nodes, links), "Rows 2, 3, 4, 5, 6 and 2 more", class = "stagemap_warning")
  })
})

describe("map summaries", {
  it("shortens long lists and checks method arguments", {
    nodes <- data.frame(id = letters[1:10], stage = LETTERS[1:10], lane = LETTERS[1:10])
    links <- data.frame(from = letters[1:9], to = letters[2:10], kind = LETTERS[1:9])
    map <- stagemap(nodes, links)
    expect_identical(
      format(map),
      c(
        "<stagemap> 10 nodes, 9 links",
        "Stages (10): A, B, C, D, E, F, G, H, and 2 more",
        "Lanes (10): A, B, C, D, E, F, G, H, and 2 more",
        "Kinds (9): A, B, C, D, E, F, G, H, and 1 more"
      )
    )
    expect_error(format.stagemap(NULL), "x")
    expect_error(print.stagemap(NULL), "x")
    expect_identical(format(map, digits = 3, foo = 1), format(map))
    expect_identical(capture.output(print(map, digits = 3)), format(map))
  })
})

describe("check_map_columns()", {
  it("checks its own arguments", {
    expect_error(check_map_columns(1, "nodes", "id"), "data")
    expect_error(check_map_columns(data.frame(), "", "id"), "arg")
    expect_error(check_map_columns(data.frame(), "nodes", 1), "columns")
  })
})


describe("check_required_columns()", {
  it("checks its own arguments", {
    expect_error(check_required_columns(1, "nodes", "id"), "data")
    expect_error(check_required_columns(data.frame(), "", "id"), "arg")
    expect_error(check_required_columns(data.frame(), "nodes", 1), "required")
  })
})


describe("validation order", {
  it("checks required columns before types and ids before stages", {
    expect_error(
      stagemap(data.frame(id = 1, stage = "S"), data.frame(other = "x")),
      "links.*from.*to",
      class = "stagemap_error_data"
    )
    expect_error(
      stagemap(data.frame(id = "", stage = NA_character_)),
      "empty.*id",
      class = "stagemap_error_data"
    )
    expect_error(
      stagemap(data.frame(id = "a", stage = "S"), data.frame(from = "unknown", to = NA_character_)),
      "missing.*to",
      class = "stagemap_error_data"
    )
  })
})


describe("new_stagemap()", {
  it("keeps the internal fields and checks their container types", {
    map <- stagemap(data.frame(id = "a", stage = "S"))
    expect_identical(new_stagemap(map$nodes, map$links), map)
    expect_error(new_stagemap(1, map$links), "nodes")
    expect_error(new_stagemap(map$nodes, 1), "links")
    for (field in c("stages", "lanes", "kinds", "groups", "status", "options")) {
      args <- list(nodes = map$nodes, links = map$links)
      args[[field]] <- 1
      expect_error(do.call(new_stagemap, args), field)
      args[[field]] <- list(example = "value")
      expect_identical(do.call(new_stagemap, args)[[field]], args[[field]])
    }
  })
})

describe("column type hints", {
  it("names the type and shows a conversion for empty and non-empty columns", {
    nodes <- data.frame(id = c("a", "b"), stage = "S")
    for (case in list(
      list(1:2, "a number"),
      list(c(TRUE, FALSE), "a logical"),
      list(list("a", "b"), "a list"),
      list(as.raw(1:2), "type raw")
    )) {
      bad <- nodes
      bad$id <- case[[1]]
      expect_error(
        stagemap(bad),
        paste0("(?s)Column.*id.*nodes.*not ", case[[2]], ".*Convert it first.*nodes\\$id <- as.character"),
        perl = TRUE,
        class = "stagemap_error_data"
      )
    }
    for (rows in list(integer(), 1L)) {
      links <- data.frame(from = rows, to = rep("b", length(rows)))
      expect_error(
        stagemap(nodes, links),
        "(?s)Column.*from.*links.*a number.*links\\$from <- as.character",
        perl = TRUE,
        class = "stagemap_error_data"
      )
    }
    expect_error(
      stagemap(data.frame(id = "a", stage = NA_character_)),
      "Row 1.*nodes.*has a missing.*stage",
      class = "stagemap_error_data"
    )
  })
})

describe("columns from real-world data", {
  it("treats an all-missing label, group or status column as none given", {
    # Given columns of only NA, which R stores as logical
    nodes <- data.frame(id = c("a", "b"), stage = "S", label = NA, group = NA, status = NA)
    links <- data.frame(from = "a", to = "b", label = NA)
    # When the map is built
    map <- stagemap(nodes, links)
    # Then they become missing character values
    expect_identical(map$nodes$label, c("a", "b"))
    expect_identical(map$nodes$group, c(NA_character_, NA_character_))
    expect_identical(map$nodes$status, c(NA_character_, NA_character_))
    expect_identical(map$links$label, NA_character_)
  })

  it("rejects matrix columns and names other classes", {
    nodes <- data.frame(id = c("a", "b"))
    nodes$stage <- matrix(c("s", "t"), ncol = 1)
    expect_error(stagemap(nodes), "stage.*not a matrix", class = "stagemap_error_data")
    nodes$stage <- as.Date(c("2026-01-01", "2026-01-02"))
    expect_error(stagemap(nodes), "stage.*not class Date", class = "stagemap_error_data")
  })

  it("rejects empty or blank stages, lanes, kinds and ids", {
    expect_error(
      stagemap(data.frame(id = c("a", "b"), stage = c("", "  "))),
      "Rows 1 and 2 of .*nodes.* have an empty .*stage",
      class = "stagemap_error_data"
    )
    expect_error(
      stagemap(data.frame(id = c("a", "b"), stage = "S", lane = factor(c("L", " ")))),
      "Row 2 of .*nodes.* has an empty .*lane",
      class = "stagemap_error_data"
    )
    expect_error(
      stagemap(data.frame(id = c("a", " "), stage = "S")),
      "Row 2 of .*nodes.* has an empty .*id",
      class = "stagemap_error_data"
    )
    expect_error(
      stagemap(data.frame(id = c("a", "b"), stage = "S"), data.frame(from = "a", to = "b", kind = "")),
      "Row 1 of .*links.* has an empty .*kind",
      class = "stagemap_error_data"
    )
  })

  it("lists each duplicated id once", {
    error <- expect_error(
      stagemap(data.frame(id = c("a", "b", "a", "a"), stage = "S")),
      class = "stagemap_error_data"
    )
    expect_match(conditionMessage(error), "Rows 1, 3 and 4")
    expect_match(conditionMessage(error), "Duplicated ids: \"a\"\\.")
  })
})
