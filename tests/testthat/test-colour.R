describe("as_colour()", {
  it("normalises names, short hex, case and alpha", {
    expect_identical(as_colour("red", "colour", environment()), "#FF0000")
    expect_identical(as_colour("#aBc", "colour", environment()), "#AABBCC")
    expect_identical(as_colour("#abcdef", "colour", environment()), "#ABCDEF")
    expect_identical(as_colour("#abcdef80", "colour", environment()), "#ABCDEF80")
    expect_identical(as_colour("#abcdefFF", "colour", environment()), "#ABCDEF")
    expect_identical(as_colour("transparent", "colour", environment()), "#FFFFFF00")
    expect_error(as_colour("not-a-colour", "colours", environment()), "colours.*not-a-colour", class = "stagemap_error")
    expect_error(as_colour(1, "colour", environment()), "x")
    expect_error(as_colour("red", "", environment()), "arg")
    expect_error(as_colour("red", "colour", NULL), "call")
  })
})

describe("settings helpers", {
  it("checks keys and helper arguments", {
    expect_invisible(check_setting_names(NULL, "settings", environment()))
    expect_invisible(check_setting_names(c(a = "x"), "settings", environment()))
    for (bad in list("x", c(a = "x", a = "y"), setNames("x", NA_character_), c(" " = "x"))) {
      expect_error(check_setting_names(bad, "settings", environment()), "settings", class = "stagemap_error")
    }
    expect_error(check_setting_names(environment(), "settings", environment()), "x")
    expect_error(check_setting_names(character(), "", environment()), "arg")
    expect_error(check_setting_names(character(), "settings", NULL), "call")
    expect_invisible(warn_unused_settings("a", "a", "settings", environment()))
    expect_warning(
      warn_unused_settings("b", "a", "settings", environment()),
      "b",
      class = "stagemap_warning_unused"
    )
    expect_warning(warn_unused_settings("b", "a", "settings", environment()), "b", class = "stagemap_warning")
    expect_error(warn_unused_settings(1, "a", "settings", environment()), "keys")
    expect_error(warn_unused_settings("a", 1, "settings", environment()), "used")
    expect_error(warn_unused_settings("a", "a", "", environment()), "arg")
    expect_error(warn_unused_settings("a", "a", "settings", NULL), "call")
  })
})

describe("as_colour() and session state", {
  it("rejects digit strings and NA, which col2rgb() would read from the palette", {
    for (bad in c("2", "0", "NA", "#12345")) {
      expect_error(as_colour(bad, "colour", environment()), "Invalid.*colour", class = "stagemap_error")
    }
  })
})
