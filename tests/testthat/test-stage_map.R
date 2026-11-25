describe("stage_map() arguments", {
  it("makes a widget for the stage map from the smallest valid call", {
    widget <- slim()
    expect_s3_class(widget, "stagemap_widget")
    expect_identical(widget$x$engine$visual, "stage-map")
  })

  it("refuses data that is not a data frame", {
    expect_error(slim(cards = list(id = "a")), "cards")
    expect_error(slim(stages = "s"), "stages")
    expect_error(slim(lanes = 1), "lanes")
  })

  it("refuses a title that is not one non-empty string, and takes none", {
    expect_error(slim(title = c("a", "b")), "title")
    expect_error(slim(title = ""), "title")
    expect_error(slim(title = NA_character_), "title")
    expect_no_error(slim(title = NULL))
  })

  it("refuses target and variant that are not one id: text, or a whole number", {
    expect_error(slim(target = ""), "target")
    expect_error(slim(variant = ""), "variant")
    expect_error(slim(target = 1.5), "target")
    expect_error(slim(variant = NA), "variant")
    expect_error(slim(variant = c("a", "b")), "variant")
    expect_error(slim(target = TRUE), "target")
  })

  it("refuses target and variant that are blank text, and takes whole numbers of any size", {
    expect_error(slim(target = "   "), "target")
    expect_error(slim(variant = "\t"), "variant")
    expect_error(slim(target = 1.5e-3), "target")
    big <- slim(cards = data.frame(id = 3e9, label = "A", stage = "s", lane = "l"), target = 3e9, variant = 1e12)
    expect_identical(data_of(big)$options$target, "3000000000")
    expect_identical(data_of(big)$options$variant, "1000000000000")
  })

  it("takes target and variant given as whole numbers, and sends them as text like any id", {
    map <- slim(cards = data.frame(id = 7, label = "A", stage = "s", lane = "l"), target = 7, variant = 100000L)
    options <- data_of(map)$options
    expect_identical(options$target, "7")
    expect_identical(options$variant, "100000")
    expect_identical(data_of(slim(target = "a", variant = "v"))$options$variant, "v")
  })

  it("does not take the layers' data, and says which arguments it takes", {
    error <- expect_error(slim(links = data.frame(from = "a", to = "a")), class = "stagemap_error_dots")
    expect_match(conditionMessage(error), "links", fixed = TRUE)
    expect_match(conditionMessage(error), "dismiss", fixed = TRUE)
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
    expect_error(slim(cell_columns = NULL), "cell_columns")
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
    expect_match(error$problems[1], "`cards` needs a column `label`.", fixed = TRUE)
  })

  it("counts an optional column that is all NA as left out, as readr types an empty column", {
    cards <- data.frame(id = "a", label = "A", stage = "s", lane = "l", sub = NA, status = NA)
    stages <- data.frame(id = "s", label = "S", date = NA)
    widget <- slim(cards = cards, stages = stages)
    expect_null(data_of(widget)$cards[[1]]$sub)
    expect_null(data_of(widget)$stages[[1]]$date)
  })
})

describe("stage_map() and the columns the engine has no field for", {
  cards <- data.frame(id = c("a", "b"), label = c("A", "B"), stage = "s", lane = "l", owner = c("Ann", "Bo"), n = 3:4)

  it("takes them without a warning, in any of the three data frames", {
    expect_no_warning(slim(cards = cards, stages = data.frame(id = "s", label = "S", rank = 1)))
    expect_no_warning(slim(cards = cards, lanes = data.frame(id = "l", label = "L", team = "x")))
  })

  it("does not send them to the engine", {
    json <- unclass(slim(cards = cards)$x$data)
    expect_false(grepl("owner|Ann", json))
    expect_identical(names(data_of(slim(cards = cards))$cards[[1]]), c("id", "label", "stage", "lane"))
  })

  it("keeps them in the data the widget holds in R, for the functions that read the map there", {
    widget <- slim(cards = cards)
    expect_identical(sm_widget_data(widget)$cards$owner, c("Ann", "Bo"))
    expect_identical(sm_widget_data(widget)$cards$n, 3:4)
  })

  it("keeps them after a layer is added", {
    widget <- add_links(slim(cards = cards), data.frame(from = "a", to = "b", weight = 2))
    expect_identical(sm_widget_data(widget)$cards$owner, c("Ann", "Bo"))
    expect_identical(sm_widget_data(widget)$links$weight, 2)
  })

  it("still warns about a misspelt name inside an option, and names it", {
    warning <- expect_warning(
      stage_map(
        data.frame(id = "a", label = "A", stage = "s", lane = "l"),
        data.frame(id = "s", label = "S"),
        data.frame(id = "l", label = "L"),
        statuses = c(done = "Pass", bogus = "x")
      ),
      class = "stagemap_warning_unused_columns"
    )
    expect_identical(warning$dropped, list("options$statuses" = "bogus"))
    expect_identical(warning$call[[1]], quote(stage_map))
  })
})

describe("stage_map() mapping", {
  it("puts the options under options as the engine wants them, with the defaults sent too and the unset left out", {
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
        cell_columns = "1",
        bundle_links = FALSE,
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
    expect_true(data_of(slim())$options$legend)
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
    cards <- data.frame(id = "a", label = "A", stage = "s", lane = "l", status = "blocked")
    widget <- slim(cards = cards, statuses = data.frame(id = "blocked", label = "Blocked"))
    expect_identical(data_of(widget)$cards[[1]]$status, "blocked")
  })

  it("refuses a card status that is neither built in nor in statuses, naming the value, the ids and the fix", {
    cards <- data.frame(id = c("a", "b"), label = c("A", "B"), stage = "s", lane = "l", status = c("done", "zzz"))
    error <- expect_error(slim(cards = cards), class = "stagemap_error_data")
    message <- conditionMessage(error)
    expect_match(message, "cards$status", fixed = TRUE)
    expect_match(message, "\"zzz\"", fixed = TRUE)
    expect_match(message, "\"done\", \"running\", \"waiting\", \"failed\", and \"skipped\"", fixed = TRUE)
    expect_match(message, "add it to `statuses`", fixed = TRUE)
    # The ids of a statuses data frame are allowed, and so are the five built-in ones
    expect_no_error(slim(cards = cards, statuses = data.frame(id = "zzz", label = "Z")))
    expect_no_error(slim(cards = cards[1, ]))
  })

  it("takes the built-in status ids from the engine's contract, not from a list of its own", {
    built_in <- names(sm_spec()$fields$options$fields$statuses$fields)
    expect_gt(length(built_in), 0L)
    for (id in built_in) {
      expect_no_error(slim(cards = data.frame(id = "a", label = "A", stage = "s", lane = "l", status = id)))
    }
  })

  it("compares ids as the page receives them: 100000 is \"100000\", never \"1e+05\"", {
    cards <- data.frame(id = 100000L, label = "A", stage = "s", lane = "l", status = 100000)
    widget <- slim(cards = cards, statuses = data.frame(id = "100000", label = "Big"))
    expect_identical(data_of(widget)$cards[[1]]$status, "100000")
    widget <- slim(cards = cards, statuses = data.frame(id = 100000, label = "Big"))
    expect_identical(data_of(widget)$statuses[[1]]$id, "100000")
    expect_error(slim(statuses = data.frame(id = c(100000, 100000), label = c("A", "B"))), "statuses$id", fixed = TRUE)
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
    expect_identical(data_of(slim())$options$cell_columns, "1")
    expect_false(data_of(slim())$options$bundle_links)
  })

  it("sends numeric ids as text, so a card's stage still names its stage", {
    widget <- slim(
      cards = data.frame(id = 1:2, label = c("A", "B"), stage = 7, lane = "l"),
      stages = data.frame(id = 7, label = "S")
    )
    data <- data_of(widget)
    expect_identical(data$cards[[2]]$id, "2")
    expect_identical(data$cards[[1]]$stage, "7")
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

describe("the defaults the help pages quote", {
  it("come from the contract", {
    expect_identical(sm_default("options", "layout"), "`\"grid\"`")
    expect_identical(sm_default("cards", "milestone"), "`FALSE`")
    expect_identical(sm_default("options", "legend"), "`TRUE`")
  })

  it("refuse a field the contract gives no default", {
    expect_error(sm_default("options", "title"), class = "stagemap_error_spec")
  })
})

describe("stage_map() names", {
  it("takes the cards as its first argument, with no default, and not under its old name", {
    expect_identical(names(formals(stage_map))[[1]], "cards")
    expect_true(is.symbol(formals(stage_map)$cards) && !nzchar(as.character(formals(stage_map)$cards)))
    error <- expect_error(
      stage_map(
        cards = data.frame(id = "a", label = "A", stage = "s", lane = "l"),
        stages = data.frame(id = "s", label = "S"),
        lanes = data.frame(id = "l", label = "L"),
        nodes = data.frame(id = "a", label = "A", stage = "s", lane = "l")
      ),
      class = "stagemap_error_dots"
    )
    expect_match(conditionMessage(error), "nodes", fixed = TRUE)
    expect_error(stage_map(), "cards")
  })

  it("sends the cards under their name, and never the old one", {
    data <- data_of(slim())
    expect_identical(names(data$cards[[1]]), c("id", "label", "stage", "lane"))
    expect_null(data$nodes)
  })

  it("sends the lines of a stage's and a step's code as code_lines, and drops the old column name", {
    stages <- data.frame(id = "s", label = "S", file = "f.R", code = "a\nb", code_lines = "2")
    expect_identical(data_of(slim(stages = stages))$stages[[1]]$code_lines, "2")
    steps <- data.frame(id = "p", label = "P", file = "f.R", code = "a\nb", code_lines = "1")
    expect_identical(data_of(add_steps(slim(), steps))$steps[[1]]$code_lines, "1")
    old <- data.frame(id = "s", label = "S", file = "f.R", code = "a\nb", highlight = "2")
    expect_null(data_of(slim(stages = old))$stages[[1]]$highlight)
    expect_null(data_of(add_steps(slim(), cbind(steps[1:4], highlight = "1")))$steps[[1]]$highlight)
  })
})

describe("stage_map() defaults", {
  it("has the defaults of the engine's contract for layout, motion, legend, cell_columns and bundle_links", {
    options <- sm_spec()$fields$options$fields
    for (name in c("layout", "motion", "legend", "cell_columns", "bundle_links")) {
      expect_identical(
        as.character(formals(stage_map)[[name]]),
        as.character(options[[name]]$default),
        info = name
      )
    }
  })

  it("takes no NULL for them", {
    for (name in c("layout", "motion", "legend", "cell_columns", "bundle_links")) {
      expect_error(do.call(slim, stats::setNames(list(NULL), name)), name)
    }
  })
})

describe("stage_map() with stages and lanes left out", {
  cards <- function(...) data.frame(id = c("a", "b", "c"), label = c("A", "B", "C"), ..., lane = "l")

  it("takes the stages from the cards in order of first appearance, with the id as the label", {
    map <- stage_map(cards(stage = c("two", "one", "two")), lanes = data.frame(id = "l", label = "L"))
    expect_identical(sm_widget_data(map)$stages, data.frame(id = c("two", "one"), label = c("two", "one")))
    expect_identical(data_of(map)$stages, list(list(id = "two", label = "two"), list(id = "one", label = "one")))
  })

  it("takes the lanes the same way, and either table may be given without the other", {
    map <- stage_map(
      data.frame(id = c("a", "b"), label = c("A", "B"), stage = "s", lane = c("y", "x")),
      stages = data.frame(id = "s", label = "Stage")
    )
    expect_identical(sm_widget_data(map)$lanes$id, c("y", "x"))
    expect_identical(data_of(map)$stages[[1]]$label, "Stage")
    map <- stage_map(
      data.frame(id = c("a", "b"), label = c("A", "B"), stage = c("q", "p"), lane = "l"),
      lanes = data.frame(id = "l", label = "Lane")
    )
    expect_identical(sm_widget_data(map)$stages$id, c("q", "p"))
    expect_identical(data_of(map)$lanes[[1]]$label, "Lane")
  })

  it("takes all the levels of a factor in their order, used or not, and not an NA level", {
    stage <- factor(c("b", "a", "b"), levels = c("c", "b", "a"))
    map <- stage_map(cards(stage = stage), lanes = data.frame(id = "l", label = "L"))
    expect_identical(sm_widget_data(map)$stages$id, c("c", "b", "a"))
    with_na <- factor(c("b", "a", NA), levels = c("b", "a", NA), exclude = NULL)
    map <- stage_map(cards(stage = factor(c("b", "a", "b"))), lanes = data.frame(id = "l", label = "L"))
    expect_identical(ids_from_cards(data.frame(stage = with_na), "stage")$id, c("b", "a"))
  })

  it("reports a card whose factor stage is NA when the stages are given", {
    stage <- factor(c("s", NA, "s"), levels = c("s", NA), exclude = NULL)
    error <- expect_error(
      stage_map(cards(stage = stage), data.frame(id = "s", label = "S"), data.frame(id = "l", label = "L")),
      class = "stagemap_error_data"
    )
    expect_match(error$problems[1], "`cards$stage[2]` is required but has NA.", fixed = TRUE)
  })

  it("writes numeric ids as text and leaves NA out, which the cards' own check reports", {
    map <- stage_map(cards(stage = c(2, 1, 2)), lanes = data.frame(id = "l", label = "L"))
    expect_identical(sm_widget_data(map)$stages$id, c("2", "1"))
    error <- expect_error(
      stage_map(cards(stage = c("s", NA, "s")), lanes = data.frame(id = "l", label = "L")),
      class = "stagemap_error_data"
    )
    expect_match(error$problems[1], "`cards$stage[2]` is required but has NA.", fixed = TRUE)
  })

  it("reports a cards table with no stage or lane column once, on the cards", {
    error <- expect_error(
      stage_map(data.frame(id = "a", label = "A", lane = "l"), lanes = data.frame(id = "l", label = "L")),
      class = "stagemap_error_data"
    )
    expect_identical(error$problems, "`cards` needs a column `stage`.")
    error <- expect_error(
      stage_map(data.frame(id = "a", label = "A", stage = "s", lane = "l")[, 1:3]),
      class = "stagemap_error_data"
    )
    expect_identical(error$problems, "`cards` needs a column `lane`.")
  })

  it("does not catch a mistyped stage, because the stage the typo names is made", {
    map <- stage_map(data.frame(id = c("a", "b"), label = c("A", "B"), stage = c("build", "biuld"), lane = "l"))
    expect_identical(sm_widget_data(map)$stages$id, c("build", "biuld"))
  })

  it("lets a later layer check its ids against the stages it made", {
    map <- slim(cards = data.frame(id = "a", label = "A", stage = "s", lane = "l"), stages = NULL, lanes = NULL)
    expect_error(
      add_steps(map, data.frame(id = "p", label = "P"), changes = data.frame(step = "p", card = "a", stage = "zz")),
      "zz"
    )
    expect_no_error(
      add_steps(map, data.frame(id = "p", label = "P"), changes = data.frame(step = "p", card = "a", stage = "s"))
    )
  })

  it("refuses a stages or lanes that is not a data frame", {
    expect_error(slim(stages = "s"), "stages")
    expect_error(slim(lanes = 1), "lanes")
  })
})

describe("stage_map() statuses", {
  it("takes a named character vector of length zero as none, like NULL", {
    expect_identical(slim(statuses = character())$x$data, slim()$x$data)
    expect_identical(slim(statuses = stats::setNames(character(), character()))$x$data, slim()$x$data)
  })

  it("refuses a blank label, in either form, naming the status", {
    error <- expect_error(slim(statuses = c(done = "")), class = "stagemap_error_data")
    expect_match(conditionMessage(error), "A status label cannot be blank.", fixed = TRUE)
    expect_match(conditionMessage(error), "done", fixed = TRUE)
    expect_error(slim(statuses = c(done = "Pass", failed = "   ")), "failed", class = "stagemap_error_data")
    expect_error(
      slim(statuses = data.frame(id = c("blocked", "late"), label = c("Blocked", " "))),
      "late",
      class = "stagemap_error_data"
    )
    expect_no_error(slim(statuses = data.frame(id = c("blocked", "late"), label = c("Blocked", NA))))
  })

  it("reads the label as text, so a blank factor label is refused too", {
    statuses <- data.frame(id = "late", label = factor("   "))
    expect_error(slim(statuses = statuses), "late", class = "stagemap_error_data")
  })

  it("reports a missing id column, not a blank label for NA", {
    error <- expect_error(slim(statuses = data.frame(label = "")), class = "stagemap_error_data")
    expect_identical(error$problems[1], "`statuses` needs a column `id`.")
  })
})

describe("stage_map() with a table that warns about a column it lacks", {
  # A data frame whose `$` warns on a missing column, as a tibble's does.
  it("reads the optional status column without warning when it is not there", {
    registerS3method("$", "stagemap_test_tbl", function(x, name) {
      value <- .subset2(x, name)
      if (is.null(value)) {
        warning("Unknown or uninitialised column: ", name)
      }
      value
    })
    cards <- data.frame(id = "a", label = "A", stage = "s", lane = "l")
    class(cards) <- c("stagemap_test_tbl", "data.frame")
    expect_no_warning(slim(cards = cards))
    changes <- data.frame(step = "p", card = "a")
    class(changes) <- c("stagemap_test_tbl", "data.frame")
    expect_no_warning(add_steps(slim(), data.frame(id = "p", label = "P"), changes = changes))
  })
})
