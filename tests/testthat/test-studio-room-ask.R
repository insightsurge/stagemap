# Plain checks for the Ask room view stub.

describe("studio_room_ask_view()", {
  it("returns empty questions and a NULL answer", {
    state <- studio_state_new(full_map())
    view <- studio_room_ask_view(state)
    expect_identical(view, list(questions = list(), answer = NULL))
    expect_error(studio_room_ask_view(list(1)), "state")
  })
})
