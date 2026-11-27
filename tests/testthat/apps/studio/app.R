# The app the studio's browser tests drive: the studio module on its own page, with the map named by the environment
# variable STAGEMAP_STUDIO_FIXTURE ("small", the default, "none", "large", or "steps") and Copy's wait from
# STAGEMAP_STUDIO_COPY_WAIT (or STAGEMAP_STUDIO_COPY_WAIT_MS). Its `on_done` keeps the map it was given and shows its
# class, title and card count as JSON in a text output beside the studio, so a test can read what Done returned, and
# `map_state` exposes `input$map_state` as JSON for redraw-preservation checks.
library(shiny)
library(stagemap)

# The studio's internals: the app is built from its module so that `on_done` and the options can be set here.
studio_ui <- utils::getFromNamespace("studio_ui", "stagemap")
studio_server <- utils::getFromNamespace("studio_server", "stagemap")

fixtures <- new.env(parent = globalenv())
sys.source("../../helper-stage_map.R", envir = fixtures)
sys.source("../../helper-studio.R", envir = fixtures)

fixture <- Sys.getenv("STAGEMAP_STUDIO_FIXTURE", "small")
map <- switch(
  fixture,
  small = fixtures$studio_small(),
  large = fixtures$studio_large(),
  steps = fixtures$studio_steps(),
  none = NULL,
  stop("Unknown fixture: ", fixture)
)
copy_wait <- Sys.getenv("STAGEMAP_STUDIO_COPY_WAIT", "")
if (!nzchar(copy_wait)) {
  copy_wait <- Sys.getenv("STAGEMAP_STUDIO_COPY_WAIT_MS", "5000")
}
options <- list(copy_wait_ms = as.integer(copy_wait))

ui <- function(request) {
  tagList(
    studio_ui("studio", options),
    # The two readouts wrap: a long line would make the page itself wider than a phone screen, and with classic
    # scrollbars the sideways scrollbar takes 15px off the height the studio fills.
    tags$pre(
      id = "done_seen",
      class = "test-done",
      style = "white-space: pre-wrap; overflow-wrap: anywhere;",
      textOutput("done", inline = TRUE)
    ),
    tags$pre(
      id = "map_state_seen",
      class = "test-map-state",
      style = "white-space: pre-wrap; overflow-wrap: anywhere;",
      textOutput("map_state", inline = TRUE)
    )
  )
}

server <- function(input, output, session) {
  done <- reactiveVal(NULL)
  studio_server("studio", map, on_done = function(map) done(map), options = options)
  output$done <- renderText({
    req(done())
    returned <- done()
    cards <- stage_map_tables(returned)$cards
    as.character(jsonlite::toJSON(
      list(
        class = class(returned),
        title = returned$stagemap$data$options$title,
        cards = nrow(cards)
      ),
      auto_unbox = TRUE
    ))
  })
  output$map_state <- renderText({
    req(input[["studio-map_state"]])
    as.character(jsonlite::toJSON(input[["studio-map_state"]], auto_unbox = FALSE))
  })
}

shinyApp(ui, server)
