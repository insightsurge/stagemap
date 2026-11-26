describe("code_string()", {
  it("escapes backslash, quote, newline, carriage return, tab and other control characters", {
    x <- c("a\\b", "say \"hi\"", "one\ntwo", "cr\r", "tab\t", "bell\a", "del\x7f")
    expect_identical(
      code_string(x),
      c(
        "\"a\\\\b\"",
        "\"say \\\"hi\\\"\"",
        "\"one\\ntwo\"",
        "\"cr\\r\"",
        "\"tab\\t\"",
        "\"bell\\x07\"",
        "\"del\\x7f\""
      )
    )
    expect_identical(eval(parse(text = paste0("c(", paste(code_string(x), collapse = ", "), ")"))), x)
  })

  it("leaves letters beyond ASCII as they are, and writes NA bare", {
    expect_identical(code_string(c("caf\u00e9", NA)), c("\"caf\u00e9\"", "NA"))
  })

  it("checks its arguments", {
    expect_error(code_string(1), "x")
  })
})

describe("code_number()", {
  it("writes whole doubles without L, integers with it, and other doubles in the fewest digits", {
    expect_identical(code_number(c(3, -2.5, 0.1, 1e20)), c("3", "-2.5", "0.1", "1e+20"))
    expect_identical(code_number(c(1L, NA)), c("1L", "NA"))
    expect_identical(code_number(c(NA, NaN, Inf, -Inf)), c("NA", "NaN", "Inf", "-Inf"))
    x <- c(1 / 3, 0.1 + 0.2, 123456789012345678)
    expect_identical(as.numeric(code_number(x)), x)
  })

  it("checks its arguments", {
    expect_error(code_number("1"), "x")
  })
})

describe("code_name()", {
  it("writes a syntactic name bare and any other name in backticks", {
    expect_identical(
      code_name(c("a", ".x", "a.b_1", "my col", "if", "_x", "...", "..1", "a`b", "caf\u00e9")),
      c("a", ".x", "a.b_1", "`my col`", "`if`", "`_x`", "`...`", "`..1`", "`a\\`b`", "`caf\u00e9`")
    )
  })

  it("checks its arguments", {
    expect_error(code_name(NA_character_), "x")
  })
})

describe("code_vector()", {
  it("writes one value bare and several, or named ones, in c()", {
    expect_identical(code_flat(code_vector("a")), "\"a\"")
    expect_identical(code_flat(code_vector(c(TRUE, NA, FALSE))), "c(TRUE, NA, FALSE)")
    expect_identical(code_flat(code_vector(c(done = "Pass"))), "c(done = \"Pass\")")
  })

  it("types NA only when every value is NA", {
    expect_identical(code_flat(code_vector(c("a", NA))), "c(\"a\", NA)")
    expect_identical(code_flat(code_vector(NA_character_)), "NA_character_")
    expect_identical(code_flat(code_vector(c(NA_real_, NA))), "c(NA_real_, NA_real_)")
    expect_identical(code_flat(code_vector(NA_integer_)), "NA_integer_")
    expect_identical(code_flat(code_vector(NA)), "NA")
  })

  it("writes vectors with no values", {
    expect_identical(
      vapply(list(character(), numeric(), integer(), logical()), function(x) code_flat(code_vector(x)), ""),
      c("character()", "numeric()", "integer()", "logical()")
    )
  })

  it("writes factors with their levels, and dates", {
    expect_identical(
      code_flat(code_vector(factor(c("b", "a"), levels = c("b", "a", "c")))),
      "factor(c(\"b\", \"a\"), levels = c(\"b\", \"a\", \"c\"))"
    )
    expect_identical(
      code_flat(code_vector(factor("a", levels = c("a", "b"), ordered = TRUE))),
      "factor(\"a\", levels = c(\"a\", \"b\"), ordered = TRUE)"
    )
    expect_identical(code_flat(code_vector(as.Date(c("2026-01-02", NA)))), "as.Date(c(\"2026-01-02\", NA))")
  })

  it("writes another class as its values and attributes inside structure(), and I() inside I()", {
    x <- as.POSIXct("2026-01-02 03:04:05", tz = "UTC")
    expect_identical(
      code_flat(code_vector(x)),
      "structure(1767323045, class = c(\"POSIXct\", \"POSIXt\"), tzone = \"UTC\")"
    )
    expect_identical(eval(parse(text = code_flat(code_vector(x)))), x)
    named <- structure(c(a = 1), class = "thing")
    expect_identical(eval(parse(text = code_flat(code_vector(named)))), named)
    expect_identical(code_flat(code_vector(I(c("a", "b")))), "I(c(\"a\", \"b\"))")
  })

  it("writes raw and complex vectors", {
    expect_identical(code_flat(code_vector(as.raw(c(1, 255)))), "as.raw(c(1L, 255L))")
    z <- complex(real = c(1, 0.5), imaginary = c(-2, 0))
    expect_identical(eval(parse(text = code_flat(code_vector(z)))), z)
  })

  it("checks its arguments", {
    expect_error(code_vector(list()), "x")
  })
})

describe("code_value()", {
  it("writes an item's attributes other than names in structure()", {
    x <- list(structure(1:4, dim = c(2L, 2L)), structure(list(1), class = "foo"), c(a = 1))
    text <- code_flat(code_value(x))
    expect_identical(
      text,
      "list(structure(c(1L, 2L, 3L, 4L), dim = c(2L, 2L)), structure(list(1), class = \"foo\"), c(a = 1))"
    )
    expect_identical(eval(parse(text = text)), x)
  })

  it("writes NULL, a data frame, a list or a vector", {
    expect_identical(code_flat(code_value(NULL)), "NULL")
    expect_identical(code_flat(code_value(list(a = 1, NULL))), "list(a = 1, NULL)")
    expect_identical(code_flat(code_value(data.frame(a = 1))), "data.frame(a = 1)")
    expect_identical(code_flat(code_value(2L)), "2L")
  })

  it("checks its arguments", {
    expect_error(code_value(sum), "x")
  })
})

describe("code_frame()", {
  it("leaves out a column of only NA and keeps the order of the others", {
    x <- data.frame(b = c("1", "2"), a = NA, c = c(1, NA))
    expect_identical(code_flat(code_frame(x)), "data.frame(b = c(\"1\", \"2\"), c = c(1, NA))")
  })

  it("writes a constant column once when another column gives the number of rows", {
    expect_identical(
      code_flat(code_frame(data.frame(id = c("a", "b"), lane = "l"))),
      "data.frame(id = c(\"a\", \"b\"), lane = \"l\")"
    )
    # Every column constant: the first is written in full.
    expect_identical(
      code_flat(code_frame(data.frame(id = c("a", "a"), lane = "l"))),
      "data.frame(id = c(\"a\", \"a\"), lane = \"l\")"
    )
  })

  it("writes a table with a column named like an argument of data.frame() inside stats::setNames()", {
    x <- data.frame(a = c(1, 2), b = "x")
    names(x) <- c("stringsAsFactors", "my col")
    text <- code_flat(code_frame(x))
    expect_identical(
      text,
      "stats::setNames(data.frame(x1 = c(1, 2), x2 = \"x\"), c(\"stringsAsFactors\", \"my col\"))"
    )
    expect_identical(eval(parse(text = text)), x)
  })

  it("keeps the names of a named list column without making them row names", {
    x <- data.frame(id = c("a", "b"))
    x$about <- I(list(p = 1, q = "r"))
    text <- code_flat(code_frame(x))
    expect_match(text, "row.names = NULL", fixed = TRUE)
    expect_identical(eval(parse(text = text)), x)
    # The same in a table written inside stats::setNames().
    names(x)[1] <- "row.names"
    expect_identical(eval(parse(text = code_flat(code_frame(x)))), x)
  })

  it("writes a matrix column with its dim, which data.frame() makes into columns", {
    x <- data.frame(id = c("a", "b"))
    x$m <- matrix(1:4, 2L)
    back <- eval(parse(text = code_flat(code_frame(x))))
    expect_identical(names(back), c("id", "m.1", "m.2"))
    expect_identical(back$m.2, 3:4)
  })

  it("keeps a name R cannot read bare, with check.names = FALSE", {
    x <- data.frame(`my col` = 1:2, b = "x", check.names = FALSE)
    text <- code_flat(code_frame(x))
    expect_identical(text, "data.frame(`my col` = c(1L, 2L), b = \"x\", check.names = FALSE)")
    expect_identical(eval(parse(text = text)), x)
  })

  it("writes a list column item by item inside I(list()), and a table with no rows", {
    x <- data.frame(id = c("a", "b"))
    x$about <- list(1 / 3, "two")
    text <- code_flat(code_frame(x))
    expect_identical(text, "data.frame(id = c(\"a\", \"b\"), about = I(list(0.3333333333333333, \"two\")))")
    back <- eval(parse(text = text))
    expect_identical(unclass(back$about), x$about)
    expect_identical(code_flat(code_frame(data.frame(id = character()))), "data.frame(id = character())")
  })

  it("checks its arguments", {
    expect_error(code_frame(list()), "x")
  })
})

describe("code_lines()", {
  it("keeps a call on one line when it fits, with its prefix and suffix", {
    node <- code_call("f", list(code_atom("1"), b = code_atom("2")))
    expect_identical(code_lines(node, 2L, prefix = "x <- ", suffix = " |>"), "  x <- f(1, b = 2) |>")
  })

  it("keeps a line of exactly 80 characters, and cuts one of 81", {
    at <- function(width) code_call("f", list(code_atom(strrep("a", width - 6L)), code_atom("1")))
    expect_identical(nchar(code_lines(at(80L))), 80L)
    expect_length(code_lines(at(81L)), 4L)
  })

  it("puts one argument on each line when a call does not fit in 80 characters", {
    long <- code_atom(strrep("a", 40))
    node <- code_call("f", list(x = long, y = long))
    expect_identical(
      code_lines(node),
      c("f(", paste0("  x = ", strrep("a", 40), ","), paste0("  y = ", strrep("a", 40)), ")")
    )
  })

  it("wraps a long vector at its commas, indented", {
    lines <- code_lines(code_vector(sprintf("item%02d", 1:20)), prefix = "id = ")
    expect_identical(lines[1], "id = c(")
    expect_identical(lines[length(lines)], ")")
    expect_true(all(nchar(lines) <= 80L))
    expect_true(all(startsWith(lines[-c(1, length(lines))], "  \"item")))
    expect_identical(eval(parse(text = paste(sub("^id = ", "", lines), collapse = "\n"))), sprintf("item%02d", 1:20))
  })

  it("wraps a named vector with its names", {
    x <- stats::setNames(rep(strrep("w", 20), 4), c("a", "b", "c", "d"))
    lines <- code_lines(code_vector(x))
    expect_identical(eval(parse(text = paste(lines, collapse = "\n"))), x)
  })

  it("leaves an atom and a call with no arguments on one line, however long", {
    expect_identical(code_lines(code_atom(strrep("a", 90))), strrep("a", 90))
    expect_identical(code_lines(code_call(strrep("f", 90))), paste0(strrep("f", 90), "()"))
  })

  it("checks its arguments", {
    expect_error(code_lines("x"), "node")
    expect_error(code_lines(code_atom("a"), -1L), "indent")
    expect_error(code_lines(code_atom("a"), prefix = 1), "prefix")
    expect_error(code_lines(code_atom("a"), suffix = 1), "suffix")
    expect_error(code_flat("x"), "node")
    expect_error(code_pack(1, ""), "items")
    expect_error(code_pack("a", 1), "pad")
    expect_error(code_atom(1), "text")
    expect_error(code_call(1), "fn")
    expect_error(code_call("f", list(1)), "args")
    expect_error(code_typed_na(list()), "x")
  })
})

describe("code_tokens()", {
  it("cuts each line into spans that paste back to the line", {
    lines <- unclass(stage_map_code(full_map()))
    spans <- code_tokens(lines)
    expect_length(spans, length(lines))
    pasted <- vapply(spans, function(line) paste(vapply(line, `[[`, "", "text"), collapse = ""), "")
    expect_identical(pasted, lines)
    classes <- unique(unlist(lapply(spans, function(line) vapply(line, `[[`, "", "class"))))
    expect_true(all(classes %in% c("str", "num", "fn", "arg", "op", "com", "name")))
  })

  it("gives each token its class, with the spaces before it", {
    spans <- code_tokens(c("x <- f(a = \"s\", 1L, NULL) # note"))[[1]]
    expect_identical(
      lapply(spans, unlist),
      list(
        c(text = "x", class = "name"),
        c(text = " <-", class = "op"),
        c(text = " f", class = "fn"),
        c(text = "(", class = "op"),
        c(text = "a", class = "arg"),
        c(text = " =", class = "op"),
        c(text = " \"s\"", class = "str"),
        c(text = ",", class = "op"),
        c(text = " 1L", class = "num"),
        c(text = ",", class = "op"),
        c(text = " NULL", class = "num"),
        c(text = ")", class = "op"),
        c(text = " # note", class = "com")
      )
    )
  })

  it("keeps a long string and letters beyond ASCII whole, in a C locale", {
    # The text is made first: a string written with a Unicode escape in a C locale is not marked as UTF-8.
    long <- code_string(strrep("x", 2000))
    lines <- c(paste0("a <- ", long), "b <- \"caf\u00e9\"")
    withr::local_locale(c(LC_CTYPE = "C"))
    spans <- code_tokens(lines)
    expect_identical(spans[[1]][[3]]$text, paste0(" ", long))
    expect_identical(spans[[2]][[3]], list(text = " \"caf\u00e9\"", class = "str"))
  })

  it("gives text that does not parse as one span per line, and an empty line no spans", {
    expect_identical(code_tokens(c("f(", "")), list(list(list(text = "f(", class = "name")), list()))
    # A string that runs over two lines: its token is not found on either line, so each line is one span.
    expect_identical(
      code_tokens(c("x <- \"a", "b\"")),
      list(list(list(text = "x <- \"a", class = "name")), list(list(text = "b\"", class = "name")))
    )
  })

  it("checks its arguments", {
    expect_error(code_tokens(1), "lines")
  })
})
