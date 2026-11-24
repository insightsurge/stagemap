skip_if_not_installed("jsonlite")

describe("the bundled stage-map engine", {
  it("ships every file a page loads, with a contract and a record of the copy", {
    # Given the files a page loads, and the two records beside them
    wanted <- c(kit_relied_on$page_files, "stage-map.json", "kit.json", "stage-map.sha256")
    # Then each is installed with the package, and none is empty
    for (name in wanted) {
      path <- kit_path(name)
      expect_true(nzchar(path), info = name)
      expect_gt(file.size(path), 0, label = paste("size of", name))
    }
  })

  it("is built under stagemap's names", {
    contract <- kit_contract()
    expected <- kit_relied_on$names
    expect_identical(contract$global, expected$global)
    expect_identical(contract$prefix, expected$prefix)
    expect_identical(contract$css, expected$css)
    expect_identical(contract$root$class, expected$css)
    expect_identical(contract$root$attribute, expected$root_attribute)
    # The names are in the files themselves, not only in the contract that describes them.
    script <- paste(readLines(kit_path("stage-map.js"), warn = FALSE), collapse = "\n")
    style <- paste(readLines(kit_path("stage-map.css"), warn = FALSE), collapse = "\n")
    expect_match(script, paste0("window.", expected$global), fixed = TRUE)
    expect_match(script, expected$root_attribute, fixed = TRUE)
    expect_match(style, paste0("--", expected$prefix, "-"), fixed = TRUE)
    expect_match(style, paste0("\\.", expected$css, "\\b"))
  })

  it("lists the data and option fields the package reads, and leaves out the old names", {
    # Given the contract's rows, one per field (paths such as "cards.id")
    rows <- kit_contract()$r
    # And the old names: a row that has `old_name_of`, and every row under one
    old <- vapply(rows, function(row) !is.null(row$old_name_of), logical(1))
    old_paths <- vapply(rows[old], function(row) paste(row$block, row$field), "")
    under_old <- function(row) any(vapply(old_paths, function(path) startsWith(paste(row$block, row$field), path), NA))
    skipped <- vapply(rows, under_old, logical(1))
    expect_true(any(old), label = "the contract marks some old names")
    # The field of the package's spec that a row describes, or NULL
    in_spec <- function(row) {
      path <- strsplit(row$field, ".", fixed = TRUE)[[1]]
      fields <- sm_spec()$fields
      found <- if (identical(row$block, "options")) fields$options$fields[[path[[1]]]] else fields[[path[[1]]]]
      for (name in path[-1L]) {
        found <- found$fields[[name]]
      }
      found
    }
    # Then each other row is a field of the spec, with the contract's type
    for (row in rows[!skipped]) {
      found <- in_spec(row)
      expect_false(is.null(found), info = row$field)
      expect_identical(found$type, row$kit_type, info = row$field)
    }
    # And no old name is in the spec, so R neither takes nor sends one
    for (row in rows[skipped]) {
      expect_null(in_spec(row), info = row$field)
    }
  })

  it("has every command the package relies on", {
    contract <- kit_contract()
    commands <- unlist(contract$commands)
    expect_true(all(kit_relied_on$commands %in% commands), info = toString(setdiff(kit_relied_on$commands, commands)))
    # Each command also says what data it takes.
    expect_true(all(kit_relied_on$commands %in% names(contract$command_data)))
  })

  it("announces every event the package relies on, under stagemap's prefix", {
    contract <- kit_contract()
    events <- unlist(contract$events)
    expect_true(all(kit_relied_on$events %in% events), info = toString(setdiff(kit_relied_on$events, events)))
    expect_true(all(startsWith(events, paste0(kit_relied_on$names$prefix, ":"))))
    expect_true(all(kit_relied_on$events %in% names(contract$event_data)))
  })

  it("has the options the package sends, and the event fields it hands to R", {
    contract <- kit_contract()
    expect_true(all(kit_relied_on$options %in% names(contract$options$fields)))
    for (event in names(kit_relied_on$event_fields)) {
      listed <- names(contract$event_data[[paste0(kit_relied_on$names$prefix, ":", event)]])
      expect_true(
        all(kit_relied_on$event_fields[[event]] %in% listed),
        info = paste(event, toString(setdiff(kit_relied_on$event_fields[[event]], listed)))
      )
    }
  })

  it("still describes the state fields that hold ids as lists of ids", {
    about <- kit_contract()$command_data$state$about
    for (field in kit_relied_on$state_id_lists) {
      expect_match(about, paste0("`", field, "`"), fixed = TRUE, info = field)
    }
    expect_match(about, "(lists of ids)", fixed = TRUE)
    expect_setequal(setdiff(kit_relied_on$state_id_lists, "highlighted"), state_id_lists)
  })

  it("names only files that are in the copy", {
    # Given the files the contract says a page loads
    contract <- kit_contract()
    expect_setequal(unlist(contract$files), kit_relied_on$page_files)
    # And the files the record of the copy lists
    record <- kit_record()
    listed <- unlist(record$files)
    # Then every one exists, and every file of the copy is listed (the record lists all but itself)
    expect_true(all(nzchar(vapply(listed, kit_path, ""))), info = toString(listed))
    on_disk <- setdiff(list.files(kit_path()), "kit.json")
    expect_setequal(listed, on_disk)
    expect_setequal(names(record$sha256), listed)
  })

  it("records the version, the source commit and a date that match the files", {
    record <- kit_record()
    contract <- kit_contract()
    expect_identical(record$engine, contract$version)
    expect_match(record$commit, "^[0-9a-f]{40}$")
    expect_match(record$date, "^[0-9]{4}-[0-9]{2}-[0-9]{2}$")
    expect_false(is.na(as.Date(record$date, format = "%Y-%m-%d")))
    expect_identical(record$names$global, contract$global)
    expect_identical(record$names$prefix, contract$prefix)
    expect_identical(record$names$css, contract$css)
    # The built script says the same version in its first line.
    first <- readLines(kit_path("stage-map.js"), n = 1L, warn = FALSE)
    expect_identical(first, sprintf("// stagemap stage map %s, built from its source; do not edit.", contract$version))
  })

  it("records the checksums the build wrote for its three files", {
    # Given the build's own list, one line per file: "<sha256>  <name>"
    lines <- strsplit(readLines(kit_path("stage-map.sha256"), warn = FALSE), "  ", fixed = TRUE)
    built <- stats::setNames(vapply(lines, `[[`, "", 1L), vapply(lines, `[[`, "", 2L))
    expect_setequal(names(built), c("stage-map.js", "stage-map.css", "stage-map.json"))
    # Then the record of the copy holds the same checksums
    record <- kit_record()
    for (name in names(built)) {
      expect_identical(record$sha256[[name]], built[[name]], info = name)
    }
  })

  it("has the copyright and licence of every file recorded in inst/COPYRIGHTS", {
    # Given the record of who holds the copyright
    copyrights <- system.file("COPYRIGHTS", package = "stagemap")
    expect_true(nzchar(copyrights))
    text <- paste(readLines(copyrights, warn = FALSE), collapse = " ")
    # Then it names each file of the copy, and each licence text is shipped beside the work it covers
    for (name in c(unlist(kit_record()$files), "kit.json")) {
      expect_match(text, name, fixed = TRUE, info = name)
    }
    expect_match(paste(readLines(kit_path("LICENSE-d3"), warn = FALSE), collapse = " "), "ISC License", fixed = TRUE)
    expect_match(
      paste(readLines(kit_path("LICENSE-lucide"), warn = FALSE), collapse = " "),
      "ISC License",
      fixed = TRUE
    )
  })
})
