# The test files keep to their kinds (tests/README.md): browser tests only in -browser.R files, which start with their
# skip; snapshot tests only in -snap.R files, which hold nothing else.
describe("the test file layout", {
  files <- function(pattern) list.files(test_path(), pattern = pattern, full.names = TRUE)
  first_call <- function(file) {
    exprs <- parse(file, keep.source = FALSE)
    if (length(exprs) == 0L) "" else as.character(exprs[[1]][[1]])[1]
  }
  all_calls <- function(x) {
    if (is.call(x)) c(as.character(x[[1]])[1], unlist(lapply(as.list(x)[-1], all_calls))) else character()
  }
  skips_on_cran <- function(file) {
    "skip_on_cran" %in% unlist(lapply(as.list(parse(file, keep.source = FALSE)), all_calls))
  }
  blocks <- function(file) {
    found <- list()
    walk <- function(x) {
      if (is.call(x)) {
        if (identical(as.character(x[[1]])[1], "it") || identical(as.character(x[[1]])[1], "test_that")) {
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
    everything <- files("^test-.*[.]R$")
    plain <- everything[
      !grepl("-(browser|snap|extended)[.]R$", everything) & basename(everything) != "test-helper-layout.R"
    ]
    wrong <- plain[vapply(plain, skips_on_cran, NA)]
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
    everything <- files("^test-.*[.]R$")
    # test-helper-chrome.R tests the Chrome helpers' own argument checks, which fail before any Chrome starts (the
    # rule in tests.md allows that in a plain file); this file names the helpers only to describe them.
    plain <- everything[
      !grepl("-(browser|snap|extended)[.]R$", everything) &
        !basename(everything) %in% c("test-helper-layout.R", "test-helper-chrome.R")
    ]
    browser_calls <- c("open_widget", "local_chrome_session", "app_driver", "AppDriver", "ChromoteSession")
    wrong <- plain[vapply(
      plain,
      function(file) any(browser_calls %in% unlist(lapply(as.list(parse(file, keep.source = FALSE)), all_calls))),
      NA
    )]
    expect_identical(basename(wrong), character())
  })

  it("finds a -browser.R file that does not start with the skip", {
    dir <- withr::local_tempdir()
    writeLines(c("x <- 1", "skip_without_chrome()"), file.path(dir, "test-a-browser.R"))
    expect_false(identical(first_call(file.path(dir, "test-a-browser.R")), "skip_without_chrome"))
  })
})
