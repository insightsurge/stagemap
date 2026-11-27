# Coverage table for stage_map() arguments and contract columns offered in the studio.

describe("studio_args()", {
  it("covers every stage_map() argument other than tables and dots", {
    tbl <- studio_args()
    expect_identical(studio_args_table(), tbl)
    expected <- setdiff(names(formals(stage_map)), c("cards", "stages", "lanes", "..."))
    args <- tbl[tbl$what == "arg", , drop = FALSE]
    expect_identical(args$name, expected)
    expect_setequal(args$name[args$where == "header"], "title")
    expect_setequal(args$name[args$where == "map"], c("layout", "target", "legend", "cell_columns", "bundle_links"))
  })

  it("covers every contract column of cards, stages, lanes and links without old_name_of entries", {
    tbl <- studio_args()
    spec_fields <- sm_spec()$fields
    for (name in c("cards", "stages", "lanes", "links")) {
      rows <- tbl[tbl$what == name, , drop = FALSE]
      expect_identical(rows$name, names(spec_fields[[name]]$fields), info = name)
    }
    expect_false("highlight" %in% tbl$name[tbl$what == "stages"])
  })

  it("explains every kept entry with a sentence and leaves offered entries without one", {
    tbl <- studio_args()
    kept <- tbl[tbl$where == "kept", , drop = FALSE]
    offered <- tbl[tbl$where != "kept", , drop = FALSE]
    expect_true(all(!is.na(kept$why) & nzchar(trimws(kept$why))))
    expect_true(all(is.na(offered$why)))
    expect_true(all(tbl$where %in% c("header", "map", "inspector", "kept")))
  })
})

describe("studio_args() against the views", {
  state <- studio_state_new()
  field_names <- function(view) vapply(view$fields, function(field) field$name, character(1))
  placed <- function(what, where) {
    tbl <- studio_args()
    tbl$name[tbl$what == what & tbl$where == where]
  }

  it("lists the title as the header's and the options as the Map room's fields, and no others", {
    expect_setequal(placed("arg", "header"), "title")
    expect_true(all(placed("arg", "header") %in% names(studio_view(state)$header)))

    # The layouts show different fields, so the Map room is read in each of its layouts.
    shown <- character()
    for (layout in c("grid", "levels", "dates")) {
      state$doc$args$layout <- layout
      shown <- union(shown, field_names(studio_room_map_view(state)))
    }
    expect_setequal(shown, placed("arg", "map"))
  })

  it("lists every offered column as a field of the matching inspector, and no others", {
    kinds <- c(cards = "card", stages = "stage", lanes = "lane", links = "link")
    for (table in names(kinds)) {
      uid <- state$doc$tables[[table]]$.studio_uid[[1L]]
      view <- studio_view_inspector(state$doc, list(kind = kinds[[table]], uid = uid))
      expect_setequal(field_names(view), placed(table, "inspector"))
    }
  })
})

describe("studio_arg_where()", {
  it("returns the placement or NULL, and checks its arguments", {
    expect_identical(studio_arg_where("arg", "title"), "header")
    expect_identical(studio_arg_where("cards", "label"), "inspector")
    expect_identical(studio_arg_where("cards", "hidden"), "kept")
    expect_null(studio_arg_where("cards", "unknown"))
    expect_error(studio_arg_where("", "title"), "what")
    expect_error(studio_arg_where("arg", ""), "name")
  })
})
