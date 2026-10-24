describe("text_width()", {
  it("reads all printable ASCII metrics and the known Helvetica widths", {
    file <- helvetica_metrics_file()
    skip_if(!nzchar(file) || !file.exists(file), "R's Helvetica metrics are unavailable")
    old <- the$helvetica
    withr::defer(the$helvetica <- old)
    the$helvetica <- NULL
    metrics <- helvetica_metrics()
    expect_identical(names(metrics$widths), as.character(32:126))
    expect_true(all(is.finite(metrics$widths)))
    expect_true(all(metrics$widths > 0))
    expect_equal(text_width(c("i", "M", " "), 1000), c(222, 833, 278))
    expect_equal(text_width("iM ", 1000), 1333)
    expect_equal(text_width(c("", "i"), 13), c(0, 2.886))
    expect_equal(text_width(c("\u00e9", "\u4e2d", "\U0001f600"), 1000), rep(600, 3))
    # Actual widths can equal 556: coverage means the file supplies every ASCII code, not that each width differs.
    expect_equal(metrics$other, 600)
    connection <- gzfile(file, "rt")
    raw <- readLines(connection, warn = FALSE)
    close(connection)
    codes <- as.integer(sub("^C[[:space:]]+(-?[0-9]+).*", "\\1", raw[grepl("^C[[:space:]]", raw)]))
    expect_true(all(32:126 %in% codes))
  })

  it("fills its own cache once and uses 556 for every character if the file cannot be read", {
    old <- the$helvetica
    withr::defer(the$helvetica <- old)
    the$helvetica <- NULL
    calls <- new.env(parent = emptyenv())
    calls$n <- 0L
    missing_file <- file.path(withr::local_tempdir(), "absent.afm.gz")
    local_mocked_bindings(helvetica_metrics_file = function() {
      calls$n <- calls$n + 1L
      missing_file
    })
    expect_equal(text_width(c("i", "M", " ", "\u00e9"), 1000), rep(556, 4))
    expect_equal(text_width("ii", 10), 11.12)
    expect_identical(calls$n, 1L)
    expect_length(the$helvetica$widths, 95L)
    expect_equal(the$helvetica$other, 556)
  })

  it("falls back for an empty readable metrics file too", {
    old <- the$helvetica
    withr::defer(the$helvetica <- old)
    the$helvetica <- NULL
    file <- file.path(withr::local_tempdir(), "empty.afm.gz")
    connection <- gzfile(file, "wt")
    close(connection)
    local_mocked_bindings(helvetica_metrics_file = function() file)
    expect_equal(text_width("i\u00e9", 1000), 1112)
  })

  it("checks its inputs and handles an empty vector and zero size", {
    expect_error(text_width(1, 13), "text")
    expect_error(text_width(NA_character_, 13), "text")
    for (bad in list(-1, Inf, NA_real_, c(1, 2))) {
      expect_error(text_width("a", bad), "size")
    }
    expect_identical(text_width(character(), 13), numeric())
    expect_equal(text_width("a", 0), 0)
  })
})

describe("wrap_label()", {
  it("keeps short and empty labels on one line and wraps long labels within the width", {
    expect_identical(wrap_label("Short label", 148, 13), "Short label")
    expect_identical(wrap_label("", 148, 13), "")
    expect_identical(wrap_label("   ", 148, 13), "")
    text <- "A long label with several words that cannot all fit on a single line"
    lines <- wrap_label(text, 80, 13)
    expect_gt(length(lines), 1L)
    expect_true(all(text_width(lines, 13) * 1.05 <= 80))
    expect_identical(paste(lines, collapse = " "), text)
    word <- "MMMMMMMMMMMMMMMMMMMM"
    lines <- wrap_label(word, 40, 13)
    expect_gt(length(lines), 1L)
    expect_true(all(text_width(lines, 13) * 1.05 <= 40))
    expect_identical(paste0(lines, collapse = ""), word)
    expect_identical(wrap_label("  a  b  ", 148, 13), "a b")
    expect_identical(wrap_label("a b", 0, 0), "a b")
    expect_identical(wrap_label("M", 0, 13), "M")
  })

  it("wraps each explicit line separately and preserves empty lines", {
    for (newline in c("\n", "\r\n")) {
      expect_identical(wrap_label(paste0("Line one", newline, "line two"), 148, 13), c("Line one", "line two"))
      expect_identical(wrap_label(paste0(newline, "a", newline, newline), 148, 13), c("", "a", "", ""))
      expect_identical(wrap_label(newline, 148, 13), c("", ""))
      expect_identical(
        wrap_label(paste0("MMMM", newline, "MMMM"), text_width("MM", 13) * 1.05, 13),
        rep("MM", 4L)
      )
    }
  })

  it("checks each argument", {
    expect_error(wrap_label(NA_character_, 148, 13), "text")
    expect_error(wrap_label(c("a", "b"), 148, 13), "text")
    for (bad in list(-1, Inf, NA_real_, c(1, 2))) {
      expect_error(wrap_label("a", bad, 13), "width")
      expect_error(wrap_label("a", 148, bad), "size")
    }
  })
})
