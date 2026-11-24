# The test files keep to their kinds (tests/README.md): browser tests only in -browser.R files, which start with their
# skip; snapshot tests only in -snap.R files, which hold nothing else and have no file-level skip.
describe("the test file layout", {
  files <- function(pattern) list.files(test_path(), pattern = pattern, full.names = TRUE)
  first_call <- function(file) {
    exprs <- parse(file, keep.source = FALSE)
    if (length(exprs) == 0L) "" else all_calls(exprs[[1]])[[1]]
  }
  # The names a call is made through, at any depth: `f()` gives "f", `pkg::f()` gives "::", "pkg" and "f", and
  # `pkg::Class$new()` gives "$", "::", "pkg", "Class" and "new", so a qualified or R6 call is seen like a plain one. The
  # first name is the outermost call's own: "f", "::" or "$".
  all_calls <- function(x) {
    if (is.symbol(x)) {
      return(as.character(x))
    }
    if (!is.call(x)) {
      return(character())
    }
    c(unlist(lapply(as.list(x)[1], all_calls)), unlist(lapply(as.list(x)[-1], all_calls)))
  }
  calls_in <- function(file) unlist(lapply(as.list(parse(file, keep.source = FALSE)), all_calls))
  skips_on_cran <- function(file) "skip_on_cran" %in% calls_in(file)
  uses_browser <- function(file) {
    browser_calls <- c("open_widget", "local_chrome_session", "app_driver", "AppDriver", "ChromoteSession")
    any(browser_calls %in% calls_in(file))
  }
  uses_snapshot <- function(file) any(startsWith(calls_in(file), "expect_snapshot"))
  # The top-level calls of a file that skip it as a whole.
  file_skips <- function(file) {
    skips <- c("skip_on_cran", "skip_without_chrome", "skip_unless_extended")
    top <- lapply(as.list(parse(file, keep.source = FALSE)), function(expr) {
      if (is.call(expr)) all_calls(expr[[1]]) else character()
    })
    intersect(unlist(top), skips)
  }
  # A temporary test file with `lines`, and its path.
  temp_file <- function(lines, name = "test-a.R", env = parent.frame()) {
    path <- file.path(withr::local_tempdir(.local_envir = env), name)
    writeLines(lines, path)
    path
  }
  # The plain test files: every test file but the browser, snapshot and extended ones, this file, and
  # test-helper-chrome.R, which tests the Chrome helpers' own argument checks. Those fail before any Chrome starts (the
  # rule in tests.md allows that in a plain file), and the file names the helpers only to describe them.
  plain_files <- function() {
    everything <- files("^test-.*[.]R$")
    everything[
      !grepl("-(browser|snap|extended)[.]R$", everything) &
        !basename(everything) %in% c("test-helper-layout.R", "test-helper-chrome.R")
    ]
  }
  blocks <- function(file) {
    found <- list()
    walk <- function(x) {
      if (is.call(x)) {
        if (all_calls(x)[[1]] %in% c("it", "test_that")) {
          found[[length(found) + 1L]] <<- x
        }
        for (part in as.list(x)[-1]) {
          walk(part)
        }
      }
    }
    for (expr in parse(file, keep.source = FALSE)) {
      walk(expr)
    }
    found
  }

  it("starts every -browser.R file with its skip", {
    found <- files("^test-.*-browser[.]R$")
    wrong <- found[vapply(found, first_call, "") != "skip_without_chrome"]
    expect_identical(basename(wrong), character())
  })

  it("starts every -extended.R file with its skip", {
    found <- files("^test-.*-extended[.]R$")
    wrong <- found[vapply(found, first_call, "") != "skip_unless_extended"]
    expect_identical(basename(wrong), character())
  })

  it("keeps skip_on_cran() out of the plain test files", {
    wrong <- plain_files()[vapply(plain_files(), skips_on_cran, NA)]
    expect_identical(basename(wrong), character())
  })

  it("finds a skip_on_cran() inside a plain test file, also in a nested it()", {
    dir <- withr::local_tempdir()
    writeLines(
      c("describe('a', {", "  it('b', {", "    skip_on_cran()", "    expect_true(TRUE)", "  })", "})"),
      file.path(dir, "test-a.R")
    )
    expect_true(skips_on_cran(file.path(dir, "test-a.R")))
  })

  it("keeps snapshots only, and every test in them, in -snap.R files", {
    found <- files("^test-.*-snap[.]R$")
    wrong <- found[vapply(
      found,
      function(file) !all(vapply(blocks(file), function(block) "expect_snapshot" %in% all_calls(block), NA)),
      NA
    )]
    expect_identical(basename(wrong), character())
  })

  it("keeps browser calls out of the plain test files", {
    wrong <- plain_files()[vapply(plain_files(), uses_browser, NA)]
    expect_identical(basename(wrong), character())
  })

  it("keeps expect_snapshot() and its variants out of every file but -snap.R files", {
    everything <- files("^test-.*[.]R$")
    others <- everything[!grepl("-snap[.]R$", everything) & basename(everything) != "test-helper-layout.R"]
    expect_identical(basename(others[vapply(others, uses_snapshot, NA)]), character())
  })

  it("refuses a file-level skip in a -snap.R file, which would delete its saved snapshots on CRAN", {
    found <- files("^test-.*-snap[.]R$")
    expect_identical(basename(found[vapply(found, function(file) length(file_skips(file)) > 0L, NA)]), character())
  })

  it("sees qualified and R6 calls, not only plain ones", {
    qualified <- temp_file(c(
      "testthat::skip_on_cran()",
      "shinytest2::AppDriver$new('app')",
      "testthat::expect_snapshot(1)"
    ))
    expect_true(skips_on_cran(qualified))
    expect_true(uses_browser(qualified))
    expect_true(uses_snapshot(qualified))
    expect_true(uses_browser(temp_file("session <- chromote::ChromoteSession$new()")))
    expect_true(uses_browser(temp_file("app <- shinytest2::AppDriver$new()")))
    expect_true(skips_on_cran(temp_file("describe('a', { it('b', { testthat::skip_on_cran() }) })")))
    expect_true(uses_snapshot(temp_file("it('a', { testthat::expect_snapshot_value(1) })")))
  })

  it("does not take a plain call for a browser, a skip or a snapshot", {
    plain <- temp_file(c("expect_true(TRUE)", "x <- list(AppDriver = 1)", "skip_if_not_installed('withr')"))
    expect_false(uses_browser(plain))
    expect_false(skips_on_cran(plain))
    expect_false(uses_snapshot(plain))
    expect_identical(file_skips(plain), character())
  })

  it("finds a file-level skip, qualified or not, and none inside a test", {
    expect_identical(file_skips(temp_file(c("skip_on_cran()", "it('a', {})"))), "skip_on_cran")
    expect_identical(file_skips(temp_file(c("testthat::skip_on_cran()", "it('a', {})"))), "skip_on_cran")
    expect_identical(file_skips(temp_file("it('a', { skip_on_cran() })")), character())
  })

  it("finds a -browser.R file that does not start with the skip", {
    dir <- withr::local_tempdir()
    writeLines(c("x <- 1", "skip_without_chrome()"), file.path(dir, "test-a-browser.R"))
    expect_false(identical(first_call(file.path(dir, "test-a-browser.R")), "skip_without_chrome"))
  })
})
