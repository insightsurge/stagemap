# Plain checks for the Check room view.

describe("studio_room_check_view()", {
  it("returns one clean message when the map builds", {
    clean <- studio_room_check_view(studio_state_new(full_map()))
    expect_true(clean$ok)
    expect_identical(clean$head, "stage_map() accepts this map.")
    expect_identical(clean$lines, list())
    expect_identical(clean$faults, list())
    expect_identical(clean$notes, list())
  })

  it("returns R's lines, fault cards with Show and valid fix events for every fault type", {
    s_ex <- studio_state_new()
    v_ex <- studio_room_check_view(s_ex)
    expect_false(v_ex$ok)
    expect_type(v_ex$head, "character")
    expect_gt(length(v_ex$lines), 0L)
    expect_true(all(vapply(v_ex$lines, function(l) l$mark %in% c("x", "i") && nzchar(l$text), logical(1))))
    expect_length(v_ex$faults, 1L)
    f_ex <- v_ex$faults[[1L]]
    expect_identical(f_ex$where$kind, "link")
    expect_true(nzchar(f_ex$where$uid))
    expect_identical(f_ex$where$field, "to")
    expect_identical(f_ex$fixes[[1L]]$style, "primary")
    expect_identical(f_ex$fixes[[length(f_ex$fixes)]]$style, "danger")

    # Every fix and Show target event passes studio_event_check()
    for (fx in f_ex$fixes) {
      expect_identical(
        studio_event_check(list(seq = 1L, type = fx$event$type, data = fx$event$data, rev = 0L))$type,
        "fix"
      )
    }
    expect_identical(
      studio_event_check(list(
        seq = 1L,
        type = "target",
        data = list(kind = f_ex$where$kind, uid = f_ex$where$uid),
        rev = 0L
      ))$type,
      "target"
    )

    # Blank, duplicate, join, and status faults on inspectable rows and on args/changes
    base <- studio_state_new(
      full_map(title = "A map", target = "b") |>
        add_steps(
          data.frame(id = "s1", label = "Step 1", stage = "write"),
          changes = data.frame(step = "s1", card = "b", stage = "ship", status = "done")
        )
    )
    cases <- list(
      list(type = "edit", data = list(table = "cards", uid = "u1", field = "label", value = ""), kind = "card"),
      list(type = "edit", data = list(table = "cards", uid = "u1", field = "id", value = "b"), kind = "card"),
      list(type = "edit", data = list(table = "cards", uid = "u1", field = "stage", value = "wrte"), kind = "card"),
      list(type = "edit", data = list(table = "cards", uid = "u1", field = "status", value = "don"), kind = "card"),
      list(type = "edit", data = list(table = "stages", uid = "u5", field = "label", value = ""), kind = "stage"),
      list(type = "edit", data = list(table = "lanes", uid = "u8", field = "id", value = ""), kind = "lane")
    )
    for (case in cases) {
      st <- studio_step(base, list(seq = 1L, type = case$type, data = case$data, rev = 0L))$state
      vw <- studio_room_check_view(st)
      expect_false(vw$ok)
      expect_true(any(vapply(vw$faults, function(f) identical(f$where$kind, case$kind), logical(1))))
    }

    # Non-inspectable table fault (args) leaves `where` NULL
    st_arg <- base
    st_arg$doc <- studio_doc_apply(base$doc, list(list(op = "arg", name = "target", value = "bb")))
    built_arg <- studio_state_build(st_arg$doc, 1L, good = st_arg$good)
    st_arg$check <- built_arg$check
    vw_arg <- studio_room_check_view(st_arg)
    expect_null(vw_arg$faults[[1L]]$where)
    expect_gte(length(vw_arg$faults[[1L]]$fixes), 1L)
  })

  it("preserves R's error head, lines and notes when a build fails with no located fault", {
    st <- studio_state_new(full_map())
    st$check <- list(
      ok = FALSE,
      head = "Unexpected build error.",
      lines = list(list(mark = "x", text = "Detail line.")),
      faults = studio_faults_df(),
      notes = "Dropped unused item."
    )
    vw <- studio_room_check_view(st)
    expect_false(vw$ok)
    expect_identical(vw$head, "Unexpected build error.")
    expect_identical(vw$lines, list(list(mark = "x", text = "Detail line.")))
    expect_identical(vw$faults, list())
    expect_identical(vw$notes, list("Dropped unused item."))
  })

  it("checks its argument", {
    expect_error(studio_room_check_view(list(1)), "state")
  })
})
