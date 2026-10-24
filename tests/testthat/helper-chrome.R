# One headless Chrome per test process, shared by the tests that draw with the engine. testthat runs the test files in
# two R processes at once (`Config/testthat/parallel` in DESCRIPTION), and each process loads this file, so each has
# its own Chromes, its own restart count and its own close at the end.
#
# Copied from mascot's tests/testthat/helper-chrome.R (with skip_without_chrome() from its helper-engine-js.R). It is
# generic: if a bug or an improvement turns up here, tell mascot as well.
#
# Chrome keeps its temporary files in TMPDIR and leaves com.google.Chrome.* folders behind, which R CMD check reports
# as a NOTE ("detritus in the temp directory"). Pointing TMPDIR inside R's session temporary directory keeps them out
# of the system temp directory: R deletes tempdir() when the session ends. Slow CI runners can need more than
# chromote's default 10 seconds to start Chrome, hence the longer timeout.
#
# A Chrome that crashes would fail every later browser test with "Chromote has been closed.". So each Chrome is
# checked when a test asks for it and replaced when its process has ended, and a Chrome
# that keeps dying stops the browser tests with a visible skip instead of a loop. Two Chromes are shared: this file's
# browser (`local_chrome_session()`) and chromote's default one, which shinytest2 uses for every app.
# `browser` and `default` hold the Chromes started here; `restarts` counts replacements across both.
test_browser_env <- new.env(parent = emptyenv())
test_browser_env$restarts <- 0L

# Skip the calling test on CRAN, or when chromote, withr or a Chrome is missing.
skip_without_chrome <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("chromote")
  testthat::skip_if_not_installed("withr")
  testthat::skip_if(is.null(chromote::find_chrome()), "no Chrome or Chromium found")
}

# How many times a run replaces a dead Chrome, both Chromes together. One machine-wide cause (memory, a broken Chrome)
# kills them both, so a count per Chrome would allow twice the restarts of a failure that cannot be fixed by retrying.
chrome_restart_limit <- 2L

# Milliseconds any browser test waits for a signal (a Shiny value, a DOM state, a finished animation) before it fails.
# One generous limit for every wait: a busy machine or a slow CI runner can take seconds to answer, while a passing
# wait returns as soon as its signal arrives, so a long limit costs nothing on a fast machine. Never sleep for a
# fixed time instead: wait for the signal.
browser_timeout <- 30000

# Start a Shiny app in Chrome with the shared timeout for loading and for every wait, click and value it reads.
# The app is stopped when the calling test ends, pass or fail: a test that fails before its own `app$stop()`
# would otherwise leave the app's R process running until the whole suite ends. Stopping twice is harmless.
# chromote's default Chrome is checked first, because shinytest2 opens every app in it.
app_driver <- function(..., env = parent.frame()) {
  checkmate::assert_environment(env)
  testthat::skip_if_not_installed("shinytest2")
  chrome_ensure_default()
  app <- shinytest2::AppDriver$new(..., load_timeout = browser_timeout, timeout = browser_timeout)
  withr::defer(app$stop(), envir = env)
  app
}

# Click the element `selector` names, found and clicked in one step in the page, as a person's click is. Use it for
# anything a Shiny output renders: the server can replace that element at any moment, and `app$click()` takes two steps
# (find the node, then click it), so a replacement between them fails with "No node with given id". A selector that
# matches nothing fails the test.
click_now <- function(app, selector) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_string(selector, min.chars = 1)
  found <- app$get_js(sprintf(
    "(() => { const node = document.querySelector(%s); if (node) node.click(); return node !== null; })()",
    jsonlite::toJSON(selector, auto_unbox = TRUE)
  ))
  if (!isTRUE(found)) {
    cli::cli_abort("No element matches {.val {selector}}.")
  }
  invisible(app)
}

# The Chrome shared by the tests that draw with the engine: the running one, or a new one when its process has ended.
# It skips the calling test first on CRAN or without Chrome, so no test starts a Chrome there.
test_browser <- function() {
  skip_without_chrome()
  browser <- test_browser_env$browser
  if (!is.null(browser)) {
    problem <- chrome_problem(browser)
    if (is.null(problem)) {
      return(browser)
    }
    chrome_count_restart("shared", problem)
    chrome_close(browser)
  }
  test_browser_env$browser <- chrome_start()
}

# Open a page (a ChromoteSession) in the shared Chrome. It is closed when the calling test ends, pass or fail, also
# when Chrome has died by then: a close that fails must not hide the error that ended the test.
local_chrome_session <- function(env = parent.frame()) {
  checkmate::assert_environment(env)
  session <- chromote::ChromoteSession$new(parent = test_browser())
  withr::defer(
    tryCatch(
      if (session$parent$is_active()) session$close(),
      error = function(e) NULL
    ),
    envir = env
  )
  session
}

# Make chromote's default Chrome (the one shinytest2 uses) a running one. The first Chrome is started here, with the same
# settings as the shared one; after that a dead one is replaced. chromote itself would start a replacement, but without
# these settings, without the restart limit and without a close at the end of the run. It skips first, as test_browser()
# does.
chrome_ensure_default <- function() {
  skip_without_chrome()
  if (chromote::has_default_chromote_object()) {
    problem <- chrome_problem(chromote::default_chromote_object())
    if (is.null(problem)) {
      return(invisible())
    }
  } else {
    problem <- "its process has ended"
  }
  previous <- test_browser_env$default
  if (!is.null(previous)) {
    chrome_count_restart("default", problem)
    chrome_close(previous)
  }
  test_browser_env$default <- chrome_start()
  chromote::set_default_chromote_object(test_browser_env$default)
  invisible()
}

# Why `browser` cannot be used (a sentence), or NULL when it can. A connection that dropped while the process lives is
# opened again by chromote; its open pages are lost, which is fine between tests.
chrome_problem <- function(browser) {
  checkmate::assert_r6(browser, "Chromote")
  if (!browser$is_alive()) {
    return("its process has ended")
  }
  tryCatch(
    {
      browser$check_active()
      NULL
    },
    error = function(e) conditionMessage(e)
  )
}

# Count one replacement of a Chrome, or skip the calling test when the run has used its replacements up.
chrome_count_restart <- function(which, problem) {
  checkmate::assert_string(which)
  checkmate::assert_string(problem)
  if (test_browser_env$restarts >= chrome_restart_limit) {
    testthat::skip(cli::format_inline(
      "The {which} Chrome stopped ({problem}) after {chrome_restart_limit} restarts in this run; ",
      "the remaining browser tests are skipped."
    ))
  }
  test_browser_env$restarts <- test_browser_env$restarts + 1L
  cli::cli_alert_warning(
    "The {which} Chrome stopped ({problem}); starting a new one (restart {test_browser_env$restarts} of {chrome_restart_limit})."
  )
  invisible()
}

# The machine every browser test assumes: a desktop with a mouse that can hover, and no wish for reduced motion. A
# headless Chrome otherwise takes these from the operating system, and CI machines differ: GitHub's Linux runners have
# no pointing device (so `(hover: none)`), and its macOS and Windows runners ask for reduced motion. Tests of touch or
# reduced motion emulate those themselves, per page.
chrome_device_args <- c(
  "--force-prefers-no-reduced-motion",
  "--blink-settings=primaryHoverType=2,availableHoverTypes=2,primaryPointerType=4,availablePointerTypes=4"
)

# Start a Chrome and close it when the run ends. The close names this Chrome, not the cache, so a Chrome that was
# replaced meanwhile is still closed; it is also safe when the process has gone, and an error in it is dropped so that
# it cannot replace the error that ended the run.
chrome_start <- function() {
  tmp <- file.path(tempdir(), "chrome-tmp")
  dir.create(tmp, showWarnings = FALSE)
  browser <- withr::with_options(
    list(chromote.timeout = 60),
    withr::with_envvar(
      c(TMPDIR = tmp),
      chromote::Chromote$new(browser = chromote::Chrome$new(args = c(chromote::get_chrome_args(), chrome_device_args)))
    )
  )
  # Sessions opened from this browser inherit the limit, in seconds, for navigation and page commands.
  browser$default_timeout <- browser_timeout / 1000
  withr::defer(chrome_close(browser), envir = testthat::teardown_env())
  browser
}

chrome_close <- function(browser) {
  checkmate::assert_r6(browser, "Chromote")
  tryCatch(browser$close(), error = function(e) NULL)
  invisible()
}
