describe("sm_spec()", {
  it("reads the engine's contract: the names, the fields, the commands and the events", {
    spec <- sm_spec()
    contract <- kit_contract()
    expect_identical(spec$name, contract$visual)
    expect_identical(spec$global, contract$global)
    expect_identical(spec$prefix, contract$prefix)
    expect_identical(spec$version, contract$version)
    expect_identical(spec$commands, as.character(unlist(contract$commands)))
    expect_identical(spec$events, as.character(unlist(contract$events)))
    expect_identical(spec$files, as.character(unlist(contract$files)))
  })

  it("lists the required fields of the data's lists", {
    fields <- sm_spec()$fields
    expect_true(all(c("options", "stages", "lanes", "cards") %in% names(fields)))
    expect_false(fields$links$required)
    expect_true(fields$cards$fields$stage$required)
    expect_identical(fields$cards$fields$tone$values[1:3], c("teal", "good", "warn"))
  })

  it("reads a status as an id the data names, with no fixed list of values", {
    status <- sm_spec()$fields$cards$fields$status
    expect_identical(status$type, "id")
    expect_null(status$values)
  })

  it("reads the options as the data's `options` field, with their types and defaults", {
    options <- sm_spec()$fields$options
    expect_identical(options$type, "object")
    expect_false(options$required)
    expect_identical(options$fields$motion$type, "boolean")
    expect_null(options$fields$motion$values)
    expect_identical(options$fields$layout$type, "enum")
    expect_identical(options$fields$layout$default, "grid")
    expect_identical(options$fields$hosted$type, "words")
    expect_identical(options$fields$hosted$values, c("title", "details", "stage", "steps", "zones"))
    expect_false(sm_spec()$fields$cards$fields$milestone$default)
  })

  it("keeps what each command and event carries", {
    spec <- sm_spec()
    expect_identical(spec$command_data$select$data$type, "object")
    expect_true("via" %in% names(spec$event_data[["stagemap:select"]]))
  })

  it("builds the spec once and keeps it", {
    expect_identical(sm_spec(), sm_spec())
    expect_true(exists("spec", envir = spec_cache))
  })
})

describe("sm_read()", {
  it("reads a file under inst/kit/ once and keeps it", {
    first <- sm_read("stage-map.json")
    expect_identical(sm_read("stage-map.json"), first)
    expect_true(exists("stage-map.json", envir = spec_cache))
  })

  it("says which file is missing from the package", {
    expect_error(sm_read("no-such-file.json"), "no-such-file.json", fixed = TRUE)
  })
})

describe("sm_kit_version()", {
  it("reads the engine's version from the contract, which the record of the copy repeats", {
    expect_match(sm_kit_version(), "^[0-9]+\\.[0-9]+\\.[0-9]+$")
    expect_identical(sm_kit_version(), kit_record()$engine)
  })
})

describe("normalise_field()", {
  it("keeps the type, the requirement, the allowed values, the default and the nested fields", {
    field <- normalise_field(list(
      type = "list",
      required = TRUE,
      fields = list(kind = list(type = "enum", values = list("a", "b"), default = "a"))
    ))
    expect_true(field$required)
    expect_identical(field$fields$kind$values, c("a", "b"))
    expect_identical(field$fields$kind$default, "a")
    expect_false(field$fields$kind$required)
    expect_null(field$fields$kind$fields)
  })
})

describe("local_spec()", {
  it("changes the spec for one test and puts it back", {
    before <- sm_spec()$commands
    local({
      local_spec(list(commands = "select"))
      expect_identical(sm_spec()$commands, "select")
    })
    expect_identical(sm_spec()$commands, before)
  })
})
