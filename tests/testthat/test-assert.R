describe("assertion helpers", {
  it("wraps checkmate failures and preserves successful values", {
    expect_identical(with_stagemap_asserts(42L), 42L)
    expect_error(with_stagemap_asserts(checkmate::assert_string(1)), "Assertion", class = "stagemap_error")
    expect_error(
      with_stagemap_asserts(checkmate::assert(
        checkmate::check_string(1),
        checkmate::check_flag(1)
      )),
      "Assertion failed\\.",
      class = "stagemap_error"
    )
    original <- simpleError("unrelated {error}")
    caught <- tryCatch(with_stagemap_asserts(stop(original)), error = identity)
    expect_identical(caught, original)
    expect_error(with_stagemap_asserts(TRUE, call = 1), "call")
  })

  it("checks a checkmate result and names the public argument", {
    expect_invisible(check_arg(TRUE, "nodes", environment()))
    expect_error(check_arg(checkmate::check_string(1), "nodes", environment()), "nodes", class = "stagemap_error")
    expect_error(check_arg(FALSE, "nodes", environment()), "Assertion failed\\.", class = "simpleError")
    expect_error(check_arg(TRUE, "", environment()), "arg")
    expect_error(check_arg(TRUE, "nodes", NULL), "call")
  })

  it("explains unnamed and named extras with either hint", {
    expect_error(
      abort_dots(NULL, 1, "colour", environment(), "stagemap", c("nodes", "links")),
      "an unnamed argument",
      class = "stagemap_error_dots"
    )
    expect_error(
      abort_dots(c("", "", "foo"), 3, "colour", environment(), "stagemap", c("nodes", "links")),
      "2 unnamed arguments.*foo"
    )
    expect_error(
      abort_dots("foo", 1, "colour", environment(), "stagemap", c("nodes", "links")),
      "Name the optional arguments"
    )
    expect_error(
      abort_dots("foo", 1, character(), environment(), "stagemap", c("nodes", "links")),
      "takes only.*nodes.*links",
      class = "stagemap_error"
    )
    expect_error(abort_dots(1, 1, character(), environment(), "stagemap", c("nodes", "links")), "extras")
    expect_error(abort_dots(NULL, 0, character(), environment(), "stagemap", c("nodes", "links")), "n")
    expect_error(abort_dots(NULL, 1, NA_character_, environment(), "stagemap", c("nodes", "links")), "valid")
    expect_error(abort_dots(NULL, 1, character(), NULL, "stagemap", c("nodes", "links")), "call")
  })

  it("limits row and value reports to five entries", {
    expect_error(
      abort_rows(1:7, "nodes", "id", "a missing"),
      "Rows 1, 2, 3, 4, 5 and 2 more",
      class = "stagemap_error_data"
    )
    expect_error(abort_rows(2L, "nodes", "id", "a duplicated", "a"), "Values:.*a", class = "stagemap_error")
    expect_error(abort_rows(integer(), "nodes", "id", "bad"), "rows")
    expect_error(abort_rows(1L, "", "id", "bad"), "arg")
    expect_error(abort_rows(1L, "nodes", "", "bad"), "column")
    expect_error(abort_rows(1L, "nodes", "id", "bad", value_label = ""), "value_label")
    expect_error(abort_rows(1L, "nodes", "id", "bad", verb = "has"), "verb")
    expect_error(abort_rows(1L, "nodes", "id", ""), "problem")
    expect_error(abort_rows(1L, "nodes", "id", "bad", 1), "values")
    expect_error(abort_rows(1L, "nodes", "id", "bad", call = NULL), "call")
  })
})


describe("row_text()", {
  it("joins rows and limits long lists", {
    expect_identical(row_text(2L), "Row 2")
    expect_identical(row_text(c(2L, 4L)), "Rows 2 and 4")
    expect_identical(row_text(c(2L, 4L, 6L)), "Rows 2, 4 and 6")
    expect_identical(row_text(1:8), "Rows 1, 2, 3, 4, 5 and 3 more")
    expect_error(row_text(integer()), "rows")
  })
})

describe("reusable dots hints", {
  it("names the supplied function and positional arguments", {
    expect_error(
      abort_dots("foo", 1, character(), environment(), "sm_layout", "map"),
      "sm_layout.*takes only.*map",
      class = "stagemap_error_dots"
    )
    expect_error(abort_dots(NULL, 1, character(), environment(), "", "map"), "fn")
    expect_error(abort_dots(NULL, 1, character(), environment(), "sm_layout", character()), "positional")
  })
})
