# Plain checks for the R code room view stub.

describe("studio_room_code_view()", {
  it("builds code_map() lines for the current document, including a broken one", {
    state <- studio_state_new(full_map(title = "Say \"hi\""))
    code <- studio_room_code_view(state)
    expected <- code_map(studio_doc_parts(state$doc))
    expect_identical(code$text, paste(expected, collapse = "\n"))
    expect_length(code$lines, length(expected))
    expect_null(code$problem)
    expect_identical(code$downloads, list())

    broken <- studio_room_code_view(studio_state_new())
    expect_match(broken$text, "Dose calculator validation", fixed = TRUE)
    expect_error(studio_room_code_view(list(1)), "state")
  })
})
