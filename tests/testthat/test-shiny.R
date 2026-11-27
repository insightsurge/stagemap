skip_if_not_installed("shiny")

describe("sm_proxy()", {
  it("is a value object that holds the namespaced id, the session and the flush choice", {
    session <- fake_session()
    proxy <- sm_proxy("map", session = session)
    expect_s3_class(proxy, "stagemap_proxy")
    expect_identical(proxy$id, "mod-map")
    expect_identical(proxy$session, session)
    expect_true(proxy$defer)
  })

  it("does not add the namespace twice when the id already has it", {
    session <- fake_session()
    expect_identical(sm_proxy("map", session = session)$id, sm_proxy(session$ns("map"), session = session)$id)
  })

  it("leaves the id alone in a session with no namespace", {
    expect_identical(sm_proxy("map", session = fake_session(prefix = ""))$id, "map")
  })

  it("follows Shiny's own namespace in a module, plain or already namespaced", {
    shiny::testServer(
      function(id) {
        shiny::moduleServer(id, function(input, output, session) {
          session$userData$ids <- c(sm_proxy("map")$id, sm_proxy(session$ns("map"))$id)
          session$userData$prefix <- session$ns("")
        })
      },
      {
        expect_identical(session$userData$ids, paste0(session$userData$prefix, c("map", "map")))
        expect_match(session$userData$ids[1], "-map$")
      },
      args = list(id = "inner")
    )
  })

  it("waits for the flush by default, and not when asked", {
    expect_true(sm_proxy("map", session = fake_session())$defer)
    expect_false(sm_proxy("map", session = fake_session(), defer_until_flush = FALSE)$defer)
  })

  it("prints and formats itself", {
    proxy <- sm_proxy("map", session = fake_session())
    expect_identical(format(proxy), c("<stagemap_proxy>", "  id: mod-map"))
    expect_output(print(proxy), "<stagemap_proxy>", fixed = TRUE)
  })

  it("checks its arguments", {
    expect_error(sm_proxy(1, session = fake_session()), "id")
    expect_error(sm_proxy("", session = fake_session()), "id")
    expect_error(sm_proxy("map", session = NULL), "session")
    expect_error(sm_proxy("map", session = fake_session(), defer_until_flush = "yes"), "defer_until_flush")
  })
})

describe("sm_send()", {
  it("sends nothing until the flush, then every command in call order", {
    # Given two commands in one observer
    session <- fake_session()
    proxy <- sm_proxy("map", session = session)
    sm_send(proxy, "select", data = list(kind = "card", id = "a"))
    sm_send(proxy, "history")
    # Then nothing has left, and one flush callback is waiting
    expect_length(session$sent, 0L)
    expect_length(session$flush_callbacks, 1L)
    expect_identical(session$flush_requests, 1L)
    # When the flush happens
    session$flush()
    # Then both leave in order, as one custom message each
    expect_identical(vapply(session$sent, function(m) m$type, ""), c("stagemap:command", "stagemap:command"))
    expect_identical(vapply(session$sent, function(m) m$message$command, ""), c("select", "history"))
    expect_identical(unclass(session$sent[[1]]$message$data), "{\"kind\":\"card\",\"id\":\"a\"}")
    expect_identical(session$sent[[1]]$message$id, "mod-map")
  })

  it("sends every command of a flush as one message, a list in call order", {
    session <- fake_session()
    proxy <- sm_proxy("map", session = session)
    for (id in c("a", "b", "c")) {
      sm_send(proxy, "hide", data = list(id = id))
    }
    session$flush()
    expect_length(session$raw, 1L)
    expect_identical(session$raw[[1]]$type, "stagemap:command")
    expect_null(names(session$raw[[1]]$message))
    expect_identical(vapply(session$raw[[1]]$message, function(m) m$command, ""), rep("hide", 3L))
    expect_identical(vapply(session$raw[[1]]$message, function(m) as_list(m$data)$id, ""), c("a", "b", "c"))
  })

  it("sends nothing for a flush that has no command", {
    session <- fake_session()
    queue <- new.env()
    queue$pending <- list()
    send_pending(session, queue)
    expect_length(session$raw, 0L)
  })

  it("starts a new batch after a flush", {
    session <- fake_session()
    proxy <- sm_proxy("map", session = session)
    sm_send(proxy, "history")
    session$flush()
    sm_send(proxy, "history")
    session$flush()
    expect_length(session$sent, 2L)
  })

  it("returns the proxy invisibly, so calls pipe", {
    proxy <- sm_proxy("map", session = fake_session())
    expect_invisible(result <- sm_send(proxy, "history"))
    expect_identical(result, proxy)
  })

  it("stamps each command with the latest revision of the reader's choice that R has seen", {
    session <- fake_session(input = list(map_stagemap_revision = 3L))
    proxy <- sm_proxy("map", session = session)
    sm_send(proxy, "select", data = list(kind = "card", id = "a"))
    session$flush()
    expect_identical(session$sent[[1]]$message$revision, 3L)
  })

  it("counts revision 0 when the reader has chosen nothing, and ignores a value that is not a count", {
    session <- fake_session()
    sm_send(sm_proxy("map", session = session), "select")
    session$flush()
    expect_identical(session$sent[[1]]$message$revision, 0L)
    for (odd in list(NA_integer_, "3", c(1L, 2L), list(revision = 3L))) {
      session <- fake_session(input = list(map_stagemap_revision = odd))
      expect_identical(latest_revision(sm_proxy("map", session = session)), 0L)
    }
  })

  it("does not read the revision from the selection input, which holds ids", {
    session <- fake_session(input = list(map_selected = "a", map_pick = list(revision = 5L)))
    expect_identical(latest_revision(sm_proxy("map", session = session)), 0L)
  })

  it("reads the revision under the name the module sees", {
    session <- fake_session(prefix = "mod-", input = list(map_stagemap_revision = 2L))
    sm_send(sm_proxy("map", session = session), "select")
    session$flush()
    expect_identical(session$sent[[1]]$message$revision, 2L)
  })

  it("sends at once, past the flush, for a proxy made with defer_until_flush = FALSE", {
    session <- fake_session()
    sm_send(sm_proxy("map", session = session, defer_until_flush = FALSE), "select")
    expect_length(session$sent, 1L)
    expect_length(session$flush_callbacks, 0L)
    expect_identical(session$sent[[1]]$type, "stagemap:command")
  })

  it("sends every command the contract lists, among them the ones the package relies on", {
    session <- fake_session()
    proxy <- sm_proxy("map", session = session)
    for (command in kit_relied_on$commands) {
      expect_no_warning(sm_send(proxy, command))
    }
    session$flush()
    expect_identical(vapply(session$sent, function(m) m$message$command, ""), kit_relied_on$commands)
  })

  it("warns and sends nothing for a command the contract does not list", {
    session <- fake_session()
    proxy <- sm_proxy("map", session = session)
    warning <- expect_warning(sm_send(proxy, "selct"), class = "stagemap_warning_command")
    expect_match(conditionMessage(warning), "Commands it takes: .*select")
    expect_length(session$flush_callbacks, 0L)
  })

  it("follows the contract's list, not one of its own", {
    local_spec(list(commands = c("select", "hosted")))
    session <- fake_session()
    proxy <- sm_proxy("map", session = session)
    sm_send(proxy, "select")
    expect_warning(sm_send(proxy, "history"), class = "stagemap_warning_command")
    session$flush()
    expect_identical(vapply(session$sent, function(m) m$message$command, ""), "select")
  })

  it("sends nothing when the contract lists no commands", {
    local_spec(list(commands = character()))
    session <- fake_session()
    warning <- expect_warning(
      sm_send(sm_proxy("map", session = session), "select"),
      class = "stagemap_warning_command"
    )
    expect_match(conditionMessage(warning), "It takes no commands.", fixed = TRUE)
    expect_no_match(conditionMessage(warning), "Commands it takes", fixed = TRUE)
    expect_length(session$flush_callbacks, 0L)
  })

  it("writes a named vector as an object, so c(kind = , id = ) selects", {
    session <- fake_session()
    sm_send(sm_proxy("map", session = session), "select", data = c(kind = "card", id = "a"))
    session$flush()
    expect_identical(unclass(session$sent[[1]]$message$data), "{\"kind\":\"card\",\"id\":\"a\"}")
  })

  it("sends a command with a highlight's ids and links as the engine reads them", {
    session <- fake_session()
    sm_send(
      sm_proxy("map", session = session),
      "highlight",
      data = list(ids = I("a"), links = data.frame(from = "a", to = "b"))
    )
    session$flush()
    expect_identical(
      unclass(session$sent[[1]]$message$data),
      "{\"ids\":[\"a\"],\"links\":[{\"from\":\"a\",\"to\":\"b\"}]}"
    )
  })

  it("warns and sends nothing when the data cannot be written as JSON", {
    session <- fake_session()
    proxy <- sm_proxy("map", session = session)
    expect_warning(sm_send(proxy, "select", data = new.env()), class = "stagemap_warning_command")
    expect_length(session$flush_callbacks, 0L)
    expect_length(session$sent, 0L)
  })

  it("shows the message of a data error as it is, with its braces", {
    local_mocked_bindings(convert_json = function(...) stop("bad {x}", call. = FALSE))
    session <- fake_session()
    warning <- expect_warning(
      sm_send(sm_proxy("map", session = session), "select", data = 1),
      class = "stagemap_warning_command"
    )
    expect_match(conditionMessage(warning), "bad {x}", fixed = TRUE)
    expect_no_match(conditionMessage(warning), "{{", fixed = TRUE)
  })

  it("names the function that called it in a warning, so a caller's own function is shown", {
    session <- fake_session()
    proxy <- sm_proxy("map", session = session)
    select_card <- function() sm_send(proxy, "selct")
    warning <- expect_warning(select_card(), class = "stagemap_warning_command")
    expect_identical(warning$call, quote(select_card()))
    pick <- function() sm_send(proxy, "select", data = new.env())
    expect_identical(expect_warning(pick(), class = "stagemap_warning_command")$call, quote(pick()))
  })

  it("checks its arguments", {
    proxy <- sm_proxy("map", session = fake_session())
    expect_error(sm_send("map", "select"), "proxy")
    expect_error(sm_send(proxy, "select", call = 1), "call")
    expect_error(sm_send(proxy, c("a", "b")), "command")
    expect_error(sm_send(proxy, "select", dat = 1), class = "stagemap_error_dots")
  })
})

describe("sm_state()", {
  held <- list(selected = c("adae", "adsl"), hidden = character())

  it("reads the whole state, one field of it, or a field the state does not have", {
    session <- fake_session(prefix = "", input = list(view_state = held))
    expect_identical(sm_state("view", session = session), held)
    expect_identical(sm_state("view", "selected", session = session), c("adae", "adsl"))
    expect_null(sm_state("view", "nothing", session = session))
  })

  it("gives NULL before the page has answered", {
    session <- fake_session(prefix = "")
    expect_null(sm_state("view", session = session))
    expect_null(sm_state("view", "selected", session = session))
  })

  it("takes a plain or a namespaced id in a module, and reads the name the module sees", {
    session <- fake_session(prefix = "mod-", input = list(view_state = held))
    expect_identical(sm_state("view", "selected", session = session), c("adae", "adsl"))
    expect_identical(sm_state("mod-view", "selected", session = session), c("adae", "adsl"))
  })

  it("reads one input in a reactive, sends nothing, and runs again only when the state changes", {
    shiny::testServer(
      function(id) {
        shiny::moduleServer(id, function(input, output, session) {
          runs <- 0L
          seen <- shiny::reactive({
            runs <<- runs + 1L
            sm_state("view", "selected")
          })
          shiny::observe(seen())
          session$userData$runs <- function() runs
          session$userData$seen <- seen
        })
      },
      {
        # Given a reactive that reads the state before the page has answered
        session$flushReact()
        expect_null(session$userData$seen())
        before <- session$userData$runs()
        # When the page answers, and the server then flushes again with no new answer
        session$setInputs(view_state = list(selected = c("a", "b")))
        session$flushReact()
        session$flushReact()
        session$flushReact()
        # Then the reactive saw the answer, ran once more for it, and queued no command
        expect_identical(session$userData$seen(), c("a", "b"))
        expect_identical(session$userData$runs(), before + 1L)
        expect_null(session$userData$stagemap_queue)
      },
      args = list(id = "inner")
    )
  })

  it("checks its arguments", {
    session <- fake_session()
    expect_error(sm_state(1, session = session), "output_id")
    expect_error(sm_state("view", name = c("a", "b"), session = session), "name")
    expect_error(sm_state("view", name = "", session = session), "name")
    expect_error(sm_state("view", session = NULL), "session")
  })
})

# `x` with the fields in `...` replaced (a NULL stays as a NULL field, and a list is not merged).
replaced <- function(x, ...) {
  changes <- list(...)
  for (name in names(changes)) {
    x[name] <- list(changes[[name]])
  }
  x
}

describe("the stagemap.state input type", {
  # What the engine answers to `state`, as Shiny hands it over (arrays are lists).
  answered <- function(...) {
    state <- list(
      selected = "b",
      selected_ids = list("a", "b"),
      stage = NULL,
      step = -1L,
      highlighted = list(ids = list(), links = list()),
      hidden = list(),
      disabled = list("c"),
      host_changes = list(list(id = "c", hidden = NULL, disabled = TRUE, reason = "no"))
    )
    replaced(state, ...)
  }

  it("gives the six fields in order, and leaves out the engine's lead card and host changes", {
    out <- sm_state_value(answered(), NULL, "view_state")
    expect_identical(names(out), c("selected", "stage", "step", "highlighted", "hidden", "disabled"))
    expect_identical(out$selected, c("a", "b"))
    expect_identical(out$disabled, "c")
    expect_identical(names(out$highlighted), c("ids", "links"))
  })

  it("gives no ids as character(0), the stage as a vector of length 0 or 1, and no link as no rows", {
    out <- sm_state_value(answered(selected_ids = list()), NULL, "view_state")
    expect_identical(out$selected, character())
    expect_identical(out$hidden, character())
    expect_identical(out$stage, character())
    expect_identical(out$highlighted$ids, character())
    expect_identical(out$highlighted$links, data.frame(from = character(), to = character(), kind = character()))
    expect_identical(sm_state_value(answered(stage = "s"), NULL, "view_state")$stage, "s")
  })

  it("counts the step from 1, with 0 at the start or without a player", {
    expect_identical(sm_state_value(answered(step = -1L), NULL, "view_state")$step, 0L)
    expect_identical(sm_state_value(answered(step = 0L), NULL, "view_state")$step, 1L)
    expect_identical(sm_state_value(answered(step = 2), NULL, "view_state")$step, 3L)
    expect_identical(sm_state_value(answered(step = NULL), NULL, "view_state")$step, 0L)
  })

  it("gives the highlighted links as a data frame, with NA for a link that has no kind", {
    links <- list(list(from = "a", to = "b", kind = NULL), list(from = "b", to = "c", kind = "hand"))
    out <- sm_state_value(answered(highlighted = list(ids = list("a", "b", "c"), links = links)), NULL, "view_state")
    expect_identical(out$highlighted$ids, c("a", "b", "c"))
    expect_identical(
      out$highlighted$links,
      data.frame(from = c("a", "b"), to = c("b", "c"), kind = c(NA, "hand"))
    )
  })

  it("passes an answer that is not a list through as it is", {
    expect_identical(sm_state_value("idle", NULL, "view_state"), "idle")
    expect_null(sm_state_value(NULL, NULL, "view_state"))
  })

  it("gives back to stage_map_highlight() what it holds, so the state can be put back as it is", {
    links <- list(list(from = "a", to = "b", kind = "hand"), list(from = "b", to = "c", kind = NULL))
    held <- sm_state_value(answered(highlighted = list(ids = list("a", "b", "c"), links = links)), NULL, "view_state")
    session <- fake_session()
    proxy <- sm_proxy("map", session = session)
    stage_map_highlight(proxy, held$highlighted$ids, links = held$highlighted$links)
    session$flush()
    expect_identical(
      as_list(session$sent[[1]]$message$data),
      list(
        ids = list("a", "b", "c"),
        links = list(list(from = "a", to = "b", kind = "hand"), list(from = "b", to = "c", kind = NULL))
      )
    )
    # A state with nothing lit lets go
    none <- sm_state_value(answered(), NULL, "view_state")
    stage_map_highlight(proxy, none$highlighted$ids, links = none$highlighted$links)
    session$flush()
    expect_identical(unclass(session$sent[[2]]$message$data), "null")
  })
})

describe("the stagemap.ids input type", {
  it("gives a character vector, and character(0) for the empty list Shiny makes of an empty array", {
    expect_identical(sm_ids_value(list("a", "b"), NULL, "map_selected"), c("a", "b"))
    expect_identical(sm_ids_value("a", NULL, "map_selected"), "a")
    expect_identical(sm_ids_value(list(), NULL, "map_selected"), character())
    expect_identical(sm_ids_value(NULL, NULL, "map_selected"), character())
  })

  it("makes req() wait for an empty selection", {
    expect_error(shiny::req(sm_ids_value(list(), NULL, "map_selected")), class = "shiny.silent.error")
  })
})

describe("the stagemap.pick input type", {
  # What the page sends for a pick: the engine's event without its details, plus whatever else it carries.
  picked <- function(...) {
    pick <- list(
      kind = "card",
      id = "a",
      ids = list("b", "a"),
      from = "b",
      label = "Card A",
      still = list(kind = "stage", id = "s", ids = list("s"), details = list(title = "S")),
      by = "reader",
      details = list(title = "A"),
      about = NULL,
      via = "key",
      at = "2026-03-03T10:15:00.000Z",
      seq = 4,
      part = "stage-map",
      name = NULL,
      revision = 3
    )
    replaced(pick, ...)
  }

  it("passes the seven fields, in order, and none of the engine's other fields", {
    out <- sm_pick_value(picked(), NULL, "map_pick")
    expect_identical(names(out), pick_fields)
    expect_identical(pick_fields, c("kind", "id", "ids", "from", "label", "still", "by"))
    expect_identical(c(out$kind, out$id, out$from, out$label, out$by), c("card", "a", "b", "Card A", "reader"))
    expect_identical(out$ids, c("b", "a"))
    expect_identical(out$still, list(kind = "stage", id = "s", ids = "s"))
  })

  it("gives NULL, not NA, for a field with nothing to say, and character(0) for no ids", {
    out <- sm_pick_value(
      list(kind = "all", id = NULL, ids = list(), from = "a", still = NULL, by = "reader"),
      NULL,
      "p"
    )
    expect_identical(names(out), pick_fields)
    expect_null(out$id)
    expect_null(out$label)
    expect_null(out$still)
    expect_identical(out$ids, character())
    expect_identical(out$from, "a")
    expect_false(anyNA(unlist(out)))
  })

  it("keeps the names of the NULL fields, so a pick always has seven", {
    expect_length(sm_pick_value(list(), NULL, "p"), 7L)
  })

  it("keeps one id as a vector of one", {
    expect_identical(sm_pick_value(picked(ids = "a"), NULL, "p")$ids, "a")
  })

  it("gives a still with no ids as character(0)", {
    out <- sm_pick_value(picked(still = list(kind = "card", id = "x")), NULL, "p")
    expect_identical(out$still, list(kind = "card", id = "x", ids = character()))
  })

  it("reads only fields the engine's contract lists for a select", {
    listed <- names(sm_spec()$event_data[["stagemap:select"]])
    expect_true(all(pick_fields %in% listed))
  })
})

describe("the input handlers", {
  it("are registered with Shiny when the package loads: ids, a pick and the state", {
    # Shiny refuses a second handler for a type unless it is forced, so a refusal shows the type is registered
    .onLoad("", "stagemap")
    for (type in c("stagemap.ids", "stagemap.pick", "stagemap.state")) {
      expect_error(shiny::registerInputHandler(type, identity), "already an input handler", info = type)
    }
  })

  it("are the ones Shiny calls: a pick, an id list and the state reach the server shaped", {
    shiny::testServer(
      function(input, output, session) {
        session$userData$seen <- shiny::reactive(list(input$map_pick, input$map_selected, input$map_state))
      },
      {
        session$setInputs(
          map_pick = sm_pick_value(list(kind = "card", id = "a", ids = list("a"), by = "reader"), NULL, ""),
          map_selected = sm_ids_value(list("a"), NULL, ""),
          map_state = sm_state_value(list(selected_ids = list("a")), NULL, "")
        )
        seen <- session$userData$seen()
        expect_identical(seen[[1]]$ids, "a")
        expect_identical(seen[[2]], "a")
        expect_identical(seen[[3]]$selected, "a")
      }
    )
  })
})
