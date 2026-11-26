# The studio's view: the sections the page draws, computed from the state.

delayedAssign("small", full_map(title = "A map"))

describe("studio_view()", {
  it("has the header, the status, the notice and the code", {
    view <- studio_view(studio_state_new(small))
    expect_named(view, c("header", "status", "notice", "code"))
    expect_identical(view$header, list(title = "A map", facts = "4 cards in 3 stages and 2 lanes", template = NULL))
    expect_identical(view$status, list(drawn_rev = 0L, problems = 0L, closed = FALSE))
    expect_null(view$notice)
  })

  it("shows the notice and the closed state of the state", {
    state <- studio_state_new(small)
    state$notice <- list(n = 1L, text = "No.", tone = "problem", room = NULL)
    state$closed <- TRUE
    view <- studio_view(state)
    expect_identical(view$notice$text, "No.")
    expect_true(view$status$closed)
  })

  it("checks the state", {
    expect_error(studio_view(list(1)), "state")
  })
})

describe("studio_facts()", {
  it("counts cards, stages and lanes, in the singular for one", {
    expect_identical(studio_facts(studio_template("blank")$map), "1 card in 1 stage and 1 lane")
  })

  it("checks the map", {
    expect_error(studio_facts("map"), "map")
  })
})

describe("studio_view_code()", {
  it("is one line, a call that holds the title, written as R text", {
    code <- studio_view_code("Say \"hi\"")
    expect_identical(code$text, "stage_map(cards, title = \"Say \\\"hi\\\"\")")
    expect_identical(code$lines, list(list(spans = list(list(code$text, "")), changed = FALSE)))
    expect_null(code$problem)
    expect_identical(code$downloads, list())
  })

  it("checks the title", {
    expect_error(studio_view_code(NULL), "title")
  })
})
