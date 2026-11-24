# The binding draws the map in a real browser. Skips the whole file on CRAN or without Chrome, before any code runs.
skip_without_chrome()

# Saves `widget` as a page with its files beside it, opens it in the shared Chrome and returns the page, with its
# console messages (warnings and errors) collected in `$messages`.
open_widget <- function(widget, env = parent.frame()) {
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

describe("the htmlwidgets binding", {
  data <- function() {
    data <- map_data()
    data$nodes <- data.frame(id = c("a", "b"), label = c("A", "B"), stage = c("s", "s"), lane = "l")
    data
  }
  cards <- "document.querySelectorAll('#map [data-card]').length"

  it("draws the map with the engine: one card for each node, in the engine's root", {
    page <- open_widget(sm_widget(data(), element_id = "map"))
    wait_for_page(page, paste(cards, "=== 2"))
    expect_identical(
      page_js(page, "document.querySelector('#map > div').getAttribute('data-stagemap-visual')"),
      "stage-map"
    )
    expect_identical(
      page_js(page, "[...document.querySelectorAll('#map [data-card]')].map(c => c.dataset.card).join()"),
      "a,b"
    )
    expect_identical(page_js(page, "document.querySelectorAll('#map > div').length"), 1L)
  })

  it("writes no warning and no error to the console", {
    page <- open_widget(sm_widget(data(), element_id = "map"))
    wait_for_page(page, paste(cards, "=== 2"))
    expect_identical(page$messages$seen, character())
  })

  it("draws again in the same root for new data, and leaves one root", {
    page <- open_widget(sm_widget(data(), element_id = "map"))
    wait_for_page(page, paste(cards, "=== 2"))
    # Given a render with one node more, sent to the instance htmlwidgets made
    more <- data()
    more$nodes <- rbind(more$nodes, data.frame(id = "c", label = "C", stage = "s", lane = "l"))
    x <- jsonlite::toJSON(sm_widget(more)$x, auto_unbox = TRUE, null = "null", json_verbatim = TRUE)
    page_js(
      page,
      sprintf(
        "(() => { window.__root = document.querySelector('#map > div'); HTMLWidgets.find('#map').renderValue(%s); })()",
        x
      )
    )
    # Then the card appears, in the root that was already there
    wait_for_page(page, paste(cards, "=== 3"))
    expect_true(page_js(page, "window.__root === document.querySelector('#map > div')"))
    expect_identical(page_js(page, "document.querySelectorAll('#map > div').length"), 1L)
  })

  it("follows the colours of the page when the look says mode host", {
    widget <- sm_widget(data(), element_id = "map")
    widget$x$look <- list(mode = "host")
    page <- open_widget(widget)
    wait_for_page(page, paste(cards, "=== 2"))
    expect_true(page_js(page, "document.querySelector('#map > div').hasAttribute('data-stagemap-mode')"))
    expect_identical(page$messages$seen, character())
  })

  it("says what is wrong in the element when the engine is not on the page", {
    widget <- sm_widget(data(), element_id = "map")
    widget$x$engine$global <- "no_such_engine"
    page <- open_widget(widget)
    wait_for_page(page, "document.getElementById('map').textContent.includes('no_such_engine')")
    expect_identical(page_js(page, "document.querySelectorAll('#map [data-card]').length"), 0L)
  })
})
