describe("stage_map() arguments", {
  it("makes a widget for the stage map from the smallest valid call", {
    widget <- slim()
    expect_s3_class(widget, "stagemap_widget")
    expect_identical(widget$x$engine$visual, "stage-map")
  })

  it("refuses data that is not a data frame", {
    expect_error(slim(nodes = list(id = "a")), "nodes")
    expect_error(slim(stages = "s"), "stages")
    expect_error(slim(lanes = 1), "lanes")
  })

  it("refuses a title that is not one non-empty string, and takes none", {
    expect_error(slim(title = c("a", "b")), "title")
    expect_error(slim(title = ""), "title")
    expect_error(slim(title = NA_character_), "title")
    expect_no_error(slim(title = NULL))
  })

  it("refuses text options that are not one string", {
    expect_error(slim(target = ""), "target")
    expect_error(slim(variant = 1), "variant")
  })

  it("does not take the layers' data, and says which arguments it takes", {
    error <- expect_error(slim(links = data.frame(from = "a", to = "a")), class = "stagemap_error_dots")
    expect_match(conditionMessage(error), "links", fixed = TRUE)
    expect_match(conditionMessage(error), "highlight", fixed = TRUE)
  })

  it("takes the layout from the engine's list in its contract, not from a list of its own", {
    expect_error(slim(layout = "circle"), "layout")
    for (layout in sm_spec()$fields$options$fields$layout$values) {
      expect_identical(data_of(slim(layout = layout))$options$layout, layout)
    }
  })

  it("takes a layout that a later copy of the engine lists, with no change to the package", {
    fields <- sm_spec()$fields
    fields$options$fields$layout$values <- c("grid", "snake")
    local_spec(list(fields = fields))
    expect_identical(data_of(slim(layout = "snake"))$options$layout, "snake")
    expect_error(slim(layout = "dates"), "layout")
  })

  it("refuses an option that is not TRUE or FALSE", {
    expect_error(slim(motion = "yes"), "motion")
    expect_error(slim(legend = NA), "legend")
    expect_error(slim(player = "no"), "player")
    expect_error(slim(panels = NULL), "panels")
    expect_error(slim(panels = NA), "panels")
  })

  it("wants statuses named, with text for each", {
    expect_error(slim(statuses = c("Pass", "Fail")), "statuses")
    expect_error(slim(statuses = c(done = "Pass", done = "Again")), "statuses")
    expect_error(slim(statuses = c(done = NA)), "statuses")
    expect_error(slim(statuses = list(done = "Pass")), "statuses")
  })

  it("takes statuses as a data frame, and a data frame with no rows as none", {
    expect_no_error(slim(statuses = data.frame(id = "blocked", label = "Blocked")))
    empty <- slim(statuses = data.frame(id = character(), label = character()))
    expect_null(data_of(empty)$statuses)
    expect_null(data_of(slim(statuses = data.frame()))$statuses)
  })

  it("refuses a status row with no id column, or a tone the engine does not know, naming the fix", {
    error <- expect_error(slim(statuses = data.frame(label = "Blocked")), class = "stagemap_error_data")
    expect_match(error$problems[1], "`statuses` needs a column `id`.", fixed = TRUE)
    error <- expect_error(slim(statuses = data.frame(id = "blocked", tone = "purple")), class = "stagemap_error_data")
    expect_match(error$problems[1], "`statuses$tone[1]` must be one of \"teal\"", fixed = TRUE)
    expect_match(error$problems[1], "not \"purple\"", fixed = TRUE)
    expect_match(error$problems[1], "\"grey\"", fixed = TRUE)
  })

  it("takes cell_columns as a whole number from 1 to 6 or \"auto\"", {
    expect_no_error(slim(cell_columns = 1))
    expect_no_error(slim(cell_columns = 6L))
    expect_no_error(slim(cell_columns = "auto"))
    expect_no_error(slim(cell_columns = NULL))
    expect_error(slim(cell_columns = 0), "cell_columns")
    expect_error(slim(cell_columns = 7), "cell_columns")
    expect_error(slim(cell_columns = 2.5), "cell_columns")
    expect_error(slim(cell_columns = "wide"), "cell_columns")
    expect_error(slim(cell_columns = c(2, 3)), "cell_columns")
    expect_error(slim(cell_columns = NA), "cell_columns")
  })

  it("refuses a bundle_links that is not TRUE or FALSE", {
    expect_error(slim(bundle_links = "yes"), "bundle_links")
    expect_error(slim(bundle_links = NA), "bundle_links")
    expect_error(slim(bundle_links = c(TRUE, FALSE)), "bundle_links")
  })

  it("checks the size arguments", {
    expect_error(slim(width = TRUE), "width")
    expect_error(slim(height = -1), "height")
    expect_error(slim(element_id = 1), "element_id")
  })

  it("has no id argument: a map's name in a page is not a thing here", {
    expect_false("id" %in% names(formals(stage_map)))
    expect_error(slim(id = "map"), class = "stagemap_error_dots")
  })

  it("names a mistyped option, and a value passed by position after the dots", {
    expect_error(slim(stauts = "x"), class = "stagemap_error_dots")
    error <- expect_error(
      stage_map(
        data.frame(id = "a", label = "A", stage = "s", lane = "l"),
        data.frame(id = "s", label = "S"),
        data.frame(id = "l", label = "L"),
        5
      ),
      class = "stagemap_error_dots"
    )
    expect_match(conditionMessage(error), "unnamed", fixed = TRUE)
  })

  it("reports problems in the data with the function the user called", {
    error <- expect_error(
      stage_map(data.frame(id = "a"), data.frame(id = "s", label = "S"), data.frame(id = "l", label = "L")),
      class = "stagemap_error_data"
    )
    expect_identical(error$call[[1]], quote(stage_map))
    expect_match(error$problems[1], "`nodes` needs a column `label`.", fixed = TRUE)
  })

  it("counts an optional column that is all NA as left out, as readr types an empty column", {
    nodes <- data.frame(id = "a", label = "A", stage = "s", lane = "l", sub = NA, status = NA)
    stages <- data.frame(id = "s", label = "S", date = NA)
    widget <- slim(nodes = nodes, stages = stages)
    expect_null(data_of(widget)$nodes[[1]]$sub)
    expect_null(data_of(widget)$stages[[1]]$date)
  })
})

describe("stage_map() and the columns the engine has no field for", {
  nodes <- data.frame(id = c("a", "b"), label = c("A", "B"), stage = "s", lane = "l", owner = c("Ann", "Bo"), n = 3:4)

  it("takes them without a warning, in any of the three data frames", {
    expect_no_warning(slim(nodes = nodes, stages = data.frame(id = "s", label = "S", rank = 1)))
    expect_no_warning(slim(nodes = nodes, lanes = data.frame(id = "l", label = "L", team = "x")))
  })

  it("does not send them to the engine", {
    json <- unclass(slim(nodes = nodes)$x$data)
    expect_false(grepl("owner|Ann", json))
    expect_identical(names(data_of(slim(nodes = nodes))$nodes[[1]]), c("id", "label", "stage", "lane"))
  })

  it("keeps them in the data the widget holds in R, for the functions that read the map there", {
    widget <- slim(nodes = nodes)
    expect_identical(sm_widget_data(widget)$nodes$owner, c("Ann", "Bo"))
    expect_identical(sm_widget_data(widget)$nodes$n, 3:4)
  })

  it("keeps them after a layer is added", {
    widget <- add_links(slim(nodes = nodes), data.frame(from = "a", to = "b", weight = 2))
    expect_identical(sm_widget_data(widget)$nodes$owner, c("Ann", "Bo"))
    expect_identical(sm_widget_data(widget)$links$weight, 2)
  })

  it("still warns about a misspelt name inside an option, and names it", {
    warning <- expect_warning(
      stage_map(
        data.frame(id = "a", label = "A", stage = "s", lane = "l"),
        data.frame(id = "s", label = "S"),
        data.frame(id = "l", label = "L"),
        highlight = list(ids = "a", lnks = data.frame(from = "a", to = "a"))
      ),
      class = "stagemap_warning_unused_columns"
    )
    expect_identical(warning$dropped, list("options$highlight" = "lnks"))
    expect_identical(warning$call[[1]], quote(stage_map))
    expect_warning(slim(statuses = c(done = "Pass", bogus = "x")), "bogus")
  })
})

describe("stage_map() mapping", {
  it("puts the options under options as the engine wants them, and leaves the unset out", {
    widget <- slim(layout = "levels", target = "a", motion = FALSE, legend = TRUE, variant = "v", title = "T")
    expect_identical(
      data_of(widget)$options,
      list(
        layout = "levels",
        title = "T",
        motion = FALSE,
        target = "a",
        variant = "v",
        legend = TRUE,
        dismiss = "no_outside",
        hosted = list("steps")
      )
    )
  })

  it("carries dismiss = \"no_outside\" when the map is built with no options", {
    expect_identical(data_of(slim())$options$dismiss, "no_outside")
    expect_identical(eval(formals(stage_map)$dismiss), "no_outside")
  })

  it("sends each dismiss the engine lists as given, and refuses any other", {
    for (value in sm_spec()$fields$options$fields$dismiss$values) {
      expect_identical(data_of(slim(dismiss = value))$options$dismiss, value)
    }
    expect_error(slim(dismiss = "never"), "dismiss")
    expect_error(slim(dismiss = c("any", "no_outside")), "dismiss")
    expect_error(slim(dismiss = NULL), "dismiss")
  })

  it("shows the details, the stage panel and the zone notes by default: it hands no panel over", {
    expect_identical(hosted_of(slim(title = "T")), "steps")
    expect_false(any(stage_map_panel_regions %in% hosted_of(slim())))
  })

  it("hides them all with panels = FALSE, by handing those regions over", {
    expect_setequal(hosted_of(slim(panels = FALSE)), c("details", "stage", "zones", "steps"))
    expect_setequal(hosted_of(slim(panels = FALSE, player = TRUE)), c("details", "stage", "zones"))
  })

  it("names only regions the engine's contract lists for hosted", {
    listed <- sm_spec()$fields$options$fields$hosted$values
    expect_true(all(c(stage_map_panel_regions, "steps") %in% listed))
  })

  it("keeps the legend unless it is turned off", {
    expect_null(data_of(slim())$options$legend)
    expect_false(data_of(slim(legend = FALSE))$options$legend)
  })

  it("sends no title without one, and never hands the title over", {
    options <- data_of(slim())$options
    expect_null(options$title)
    expect_false("title" %in% unlist(options$hosted))
  })

  it("shows the step player only with steps or player = TRUE, and never with player = FALSE", {
    steps <- data.frame(id = "x", label = "X")
    expect_true("steps" %in% hosted_of(slim()))
    expect_false("steps" %in% hosted_of(slim(player = TRUE)))
    expect_true("steps" %in% hosted_of(slim(player = FALSE)))
    expect_false("steps" %in% hosted_of(add_steps(slim(), steps)))
    expect_false("steps" %in% hosted_of(add_steps(slim(player = TRUE), steps)))
    expect_true("steps" %in% hosted_of(add_steps(slim(player = FALSE), steps)))
  })

  it("keeps the hidden panels hidden when steps bring the player", {
    widget <- add_steps(slim(panels = FALSE), data.frame(id = "x", label = "X"))
    expect_setequal(hosted_of(widget), c("details", "stage", "zones"))
  })

  it("writes statuses as an object keyed by the engine's statuses", {
    widget <- slim(statuses = c(done = "Pass", failed = "Fail"))
    expect_identical(data_of(widget)$options$statuses, list(done = "Pass", failed = "Fail"))
  })

  it("sends statuses given as a data frame to the data, row by row, and none to the options", {
    statuses <- data.frame(
      id = c("done", "blocked"),
      label = c("Passed", "Blocked"),
      tone = c("good", NA),
      icon = c(NA, "lock")
    )
    data <- data_of(slim(statuses = statuses))
    expect_identical(
      canonical(data$statuses),
      list(list(id = "done", label = "Passed", tone = "good"), list(id = "blocked", label = "Blocked", icon = "lock"))
    )
    expect_null(data$options$statuses)
  })

  it("lets a card use the id of a status given in the data frame", {
    nodes <- data.frame(id = "a", label = "A", stage = "s", lane = "l", status = "blocked")
    widget <- slim(nodes = nodes, statuses = data.frame(id = "blocked", label = "Blocked"))
    expect_identical(data_of(widget)$nodes[[1]]$status, "blocked")
  })

  it("refuses a card status that is neither built in nor in statuses, naming the value, the ids and the fix", {
    nodes <- data.frame(id = c("a", "b"), label = c("A", "B"), stage = "s", lane = "l", status = c("done", "zzz"))
    error <- expect_error(slim(nodes = nodes), class = "stagemap_error_data")
    message <- conditionMessage(error)
    expect_match(message, "nodes$status", fixed = TRUE)
    expect_match(message, "\"zzz\"", fixed = TRUE)
    expect_match(message, "\"done\", \"running\", \"waiting\", \"failed\", and \"skipped\"", fixed = TRUE)
    expect_match(message, "add it to `statuses`", fixed = TRUE)
    # The ids of a statuses data frame are allowed, and so are the five built-in ones
    expect_no_error(slim(nodes = nodes, statuses = data.frame(id = "zzz", label = "Z")))
    expect_no_error(slim(nodes = nodes[1, ]))
  })

  it("takes the built-in status ids from the engine's contract, not from a list of its own", {
    built_in <- names(sm_spec()$fields$options$fields$statuses$fields)
    expect_gt(length(built_in), 0L)
    for (id in built_in) {
      expect_no_error(slim(nodes = data.frame(id = "a", label = "A", stage = "s", lane = "l", status = id)))
    }
  })

  it("refuses a statuses data frame that gives an id twice", {
    error <- expect_error(
      slim(statuses = data.frame(id = c("blocked", "blocked"), label = c("Blocked", "Again"))),
      class = "stagemap_error_data"
    )
    expect_match(conditionMessage(error), "statuses$id", fixed = TRUE)
    expect_match(conditionMessage(error), "\"blocked\"", fixed = TRUE)
  })

  it("sends cell_columns as a number or \"auto\", and bundle_links as a flag, under the options", {
    options <- data_of(slim(cell_columns = 3, bundle_links = TRUE))$options
    expect_identical(options$cell_columns, "3")
    expect_true(options$bundle_links)
    expect_identical(data_of(slim(cell_columns = "auto"))$options$cell_columns, "auto")
    expect_false(data_of(slim(bundle_links = FALSE))$options$bundle_links)
    expect_null(data_of(slim())$options$cell_columns)
    expect_null(data_of(slim())$options$bundle_links)
  })

  it("sends numeric ids as text, so a card's stage still names its stage", {
    widget <- slim(
      nodes = data.frame(id = 1:2, label = c("A", "B"), stage = 7, lane = "l"),
      stages = data.frame(id = 7, label = "S")
    )
    data <- data_of(widget)
    expect_identical(data$nodes[[2]]$id, "2")
    expect_identical(data$nodes[[1]]$stage, "7")
    expect_identical(data$stages[[1]]$id, "7")
  })

  it("accepts a tibble-like data frame and a Date for a stage", {
    stages <- data.frame(id = "s", label = "S")
    stages$date <- as.Date("2026-03-02")
    class(stages) <- c("tbl_df", "tbl", "data.frame")
    expect_identical(data_of(slim(stages = stages))$stages[[1]]$date, "2026-03-02")
  })

  it("passes the user's size and element id on", {
    widget <- slim(width = "50%", height = 400, element_id = "map")
    expect_identical(widget$width, "50%")
    expect_identical(widget$height, 400)
    expect_identical(widget$elementId, "map")
  })

  it("keeps the player choice beside the data, not in what the page receives", {
    expect_false(slim(player = FALSE)$stagemap$keep$player)
    expect_null(slim()$stagemap$keep$player)
    expect_false(grepl("player", unclass(slim(player = FALSE)$x$data), fixed = TRUE))
  })
})

describe("stage_map() highlight", {
  it("sends the ids and the links to the engine's highlight option, with ids as text and links as rows", {
    widget <- slim(
      nodes = data.frame(id = 1:2, label = c("A", "B"), stage = "s", lane = "l"),
      highlight = list(ids = c(1, 2), links = data.frame(from = 1, to = 2, kind = "k"))
    )
    expect_identical(
      data_of(widget)$options$highlight,
      list(ids = list("1", "2"), links = list(list(from = "1", to = "2", kind = "k")))
    )
  })

  it("takes ids alone, or links as a list of named lists", {
    expect_identical(data_of(slim(highlight = list(ids = "a")))$options$highlight, list(ids = list("a")))
    widget <- slim(highlight = list(ids = "a", links = list(list(from = "a", to = "a"))))
    expect_identical(data_of(widget)$options$highlight$links, list(list(from = "a", to = "a")))
  })

  it("sends nothing for NULL or an empty list, and carries no highlight by default", {
    expect_null(data_of(slim())$options$highlight)
    expect_null(data_of(slim(highlight = NULL))$options$highlight)
    expect_null(data_of(slim(highlight = list()))$options$highlight)
  })

  it("refuses what is not a named list", {
    expect_error(slim(highlight = "a"), "highlight")
    expect_error(slim(highlight = list("a")), "highlight")
  })

  it("names the path of a wrong value inside it", {
    error <- expect_error(slim(highlight = list(ids = 1.5)), class = "stagemap_error_data")
    expect_match(error$problems[1], "`options$highlight$ids[1]`", fixed = TRUE)
    error <- expect_error(slim(highlight = list(links = data.frame(from = "a"))), class = "stagemap_error_data")
    expect_match(error$problems[1], "`options$highlight$links` needs a column `to`.", fixed = TRUE)
  })

  it("keeps it when a layer is added", {
    widget <- add_links(slim(highlight = list(ids = "a")), data.frame(from = "a", to = "a"))
    expect_identical(data_of(widget)$options$highlight, list(ids = list("a")))
  })
})

describe("the defaults the help pages quote", {
  it("come from the contract", {
    expect_identical(sm_default("options", "layout"), "`\"grid\"`")
    expect_identical(sm_default("nodes", "milestone"), "`FALSE`")
    expect_identical(sm_default("options", "legend"), "`TRUE`")
  })

  it("refuse a field the contract gives no default", {
    expect_error(sm_default("options", "title"), class = "stagemap_error_spec")
  })
})
