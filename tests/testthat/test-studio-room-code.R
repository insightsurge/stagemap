# Plain checks for the R code room: code lines, problem note, changed-line flags, token spans, last question call,
# `.R` download text, and per-table CSV exports without `.studio_uid`.

# The text of each line of a code view.
expected_lines_of <- function(view) {
  vapply(
    view$lines,
    function(line) paste(vapply(line$spans, function(sp) sp[[1L]], ""), collapse = ""),
    ""
  )
}

# The text of the lines a code view marks as changed, after the event `type` with `data` on `state`.
changed_after <- function(state, type, data) {
  after <- studio_step(state, list(seq = 1L, type = type, data = data, rev = state$rev))$state
  view <- studio_room_code_view(after)
  expected_lines_of(view)[vapply(view$lines, function(l) isTRUE(l$changed), logical(1))]
}

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
    flags1 <- vapply(view1$lines, function(l) isTRUE(l$changed), logical(1))
    expect_identical(sum(flags1), 1L)
    expect_match(expected_lines_of(view1)[flags1], "Updated", fixed = TRUE)

    # Undoing returns to base with zero changed lines
    undone <- studio_step(edited, list(seq = 2L, type = "undo", data = list(), rev = edited$rev))$state
    view2 <- studio_room_code_view(undone)
    expect_false(any(vapply(view2$lines, function(l) isTRUE(l$changed), logical(1))))
  })

  it("marks the lines an edit changed, and only those", {
    state <- studio_state_new(full_map(title = "Original"))
    expect_identical(
      changed_after(state, "option", list(name = "title", value = "New title")),
      "stage_map(cards, stages, lanes, title = \"New title\") |>"
    )

    one <- studio_state_new(slim())
    expect_identical(
      changed_after(one, "edit", list(table = "cards", uid = "u1", field = "label", value = "Updated")),
      "cards <- data.frame(id = \"a\", label = \"Updated\", stage = \"s\", lane = \"l\")"
    )
    # An added card rewrites the cards table (now several lines), and nothing else
    added <- changed_after(one, "add", list(table = "cards"))
    expect_identical(
      added,
      c(
        "cards <- data.frame(",
        "  id = c(\"a\", \"card\"),",
        "  label = c(\"A\", \"New card\"),",
        "  stage = \"s\",",
        "  lane = \"l\"",
        ")"
      )
    )
    # A removed card rewrites the cards table, and nothing else
    two <- studio_state_new(small())
    expect_identical(
      changed_after(two, "remove", list(table = "cards", uid = "u2")),
      "cards <- data.frame(id = \"a\", label = \"A\", stage = \"s\", lane = \"l\")"
    )
    # Removing a card also removes its links: the card table and the links table change, and no other line
    full_removed <- changed_after(state, "remove", list(table = "cards", uid = "u4"))
    expect_true(any(grepl("^  id = c\\(", full_removed)))
    expect_true(any(startsWith(full_removed, "links <- data.frame(")))
    expect_false(any(grepl("Archive", full_removed, fixed = TRUE)))
    expect_false(any(startsWith(full_removed, "stage_map(")))
  })

  it("marks no question line as changed, and the `map <-` line only when its call changed", {
    state <- studio_state_new(full_map(title = "Ask check"))
    state$ask <- list(question = "trace", call = "sm_trace(map, \"a\")", rev = state$rev, stale = FALSE, error = NULL)
    view <- studio_room_code_view(state)
    shown <- expected_lines_of(view)
    expect_true("# The last question" %in% shown)
    expect_true(any(startsWith(shown, "map <- stage_map(")))
    expect_false(any(vapply(view$lines, function(l) isTRUE(l$changed), logical(1))))

    # A title change after the question was asked drops the question (it is stale), so the `stage_map(` line is the only
    # change; with a question for the new revision the `map <-` line is marked and the question lines are not
    edited <- studio_step(
      state,
      list(seq = 1L, type = "option", data = list(name = "title", value = "Other"), rev = state$rev)
    )$state
    edited$ask <- list(question = "trace", call = "sm_trace(map, \"a\")", rev = edited$rev, stale = FALSE, error = NULL)
    view2 <- studio_room_code_view(edited)
    shown2 <- expected_lines_of(view2)
    flags2 <- vapply(view2$lines, function(l) isTRUE(l$changed), logical(1))
    expect_identical(shown2[flags2], sub("^", "map <- ", "stage_map(cards, stages, lanes, title = \"Other\") |>"))
    expect_false(flags2[match("# The last question", shown2)])
    expect_false(flags2[length(flags2)])

    # An edit elsewhere leaves the `map <-` line unmarked
    label_edit <- studio_step(
      state,
      list(
        seq = 1L,
        type = "edit",
        data = list(table = "cards", uid = "u1", field = "label", value = "Updated"),
        rev = state$rev
      )
    )$state
    label_edit$ask <- state$ask
    label_edit$ask$rev <- label_edit$rev
    view3 <- studio_room_code_view(label_edit)
    flags3 <- vapply(view3$lines, function(l) isTRUE(l$changed), logical(1))
    expect_identical(sum(flags3), 1L)
    expect_match(expected_lines_of(view3)[flags3], "Updated", fixed = TRUE)
  })

  it("does not build the view again while the document, base and question are the same", {
    state <- studio_state_new(full_map(title = "Cache"))
    builds <- 0L
    tokenise <- code_tokens
    local_mocked_bindings(code_tokens = function(lines) {
      builds <<- builds + 1L
      tokenise(lines)
    })
    cache <- new.env()
    first <- studio_room_code_view(state, cache)
    expect_identical(builds, 1L)
    picked <- studio_step(
      state,
      list(seq = 1L, type = "target", data = list(kind = "card", uid = "u1"), rev = state$rev)
    )$state
    expect_false(identical(picked$target, state$target))
    expect_identical(studio_room_code_view(picked, cache), first)
    expect_identical(builds, 1L)

    # A change to the document, or a question, builds it again
    edited <- studio_step(
      picked,
      list(seq = 2L, type = "option", data = list(name = "title", value = "Other"), rev = picked$rev)
    )$state
    studio_room_code_view(edited, cache)
    expect_identical(builds, 2L)
    edited$ask <- list(question = "trace", call = "sm_trace(map, \"a\")", rev = edited$rev, stale = FALSE, error = NULL)
    studio_room_code_view(edited, cache)
    expect_identical(builds, 3L)
  })

  it("keeps the last view for one session only: two sessions do not evict each other's, and no call keeps nothing", {
    state <- studio_state_new(full_map(title = "Cache"))
    other <- studio_state_new(full_map(title = "Other"))
    builds <- 0L
    tokenise <- code_tokens
    local_mocked_bindings(code_tokens = function(lines) {
      builds <<- builds + 1L
      tokenise(lines)
    })
    cache_a <- new.env()
    cache_b <- new.env()
    for (i in 1:3) {
      studio_room_code_view(state, cache_a)
      studio_room_code_view(other, cache_b)
    }
    expect_identical(builds, 2L)
    studio_room_code_view(state)
    studio_room_code_view(state)
    expect_identical(builds, 4L)
    expect_error(studio_room_code_view(state, list()), "environment")
  })

  it("keeps the base's code lines in the state, and renews them when a map is opened", {
    state <- studio_state_new(full_map(title = "Base"))
    expect_identical(state$base_code, code_map(studio_doc_parts(state$base)))
    edited <- studio_step(
      state,
      list(seq = 1L, type = "option", data = list(name = "title", value = "Other"), rev = state$rev)
    )$state
    expect_identical(edited$base_code, state$base_code)
    opened <- studio_step(
      edited,
      list(seq = 2L, type = "open", data = list(template = "blank", confirm = TRUE), rev = edited$rev)
    )$state
    expect_identical(opened$base_code, code_map(studio_doc_parts(opened$base)))
    expect_false(identical(opened$base_code, state$base_code))
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

  it("keeps non-ASCII text, quotes, commas and NA in a C locale", {
    withr::local_locale(c(LC_CTYPE = "C"))
    cafe <- rawToChar(as.raw(c(0x43, 0x61, 0x66, 0xc3, 0xa9)))
    Encoding(cafe) <- "UTF-8"
    quoted <- "Say \"hi\", then go"
    state <- studio_state_new(full_map())
    state$doc$tables$cards$label[[1L]] <- cafe
    state$doc$tables$cards$label[[2L]] <- quoted
    state$doc$tables$cards$owner[[3L]] <- NA
    state$doc$tables$cards$size <- c(0.5, 2, NA, 4)
    state$doc$tables$cards$flag <- c(TRUE, FALSE, NA, TRUE)
    csv <- studio_csv(state, "cards")
    expect_identical(Encoding(csv), "UTF-8")
    expect_false(grepl("<U+", csv, fixed = TRUE))
    expect_true(grepl(
      rawToChar(as.raw(c(0x22, 0x43, 0x61, 0x66, 0xc3, 0xa9, 0x22))),
      csv,
      fixed = TRUE,
      useBytes = TRUE
    ))
    rows <- strsplit(csv, "\n", fixed = TRUE)[[1L]]
    expect_identical(
      rows[[1L]],
      "\"id\",\"label\",\"stage\",\"lane\",\"status\",\"zone\",\"owner\",\"size\",\"flag\""
    )
    expect_identical(rows[[2L]], "\"a\",\"Caf\u00e9\",\"write\",\"docs\",\"done\",NA,\"Ann\",0.5,TRUE")
    expect_identical(
      rows[[3L]],
      "\"b\",\"Say \"\"hi\"\", then go\",\"check\",\"docs\",\"running\",\"sign\",\"Bo\",2,FALSE"
    )
    expect_identical(rows[[4L]], "\"c\",\"Publish\",\"check\",\"code\",\"waiting\",\"sign\",NA,NA,NA")
    # The text that goes into the file keeps its bytes
    expect_identical(charToRaw(enc2utf8(csv)), charToRaw(csv))
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
