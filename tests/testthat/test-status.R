describe("sm_status() and resolve_status()", {
  it("resolves built-ins, overrides, configured words and node-only words in order", {
    map <- stagemap(data.frame(
      id = c("REQ-1", "REQ-2", "TST-1", "RES-1"),
      stage = c("Requirement", "Requirement", "Test", "Result"),
      status = c("pass", "pending", NA, "fail")
    ))
    expected <- data.frame(
      word = c("pass", "fail", "missing", "warn", "skip", "pending"),
      text = c("Pass", "Fail", "Missing", "Warning", "Skipped", "pending"),
      icon = c("check", "cross", "dash", "warning", "skip", NA_character_),
      tone = c("good", "bad", "bad", "warn", "neutral", "neutral"),
      used = c(TRUE, TRUE, FALSE, FALSE, FALSE, TRUE)
    )
    expect_identical(resolve_status(map), expected)
    changed <- map |>
      sm_status(skip = "not planned", review = "In review") |>
      sm_status(pass = "Complete", review = "Review")
    expect_identical(changed$status, c(skip = "not planned", review = "Review", pass = "Complete"))
    resolved <- resolve_status(changed)
    expect_identical(resolved$word, c("pass", "fail", "missing", "warn", "skip", "review", "pending"))
    expect_identical(resolved$text, c("Complete", "Fail", "Missing", "Warning", "not planned", "Review", "pending"))
    expect_identical(resolved$icon, c("check", "cross", "dash", "warning", "skip", NA_character_, NA_character_))
    expect_identical(resolved$tone, c("good", "bad", "bad", "warn", "neutral", "neutral", "neutral"))
    expect_identical(resolved$used, c(TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, TRUE))
    expect_identical(sm_status(changed), changed)
    expect_true(withVisible(sm_status(map, skip = "not planned"))$visible)
    plain <- stagemap(data.frame(id = "a", stage = "S"))
    expect_identical(resolve_status(plain)$used, rep(FALSE, 5))
    expect_identical(resolve_status(sm_status(map, pending = "Waiting"))$used, expected$used)
  })

  it("rejects invalid maps, keys and badge strings", {
    map <- stagemap(data.frame(id = "a", stage = "S"))
    expect_error(sm_status(NULL), "map", class = "stagemap_error")
    expect_error(resolve_status(NULL), "map")
    expect_error(sm_status(map, "Text"), "...", fixed = TRUE, class = "stagemap_error")
    expect_error(sm_status(map, a = "A", a = "B"), "...", fixed = TRUE, class = "stagemap_error")
    expect_error(
      do.call(sm_status, c(list(map), setNames(list("A"), " "))),
      "...",
      fixed = TRUE,
      class = "stagemap_error"
    )
    for (bad in list(NULL, NA_character_, "", " ", 1, TRUE, c("A", "B"), list("A"))) {
      expect_error(sm_status(map, word = bad), "word", class = "stagemap_error")
    }
  })
})
