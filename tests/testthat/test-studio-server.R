# The studio's server, run with shiny::testServer(): studio_send() is replaced by a recorder, so each test reads the
# messages the page would get. Then the effects, the map it draws and the rule that no observer is made inside another.

delayedAssign("small", full_map(title = "A map"))

event <- function(seq, type, data = structure(list(), names = character()), rev = 0L) {
  list(seq = seq, type = type, data = data, rev = rev)
}

# Records the messages sent and the maps given to `on_done`, in `log`.
local_studio_log <- function(env = parent.frame()) {
  log <- new.env()
  log$messages <- list()
  log$done <- list()
  local_mocked_bindings(
    studio_send = function(session, message) log$messages[[length(log$messages) + 1L]] <- message,
    .env = env
  )
  log
}

describe("studio_server()", {
  skip_if_not_installed("shiny")

  it("sends nothing before the page asks with ready, then every section", {
    log <- local_studio_log()
    shiny::testServer(studio_server, args = list(map = small), {
      session$flushReact()
      expect_length(log$messages, 0L)
      session$setInputs(event = event(1L, "ready"))
      expect_length(log$messages, 1L)
      message <- log$messages[[1]]
      expect_named(message, c("ns", "n", "ack", "rev", "sections"))
      expect_identical(message[c("n", "ack", "rev")], list(n = 1L, ack = 1L, rev = 0L))
      expect_named(
        message$sections,
        c("header", "outline", "inspector", "journal", "start", "status", "notice", "ask", "check", "code", "map")
      )
      expect_identical(message$sections$header$title, "A map")
    })
  })

  it("answers a title with a higher revision and ack, and only the sections that changed", {
    log <- local_studio_log()
    shiny::testServer(studio_server, args = list(map = small), {
      session$setInputs(event = event(1L, "ready"))
      session$setInputs(event = event(2L, "option", list(name = "title", value = "Plan B")))
      message <- log$messages[[2]]
      expect_identical(message[c("n", "ack", "rev")], list(n = 2L, ack = 2L, rev = 1L))
      expect_named(message$sections, c("header", "journal", "status", "code"))
      expect_match(message$sections$code$text, "Plan B", fixed = TRUE)
    })
  })

  it("answers an event that changes nothing with an empty set of sections, so the page is no longer busy", {
    log <- local_studio_log()
    shiny::testServer(studio_server, args = list(map = small), {
      session$setInputs(event = event(1L, "ready"))
      session$setInputs(event = event(2L, "option", list(name = "title", value = "A map")))
      expect_identical(log$messages[[2]]$ack, 2L)
      expect_length(log$messages[[2]]$sections, 0L)
    })
  })

  it("steps no event before ready: a replayed done neither closes the studio nor calls on_done", {
    # Given a session that starts with the last event of an earlier one (Shiny's init carries it), a done
    log <- local_studio_log()
    on_done <- function(map) log$done[[length(log$done) + 1L]] <- map
    shiny::testServer(studio_server, args = list(map = small, on_done = on_done), {
      session$setInputs(event = event(7L, "done"))
      session$setInputs(event = event(8L, "option", list(name = "title", value = "Old edit")))
      # Then nothing is answered and nothing is called
      expect_length(log$messages, 0L)
      expect_length(log$done, 0L)
      # When the page then asks with ready
      session$setInputs(event = event(3L, "ready"))
      # Then it gets the map as it was opened, open, with the ack of the ready alone
      expect_length(log$messages, 1L)
      expect_identical(log$messages[[1]]$ack, 3L)
      expect_identical(log$messages[[1]]$sections$header$title, "A map")
      expect_false(log$messages[[1]]$sections$status$closed)
      expect_length(log$done, 0L)
    })
  })

  it("acknowledges each event as it applies it, in the order they arrive after ready", {
    log <- local_studio_log()
    shiny::testServer(studio_server, args = list(map = small), {
      session$setInputs(event = event(10L, "ready"))
      session$setInputs(event = event(11L, "option", list(name = "title", value = "First")))
      session$setInputs(event = event(12L, "option", list(name = "title", value = "Second")))
      expect_identical(vapply(log$messages, function(m) m$ack, integer(1)), c(10L, 11L, 12L))
      expect_match(log$messages[[2]]$sections$code$text, "First", fixed = TRUE)
      expect_match(log$messages[[3]]$sections$code$text, "Second", fixed = TRUE)
    })
  })

  it("sends every section again when the page asks with ready again", {
    log <- local_studio_log()
    shiny::testServer(studio_server, args = list(map = small), {
      session$setInputs(event = event(1L, "ready"))
      session$setInputs(event = event(2L, "ready"))
      expect_named(
        log$messages[[2]]$sections,
        c("header", "outline", "inspector", "journal", "start", "status", "notice", "ask", "check", "code", "map")
      )
    })
  })

  it("calls on_done once with the map, after the message that says the studio is closed", {
    log <- local_studio_log()
    on_done <- function(map) log$done[[length(log$done) + 1L]] <- list(map = map, messages = length(log$messages))
    shiny::testServer(studio_server, args = list(map = small, on_done = on_done), {
      session$setInputs(event = event(1L, "ready"))
      session$setInputs(event = event(2L, "option", list(name = "title", value = "Plan B")))
      session$setInputs(event = event(3L, "done"))
      session$setInputs(event = event(4L, "done"))
    })
    expect_length(log$done, 1L)
    expect_identical(log$done[[1]]$messages, 3L)
    expect_true(log$messages[[3]]$sections$status$closed)
    expect_identical(sm_widget_data(log$done[[1]]$map)$options$title, "Plan B")
  })

  it("draws the map it was given, as the studio shows it", {
    local_studio_log()
    shiny::testServer(studio_server, args = list(map = small), {
      drawn <- jsonlite::fromJSON(output$map, simplifyVector = FALSE)
      expect_identical(drawn$x$data$options$dismiss, "no_outside")
      expect_true(all(c("title", "details", "stage") %in% unlist(drawn$x$data$options$hosted)))
    })
  })

  it("handles a scripted run of events and only redraws output$map when good$serial rises", {
    log <- local_studio_log()
    shiny::testServer(studio_server, args = list(map = NULL), {
      session$setInputs(event = event(1L, "ready"))
      first_drawn <- jsonlite::fromJSON(output$map, simplifyVector = FALSE)
      expect_true(log$messages[[1]]$sections$start$open)

      session$setInputs(event = event(2L, "open", list(template = "blank", confirm = FALSE)))
      expect_false(log$messages[[2]]$sections$start$open)
      blank_drawn <- jsonlite::fromJSON(output$map, simplifyVector = FALSE)
      expect_length(blank_drawn$x$data$cards, 1L)

      session$setInputs(event = event(3L, "add", list(table = "cards")))
      expect_identical(log$messages[[3]]$sections$inspector$kind, "card")
      added_drawn <- jsonlite::fromJSON(output$map, simplifyVector = FALSE)
      expect_length(added_drawn$x$data$cards, 2L)

      # Breaking the card id leaves good$serial unchanged: output$map still has the last working cards
      new_uid <- log$messages[[3]]$sections$inspector$uid
      session$setInputs(event = event(4L, "edit", list(table = "cards", uid = new_uid, field = "id", value = "")))
      expect_identical(log$messages[[4]]$sections$status$problems, 1L)
      still_drawn <- jsonlite::fromJSON(output$map, simplifyVector = FALSE)
      expect_length(still_drawn$x$data$cards, 2L)

      session$setInputs(event = event(5L, "undo"))
      session$setInputs(event = event(6L, "undo"))
      undone_drawn <- jsonlite::fromJSON(output$map, simplifyVector = FALSE)
      expect_length(undone_drawn$x$data$cards, 1L)
    })
  })

  it("accepts input$map_pick only from the reader after ready, and clears target when id is absent", {
    log <- local_studio_log()
    shiny::testServer(studio_server, args = list(map = small), {
      session$setInputs(map_pick = list(kind = "card", id = "b", by = "reader"))
      expect_length(log$messages, 0L)

      session$setInputs(event = event(1L, "ready"))
      session$setInputs(map_pick = list(kind = "card", id = "b", by = "data"))
      expect_length(log$messages, 1L)

      session$setInputs(map_pick = list(kind = "card", id = "b", by = "reader"))
      expect_length(log$messages, 2L)
      expect_identical(log$messages[[2]]$sections$inspector$sub, "b")

      session$setInputs(map_pick = list(kind = "card", id = NULL, by = "reader"))
      expect_length(log$messages, 3L)
      expect_null(log$messages[[3]]$sections$inspector)
    })
  })

  it("checks its arguments", {
    expect_error(studio_server(""), "id")
    expect_error(studio_server("studio", map = "map"), "map")
    expect_error(studio_server("studio", on_done = "stop"), "on_done")
    expect_error(studio_server("studio", options = list(wait = 1)), "options")
  })
})

describe("studio_send()", {
  it("sends the message as the stagemap:studio custom message", {
    session <- fake_session()
    studio_send(session, list(ns = "studio-", n = 1L))
    expect_identical(session$raw, list(list(type = "stagemap:studio", message = list(ns = "studio-", n = 1L))))
  })

  it("checks its arguments", {
    expect_error(studio_send(list(), list(n = 1L)), "sendCustomMessage")
    expect_error(studio_send(fake_session(), list(1)), "message")
  })
})

describe("studio_effects()", {
  skip_if_not_installed("shiny")

  it("selects a card, a stage or nothing, and lights cards, through the map's proxy", {
    session <- fake_session()
    proxy <- sm_proxy("map", session)
    outbox <- new.env()
    studio_effects(
      list(
        list(type = "select", kind = "card", id = "a"),
        list(type = "select", kind = "stage", id = "write"),
        list(type = "select", kind = "none", id = NULL),
        list(type = "highlight", ids = c("a", "b"), links = NULL)
      ),
      proxy,
      outbox
    )
    session$flush()
    commands <- lapply(session$sent, function(sent) {
      list(command = sent$message$command, data = jsonlite::fromJSON(sent$message$data, simplifyVector = FALSE))
    })
    expect_identical(
      vapply(commands, function(command) command$command, ""),
      c("select", "select", "select", "highlight")
    )
    expect_identical(unlist(commands[[1]]$data$ids), "a")
    expect_identical(commands[[2]]$data, list(kind = "stage", id = "write"))
    expect_null(commands[[3]]$data)
    expect_identical(unlist(commands[[4]]$data$ids), c("a", "b"))
  })

  it("keeps the map of Done for the message that tells the page", {
    outbox <- new.env()
    outbox$done <- list()
    studio_effects(list(list(type = "done", map = "the map")), sm_proxy("map", fake_session()), outbox)
    expect_identical(outbox$done, list("the map"))
  })

  it("checks its arguments", {
    proxy <- sm_proxy("map", fake_session())
    expect_error(studio_effects("x", proxy, new.env()), "effects")
    expect_error(studio_effects(list(), "proxy", new.env()), "proxy")
    expect_error(studio_effects(list(), proxy, list()), "outbox")
  })
})

describe("studio_display_map()", {
  it("leaves the title, the details and the stage panel to the studio, keeps the pick, and has no fixed size or id", {
    map <- stage_map(
      data.frame(id = "a", label = "A", stage = "s", lane = "l"),
      title = "T",
      dismiss = "any",
      width = "300px",
      height = "200px",
      element_id = "fixed"
    )
    shown <- studio_display_map(map)
    options <- sm_widget_data(shown)$options
    expect_setequal(options$hosted, c("steps", "title", "details", "stage"))
    expect_identical(options$dismiss, "no_outside")
    expect_null(shown$width)
    expect_null(shown$height)
    expect_null(shown$elementId)
    expect_identical(options$title, "T")
  })

  it("checks the map", {
    expect_error(studio_display_map("map"), "map")
  })
})

describe("the studio's R files", {
  it("make no observer, reactive or output inside another one", {
    makers <- c(
      "observe",
      "observeEvent",
      "reactive",
      "eventReactive",
      "reactiveVal",
      "reactiveValues",
      "bindEvent",
      "render_stage_map",
      "renderText",
      "renderUI",
      "downloadHandler",
      "moduleServer"
    )
    # The makers named in a call, at any depth, as `f` or `pkg::f`
    called <- function(x) {
      if (!is.call(x)) {
        return(character())
      }
      head <- x[[1]]
      name <- if (is.call(head) && identical(head[[1]], as.name("::"))) as.character(head[[3]]) else deparse(head)
      c(if (name %in% makers) name, unlist(lapply(as.list(x)[-1], called)))
    }
    # A maker inside another maker's arguments, skipping moduleServer(), which holds them all
    nested <- function(x) {
      if (!is.call(x)) {
        return(character())
      }
      head <- x[[1]]
      name <- if (is.call(head) && identical(head[[1]], as.name("::"))) as.character(head[[3]]) else deparse(head)
      if (name %in% setdiff(makers, "moduleServer")) {
        return(unlist(lapply(as.list(x)[-1], called)))
      }
      unlist(lapply(as.list(x)[-1], nested))
    }
    # The check sees a nested maker, and an observer beside another inside moduleServer() is fine
    expect_identical(nested(quote(shiny::observe(observeEvent(x, y)))), "observeEvent")
    expect_length(
      nested(quote(shiny::moduleServer(id, function(input) {
        shiny::observe(x)
        shiny::observe(y)
      }))),
      0L
    )
    files <- list.files(test_path("..", "..", "R"), pattern = "^studio.*[.]R$", full.names = TRUE)
    skip_if(length(files) == 0L, "the R sources are not beside the tests")
    found <- unlist(lapply(files, function(file) unlist(lapply(as.list(parse(file, keep.source = FALSE)), nested))))
    expect_length(found, 0L)
  })
})
