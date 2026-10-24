describe("sm_layout()", {
  it("stores defaults and each setting visibly without changing the data", {
    map <- stagemap(data.frame(id = "a", stage = "A"))
    changed <- sm_layout(map)
    expect_identical(changed$options$layout, list(direction = "LR", order = "auto", spacing = 1))
    expect_identical(changed$nodes, map$nodes)
    expect_identical(changed$links, map$links)
    expect_identical(format(changed), format(map))
    expect_true(withVisible(sm_layout(map))$visible)
    changed <- map |> sm_layout(direction = "TB", order = "data", spacing = 0.25)
    expect_identical(changed$options$layout, list(direction = "TB", order = "data", spacing = 0.25))
    expect_identical(sm_layout(changed, spacing = 4)$options$layout$spacing, 4)
    expect_identical(sm_layout(map, "LR", "auto", 2)$options$layout$spacing, 2)
  })

  it("rejects invalid maps, choices and spacing with the package error class", {
    map <- stagemap(data.frame(id = "a", stage = "A"))
    expect_error(sm_layout(NULL), "map", class = "stagemap_error")
    for (bad in list("RL", NA_character_, c("LR", "TB"), NULL, 1)) {
      expect_error(sm_layout(map, direction = bad), "direction", class = "stagemap_error")
    }
    for (bad in list("other", NA_character_, c("auto", "data"), NULL, 1)) {
      expect_error(sm_layout(map, order = bad), "order", class = "stagemap_error")
    }
    for (bad in list(0.24, 4.01, NA_real_, c(1, 2), Inf, -Inf, "1", NULL)) {
      expect_error(sm_layout(map, spacing = bad), "spacing", class = "stagemap_error")
    }
  })
})
