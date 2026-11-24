describe("check_dots()", {
  caller <- function(a, ..., b = NULL) {
    check_dots(...)
    "fine"
  }

  it("lets a call with an empty dots through", {
    expect_identical(caller(1, b = 2), "fine")
  })

  it("names a typo and lists the valid argument names read from the caller's formals", {
    # Given a call with a misspelt option
    error <- expect_error(caller(1, c = 2), class = "stagemap_error_dots")
    # Then the condition holds the stray name and the valid ones
    expect_identical(error$names, "c")
    expect_identical(error$valid, c("a", "b"))
    expect_match(conditionMessage(error), "`c`", fixed = TRUE)
  })

  it("reports a value passed by position after the dots as unnamed", {
    error <- expect_error(caller(1, 2), class = "stagemap_error_dots")
    expect_match(conditionMessage(error), "1 unnamed value", fixed = TRUE)
    expect_s3_class(error, "stagemap_error")
  })
})

describe("sm_abort() and sm_warn()", {
  it("add the package class after the subclass", {
    error <- expect_error(sm_abort("Broken.", class = "stagemap_error_data"), class = "stagemap_error_data")
    expect_identical(class(error)[1:2], c("stagemap_error_data", "stagemap_error"))
    warning <- expect_warning(sm_warn("Odd.", class = "stagemap_warning_command"), class = "stagemap_warning_command")
    expect_s3_class(warning, "stagemap_warning")
  })

  it("carry extra fields on the condition", {
    error <- expect_error(sm_abort("Broken.", class = "stagemap_error_data", problems = "a"))
    expect_identical(error$problems, "a")
  })

  it("check their own arguments", {
    expect_error(sm_abort(1, class = "x"), "message")
    expect_error(sm_warn("Odd.", class = 1), "class")
  })
})

describe("assert_widget_args()", {
  it("accepts a CSS size, a number or NULL, and a string id", {
    expect_silent(assert_widget_args(NULL, NULL, NULL))
    expect_silent(assert_widget_args("50%", 300, "map"))
  })

  it("refuses a bad width, height or id with checkmate's own message", {
    expect_error(assert_widget_args(c(1, 2), NULL, NULL), "width")
    expect_error(assert_widget_args(NULL, TRUE, NULL), "height")
    expect_error(assert_widget_args(NULL, NULL, 1), "element_id")
  })
})

describe("assert_dismiss()", {
  it("takes the values the engine's contract lists for the option", {
    expect_silent(assert_dismiss("no_outside"))
    expect_silent(assert_dismiss("any"))
    expect_error(assert_dismiss("never"), "dismiss")
  })

  it("follows the contract, not a list of its own", {
    changed <- sm_spec()
    changed$fields$options$fields$dismiss$values <- c("never")
    local_spec(list(fields = changed$fields))
    expect_silent(assert_dismiss("never"))
    expect_error(assert_dismiss("any"), "dismiss")
  })
})

describe("cli_escape()", {
  it("doubles braces so cli prints them as typed", {
    expect_identical(cli_escape("a {b} c"), "a {{b}} c")
  })
})

describe("bullets()", {
  it("gives every line the same bullet", {
    expect_identical(bullets(c("a", "b"), "x"), c(x = "a", x = "b"))
  })
})
