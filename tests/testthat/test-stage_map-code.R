# A map with steps, changes and variants, and a highlight.
story_map <- function() {
  stage_map(
    data.frame(
      id = c("a", "b"),
      label = c("Draft", "Review"),
      stage = c("w", "c"),
      lane = "docs",
      status = "running",
      variants = c("full", "full, docs")
    ),
    variant = "full"
  ) |>
    add_links(data.frame(from = "a", to = "b")) |>
    add_steps(
      data.frame(id = c("one", "two"), label = c("Start", "Move on")),
      changes = data.frame(step = "two", card = "a", status = "done", stage = "c"),
      intro = "How it went"
    ) |>
    add_variants(data.frame(id = c("full", "docs"), label = c("Full", "Docs"))) |>
    stage_map_highlight(c("a", "b"), links = data.frame(from = "a", to = "b"))
}

describe("stage_map_code()", {
  it("writes code that builds the same map again", {
    expect_code_rebuilds(slim())
    expect_code_rebuilds(small())
    expect_code_rebuilds(full_map())
    expect_code_rebuilds(story_map())
  })

  it("rebuilds a map whose layers were added in another order, up to the order of the JSON keys", {
    # Given zones before links, and the highlight before the steps
    map <- stage_map(
      data.frame(id = c("a", "b"), label = "A", stage = "s", lane = "l", zone = "z")
    ) |>
      add_zones(data.frame(id = "z", label = "Z")) |>
      add_links(data.frame(from = "a", to = "b")) |>
      stage_map_highlight("a") |>
      add_steps(data.frame(id = "one", label = "One"), intro = "Before")
    # Then the code writes the canonical order, so only the order of the keys differs
    code <- expect_code_rebuilds(map, exact = FALSE)
    expect_lt(grep("add_links", code, fixed = TRUE), grep("add_zones", code, fixed = TRUE))
    expect_lt(grep("add_steps", code, fixed = TRUE), grep("stage_map_highlight", code, fixed = TRUE))
    expect_false(identical(run_code(code)$x$data, map$x$data))
  })

  it("starts with library(stagemap), a blank line, the tables, a blank line and the pipeline", {
    code <- unclass(stage_map_code(full_map()))
    expect_identical(code[1:2], c("library(stagemap)", ""))
    expect_match(code[3], "^cards <- data.frame\\($")
    blank <- which(code == "")
    expect_length(blank, 2L)
    expect_match(code[blank[2] + 1L], "^stage_map\\(")
    expect_true(all(nchar(code) <= 80L))
  })

  it("writes the pipeline after one blank line when every table is written in place", {
    code <- unclass(stage_map_code(stage_map(data.frame(id = "a", label = "A", stage = "s", lane = "l"))))
    expect_identical(
      code,
      c(
        "library(stagemap)",
        "",
        "stage_map(data.frame(id = \"a\", label = \"A\", stage = \"s\", lane = \"l\"))"
      )
    )
  })

  it("puts a table in a variable when the call that takes it does not fit on one line with it", {
    # The stages fit on one line, but stage_map() with them does not, so they become a variable too.
    map <- stage_map(
      data.frame(id = c("draft", "review"), label = c("Draft", "Review"), stage = c("write", "check"), lane = "docs"),
      data.frame(id = c("write", "check"), label = c("Write", "Check")),
      title = "A small piece of work"
    ) |>
      add_links(data.frame(from = "draft", to = "review"))
    expect_identical(
      unclass(stage_map_code(map)),
      c(
        "library(stagemap)",
        "",
        "cards <- data.frame(",
        "  id = c(\"draft\", \"review\"),",
        "  label = c(\"Draft\", \"Review\"),",
        "  stage = c(\"write\", \"check\"),",
        "  lane = \"docs\"",
        ")",
        "stages <- data.frame(id = c(\"write\", \"check\"), label = c(\"Write\", \"Check\"))",
        "",
        "stage_map(cards, stages, title = \"A small piece of work\") |>",
        "  add_links(data.frame(from = \"draft\", to = \"review\"))"
      )
    )
  })

  it("leaves out arguments equal to their defaults and stages or lanes taken from the cards", {
    map <- stage_map(
      data.frame(id = "a", label = "A", stage = "s", lane = "l"),
      data.frame(id = "s", label = "s"),
      data.frame(id = "l", label = "l"),
      layout = "grid",
      cell_columns = 1L,
      motion = TRUE
    )
    code <- paste(stage_map_code(map), collapse = "\n")
    expect_no_match(code, "stages|lanes|layout|cell_columns|motion")
  })

  it("writes lanes by name when the stages are left out", {
    map <- stage_map(
      data.frame(id = "a", label = "A", stage = "s", lane = "l"),
      lanes = data.frame(id = "l", label = "L")
    )
    expect_match(paste(stage_map_code(map), collapse = "\n"), "lanes = ", fixed = TRUE)
    expect_code_rebuilds(map)
  })

  it("writes statuses given as a table, and as words", {
    rows <- slim(
      cards = data.frame(id = "a", label = "A", stage = "s", lane = "l", status = "blocked"),
      statuses = data.frame(id = "blocked", label = "Blocked")
    )
    expect_match(paste(stage_map_code(rows), collapse = "\n"), "statuses = statuses", fixed = TRUE)
    expect_code_rebuilds(rows)
    words <- slim(statuses = c(done = "Pass", failed = "Not passed"))
    expect_match(
      paste(stage_map_code(words), collapse = "\n"),
      "c(done = \"Pass\", failed = \"Not passed\")",
      fixed = TRUE
    )
    expect_code_rebuilds(words)
  })

  it("rebuilds panels = FALSE and both values of player", {
    expect_code_rebuilds(slim(panels = FALSE))
    expect_code_rebuilds(slim(player = TRUE))
    expect_code_rebuilds(slim(player = FALSE) |> add_steps(data.frame(id = "one", label = "One")))
  })

  it("leaves out a column that holds only NA, which the map reads as left out", {
    map <- slim(cards = data.frame(id = "a", label = "A", stage = "s", lane = "l", sub = NA_character_))
    expect_no_match(paste(stage_map_code(map), collapse = "\n"), "sub")
    expect_code_rebuilds(map, exact = FALSE)
  })

  it("prints the lines and returns the code invisibly", {
    code <- stage_map_code(slim())
    expect_output(out <- withVisible(print(code)), "library(stagemap)", fixed = TRUE)
    expect_false(out$visible)
    expect_identical(out$value, code)
    expect_identical(format(code), unclass(code))
  })

  it("refuses anything that is not a stage map widget", {
    expect_error(stage_map_code(list()), "must be a widget", class = "stagemap_error_widget")
  })
})

describe("code_map()", {
  it("writes the code of parts that do not build a map", {
    # No cards, and a change without its step: the code is still written, and parses.
    parts <- list(
      tables = list(steps = data.frame(id = "one", label = "One"), changes = data.frame(step = "two", card = "x")),
      args = list(layout = "grid")
    )
    code <- code_map(parts)
    expect_silent(parse(text = code))
    expect_identical(code[5], "stage_map(data.frame()) |>")
    expect_match(code[6], "add_steps(steps, changes = ", fixed = TRUE)
  })

  it("leaves out kinds without links, changes and intro without steps, and an empty highlight", {
    parts <- list(
      tables = list(cards = data.frame(id = "a"), kinds = data.frame(id = "k"), changes = data.frame(step = "s")),
      args = list(intro = "Before", highlight = list(ids = character(), links = NULL))
    )
    code <- paste(code_map(parts), collapse = "\n")
    expect_no_match(code, "kinds|changes|intro|highlight")
  })

  it("refuses a table with the studio's .studio_uid column", {
    parts <- list(tables = list(cards = data.frame(id = "a", .studio_uid = "u1")), args = list())
    expect_error(code_map(parts), "studio_uid")
  })

  it("checks its arguments", {
    expect_error(code_map("x"), "parts")
    expect_error(code_map(list(tables = list(1), args = list())), "tables")
    expect_error(code_map(list(tables = list(), args = 1)), "args")
    expect_error(code_map_given(1, stage_map), "args")
    expect_error(code_map_given(list(), "f"), "fn")
    expect_error(code_map_table_args("x"), "call")
    expect_error(code_map_node("x", list(), character()), "call")
    expect_error(code_map_node(list(), "x", character()), "tables")
    expect_error(code_map_node(list(), list(), 1), "variables")
  })
})
