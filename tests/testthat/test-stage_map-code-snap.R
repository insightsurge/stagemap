# Snapshots of the code stage_map_code() writes, as a person reads it.
describe("stage_map_code() snapshots", {
  it("writes the code of the full test map", {
    expect_snapshot(stage_map_code(full_map()))
  })

  it("writes the code of a map with every layer and every argument it can take", {
    map <- full_map(
      title = "Every layer",
      statuses = c(done = "Pass"),
      cell_columns = 2,
      panels = FALSE,
      variant = "full",
      width = "100%",
      height = "480px"
    ) |>
      add_steps(
        data.frame(id = c("one", "two"), label = c("Start", "Move on"), stage = c("write", "check")),
        changes = data.frame(step = "two", card = "a", stage = "check"),
        intro = "How the notes were written"
      ) |>
      add_variants(data.frame(id = c("full", "docs"), label = c("Full release", "Docs only"))) |>
      stage_map_highlight(c("a", "b"), links = data.frame(from = "a", to = "b"))
    expect_snapshot(stage_map_code(map))
  })
})
