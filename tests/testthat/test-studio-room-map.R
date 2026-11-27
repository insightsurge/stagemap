# Plain checks for the Map room view stub.

describe("studio_room_map_view()", {
  it("returns an empty fields list and checks its argument", {
    state <- studio_state_new(full_map())
    view <- studio_room_map_view(state)
    expect_identical(view, list(fields = list()))
    expect_error(studio_room_map_view(list(1)), "state")
  })
})
