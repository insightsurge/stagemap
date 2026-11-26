describe("stage_map_tables()", {
  it("gives back the tables the map holds, in their order, with every column", {
    # Given a map with every layer
    map <- full_map() |>
      add_steps(
        data.frame(id = "one", label = "One"),
        changes = data.frame(step = "one", card = "a", status = "done")
      ) |>
      add_variants(data.frame(id = "v", label = "V"))
    # When
    tables <- stage_map_tables(map)
    # Then
    expect_identical(
      names(tables),
      c("cards", "stages", "lanes", "links", "kinds", "zones", "steps", "changes", "variants")
    )
    expect_identical(tables$cards$owner, c("Ann", "Bo", "Cy", "Di"))
    expect_identical(tables$zones, data.frame(id = "sign", label = "Needs sign-off", note = "Two people read it."))
  })

  it("gives the stages and lanes taken from the cards when none were given", {
    map <- stage_map(data.frame(id = "a", label = "A", stage = factor("s", levels = c("t", "s")), lane = "l"))
    tables <- stage_map_tables(map)
    expect_identical(tables$stages, data.frame(id = c("t", "s"), label = c("t", "s")))
    expect_identical(tables$lanes, data.frame(id = "l", label = "l"))
  })

  it("holds statuses only when they were given as a data frame", {
    rows <- data.frame(id = "blocked", label = "Blocked")
    expect_identical(stage_map_tables(slim(statuses = rows))$statuses, rows)
    expect_null(stage_map_tables(slim(statuses = c(done = "Pass")))$statuses)
  })

  it("refuses anything that is not a stage map widget", {
    expect_error(stage_map_tables("map"), "must be a widget", class = "stagemap_error_widget")
    expect_error(stage_map_tables(NULL), class = "stagemap_error_widget")
  })
})

describe("map_parts()", {
  it("gives back each argument of stage_map() set to a value that is not its default", {
    given <- list(
      title = "T",
      layout = "levels",
      target = "a",
      variant = "v",
      statuses = c(done = "Pass"),
      motion = FALSE,
      legend = FALSE,
      cell_columns = 3,
      bundle_links = TRUE,
      dismiss = "any",
      player = TRUE,
      panels = FALSE,
      width = "50%",
      height = 300,
      element_id = "m"
    )
    map <- do.call(slim, given)
    args <- map_parts(map)$args
    expect_identical(args[names(given)], given)
    expect_identical(
      names(args),
      c(setdiff(names(formals(stage_map)), c("cards", "stages", "lanes", "...")), "intro", "highlight")
    )
  })

  it("gives the defaults of a plain map, and NULL for the arguments left out", {
    args <- map_parts(slim())$args
    expect_identical(args$layout, "grid")
    expect_identical(args$cell_columns, 1)
    expect_true(args$panels)
    expect_null(args$title)
    expect_null(args$player)
    expect_null(args$statuses)
    expect_null(args$intro)
    expect_null(args$highlight)
    expect_identical(map_parts(slim(cell_columns = "auto"))$args$cell_columns, "auto")
  })

  it("gives player FALSE back, and keeps the player hidden after steps", {
    map <- slim(player = FALSE) |> add_steps(data.frame(id = "one", label = "One"))
    expect_false(map_parts(map)$args$player)
  })

  it("gives the intro of the steps and the highlight", {
    map <- small() |>
      add_steps(data.frame(id = "one", label = "One"), intro = "Before") |>
      stage_map_highlight(c("a", "b"), links = data.frame(from = "a", to = "b"))
    args <- map_parts(map)$args
    expect_identical(args$intro, "Before")
    expect_identical(args$highlight, list(ids = c("a", "b"), links = data.frame(from = "a", to = "b")))
  })

  it("refuses a hosted option that no argument gives, naming it", {
    map <- slim()
    map$stagemap$data$options$hosted <- c("details", "steps")
    expect_error(map_parts(map), "details", class = "stagemap_error_widget")
    map$stagemap$data$options$hosted <- c("steps", "menu")
    expect_error(map_parts(map), "menu", class = "stagemap_error_widget")
    # A player kept on with "steps" hosted.
    on <- slim(player = TRUE)
    on$stagemap$data$options$hosted <- "steps"
    expect_error(map_parts(on), class = "stagemap_error_widget")
  })

  it("checks its arguments", {
    expect_error(map_parts(slim(), call = "x"), "call")
    expect_error(map_check_hosted(1, TRUE, NULL, FALSE, globalenv()), "hosted")
    expect_error(map_check_hosted("steps", NA, NULL, FALSE, globalenv()), "panels")
    expect_error(map_check_hosted("steps", TRUE, "yes", FALSE, globalenv()), "player")
    expect_error(map_check_hosted("steps", TRUE, NULL, NA, globalenv()), "has_steps")
    expect_error(map_check_hosted("steps", TRUE, NULL, FALSE, "x"), "call")
  })
})
