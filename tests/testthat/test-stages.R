describe("stage and lane order", {
  it("uses first appearance, all factor levels, then explicit settings", {
    nodes <- data.frame(
      id = c("REQ-1", "REQ-2", "TST-1", "RES-1"),
      stage = c("Requirement", "Requirement", "Test", "Result"),
      lane = c("Safety", "Usability", "Safety", "Safety")
    )
    map <- stagemap(nodes)
    expect_identical(resolve_stages(map), c("Requirement", "Test", "Result"))
    expect_identical(resolve_lanes(map), c("Safety", "Usability"))
    nodes$stage <- factor(nodes$stage, levels = c("Result", "Test", "Requirement", "Archive"))
    nodes$lane <- factor(nodes$lane, levels = c("Usability", "Safety", "Other"))
    map <- stagemap(nodes)
    expect_identical(resolve_stages(map), levels(nodes$stage))
    expect_identical(resolve_lanes(map), levels(nodes$lane))
    changed <- map |>
      sm_stages(c("Requirement", "Test", "Result", "Empty")) |>
      sm_lanes(c("Safety", "Usability", "Empty"))
    expect_identical(changed$stages, c("Requirement", "Test", "Result", "Empty"))
    expect_identical(changed$lanes, c("Safety", "Usability", "Empty"))
    expect_identical(resolve_stages(changed), changed$stages)
    expect_identical(resolve_lanes(changed), changed$lanes)
    expect_identical(changed$nodes, map$nodes)
    expect_true(withVisible(sm_stages(map, c("Test", "Requirement", "Result")))$visible)
    expect_true(withVisible(sm_lanes(map, c("Safety", "Usability")))$visible)
    expect_identical(
      format(changed)[2:3],
      c("Stages (4): Requirement, Test, Result, Empty", "Lanes (3): Safety, Usability, Empty")
    )
  })

  it("rejects invalid maps and invalid order vectors", {
    map <- stagemap(data.frame(id = "a", stage = "S", lane = "L"))
    for (bad in list(NULL, 1, NA_character_, "", " ", c("a", "a"), c("a", NA_character_))) {
      expect_error(sm_stages(map, bad), "stages", class = "stagemap_error")
      expect_error(sm_lanes(map, bad), "lanes", class = "stagemap_error")
    }
    expect_error(sm_stages(NULL, "S"), "map", class = "stagemap_error")
    expect_error(sm_lanes(NULL, "L"), "map", class = "stagemap_error")
    expect_error(resolve_stages(NULL), "map")
    expect_error(resolve_lanes(NULL), "map")
  })

  it("names unknown values and their node rows", {
    map <- stagemap(data.frame(id = c("a", "b", "c"), stage = c("A", "B", "B"), lane = c("X", "Y", "Y")))
    expect_error(sm_stages(map, "A"), "Rows 2 and 3.*stage", class = "stagemap_error_data")
    stage_error <- expect_error(sm_stages(map, "A"), "Unknown stages:.*B", class = "stagemap_error_data")
    expect_length(gregexpr("B", conditionMessage(stage_error), fixed = TRUE)[[1]], 1L)
    expect_error(sm_lanes(map, "X"), "Rows 2 and 3.*lane", class = "stagemap_error_data")
    lane_error <- expect_error(sm_lanes(map, "X"), "Unknown lanes:.*Y", class = "stagemap_error_data")
    expect_length(gregexpr("Y", conditionMessage(lane_error), fixed = TRUE)[[1]], 1L)
    expect_error(sm_stages(map, character()), "Row", class = "stagemap_error_data")
    expect_error(sm_lanes(map, character()), "Row", class = "stagemap_error_data")
    plain <- stagemap(data.frame(id = "a", stage = "S"))
    expect_identical(resolve_lanes(plain), character())
    expect_error(sm_lanes(plain, "L"), "no.*lane.*column", class = "stagemap_error")
  })
})

describe("sm_stages() and sm_lanes() without values", {
  it("explains a missing argument", {
    map <- stagemap(data.frame(id = "a", stage = "S", lane = "L"))
    expect_error(sm_stages(map), "stages.*is missing", class = "stagemap_error")
    expect_error(sm_lanes(map), "lanes.*is missing", class = "stagemap_error")
  })
})
