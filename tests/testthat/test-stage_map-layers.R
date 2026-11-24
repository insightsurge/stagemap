describe("add_links()", {
  it("adds the links, and their kinds, to the map's data as rows", {
    map <- small() |> add_links(data.frame(from = "a", to = "b", kind = "k"), kinds = data.frame(id = "k", label = "K"))
    data <- data_of(map)
    expect_identical(data$links, list(list(from = "a", to = "b", kind = "k")))
    expect_identical(data$kinds, list(list(id = "k", label = "K")))
  })

  it("takes a quiet column on the kinds, and sends it as a flag", {
    kinds <- data.frame(id = c("k", "q"), label = c("K", "Q"), quiet = c(NA, TRUE))
    map <- small() |> add_links(data.frame(from = "a", to = "b", kind = "q"), kinds = kinds)
    expect_identical(
      canonical(data_of(map)$kinds),
      list(list(id = "k", label = "K"), list(id = "q", label = "Q", quiet = TRUE))
    )
  })

  it("refuses a quiet column that is not TRUE or FALSE, naming the path", {
    kinds <- data.frame(id = "q", label = "Q", quiet = "yes")
    error <- expect_error(
      add_links(small(), data.frame(from = "a", to = "b"), kinds = kinds),
      class = "stagemap_error_data"
    )
    expect_match(error$problems[1], "`kinds$quiet`", fixed = TRUE)
  })

  it("checks its arguments", {
    expect_error(add_links(small(), "a"), "links")
    expect_error(add_links(small(), data.frame(from = "a", to = "b"), kinds = "k"), "kinds")
    expect_error(add_links(small(), data.frame(from = "a", to = "b"), kind = 1), class = "stagemap_error_dots")
  })

  it("takes an empty data frame, and NULL, as no links, and lets links come after", {
    for (none in list(data.frame(), data.frame(from = character(), to = character()), NULL)) {
      map <- add_links(small(), none)
      expect_null(data_of(map)$links)
      expect_identical(map$x$data, small()$x$data)
    }
    later <- small() |> add_links(data.frame()) |> add_links(data.frame(from = "a", to = "b"))
    expect_identical(data_of(later)$links, list(list(from = "a", to = "b")))
  })

  it("adds no kinds when it adds no links, so a later call can bring both", {
    kinds <- data.frame(id = "k", label = "K")
    map <- add_links(small(), data.frame(), kinds = kinds)
    expect_null(data_of(map)$kinds)
    later <- add_links(map, data.frame(from = "a", to = "b", kind = "k"), kinds = kinds)
    expect_identical(data_of(later)$kinds, list(list(id = "k", label = "K")))
  })

  it("refuses a second set of links, and a widget it did not make", {
    twice <- small() |> add_links(data.frame(from = "a", to = "b"))
    expect_error(add_links(twice, data.frame(from = "b", to = "a")), class = "stagemap_error_layer")
    expect_error(add_links(list(), data.frame(from = "a", to = "b")), class = "stagemap_error_widget")
  })

  it("keeps a column the engine lacks in the R data, quietly", {
    map <- NULL
    expect_no_warning(map <- add_links(small(), data.frame(from = "a", to = "b", weight = 3)))
    expect_identical(sm_widget_data(map)$links$weight, 3)
    expect_null(data_of(map)$links[[1]]$weight)
  })
})

describe("add_zones()", {
  it("adds the zones", {
    map <- small() |> add_zones(data.frame(id = "z", label = "Z"))
    expect_identical(data_of(map)$zones, list(list(id = "z", label = "Z")))
  })

  it("checks its arguments", {
    expect_error(add_zones(small(), 1), "zones")
    expect_error(add_zones(small(), data.frame(id = "z", label = "Z"), 2), class = "stagemap_error_dots")
  })

  it("takes an empty data frame as no zones", {
    expect_null(data_of(add_zones(small(), data.frame()))$zones)
    expect_null(data_of(add_zones(small(), NULL))$zones)
  })

  it("refuses a second set of zones", {
    twice <- small() |> add_zones(data.frame(id = "z", label = "Z"))
    expect_error(add_zones(twice, data.frame(id = "y", label = "Y")), class = "stagemap_error_layer")
  })
})

describe("add_steps()", {
  it("adds the steps, and the caption before the first one under the options", {
    map <- small() |> add_steps(data.frame(id = "x", label = "X"), intro = "Before")
    data <- data_of(map)
    expect_identical(data$steps, list(list(id = "x", label = "X")))
    expect_identical(data$options$intro, "Before")
  })

  it("leaves the caption out when there is none", {
    expect_null(data_of(add_steps(small(), data.frame(id = "x", label = "X")))$options$intro)
  })

  it("checks its arguments", {
    expect_error(add_steps(small(), list()), "steps")
    expect_error(add_steps(small(), data.frame(id = "x", label = "X"), intro = ""), "intro")
    expect_error(add_steps(small(), data.frame(id = "x", label = "X"), NULL, 2), class = "stagemap_error_dots")
    expect_error(add_steps(small(), data.frame(id = "x", label = "X"), NULL), class = "stagemap_error_dots")
    expect_error(add_steps(small(), data.frame(id = "x", label = "X"), changes = "a"), "changes")
    expect_error(add_steps(small(), data.frame(id = "x", label = "X"), extra = 2), class = "stagemap_error_dots")
  })

  it("takes empty steps as none: no steps are added and no player comes", {
    map <- add_steps(small(), data.frame())
    expect_null(data_of(map)$steps)
    expect_true("steps" %in% hosted_of(map))
  })

  it("takes changes and intro only by name, so a changes data frame given by position is an error", {
    expect_identical(names(formals(add_steps)), c("map", "steps", "...", "changes", "intro"))
    error <- expect_error(
      add_steps(small(), data.frame(id = "x", label = "X"), data.frame(step = "x", card = "a")),
      class = "stagemap_error_dots"
    )
    expect_match(conditionMessage(error), "unnamed", fixed = TRUE)
  })

  it("adds no caption when it adds no steps, so a later call can bring both", {
    map <- add_steps(small(), data.frame(), intro = "Before")
    expect_null(data_of(map)$options$intro)
    later <- add_steps(map, data.frame(id = "x", label = "X"), intro = "Now")
    expect_identical(data_of(later)$options$intro, "Now")
  })

  it("refuses a widget it did not make", {
    expect_error(add_steps(list(), data.frame(id = "x", label = "X")), class = "stagemap_error_widget")
  })

  describe("with changes", {
    steps <- function() data.frame(id = c("x", "y"), label = c("X", "Y"))

    it("adds the changes as rows, one per card per step, and counts NA as unchanged", {
      changes <- data.frame(
        step = c("x", "y", "y"),
        card = c("a", "a", "b"),
        status = c("running", NA, "done"),
        stage = c(NA, "s", NA),
        hidden = c(NA, NA, TRUE)
      )
      data <- data_of(add_steps(small(), steps(), changes = changes))
      expect_identical(
        canonical(data$changes),
        list(
          list(step = "x", card = "a", status = "running"),
          list(step = "y", card = "a", stage = "s"),
          list(step = "y", card = "b", status = "done", hidden = TRUE)
        )
      )
    })

    it("takes ids given as numbers, as text", {
      map <- stage_map(
        data.frame(id = 1:2, label = c("A", "B"), stage = "s", lane = "l"),
        data.frame(id = "s", label = "S"),
        data.frame(id = "l", label = "L")
      )
      data <- data_of(add_steps(
        map,
        data.frame(id = 5, label = "Five"),
        changes = data.frame(step = 5, card = 2, hidden = TRUE)
      ))
      expect_identical(data$changes, list(list(step = "5", card = "2", hidden = TRUE)))
    })

    it("sends no changes when there are none, or an empty data frame", {
      expect_null(data_of(add_steps(small(), steps()))$changes)
      expect_null(data_of(add_steps(small(), steps(), changes = data.frame()))$changes)
    })

    it("wants steps with the changes", {
      error <- expect_error(
        add_steps(small(), NULL, changes = data.frame(step = "x", card = "a")),
        class = "stagemap_error_layer"
      )
      expect_match(conditionMessage(error), "needs `steps`", fixed = TRUE)
    })

    it("refuses a step that steps does not have, with the ids and the fix", {
      error <- expect_error(
        add_steps(small(), steps(), changes = data.frame(step = c("x", "z", "w"), card = "a")),
        class = "stagemap_error_layer"
      )
      expect_identical(error$call[[1]], quote(add_steps))
      expect_match(conditionMessage(error), "changes$step", fixed = TRUE)
      expect_match(conditionMessage(error), "\"z\" and \"w\"", fixed = TRUE)
      expect_match(conditionMessage(error), "add that step", fixed = TRUE)
    })

    it("refuses a card that the map does not have, with the ids and the fix", {
      error <- expect_error(
        add_steps(small(), steps(), changes = data.frame(step = "x", card = c("a", "ghost"))),
        class = "stagemap_error_layer"
      )
      expect_match(conditionMessage(error), "changes$card", fixed = TRUE)
      expect_match(conditionMessage(error), "\"ghost\"", fixed = TRUE)
      expect_match(conditionMessage(error), "cards$id", fixed = TRUE)
    })

    it("refuses a stage that the map does not have, with the ids and the fix", {
      error <- expect_error(
        add_steps(small(), steps(), changes = data.frame(step = "x", card = "a", stage = "nowhere")),
        class = "stagemap_error_layer"
      )
      expect_match(conditionMessage(error), "changes$stage", fixed = TRUE)
      expect_match(conditionMessage(error), "\"nowhere\"", fixed = TRUE)
      expect_match(conditionMessage(error), "stages$id", fixed = TRUE)
      expect_no_error(add_steps(small(), steps(), changes = data.frame(step = "x", card = "a", stage = "s")))
    })

    it("refuses a status that the map does not know, and takes the ones in statuses", {
      error <- expect_error(
        add_steps(small(), steps(), changes = data.frame(step = "x", card = "a", status = "zzz")),
        class = "stagemap_error_layer"
      )
      expect_match(conditionMessage(error), "changes$status", fixed = TRUE)
      expect_match(conditionMessage(error), "\"zzz\"", fixed = TRUE)
      expect_match(conditionMessage(error), "add it to `statuses`", fixed = TRUE)
      expect_no_error(add_steps(small(), steps(), changes = data.frame(step = "x", card = "a", status = "done")))
      with_own <- slim(statuses = data.frame(id = "blocked", label = "Blocked"))
      expect_no_error(add_steps(with_own, steps(), changes = data.frame(step = "x", card = "a", status = "blocked")))
    })

    it("refuses a card changed twice at one step, naming the rows", {
      changes <- data.frame(step = c("x", "y", "x"), card = c("a", "a", "a"), status = c("done", "done", "failed"))
      error <- expect_error(add_steps(small(), steps(), changes = changes), class = "stagemap_error_layer")
      expect_match(conditionMessage(error), "changes a card twice at one step", fixed = TRUE)
      expect_match(conditionMessage(error), "card \"a\" at step \"x\" (rows 1, 3)", fixed = TRUE)
      expect_no_error(add_steps(small(), steps(), changes = changes[1:2, ]))
    })

    it("lists every problem in one error", {
      changes <- data.frame(
        step = c("z", "x", "x"),
        card = c("a", "ghost", "ghost"),
        stage = "nowhere",
        status = "zzz"
      )
      error <- expect_error(add_steps(small(), steps(), changes = changes), class = "stagemap_error_layer")
      for (path in c("changes$step", "changes$card", "changes$stage", "changes$status", "twice")) {
        expect_match(conditionMessage(error), path, fixed = TRUE)
      }
    })

    it("leaves a missing column or an NA to the data check, with its own message", {
      error <- expect_error(
        add_steps(small(), steps(), changes = data.frame(step = "x")),
        class = "stagemap_error_data"
      )
      expect_match(error$problems[1], "`changes` needs a column `card`.", fixed = TRUE)
      error <- expect_error(
        add_steps(small(), steps(), changes = data.frame(step = NA_character_, card = "a")),
        class = "stagemap_error_data"
      )
      expect_match(error$problems[1], "`changes$step[1]` is required but has NA.", fixed = TRUE)
    })

    it("refuses a hidden that is not TRUE or FALSE", {
      error <- expect_error(
        add_steps(small(), steps(), changes = data.frame(step = "x", card = "a", hidden = "yes")),
        class = "stagemap_error_data"
      )
      expect_match(error$problems[1], "`changes$hidden` must be TRUE or FALSE", fixed = TRUE)
    })

    it("reports a wrong type or a missing column before it checks the changes against the steps", {
      error <- expect_error(
        add_steps(small(), steps(), changes = data.frame(step = TRUE, card = "a")),
        class = "stagemap_error_data"
      )
      expect_match(error$problems[1], "`changes$step`", fixed = TRUE)
      error <- expect_error(
        add_steps(small(), steps(), changes = data.frame(step = "nope")),
        class = "stagemap_error_data"
      )
      expect_match(error$problems[1], "`changes` needs a column `card`.", fixed = TRUE)
    })

    it("says the widget already has steps before it checks the changes", {
      once <- small() |> add_steps(steps())
      error <- expect_error(
        add_steps(once, steps(), changes = data.frame(step = "nope", card = "ghost")),
        class = "stagemap_error_layer"
      )
      expect_match(conditionMessage(error), "already has", fixed = TRUE)
      expect_no_match(conditionMessage(error), "ghost", fixed = TRUE)
    })

    it("accepts ids that print with an exponent: a card 100000 changed by a step", {
      map <- slim(cards = data.frame(id = 100000L, label = "Big", stage = "s", lane = "l"))
      added <- add_steps(map, data.frame(id = "x", label = "X"), changes = data.frame(step = "x", card = 100000))
      expect_identical(data_of(added)$changes, list(list(step = "x", card = "100000")))
      twice <- data.frame(step = c("x", "x"), card = c(100000, 100000))
      error <- expect_error(
        add_steps(map, data.frame(id = "x", label = "X"), changes = twice),
        class = "stagemap_error_layer"
      )
      expect_match(conditionMessage(error), "card \"100000\" at step \"x\" (rows 1, 2)", fixed = TRUE)
    })

    it("refuses a second set of steps", {
      error <- expect_error(
        add_steps(small() |> add_steps(steps()), steps(), changes = data.frame(step = "x", card = "a")),
        class = "stagemap_error_layer"
      )
      expect_match(conditionMessage(error), "steps", fixed = TRUE)
    })
  })
})

describe("add_variants()", {
  it("adds the variants", {
    map <- small() |> add_variants(data.frame(id = "v", label = "V"))
    expect_identical(data_of(map)$variants, list(list(id = "v", label = "V")))
  })

  it("checks its arguments", {
    expect_error(add_variants(small(), "v"), "variants")
    expect_error(add_variants(small(), data.frame(id = "v", label = "V"), 2), class = "stagemap_error_dots")
  })

  it("takes an empty data frame as no variants", {
    expect_null(data_of(add_variants(small(), data.frame()))$variants)
  })
})

describe("the data layers together", {
  it("take the map as their first argument", {
    for (layer in list(add_links, add_zones, add_steps, add_variants)) {
      expect_identical(names(formals(layer))[[1]], "map")
    }
    error <- expect_error(add_zones(list(), data.frame(id = "z", label = "Z")), class = "stagemap_error_widget")
    expect_match(conditionMessage(error), "map", fixed = TRUE)
  })

  it("pipe in any order, and the data reaches the engine checked as it would be in one call", {
    map <- small() |>
      add_zones(data.frame(id = "z", label = "Z")) |>
      add_links(data.frame(from = "a", to = "b"))
    expect_setequal(names(data_of(map)), c("options", "stages", "lanes", "cards", "zones", "links"))
    error <- expect_error(add_links(small(), data.frame(from = "a")), class = "stagemap_error_data")
    expect_identical(error$call[[1]], quote(add_links))
  })

  it("keep the options the map was built with, the highlight, the hidden panels and the size", {
    map <- slim(highlight = list(ids = "a"), panels = FALSE, height = 300) |>
      add_links(data.frame(from = "a", to = "a")) |>
      add_steps(data.frame(id = "x", label = "X"), intro = "I")
    expect_identical(data_of(map)$options$highlight, list(ids = list("a")))
    expect_identical(data_of(map)$options$dismiss, "no_outside")
    expect_setequal(hosted_of(map), c("details", "stage", "zones"))
    expect_identical(map$height, 300)
  })
})
