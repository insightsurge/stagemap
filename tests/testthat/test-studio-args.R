# Coverage table for stage_map() arguments and contract columns offered in the studio.

describe("studio_args", {
  it("covers every stage_map() argument other than tables and dots", {
    expect_identical(studio_args_table(), studio_args)
    expected <- setdiff(names(formals(stage_map)), c("cards", "stages", "lanes", "..."))
    args <- studio_args[studio_args$what == "arg", , drop = FALSE]
    expect_identical(args$name, expected)
    expect_setequal(args$name[args$where == "header"], "title")
    expect_setequal(args$name[args$where == "map"], c("layout", "target", "legend", "cell_columns", "bundle_links"))
  })

  it("covers every contract column of cards, stages, lanes and links without old_name_of entries", {
    spec_fields <- sm_spec()$fields
    for (tbl in c("cards", "stages", "lanes", "links")) {
      rows <- studio_args[studio_args$what == tbl, , drop = FALSE]
      expect_identical(rows$name, names(spec_fields[[tbl]]$fields), info = tbl)
    }
    expect_false("highlight" %in% studio_args$name[studio_args$what == "stages"])
  })

  it("explains every kept entry with a sentence and leaves offered entries without one", {
    kept <- studio_args[studio_args$where == "kept", , drop = FALSE]
    offered <- studio_args[studio_args$where != "kept", , drop = FALSE]
    expect_true(all(!is.na(kept$why) & nzchar(trimws(kept$why))))
    expect_true(all(is.na(offered$why)))
    expect_true(all(studio_args$where %in% c("header", "map", "inspector", "kept")))
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
