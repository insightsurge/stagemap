# The converter's JSON is tested once, here, with the made-up specs of helper-spec.R: it sees only types.
describe("convert_json()", {
  it("writes rows, and one row is still an array", {
    json <- convert_json(list(rows = data.frame(id = "x")), made_up)
    expect_s3_class(json, "json")
    expect_identical(unclass(json), "{\"rows\":[{\"id\":\"x\"}]}")
  })

  it("writes ids as text, without exponents", {
    json <- convert_json(list(rows = data.frame(id = c(7, 1e5, 2.5))), made_up)
    ids <- vapply(as_list(json)$rows, `[[`, "", "id")
    expect_identical(ids, c("7", "100000", "2.5"))
  })

  it("writes NA in an optional column as null and leaves out what is NULL", {
    json <- convert_json(list(rows = rows(n = c(TRUE, NA)), opts = NULL), made_up)
    parsed <- as_list(json)
    expect_null(parsed$rows[[2]]$n)
    expect_true("n" %in% names(parsed$rows[[2]]))
    expect_false("opts" %in% names(parsed))
  })

  it("writes factors and dates as text", {
    data <- data.frame(id = factor(c("a", "b")), day = as.Date(c("2026-03-02", "2026-03-03")))
    parsed <- as_list(convert_json(list(rows = data), made_up))
    expect_identical(parsed$rows[[1]]$id, "a")
    expect_identical(parsed$rows[[2]]$day, "2026-03-03")
  })

  it("writes booleans as such", {
    parsed <- as_list(convert_json(list(rows = rows(n = c(TRUE, FALSE))), made_up))
    expect_identical(parsed$rows[[1]]$n, TRUE)
    expect_identical(parsed$rows[[2]]$n, FALSE)
  })

  it("writes an object from a named vector or a named list, with scalars unboxed by the spec", {
    from_vector <- as_list(convert_json(list(rows = rows(), opts = c(title = "T")), made_up))
    from_list <- as_list(convert_json(list(rows = rows(), opts = list(title = "T", flag = TRUE)), made_up))
    expect_identical(from_vector$opts, list(title = "T"))
    expect_identical(from_list$opts, list(title = "T", flag = TRUE))
    expect_identical(
      unclass(convert_json(list(rows = rows(), opts = c(title = "T")), made_up)),
      unclass(convert_json(list(rows = rows(), opts = list(title = "T")), made_up))
    )
  })

  it("warns once about names the spec lacks, drops them, and says what is valid", {
    data <- list(rows = rows(n = c(TRUE, FALSE), extra_col = 3:4), opts = list(title = "T", other = 1), unknown = 1)
    warning <- expect_warning(json <- convert_json(data, made_up), class = "stagemap_warning_unused_columns")
    expect_s3_class(warning, "stagemap_warning")
    expect_identical(warning$dropped, list("." = "unknown", rows = "extra_col", opts = "other"))
    expect_match(conditionMessage(warning), "id, n, kind, day, meta, tags", fixed = TRUE)
    expect_false(grepl("extra_col|other|unknown", unclass(json)))
  })

  it("escapes every less-than sign, so a string cannot end the page's script", {
    json <- convert_json(list(rows = data.frame(id = "<!--<script></script>")), made_up)
    expect_false(grepl("<", unclass(json), fixed = TRUE))
    expect_identical(as_list(json)$rows[[1]]$id, "<!--<script></script>")
  })

  it("keeps a one-item list a list and a vector of one a single value when there is no spec", {
    expect_identical(unclass(convert_json(list(list("x")))), "[[\"x\"]]")
    expect_identical(unclass(convert_json("details")), "\"details\"")
    expect_identical(unclass(convert_json(I("details"))), "[\"details\"]")
    expect_identical(unclass(convert_json(NULL)), "null")
    expect_identical(unclass(convert_json(list(kind = "card", id = NA_character_))), "{\"kind\":\"card\",\"id\":null}")
  })

  it("writes an any field as it is, with scalars unboxed", {
    json <- convert_json(list(rows = rows(), extra = list(a = 1, b = c(1, 2))), made_up)
    expect_identical(as_list(json)$extra, list(a = 1L, b = list(1L, 2L)))
  })

  it("writes a data frame in an any field as rows", {
    json <- convert_json(list(rows = rows(), extra = data.frame(a = 1:2)), made_up)
    expect_identical(as_list(json)$extra, list(list(a = 1L), list(a = 2L)))
  })

  it("is embedded as it is by htmlwidgets, as an object and not as a string", {
    widget <- htmlwidgets::createWidget("stage_map", list(data = convert_json(list(rows = rows()), made_up)))
    html <- as.character(htmltools::renderTags(widget)$html)
    expect_match(html, "\"data\":{\"rows\":[{\"id\":\"x\"},{\"id\":\"y\"}]}", fixed = TRUE)
  })

  it("writes an all-NA column of any type as null", {
    json <- convert_json(list(rows = rows(n = c(NA, NA), kind = c(NA, NA), day = c(NA, NA))), made_up)
    expect_identical(as_list(json)$rows[[1]], list(id = "x", n = NULL, kind = NULL, day = NULL))
  })

  it("embeds a json object as it is, not as a string, at any depth", {
    inner <- structure("{\"a\":[1,2]}", class = "json")
    expect_identical(unclass(convert_json(list(x = inner))), "{\"x\":{\"a\":[1,2]}}")
    expect_identical(
      unclass(convert_json(list(rows = rows(), extra = list(deep = inner)), made_up)),
      "{\"rows\":[{\"id\":\"x\"},{\"id\":\"y\"}],\"extra\":{\"deep\":{\"a\":[1,2]}}}"
    )
  })

  it("writes the objects inside a list column with scalars unboxed, as a packed data frame comes out", {
    list_column <- rows()
    list_column$meta <- list(list(who = "Ann", flag = TRUE), list(who = "Bo"))
    packed <- rows()
    packed$meta <- data.frame(who = c("Ann", "Bo"), flag = c(TRUE, NA))
    from_list <- as_list(convert_json(list(rows = list_column), made_up))
    from_packed <- as_list(convert_json(list(rows = packed), made_up))
    expect_identical(from_list$rows[[1]]$meta, list(who = "Ann", flag = TRUE))
    expect_identical(from_list$rows[[2]]$meta, list(who = "Bo"))
    expect_identical(from_packed$rows[[1]]$meta, list(who = "Ann", flag = TRUE))
  })

  it("applies the spec at any depth: ids become text and unknown names are dropped with their path", {
    data <- list(rows = rows())
    data$rows$meta <- list(list(who = 7, extra_key = 1), list(who = "Bo"))
    warning <- expect_warning(json <- convert_json(data, made_up), class = "stagemap_warning_unused_columns")
    expect_identical(warning$dropped, list("rows$meta" = "extra_key"))
    expect_identical(as_list(json)$rows[[1]]$meta, list(who = "7"))
  })

  it("writes the data frames inside a list column as rows, and an empty cell as null", {
    data <- list(rows = rows())
    data$rows$parts <- list(data.frame(k = 1:2), NULL)
    parsed <- as_list(convert_json(data, made_up))
    expect_identical(parsed$rows[[1]]$parts, list(list(k = "1"), list(k = "2")))
    expect_null(parsed$rows[[2]]$parts)
  })

  it("writes words as an array, even with one word, and a plain column as one word per row", {
    data <- list(rows = rows())
    data$rows$tags <- list("x", c("x", "y"))
    parsed <- as_list(convert_json(data, made_up))
    expect_identical(parsed$rows[[1]]$tags, list("x"))
    expect_identical(parsed$rows[[2]]$tags, list("x", "y"))
    data$rows$tags <- c("y", "x")
    expect_identical(as_list(convert_json(data, made_up))$rows[[1]]$tags, list("y"))
  })

  it("writes an any-typed column as it is", {
    data <- list(rows = data.frame(id = "a", anything = 3))
    expect_identical(as_list(convert_json(data, made_up))$rows[[1]]$anything, 3L)
  })

  it("writes a named vector as an object when there is no spec, as it does with one", {
    expect_identical(unclass(convert_json(c(kind = "card", id = "a"))), "{\"kind\":\"card\",\"id\":\"a\"}")
    expect_identical(unclass(convert_json(list(who = c(a = 1)))), "{\"who\":{\"a\":1}}")
  })

  it("drops the names a list, an object and a column lack a field for, naming each path once", {
    spec <- list(
      list_of = field("list", fields = list(id = field("string"))),
      bag = field("object", fields = list(id = field("string")))
    )
    data <- list(list_of = data.frame(id = c(1, 2), mine = 2:3), bag = list(id = 1, mine = c(a = 2)))
    warning <- expect_warning(json <- convert_json(data, spec), class = "stagemap_warning_unused_columns")
    expect_identical(warning$dropped, list(list_of = "mine", bag = "mine"))
    parsed <- as_list(json)
    expect_identical(parsed$list_of, list(list(id = "1"), list(id = "2")))
    expect_identical(parsed$bag, list(id = "1"))
  })
})

describe("prepare_any()", {
  it("leaves a value already marked as one value as it is", {
    expect_identical(prepare_any(jsonlite::unbox("x")), jsonlite::unbox("x"))
  })
})

describe("convert_json() for lists given as records", {
  it("writes a list of named lists as an array of objects, and keeps a key a record leaves out left out", {
    data <- list(rows = list(list(id = "a", kind = "a"), list(id = 7)))
    expect_identical(unclass(convert_json(data, made_up)), "{\"rows\":[{\"id\":\"a\",\"kind\":\"a\"},{\"id\":\"7\"}]}")
  })

  it("writes an object with nothing in it as {}", {
    expect_identical(unclass(convert_json(list(opts = list()), made_up)), "{\"opts\":{}}")
  })

  it("drops what the spec lacks inside records, naming the path without the record's number", {
    data <- list(rows = list(list(id = "a", mine = 1), list(id = "b", mine = 2)))
    warning <- expect_warning(convert_json(data, made_up), class = "stagemap_warning_unused_columns")
    expect_identical(warning$dropped, list(rows = "mine"))
  })
})
