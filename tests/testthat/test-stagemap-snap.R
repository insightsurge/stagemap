describe("stagemap output", {
  it("prints the example map", {
    nodes <- data.frame(
      id = c("REQ-1", "REQ-2", "TST-1", "RES-1"),
      stage = c("Requirement", "Requirement", "Test", "Result"),
      lane = c("Safety", "Usability", "Safety", "Safety"),
      group = c("Safety", "Usability", "Safety", "Safety"),
      status = c("pass", "missing", "pass", "fail")
    )
    links <- data.frame(from = c("REQ-1", "TST-1"), to = c("TST-1", "RES-1"), kind = c("verifies", "produces"))
    expect_snapshot(print(stagemap(nodes, links)))
  })

  it("explains a missing column", {
    expect_snapshot(error = TRUE, stagemap(data.frame(id = "a")))
  })

  it("explains an unknown endpoint", {
    expect_snapshot(error = TRUE, stagemap(data.frame(id = "a", stage = "S"), data.frame(from = "a", to = "unknown")))
  })

  it("explains unexpected arguments", {
    expect_snapshot(error = TRUE, stagemap(data.frame(id = "a", stage = "S"), foo = 1))
  })
})
