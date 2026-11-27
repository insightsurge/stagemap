# Plain checks for the Map room view.

describe("studio_room_map_view()", {
  field_names <- function(view) vapply(view$fields, `[[`, "", "name")
  field_by <- function(view, name) view$fields[[match(name, field_names(view))]]

  it("offers the grid, levels and dates fields matching studio_args()", {
    s_grid <- studio_state_new(full_map())
    v_grid <- studio_room_map_view(s_grid)
    expect_identical(field_names(v_grid), c("layout", "cell_columns", "bundle_links", "legend"))
    layout_f <- field_by(v_grid, "layout")
    expect_identical(vapply(layout_f$choices, `[[`, "", "value"), sm_spec()$fields$options$fields$layout$values)
    expect_identical(
      vapply(layout_f$choices, `[[`, "", "label"),
      c("Grid", "Levels (experimental)", "Dates (experimental)")
    )
    expect_null(layout_f$hint)
    expect_identical(
      vapply(field_by(v_grid, "cell_columns")$choices, `[[`, "", "value"),
      c(as.character(1:6), "auto")
    )

    s_levels <- studio_step(
      s_grid,
      list(seq = 1L, type = "option", data = list(name = "layout", value = "levels"), rev = 0L)
    )$state
    v_levels <- studio_room_map_view(s_levels)
    expect_identical(field_names(v_levels), c("layout", "target", "legend"))
    expect_identical(vapply(field_by(v_levels, "target")$choices, `[[`, "", "value"), c("", "a", "b", "c", "d"))

    s_dates <- studio_step(
      s_grid,
      list(seq = 1L, type = "option", data = list(name = "layout", value = "dates"), rev = 0L)
    )$state
    v_dates <- studio_room_map_view(s_dates)
    expect_identical(field_names(v_dates), c("layout", "legend"))
    expect_match(field_by(v_dates, "layout")$hint, "No stage has a date yet")

    # Adding a stage date clears the dates hint
    s_dated <- studio_step(
      s_dates,
      list(
        seq = 2L,
        type = "edit",
        data = list(table = "stages", uid = "u5", field = "date", value = "2026-05-01"),
        rev = 1L
      )
    )$state
    expect_null(field_by(studio_room_map_view(s_dated), "layout")$hint)

    # Offered fields across layouts match studio_args() entries marked "map"
    all_offered <- unique(c(field_names(v_grid), field_names(v_levels), field_names(v_dates)))
    args_tbl <- studio_args()
    map_args <- args_tbl$name[args_tbl$what == "arg" & args_tbl$where == "map"]
    expect_setequal(all_offered, map_args)
  })

  it("attaches target problem in levels view and produces valid option events", {
    s <- studio_state_new(full_map())
    s_lv <- studio_step(
      s,
      list(seq = 1L, type = "option", data = list(name = "layout", value = "levels"), rev = 0L)
    )$state
    s_lv$doc <- studio_doc_apply(s_lv$doc, list(list(op = "arg", name = "target", value = "missing_card")))
    s_lv$check <- studio_state_build(s_lv$doc, 2L, good = s_lv$good)$check
    v_bad <- studio_room_map_view(s_lv)
    target_f <- field_by(v_bad, "target")
    expect_match(target_f$problem$text, "No card has the id")

    for (f in studio_room_map_view(s)$fields) {
      val <- if (identical(f$type, "toggle")) FALSE else f$choices[[1L]]$value
      checked <- studio_event_check(list(
        seq = 1L,
        type = f$event$type,
        data = c(f$event$data, list(value = val)),
        rev = 0L
      ))
      expect_identical(checked$type, "option")
    }
  })

  it("shows each option's current value and sends each field's own event name", {
    set_option <- function(state, name, value) {
      studio_step(
        state,
        list(seq = 1L, type = "option", data = list(name = name, value = value), rev = 0L)
      )$state
    }
    state <- studio_state_new(full_map())
    view <- studio_room_map_view(state)

    # Defaults, and every field names its own option in its event
    expect_identical(field_by(view, "layout")$value, "grid")
    expect_identical(field_by(view, "cell_columns")$value, "1")
    expect_false(field_by(view, "bundle_links")$value)
    expect_true(field_by(view, "legend")$value)
    for (f in view$fields) {
      expect_identical(f$event$type, "option", info = f$name)
      expect_identical(f$event$data$name, f$name, info = f$name)
    }

    # Grid options read back after each change
    cols3 <- studio_room_map_view(set_option(state, "cell_columns", 3L))
    expect_identical(field_by(cols3, "cell_columns")$value, "3")
    cols_auto <- studio_room_map_view(set_option(state, "cell_columns", "auto"))
    expect_identical(field_by(cols_auto, "cell_columns")$value, "auto")
    bundled <- studio_room_map_view(set_option(state, "bundle_links", TRUE))
    expect_true(field_by(bundled, "bundle_links")$value)
    no_legend <- studio_room_map_view(set_option(state, "legend", FALSE))
    expect_false(field_by(no_legend, "legend")$value)
    # The other fields keep their values when one changes
    expect_identical(field_by(no_legend, "cell_columns")$value, "1")
    expect_false(field_by(no_legend, "bundle_links")$value)

    # Layout levels and dates, and the target in levels
    for (layout in c("levels", "dates", "grid")) {
      lay <- studio_room_map_view(set_option(state, "layout", layout))
      expect_identical(field_by(lay, "layout")$value, layout, info = layout)
      expect_identical(field_by(lay, "layout")$event$data$name, "layout", info = layout)
    }
    levels <- set_option(state, "layout", "levels")
    expect_identical(field_by(studio_room_map_view(levels), "target")$value, "")
    targeted <- studio_room_map_view(set_option(levels, "target", "c"))
    expect_identical(field_by(targeted, "target")$value, "c")
    expect_identical(field_by(targeted, "target")$event$data$name, "target")
    expect_identical(field_by(targeted, "legend")$event$data$name, "legend")
  })

  it("checks its argument", {
    expect_error(studio_room_map_view(list(1)), "state")
  })
})
