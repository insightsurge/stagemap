# The studio's server: one store of state, one observer for the page's events, one observer that answers with the view,
# and the map. Every event goes through studio_step(); every answer goes through studio_send() from onFlushed, so it
# leaves after the outputs of the same flush. No observer, reactive or handler is made inside another, so a session
# always has the same number of them.

# The server of the studio module `id`, opened on `map` (NULL for the built-in example map). Events reach it in the
# order they were sent, `ready` first, so the `ack` of an answer is the last event the server has applied. `on_done` is
# called with the map once Done has been answered on the page. `options` are the page's settings (studio_options());
# the server checks them and the page reads them from the boot JSON.
studio_server <- function(id, map = NULL, on_done = shiny::stopApp, options = list()) {
  checkmate::assert_string(id, min.chars = 1L)
  checkmate::assert_class(map, "stagemap_widget", null.ok = TRUE)
  checkmate::assert_function(on_done)
  studio_options(options)
  rlang::check_installed("shiny")
  shiny::moduleServer(id, function(input, output, session) {
    first <- studio_state_new(map)
    store <- shiny::reactiveVal(first)
    # What the server has told the page: the view of the last message, the count of messages, whether the page has
    # asked with `ready` yet, and the maps of Done waiting for their message to leave.
    outbox <- new.env(parent = emptyenv())
    outbox$view <- NULL
    outbox$n <- 0L
    outbox$ready <- FALSE
    outbox$done <- list()
    proxy <- stage_map_proxy("map", session)

    shiny::observeEvent(input$event, {
      event <- input$event
      is_ready <- is.list(event) && identical(event$type, "ready")
      # The page sends `ready` first. An event that comes before it is not the page's own: when a page reconnects, the
      # new session starts with the last event of the old one (Shiny's `init` carries every input), which may be a
      # `done`. Only `ready` is stepped until it has come.
      if (!outbox$ready && !is_ready) {
        return()
      }
      if (is_ready) {
        # The page starts again (a first load or a reconnect): it gets every section.
        outbox$ready <- TRUE
        outbox$view <- NULL
      }
      result <- studio_step(shiny::isolate(store()), event)
      store(result$state)
      studio_effects(result$effects, proxy, outbox)
    })

    shiny::observe({
      state <- store()
      if (!outbox$ready) {
        return()
      }
      view <- studio_view(state)
      outbox$n <- outbox$n + 1L
      message <- c(
        list(ns = session$ns(""), n = outbox$n, ack = state$ack, rev = state$rev),
        studio_message(view, outbox$view)
      )
      outbox$view <- view
      done <- outbox$done
      outbox$done <- list()
      session$onFlushed(
        function() {
          studio_send(session, message)
          for (map in done) {
            on_done(map)
          }
        },
        once = TRUE
      )
    })

    output$map <- render_stage_map(studio_display_map(first$good$map))
  })
}

# Sends `message` to the page. The only call to sendCustomMessage() for the studio, so a test can record what is sent.
studio_send <- function(session, message) {
  checkmate::assert_function(session$sendCustomMessage, .var.name = "session$sendCustomMessage")
  checkmate::assert_list(message, names = "unique")
  session$sendCustomMessage("stagemap:studio", message)
  invisible(NULL)
}

# Carries out the effects of one step: a select or highlight goes to the drawn map through `proxy`, and the map of a
# Done waits in `outbox` until the message that tells the page has left.
studio_effects <- function(effects, proxy, outbox) {
  checkmate::assert_list(effects)
  checkmate::assert_class(proxy, "stagemap_proxy")
  checkmate::assert_environment(outbox)
  for (effect in effects) {
    switch(
      effect$type,
      select = if (identical(effect$kind, "stage")) {
        sm_send(proxy, "select", data = list(kind = "stage", id = effect$id))
      } else {
        stage_map_select(proxy, if (identical(effect$kind, "card")) effect$id else character())
      },
      highlight = stage_map_highlight(proxy, effect$ids, links = effect$links),
      done = outbox$done[[length(outbox$done) + 1L]] <- effect$map
    )
  }
  invisible(NULL)
}

# The map as the studio draws it: the same data, with the title, the card's details and the stage's panel left to the
# studio's own page (`hosted`), a click outside the map keeping the pick, and no fixed size or element id.
studio_display_map <- function(map) {
  checkmate::assert_class(map, "stagemap_widget")
  data <- sm_widget_data(map)
  data$options <- as.list(data$options)
  data$options$hosted <- union(unlist(data$options$hosted), c("title", "details", "stage"))
  data$options$dismiss <- "no_outside"
  sm_rebuild(map, data, width = NULL, height = NULL, element_id = NULL)
}
