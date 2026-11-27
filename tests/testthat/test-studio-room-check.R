# Plain checks for the Check room view stub.

describe("studio_room_check_view()", {
  it("reflects the document's check status and checks its argument", {
    clean <- studio_room_check_view(studio_state_new(full_map()))
    expect_true(clean$ok)
    expect_null(clean$head)
    expect_identical(clean$faults, list())

    broken <- studio_room_check_view(studio_state_new())
    expect_false(broken$ok)
    expect_type(broken$head, "character")
    expect_error(studio_room_check_view(list(1)), "state")
  })
})
