# Plain checks for the R code room: code lines, problem note, changed-line flags, token spans, last question call,
# `.R` download text, and per-table CSV exports without `.studio_uid`.

describe("studio_code_lines() and studio_code_file()", {
  it("matches stage_map_code() of the built map and evaluates back to an equal map", {
    map <- full_map(title = "Say \"hi\"")
    state <- studio_state_new(map)
    lines <- studio_code_lines(state)
    expect_identical(lines, unclass(stage_map_code(map)))
    expect_false(any(startsWith(lines, "map <- ")))

    file_text <- studio_code_file(state)
    expect_true(endsWith(file_text, "\n"))
    expect_identical(file_text, paste0(paste(lines, collapse = "\n"), "\n"))

    env <- new.env(parent = globalenv())
    rebuilt <- eval(parse(text = file_text, encoding = "UTF-8"), envir = env)
    expect_s3_class(rebuilt, "stagemap_widget")
    expect_identical(stage_map_tables(rebuilt), stage_map_tables(state$good$map))
  })

  it("prepends the problem comment when the document does not build", {
    state <- studio_state_new()
    expect_false(isTRUE(state$check$ok))
    lines <- studio_code_lines(state)
    expect_identical(lines, code_map(studio_doc_parts(state$doc)))
    file_text <- studio_code_file(state)
    expect_true(startsWith(file_text, "# stage_map() stops on this map: see Check.\n"))
    expect_identical(
      file_text,
      paste0(paste(c("# stage_map() stops on this map: see Check.", lines), collapse = "\n"), "\n")
    )
    expect_no_error(parse(text = file_text, encoding = "UTF-8"))
  })

  it("assigns `map` and appends the last question call when current, and drops it when stale or errored", {
    state <- studio_state_new(full_map(title = "Ask check"))
    state$ask <- list(
      question = "trace",
      call = "sm_trace(map, \"a\")",
      rev = state$rev,
      stale = FALSE,
      error = NULL
    )
    lines <- studio_code_lines(state)
    expect_true(any(startsWith(lines, "map <- stage_map(")))
    expect_identical(utils::tail(lines, 3L), c("", "# The last question", "sm_trace(map, \"a\")"))

    env <- new.env(parent = globalenv())
    answer <- eval(parse(text = studio_code_file(state), encoding = "UTF-8"), envir = env)
    expect_identical(answer, sm_trace(state$good$map, "a"))
    expect_s3_class(env$map, "stagemap_widget")

    # Multi-line call string splits cleanly into individual lines
    state$ask$call <- "sm_trace(\n  map,\n  \"a\"\n)"
    expect_identical(
      utils::tail(studio_code_lines(state), 6L),
      c("", "# The last question", "sm_trace(", "  map,", "  \"a\"", ")")
    )

    # An edit marks `state$ask$stale` TRUE and drops the call
    edited <- studio_step(
      state,
      list(seq = 1L, type = "option", data = list(name = "title", value = "New title"), rev = state$rev)
    )$state
    edited_lines <- studio_code_lines(edited)
    expect_false(any(startsWith(edited_lines, "map <- ")))
    expect_false("# The last question" %in% edited_lines)

    # Error or rev mismatch also suppresses the call
    err_state <- state
    err_state$ask$error <- list(head = "Failed")
    expect_false("# The last question" %in% studio_code_lines(err_state))

    mismatch_state <- state
    mismatch_state$ask$rev <- state$rev + 1L
    expect_false("# The last question" %in% studio_code_lines(mismatch_state))
  })
})

describe("studio_room_code_view()", {
  it("builds token spans as [text, class] pairs, changed flags against base, and download descriptors", {
    state <- studio_state_new(full_map(title = "Original"))
    view0 <- studio_room_code_view(state)
    expected_lines <- code_map(studio_doc_parts(state$doc))
    expect_null(view0$problem)
    expect_identical(view0$text, paste(expected_lines, collapse = "\n"))
    expect_length(view0$lines, length(expected_lines))
    expect_false(any(vapply(view0$lines, function(l) isTRUE(l$changed), logical(1))))

    # Each span is an unnamed 2-element list [text, class] that pastes back to the line
    pasted <- vapply(
      view0$lines,
      function(line) paste(vapply(line$spans, function(sp) sp[[1L]], ""), collapse = ""),
      ""
    )
    expect_identical(pasted, expected_lines)
    expect_true(all(vapply(
      view0$lines,
      function(line) {
        all(vapply(line$spans, function(sp) is.null(names(sp)) && length(sp) == 2L, logical(1)))
      },
      logical(1)
    )))
    classes <- unique(unlist(lapply(view0$lines, function(line) {
      vapply(line$spans, function(sp) sp[[2L]], "")
    })))
    expect_true(all(classes %in% c("str", "num", "fn", "arg", "op", "com", "name")))

    # Downloads list has map.R and one CSV per table in the document
    expect_identical(
      view0$downloads,
      list(
        list(id = "download_r", label = "map.R"),
        list(id = "download_csv_cards", label = "cards.csv"),
        list(id = "download_csv_stages", label = "stages.csv"),
        list(id = "download_csv_lanes", label = "lanes.csv"),
        list(id = "download_csv_links", label = "links.csv"),
        list(id = "download_csv_kinds", label = "kinds.csv"),
        list(id = "download_csv_zones", label = "zones.csv")
      )
    )

    # Editing a card label marks only the changed line(s) against base
    edited <- studio_step(
      state,
      list(
        seq = 1L,
        type = "edit",
        data = list(table = "cards", uid = "u1", field = "label", value = "Updated"),
        rev = 0L
      )
    )$state
    view1 <- studio_room_code_view(edited)
    edited_lines <- studio_code_lines(edited)
    base_lines <- code_map(studio_doc_parts(edited$base))
    expect_identical(
      vapply(view1$lines, function(l) isTRUE(l$changed), logical(1)),
      !(edited_lines %in% base_lines)
    )
    expect_true(any(vapply(view1$lines, function(l) isTRUE(l$changed), logical(1))))

    # Undoing returns to base with zero changed lines
    undone <- studio_step(edited, list(seq = 2L, type = "undo", data = list(), rev = edited$rev))$state
    view2 <- studio_room_code_view(undone)
    expect_false(any(vapply(view2$lines, function(l) isTRUE(l$changed), logical(1))))
  })

  it("sets problem and prepends it to copy text on a broken map", {
    broken <- studio_room_code_view(studio_state_new())
    expect_identical(broken$problem, "stage_map() stops on this map: see Check.")
    expect_true(startsWith(broken$text, "# stage_map() stops on this map: see Check.\n"))
    expect_false(grepl("stage_map() stops on this map", broken$lines[[1L]]$spans[[1L]][[1L]], fixed = TRUE))
  })
})

describe("studio_csv()", {
  it("writes each document table without .studio_uid and reads back equal for text columns", {
    state <- studio_state_new()
    for (tbl_name in names(state$doc$tables)) {
      csv <- studio_csv(state, tbl_name)
      expect_false(grepl(".studio_uid", csv, fixed = TRUE), info = tbl_name)
      back <- utils::read.csv(text = csv, stringsAsFactors = FALSE)
      orig <- studio_doc_tables(state$doc)[[tbl_name]]
      expect_identical(names(back), names(orig), info = tbl_name)
      expect_identical(nrow(back), nrow(orig), info = tbl_name)
      for (col in names(orig)) {
        if (is.character(orig[[col]]) && !all(is.na(orig[[col]]))) {
          expect_identical(back[[col]], orig[[col]], info = paste(tbl_name, col))
        }
      }
    }
  })

  it("writes header-only CSV for a table the document lacks, and handles UTF-8 and list columns", {
    state <- studio_state_new(full_map())
    csv_steps <- studio_csv(state, "steps")
    expect_false(grepl(".studio_uid", csv_steps, fixed = TRUE))
    back_steps <- utils::read.csv(text = csv_steps, stringsAsFactors = FALSE)
    expect_identical(nrow(back_steps), 0L)
    expect_identical(names(back_steps), names(sm_spec()$fields$steps$fields))

    # UTF-8 text and list column in cards
    state$doc$tables$cards$label[[1L]] <- "Caf\u00e9"
    state$doc$tables$cards$extra <- I(list(c("x", "y"), "z", character(), "w"))
    csv_cards <- studio_csv(state, "cards")
    back_cards <- utils::read.csv(text = csv_cards, stringsAsFactors = FALSE)
    expect_identical(back_cards$label[[1L]], "Caf\u00e9")
    expect_identical(back_cards$extra[[1L]], "x, y")
  })

  it("checks its arguments", {
    state <- studio_state_new(full_map())
    expect_error(studio_room_code_view(list(1)), "state")
    expect_error(studio_room_code_view(list(doc = state$doc)), "state")
    expect_error(studio_code_lines(list(1)), "state")
    expect_error(studio_code_file(list(1)), "state")
    expect_error(studio_csv(list(1), "cards"), "state")
    expect_error(studio_csv(state, "unknown"), "table")
  })
})

describe("studio_server() download handlers", {
  skip_if_not_installed("shiny")

  it("writes map.R and table CSVs from the live server store, including after an edit", {
    local_mocked_bindings(studio_send = function(session, message) invisible(NULL))
    shiny::testServer(studio_server, args = list(map = full_map(title = "Before")), {
      session$setInputs(event = list(seq = 1L, type = "ready", data = list(), rev = 0L))
      session$setInputs(
        event = list(seq = 2L, type = "option", data = list(name = "title", value = "After"), rev = 0L)
      )
      r_lines <- readLines(output$download_r, encoding = "UTF-8", warn = FALSE)
      expect_match(paste(r_lines, collapse = "\n"), "After", fixed = TRUE)

      cards_df <- utils::read.csv(output$download_csv_cards, stringsAsFactors = FALSE)
      expect_identical(nrow(cards_df), 4L)
      expect_false(".studio_uid" %in% names(cards_df))

      steps_df <- utils::read.csv(output$download_csv_steps, stringsAsFactors = FALSE)
      expect_identical(nrow(steps_df), 0L)
      expect_identical(names(steps_df), names(sm_spec()$fields$steps$fields))
    })
  })
})
