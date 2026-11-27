# The studio's server: one store of state, one observer for the page's events, one observer that answers with the view,
# and the map. Every event goes through studio_step(); every answer goes through studio_send() from onFlushed, so it
# leaves after the outputs of the same flush. No observer, reactive or handler is made inside another, so a session
# always has the same number of them.

# The server of the studio module `id`, opened on `map` (NULL for the built-in example map). Events reach it in the
# order they were sent, `ready` first, so the `ack` of an answer is the last event the server has applied. `on_done` is
# called with the map once Done has been answered on the page. `options` are the page's settings (studio_options());
# the server checks them and the page reads them from the boot JSON. `keep` is NULL for a hosted app: every session
# starts from `map`, no state passes from one session to the next, and a `ready` that comes from a page that was loaded
# before (its connection dropped) gets a notice that the studio started again. With an environment (the app that
# stage_map_studio() runs for one person) the last state is kept in `keep$state`, and a new session, from a reload or a
# reconnect, starts from it and continues the work.
studio_server <- function(id, map = NULL, on_done = shiny::stopApp, options = list(), keep = NULL) {
  checkmate::assert_string(id, min.chars = 1L)
  checkmate::assert_class(map, "stagemap_widget", null.ok = TRUE)
  checkmate::assert_function(on_done)
  studio_options(options)
  checkmate::assert_environment(keep, null.ok = TRUE)
  rlang::check_installed("shiny")
  shiny::moduleServer(id, function(input, output, session) {
    first <- if (is.null(keep) || is.null(keep$state)) studio_state_new(map) else studio_state_resume(keep$state)
    store <- shiny::reactiveVal(first)
    drawn_map <- shiny::reactiveVal(first$good$map)
    # What the server has told the page: the view of the last message, the count of messages, whether the page has
    # asked with `ready` yet, and the maps of Done waiting for their message to leave.
    outbox <- new.env(parent = emptyenv())
    outbox$view <- NULL
    outbox$n <- 0L
    outbox$ready <- FALSE
    outbox$done <- list()
    # The code room's last view: kept for this session only, so it goes with the session.
    code_cache <- new.env(parent = emptyenv())
    proxy <- stage_map_proxy("map", session)

    step <- function(fn) {
      prev <- shiny::isolate(store())
      result <- fn(prev)
      store(result$state)
      if (!is.null(keep)) {
        keep$state <- result$state
      }
      if (!identical(result$state$good$serial, prev$good$serial)) {
        drawn_map(result$state$good$map)
      }
      studio_effects(result$effects, proxy, outbox)
    }

    # Register `map_pick` before `event` so a pick and an immediate action (`+ Card`) in the same Shiny message
    # apply the pick first; an edit flushed before a pick addresses its row by uid and does not move `state$target`.
    shiny::observeEvent(input$map_pick, {
      if (!outbox$ready) {
        return()
      }
      pick <- input$map_pick
      if (!is.list(pick) || !identical(pick$by, "reader")) {
        return()
      }
      kind <- if (is.character(pick$kind) && length(pick$kind) == 1L && nzchar(pick$kind)) pick$kind else NULL
      id <- if (is.character(pick$id) && length(pick$id) == 1L && nzchar(pick$id)) pick$id else NULL
      step(function(state) studio_pick(state, kind, id))
    })

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
      step(function(state) {
        res <- studio_step(state, event)
        # A `ready` numbered above 1 comes from a page whose connection dropped: this session is new, and when it
        # started from the map it opened with, the person is told.
        if (is_ready && is.null(keep) && checkmate::test_int(event$seq, lower = 2)) {
          res$state <- studio_next_notice(res$state, studio_restart_notice, tone = "problem")
        }
        res
      })
    })

    shiny::observe({
      state <- store()
      if (!outbox$ready) {
        return()
      }
      view <- studio_view(state, code_cache)
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

    output$map <- render_stage_map(studio_display_map(drawn_map()))

    output$download_r <- shiny::downloadHandler(
      filename = function() "map.R",
      content = function(file) {
        writeBin(charToRaw(enc2utf8(studio_code_file(shiny::isolate(store())))), file)
      }
    )
    shiny::outputOptions(output, "download_r", suspendWhenHidden = FALSE)

    for (tbl_name in map_table_names) {
      local({
        name <- tbl_name
        id <- paste0("download_csv_", name)
        output[[id]] <- shiny::downloadHandler(
          filename = function() paste0(name, ".csv"),
          content = function(file) {
            writeBin(charToRaw(enc2utf8(studio_csv(shiny::isolate(store()), name))), file)
          }
        )
        shiny::outputOptions(output, id, suspendWhenHidden = FALSE)
      })
    }
  })
}

# What the page is told when its connection dropped and the new session started from the map the studio opened with.
studio_restart_notice <- "The connection was lost; the studio started again from the map it opened with."

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
