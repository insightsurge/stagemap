skip_unless_extended()

# The round trip of stage_map_code() on many maps: every argument worth setting, a large map, strings that need
# escapes, and columns of every class the code writes. `exact = FALSE` marks the maps that hold a column of only NA.

describe("stage_map_code() on many maps", {
  it("rebuilds every combination of arguments worth having", {
    cases <- list(
      list(title = "T", layout = "levels", target = "a"),
      list(layout = "dates"),
      list(motion = FALSE, legend = FALSE, bundle_links = TRUE, dismiss = "any"),
      list(cell_columns = "auto"),
      list(cell_columns = 6L),
      list(player = TRUE, panels = FALSE),
      list(player = FALSE, panels = FALSE),
      list(width = 400, height = "300px", element_id = "map"),
      list(statuses = c(done = "Pass", waiting = "Queued", skipped = "Left out"))
    )
    for (args in cases) {
      expect_code_rebuilds(do.call(full_map, args))
    }
  })

  it("rebuilds a map of 120 cards in many lanes, with long vectors wrapped", {
    n <- 120L
    cards <- data.frame(
      id = sprintf("card%03d", seq_len(n)),
      label = sprintf("Card number %d", seq_len(n)),
      stage = sprintf("s%d", (seq_len(n) - 1L) %% 8L),
      lane = sprintf("l%d", (seq_len(n) - 1L) %/% 8L),
      status = rep(c("done", "running", "waiting"), length.out = n)
    )
    links <- data.frame(from = cards$id[-n], to = cards$id[-1])
    map <- stage_map(cards) |> add_links(links)
    code <- expect_code_rebuilds(map)
    expect_true(all(nchar(code) <= 80L))
  })

  it("rebuilds strings with quotes, backslashes, newlines and letters beyond ASCII, in a C locale", {
    # The strings are made first: a string written with a Unicode escape in a C locale is not marked as UTF-8.
    labels <- c("say \"yes\"", "back\\slash", "two\nlines", "caf\u00e9 \u4e2d\u6587", "tab\there")
    withr::local_locale(c(LC_CTYPE = "C"))
    map <- stage_map(data.frame(id = letters[1:5], label = labels, stage = "s", lane = "l"))
    expect_code_rebuilds(map)
    expect_identical(stage_map_tables(run_code(stage_map_code(map)))$cards$label, labels)
  })

  it("writes the same code in a C locale as in a UTF-8 one", {
    map <- stage_map(data.frame(id = "a", label = "caf\u00e9 \u00fcber", stage = "s", lane = "l"))
    utf8 <- withr::with_locale(c(LC_CTYPE = "en_US.UTF-8"), unclass(stage_map_code(map)))
    plain <- withr::with_locale(c(LC_CTYPE = "C"), unclass(stage_map_code(map)))
    expect_identical(charToRaw(paste(plain, collapse = "\n")), charToRaw(paste(utf8, collapse = "\n")))
  })

  it("rebuilds factor and Date columns, numeric ids and a one-row table", {
    map <- stage_map(
      data.frame(
        id = c(1, 2, 30000000000),
        label = c("A", "B", "C"),
        stage = factor(c("w", "c", "w"), levels = c("w", "c", "x")),
        lane = 7L
      ),
      stages = data.frame(
        id = c("w", "c", "x"),
        label = c("Write", "Check", "Ship"),
        date = as.Date(c("2026-03-02", NA, "2026-03-09"))
      )
    ) |>
      add_links(data.frame(from = 1, to = 2)) |>
      add_zones(data.frame(id = "z", label = "Zone"))
    expect_code_rebuilds(map)
    expect_code_rebuilds(stage_map(data.frame(id = "a", label = "A", stage = factor("s"), lane = "l")))
  })

  it("rebuilds a map with an all-NA column and a column whose name R cannot read bare", {
    cards <- data.frame(
      id = c("a", "b"),
      label = c("A", "B"),
      stage = "s",
      lane = "l",
      sub = NA,
      `owner name` = c("Ann", "Bo"),
      check.names = FALSE
    )
    map <- stage_map(cards)
    code <- expect_code_rebuilds(map, exact = FALSE)
    expect_identical(names(stage_map_tables(run_code(code))$cards), setdiff(names(cards), "sub"))
  })
})
