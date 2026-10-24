# Each edge has distinct endpoints, so adding kinds does not create duplicates.
kind_map <- function(n) {
  checkmate::assert_count(n, positive = TRUE)
  stagemap(
    data.frame(id = as.character(seq_len(n + 1L)), stage = "S"),
    data.frame(from = "1", to = as.character(seq_len(n) + 1L), kind = paste0("kind", seq_len(n)))
  )
}

describe("sm_kind()", {
  it("keeps automatic fields and stores checked explicit fields", {
    expect_identical(
      sm_kind(),
      structure(list(line = NULL, colour = NULL, width = NULL, arrow = NULL, mark = NULL), class = "stagemap_kind")
    )
    expect_identical(
      sm_kind("dashed", "red", 2, FALSE, "circle"),
      structure(
        list(line = "dashed", colour = "#FF0000", width = 2, arrow = FALSE, mark = "circle"),
        class = "stagemap_kind"
      )
    )
    for (line in c("solid", "dashed", "dotted", "dotdash", "longdash", "twodash")) {
      expect_identical(sm_kind(line = line)$line, line)
    }
    for (mark in c("none", "circle", "square", "diamond", "bar", "cross")) {
      expect_identical(sm_kind(mark = mark)$mark, mark)
    }
    expect_identical(sm_kind(colour = "from")$colour, "from")
    expect_identical(sm_kind(colour = "to")$colour, "to")
    expect_identical(sm_kind(colour = "#abc")$colour, "#AABBCC")
    expect_identical(sm_kind(colour = "#abcdef80")$colour, "#ABCDEF80")
  })

  it("rejects each invalid style argument", {
    for (bad in list("invalid", NA_character_, c("solid", "dashed"), 1)) {
      expect_error(sm_kind(line = bad), "line", class = "stagemap_error")
      expect_error(sm_kind(mark = bad), "mark", class = "stagemap_error")
    }
    for (bad in list(1, NA_character_, "", c("red", "blue"))) {
      expect_error(sm_kind(colour = bad), "colour", class = "stagemap_error")
    }
    expect_error(sm_kind(colour = "no-such-colour"), "colour.*no-such-colour", class = "stagemap_error")
    for (bad in list(0, -1, Inf, -Inf, NA_real_, NaN, "wide", c(1, 2))) {
      expect_error(sm_kind(width = bad), "width", class = "stagemap_error")
    }
    for (bad in list(1, NA, "yes", c(TRUE, FALSE))) {
      expect_error(sm_kind(arrow = bad), "arrow", class = "stagemap_error")
    }
  })
})

describe("sm_kinds()", {
  it("merges kinds by name and replaces a named kind's whole style", {
    map <- kind_map(2)
    changed <- map |>
      sm_kinds(kind1 = sm_kind(line = "dashed", colour = "from")) |>
      sm_kinds(kind2 = sm_kind(width = 3, arrow = FALSE, mark = "bar")) |>
      sm_kinds(kind1 = sm_kind(colour = "to"))
    expect_identical(
      changed$kinds,
      list(kind1 = sm_kind(colour = "to"), kind2 = sm_kind(width = 3, arrow = FALSE, mark = "bar"))
    )
    expect_identical(
      resolve_kinds(changed),
      data.frame(
        kind = c("kind1", "kind2"),
        line = c("solid", "dashed"),
        colour = c("to", NA_character_),
        width = c(1.5, 3),
        arrow = c(TRUE, FALSE),
        mark = c("none", "bar")
      )
    )
    expect_identical(sm_kinds(changed), changed)
    expect_true(withVisible(sm_kinds(map, kind1 = sm_kind()))$visible)
    expect_warning(
      unused <- sm_kinds(map, other = sm_kind(line = "dotted")),
      "other",
      class = "stagemap_warning_unused"
    )
    expect_identical(unused$kinds$other, sm_kind(line = "dotted"))
    expect_identical(resolve_kinds(unused), resolve_kinds(map))
  })

  it("rejects invalid maps, unnamed values, duplicate keys and non-kind values", {
    map <- kind_map(2)
    expect_error(sm_kinds(NULL), "map", class = "stagemap_error")
    expect_error(sm_kinds(map, sm_kind()), "...", fixed = TRUE, class = "stagemap_error")
    expect_error(sm_kinds(map, a = sm_kind(), a = sm_kind()), "...", fixed = TRUE, class = "stagemap_error")
    expect_error(
      do.call(sm_kinds, c(list(map), setNames(list(sm_kind()), " "))),
      "...",
      fixed = TRUE,
      class = "stagemap_error"
    )
    expect_error(sm_kinds(map, a = "solid"), "stagemap_kind", class = "stagemap_error")
    expect_error(sm_kinds(map, a = NULL), "stagemap_kind", class = "stagemap_error")
    expect_error(resolve_kinds(NULL), "map")
  })
})

describe("resolve_kinds()", {
  it("assigns automatic lines, defaults and marks deterministically", {
    two <- kind_map(2)
    expect_identical(
      resolve_kinds(two),
      data.frame(
        kind = c("kind1", "kind2"),
        line = c("solid", "dashed"),
        colour = rep(NA_character_, 2),
        width = c(1.5, 1.5),
        arrow = c(TRUE, TRUE),
        mark = c("none", "none")
      )
    )
    six <- kind_map(6)
    lines <- c("solid", "dashed", "dotted", "dotdash", "longdash", "twodash")
    expect_identical(resolve_kinds(six)$line, lines)
    expect_identical(resolve_kinds(six)$mark, rep("none", 6))
    eight <- kind_map(8)
    expect_identical(resolve_kinds(eight)$line, c(lines, "solid", "dashed"))
    expect_identical(resolve_kinds(eight)$mark, c(rep("none", 6), "circle", "circle"))
    expect_identical(resolve_kinds(eight), resolve_kinds(eight))
    thirty_one <- resolve_kinds(kind_map(31))
    expect_identical(anyDuplicated(thirty_one[c("line", "mark")]), 0L)
    expect_identical(
      thirty_one$mark,
      c(rep("none", 6), rep(c("circle", "square", "diamond", "bar"), each = 6), "cross")
    )
    all_explicit <- sm_kinds(eight, kind7 = sm_kind(mark = "diamond"))
    expect_identical(resolve_kinds(all_explicit)$mark[7], "diamond")
    empty <- resolve_kinds(stagemap(data.frame(id = "a", stage = "S")))
    expect_identical(
      empty,
      data.frame(
        kind = character(),
        line = character(),
        colour = character(),
        width = numeric(),
        arrow = logical(),
        mark = character()
      )
    )
  })

  it("skips explicit lines while unused automatic lines remain", {
    map <- sm_kinds(kind_map(8), kind2 = sm_kind(line = "solid"), kind4 = sm_kind(line = "dotted"))
    expect_identical(
      resolve_kinds(map)$line,
      c("dashed", "solid", "dotdash", "dotted", "longdash", "twodash", "solid", "dashed")
    )
    expect_identical(resolve_kinds(map)$mark, c(rep("none", 6), "circle", "circle"))
    explicit <- sm_kinds(
      kind_map(2),
      kind1 = sm_kind(line = "twodash", colour = "red", width = 2, arrow = FALSE, mark = "square")
    )
    expect_identical(resolve_kinds(explicit)$colour, c("#FF0000", NA_character_))
    expect_identical(resolve_kinds(explicit)$line, c("twodash", "solid"))
    links <- rbind(explicit$links[2:1, ], explicit$links[1, ])
    reordered <- stagemap(explicit$nodes, transform(links, to = c("3", "2", "3")))
    expect_identical(resolve_kinds(reordered)$kind, c("kind2", "kind1"))
  })

  it("distinguishes automatic kinds from explicit solid and dashed kinds", {
    map <- sm_kinds(kind_map(7), kind1 = sm_kind(line = "solid"), kind2 = sm_kind(line = "dashed"))
    resolved <- resolve_kinds(map)
    expect_identical(resolved$line, c("solid", "dashed", "dotted", "dotdash", "longdash", "twodash", "solid"))
    expect_identical(resolved$mark, c(rep("none", 6), "circle"))
    expect_identical(anyDuplicated(resolved[c("line", "mark")]), 0L)
  })

  it("distinguishes one explicit kind and thirty automatic kinds", {
    map <- sm_kinds(kind_map(31), kind1 = sm_kind(line = "solid"))
    resolved <- resolve_kinds(map)
    expect_identical(anyDuplicated(resolved[c("line", "mark")]), 0L)
    expect_identical(resolved$mark, c(rep("none", 6), rep(c("circle", "square", "diamond", "bar"), each = 6), "cross"))
    explicit_mark <- sm_kinds(map, kind7 = sm_kind(mark = "cross"))
    expect_identical(resolve_kinds(explicit_mark)$mark[7], "cross")
  })

  it("pipes all meaning settings together", {
    nodes <- data.frame(
      id = c("REQ-1", "REQ-2", "TST-1", "RES-1"),
      stage = c("Requirement", "Requirement", "Test", "Result"),
      lane = c("Safety", "Usability", "Safety", "Safety"),
      group = c("Safety", "Usability", "Safety", "Safety"),
      status = c("pass", "missing", "pass", "fail")
    )
    links <- data.frame(from = c("REQ-1", "TST-1"), to = c("TST-1", "RES-1"), kind = c("verifies", "produces"))
    map <- stagemap(nodes, links) |>
      sm_stages(c("Requirement", "Test", "Result")) |>
      sm_lanes(c("Safety", "Usability")) |>
      sm_kinds(verifies = sm_kind(line = "dashed", arrow = TRUE)) |>
      sm_groups(colours = c(Safety = "red")) |>
      sm_status(skip = "not planned")
    expect_s3_class(map, "stagemap")
    expect_identical(resolve_stages(map), c("Requirement", "Test", "Result"))
    expect_identical(resolve_lanes(map), c("Safety", "Usability"))
    expect_identical(resolve_kinds(map)$line, c("dashed", "solid"))
    expect_identical(resolve_groups(map)$colour, c("#FF0000", "#E69F00"))
    expect_identical(resolve_status(map)$text[5], "not planned")
  })
})

describe("resolve_kinds() with explicit styles", {
  it("never gives an automatic kind a line and mark pair that a styled kind uses", {
    # Given seven kinds, the first styled with the pair the overflow would pick
    kinds <- paste0("k", 1:7)
    nodes <- data.frame(id = paste0("n", 1:8), stage = paste0("s", 1:8))
    links <- data.frame(from = paste0("n", 1:7), to = paste0("n", 2:8), kind = kinds)
    map <- stagemap(nodes, links) |> sm_kinds(k1 = sm_kind(line = "solid", mark = "circle"))
    # When the styles are resolved
    styles <- resolve_kinds(map)
    # Then every pair differs
    expect_false(anyDuplicated(paste(styles$line, styles$mark)) > 0L)
    expect_identical(styles$line[2:6], c("solid", "dashed", "dotted", "dotdash", "longdash"))
    expect_identical(styles$mark[7], "none")
  })

  it("keeps an explicit mark and picks a free line for it", {
    nodes <- data.frame(id = paste0("n", 1:3), stage = paste0("s", 1:3))
    links <- data.frame(from = c("n1", "n2"), to = c("n2", "n3"), kind = c("a", "b"))
    map <- stagemap(nodes, links) |>
      sm_kinds(a = sm_kind(line = "solid", mark = "cross"), b = sm_kind(mark = "cross"))
    styles <- resolve_kinds(map)
    expect_identical(styles$line, c("solid", "dashed"))
    expect_identical(styles$mark, c("cross", "cross"))
  })

  it("cycles once every pair is taken", {
    kinds <- paste0("k", 1:38)
    nodes <- data.frame(id = paste0("n", 1:39), stage = "s")
    links <- data.frame(from = paste0("n", 1:38), to = paste0("n", 2:39), kind = kinds)
    styles <- resolve_kinds(stagemap(nodes, links))
    expect_identical(anyDuplicated(paste(styles$line, styles$mark)[1:36]), 0L)
    expect_identical(paste(styles$line, styles$mark)[37:38], c("solid none", "dashed none"))
  })
})
