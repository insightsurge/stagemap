# The app the studio's browser tests drive: the studio module on its own page, with the map named by the environment
# variable STAGEMAP_STUDIO_FIXTURE ("small", the default, or "none" for the studio's own map of one card) and Copy's wait
# from STAGEMAP_STUDIO_COPY_WAIT_MS. Its `on_done` keeps the map it was given and shows its title and class as JSON in
# a text output beside the studio, so a test can read what Done returned.
library(shiny)
library(stagemap)

# The studio's internals: the app is built from its module so that `on_done` and the options can be set here.
studio_ui <- utils::getFromNamespace("studio_ui", "stagemap")
studio_server <- utils::getFromNamespace("studio_server", "stagemap")

small_map <- function() {
  stage_map(
    data.frame(
      id = c("a", "b", "c", "d"),
      label = c("Draft", "Review", "Publish", "Archive"),
      stage = c("write", "check", "check", "ship"),
      lane = c("docs", "docs", "code", "code"),
      status = c("done", "running", "waiting", "waiting")
    ),
    data.frame(id = c("write", "check", "ship"), label = c("Write", "Check", "Ship")),
    data.frame(id = c("docs", "code"), label = c("Docs", "Code")),
    title = "A small piece of work"
  ) |>
    add_links(data.frame(from = c("a", "b", "c"), to = c("b", "c", "d")))
}

fixture <- Sys.getenv("STAGEMAP_STUDIO_FIXTURE", "small")
map <- switch(fixture, small = small_map(), none = NULL, stop("Unknown fixture: ", fixture))
options <- list(copy_wait_ms = as.integer(Sys.getenv("STAGEMAP_STUDIO_COPY_WAIT_MS", "5000")))

ui <- function(request) {
  tagList(
    studio_ui("studio", options),
    tags$pre(id = "done_seen", class = "test-done", textOutput("done", inline = TRUE))
  )
}

server <- function(input, output, session) {
  done <- reactiveVal(NULL)
  studio_server("studio", map, on_done = function(map) done(map), options = options)
  output$done <- renderText({
    req(done())
    as.character(jsonlite::toJSON(
      list(class = class(done()), title = done()$stagemap$data$options$title),
      auto_unbox = TRUE
    ))
  })
}

shinyApp(ui, server)
