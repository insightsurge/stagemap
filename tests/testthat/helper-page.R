# Helpers for the tests that draw a widget in a real browser page (the binding's and the stage map's browser tests). They
# start no Chrome themselves: the calling test file begins with skip_without_chrome().

# Saves `widget` as a page with its files beside it, opens it in the shared Chrome and returns the page, with its
# console messages (warnings and errors) collected in `$messages`.
# `before` is JavaScript that runs before the page's own scripts: a stand-in for the parts of Shiny the binding talks to.
open_widget <- function(widget, before = NULL, env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  file <- file.path(dir, "map.html")
  htmlwidgets::saveWidget(widget, file, selfcontained = FALSE)
  page <- local_chrome_session(env)
  messages <- new.env()
  messages$seen <- character()
  page$Runtime$enable()
  page$Runtime$consoleAPICalled(function(message) {
    if (message$type %in% c("error", "warning")) {
      messages$seen <- c(
        messages$seen,
        paste(vapply(message$args, function(a) as.character(a$value %||% a$description %||% ""), ""), collapse = " ")
      )
    }
  })
  page$Runtime$exceptionThrown(function(message) {
    messages$seen <- c(messages$seen, paste("exception:", message$exceptionDetails$text))
  })
  if (!is.null(before)) {
    page$Page$enable()
    page$Page$addScriptToEvaluateOnNewDocument(source = before)
  }
  page$go_to(paste0("file://", file), timeout = browser_timeout / 1000)
  list(session = page, messages = messages)
}

# The value of a JavaScript expression in the page.
page_js <- function(page, js) {
  page$session$Runtime$evaluate(js, returnByValue = TRUE, awaitPromise = TRUE)$result$value
}

# Waits until the expression is true in the page: the page's own signal, never a fixed sleep.
wait_for_page <- function(page, js, timeout = browser_timeout) {
  deadline <- Sys.time() + timeout / 1000
  while (!isTRUE(page_js(page, js))) {
    if (Sys.time() > deadline) {
      stop(sprintf("The page never showed: %s", js), call. = FALSE)
    }
    Sys.sleep(0.05)
  }
  invisible(page)
}
