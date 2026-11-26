# stage_map_studio() and the app it builds. The app runs in the browser tests (test-studio-browser.R); here it is built,
# its page is requested from its own handler, and running it is stood in for.

delayedAssign("small", full_map())

# The page the app serves at "/", as text.
studio_page <- function(app) {
  req <- new.env()
  req$PATH_INFO <- "/"
  req$REQUEST_METHOD <- "GET"
  req$QUERY_STRING <- ""
  req$HTTP_HOST <- "localhost"
  app$httpHandler(req)$content
}

describe("stage_map_studio()", {
  skip_if_not_installed("shiny")

  it("refuses a map that is not a stagemap widget, before any other check", {
    expect_error(stage_map_studio(data.frame(a = 1), run = "no"), class = "stagemap_error_widget")
    expect_error(
      stage_map_studio("map"),
      "must be a widget made by a stagemap function",
      class = "stagemap_error_widget"
    )
  })

  it("refuses a run that is not TRUE or FALSE", {
    expect_error(stage_map_studio(run = NA), "run")
    expect_error(stage_map_studio(run = "yes"), "run")
  })

  it("refuses values in the dots", {
    expect_error(stage_map_studio(small, FALSE), class = "stagemap_error_dots")
    expect_error(stage_map_studio(rnu = FALSE), class = "stagemap_error_dots")
  })

  it("returns the app with run = FALSE, on a map or on none", {
    expect_s3_class(stage_map_studio(small, run = FALSE), "shiny.appobj")
    expect_s3_class(stage_map_studio(run = FALSE), "shiny.appobj")
  })

  it("stops with stagemap_error_studio when run = TRUE outside an interactive session", {
    local_mocked_bindings(
      studio_interactive = function() FALSE,
      studio_run = function(app) stop("must not run")
    )
    expect_error(stage_map_studio(small), "needs an interactive R session", class = "stagemap_error_studio")
  })

  it("runs the app with run = TRUE in an interactive session and returns its value invisibly", {
    # Given an interactive session and a stand-in for runApp() that records the app and returns the map from Done
    ran <- new.env()
    local_mocked_bindings(
      studio_interactive = function() TRUE,
      studio_run = function(app) {
        ran$app <- app
        "the map from Done"
      }
    )
    # When the studio runs
    result <- withVisible(stage_map_studio(small))
    # Then it ran the app once and gives back its value, invisibly
    expect_s3_class(ran$app, "shiny.appobj")
    expect_identical(result$value, "the map from Done")
    expect_false(result$visible)
  })
})

describe("stage_map_studio() when the page is closed", {
  skip_if_not_installed("shiny")

  # Runs the app that stage_map_studio() hands to studio_run(), with the stand-ins for its timer and its stop, and
  # returns what they recorded.
  close_page <- function(run, env = parent.frame()) {
    seen <- new.env()
    seen$stops <- 0L
    seen$timers <- list()
    local_mocked_bindings(
      studio_after = function(seconds, fn) seen$timers[[length(seen$timers) + 1L]] <- fn,
      studio_stop = function() seen$stops <- seen$stops + 1L,
      studio_interactive = function() TRUE,
      studio_run = function(app) {
        seen$app <- app
        NULL
      },
      .env = env
    )
    if (run) {
      stage_map_studio(small)
    } else {
      seen$app <- stage_map_studio(small, run = FALSE)
    }
    seen
  }

  it("stops the app with NULL once its page is gone without Done", {
    seen <- close_page(run = TRUE)
    shiny::testServer(seen$app, {
      session$setInputs(`studio-event` = list(seq = 1L, type = "ready", data = list(), rev = 0L))
      session$close()
    })
    # The stop waits for the timer, so a page that reloads can open its new session first
    expect_identical(seen$stops, 0L)
    seen$timers[[1]]()
    expect_identical(seen$stops, 1L)
  })

  it("does not stop the app after Done, which has already returned the map", {
    seen <- close_page(run = TRUE)
    shiny::testServer(seen$app, {
      session$setInputs(`studio-event` = list(seq = 1L, type = "ready", data = list(), rev = 0L))
      session$setInputs(`studio-event` = list(seq = 2L, type = "done", data = list(), rev = 0L))
      session$flushReact()
      session$close()
    })
    seen$timers[[1]]()
    expect_identical(seen$stops, 0L)
  })

  it("leaves an app from run = FALSE running when its page closes", {
    seen <- close_page(run = FALSE)
    shiny::testServer(seen$app, {
      session$close()
    })
    expect_length(seen$timers, 0L)
    expect_identical(seen$stops, 0L)
  })
})

describe("studio_interactive()", {
  it("says whether R runs interactively", {
    expect_identical(studio_interactive(), interactive())
  })
})

describe("studio_app()", {
  skip_if_not_installed("shiny")

  it("checks its arguments", {
    expect_error(studio_app("map"), "map")
    expect_error(studio_app(on_done = "stop"), "on_done")
    expect_error(studio_app(options = list(wait = 1)), "options")
  })

  it("serves the studio's page, in English, with its module script and its settings", {
    page <- studio_page(studio_app(small, options = list(copy_wait_ms = 300)))
    expect_match(page, "<html lang=\"en\">", fixed = TRUE)
    expect_match(page, "<title>stagemap studio</title>", fixed = TRUE)
    expect_match(page, "studio.js\" type=\"module\"", fixed = TRUE)
    expect_match(page, "data-sms-ns=\"studio-\"", fixed = TRUE)
    expect_match(page, "\"copy_wait_ms\":300", fixed = TRUE)
  })

  it("runs the studio's server for the module studio", {
    sent <- new.env()
    sent$messages <- list()
    local_mocked_bindings(studio_send = function(session, message) {
      sent$messages[[length(sent$messages) + 1L]] <- message
    })
    shiny::testServer(studio_app(small), {
      session$setInputs(`studio-event` = list(seq = 1L, type = "ready", data = list(), rev = 0L))
    })
    expect_length(sent$messages, 1L)
    expect_identical(sent$messages[[1]]$ns, "studio-")
  })
})
