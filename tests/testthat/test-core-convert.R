# The converter's checks are tested once, here, with the made-up specs of helper-spec.R: it sees only types.
describe("convert_problems()", {
  it("finds nothing wrong with valid data, and never throws", {
    expect_identical(convert_problems(list(rows = rows(n = c(TRUE, NA))), made_up), character())
    expect_type(convert_problems(list(rows = 1), made_up), "character")
  })

  it("names a missing required list, and a required column that is not there", {
    expect_identical(convert_problems(list(), made_up), "`rows` is required.")
    expect_identical(
      convert_problems(list(rows = data.frame(day = "2026-03-02")), made_up),
      "`rows` needs a column `id`."
    )
  })

  it("names the rows of a required column that holds NA", {
    problems <- convert_problems(list(rows = data.frame(id = c("a", NA, "c", NA))), made_up)
    expect_identical(problems, "`rows$id[2, 4]` is required but has NA.")
  })

  it("names a wrong type, and the values an enum allows", {
    problems <- convert_problems(list(rows = rows(n = c("1", "2"), kind = c("a", "z"))), made_up)
    expect_match(problems[1], "`rows$n` must be TRUE or FALSE, not character.", fixed = TRUE)
    expect_match(problems[2], "`rows$kind[2]` must be one of \"a\", \"b\", not \"z\".", fixed = TRUE)
  })

  it("refuses a list that is not a data frame", {
    expect_match(convert_problems(list(rows = list(id = "a")), made_up), "must be a data frame", fixed = TRUE)
  })

  it("checks dates in text form", {
    problems <- convert_problems(list(rows = rows(day = c("2026-03-02", "3 March"))), made_up)
    expect_length(problems, 1L)
    expect_match(problems, "`rows$day[2]` must be a Date, or text like", fixed = TRUE)
  })

  it("checks an object's scalars: one value each, and the required ones present", {
    expect_identical(
      convert_problems(list(rows = rows(), opts = list(flag = TRUE)), made_up),
      "`opts$title` is required."
    )
    expect_match(
      convert_problems(list(rows = rows(), opts = list(title = c("a", "b"))), made_up),
      "`opts$title` must have one value, not 2.",
      fixed = TRUE
    )
    expect_match(
      convert_problems(list(rows = rows(), opts = "text"), made_up),
      "must be a named list or a named vector",
      fixed = TRUE
    )
  })

  it("shortens the rows it names after five", {
    problems <- convert_problems(list(rows = data.frame(id = rep(NA_character_, 7))), made_up)
    expect_identical(problems, "`rows$id[1, 2, 3, 4, 5, ...]` is required but has NA.")
  })

  it("says so when the spec has a type it cannot check", {
    odd <- list(colour = field("colour", TRUE))
    expect_match(convert_problems(list(colour = "red"), odd), "type stagemap cannot check (colour)", fixed = TRUE)
  })

  it("leaves any-typed values to the kit, also in a column", {
    data <- list(rows = data.frame(id = "a", anything = I(list(list(deep = 1)))), extra = list(anything = 1))
    expect_identical(convert_problems(data, made_up), character())
  })

  it("counts a column of NA as left out, whatever type R gave it", {
    # readr types an empty column as logical
    blank <- rep(NA, 2)
    data <- list(rows = rows(n = blank, kind = blank, day = blank, tags = blank))
    expect_identical(convert_problems(data, made_up), character())
    expect_identical(
      convert_problems(list(rows = data.frame(id = blank)), made_up),
      "`rows$id[1, 2]` is required but has NA."
    )
  })

  it("still refuses a logical column that holds values where the spec wants text", {
    expect_match(
      convert_problems(list(rows = rows(kind = c(TRUE, NA))), made_up),
      "`rows$kind` must be one of",
      fixed = TRUE
    )
  })

  it("checks the objects inside a list column, with the row in the path", {
    data <- list(rows = rows())
    data$rows$meta <- list(list(who = "Ann"), list(who = 5, flag = "x"))
    expect_identical(convert_problems(data, made_up), "`rows$meta[2]$flag` must be TRUE or FALSE, not character.")
  })

  it("checks a packed data frame column the same way", {
    data <- list(rows = rows())
    data$rows$meta <- data.frame(who = c("Ann", NA), flag = c(TRUE, FALSE))
    expect_identical(convert_problems(data, made_up), "`rows$meta[2]$who` is required but has NA.")
  })

  it("refuses an object that names a field twice, because only one of the two would be sent", {
    spec <- list(opts = field("object", fields = list(title = field("string"), flag = field("boolean"))))
    expect_identical(
      convert_problems(list(opts = list(title = "a", title = "b")), spec),
      "`opts` has the name `title` more than once."
    )
    expect_identical(
      convert_problems(list(opts = c(title = "a", title = "b")), spec),
      "`opts` has the name `title` more than once."
    )
    expect_length(convert_problems(list(opts = list(title = "a", flag = TRUE)), spec), 0L)
  })

  it("names a nested object that is required but empty", {
    spec <- list(
      rows = field("list", TRUE, fields = list(meta = field("object", TRUE, fields = list(who = field("string")))))
    )
    data <- list(rows = data.frame(id = 1:2))
    data$rows$meta <- list(list(who = "a"), NULL)
    expect_identical(convert_problems(data, spec), "`rows$meta[2]` is required.")
  })

  it("checks the data frames inside a list column", {
    data <- list(rows = rows())
    data$rows$parts <- list(data.frame(k = "a"), data.frame(j = 1))
    expect_identical(convert_problems(data, made_up), "`rows$parts[2]` needs a column `k`.")
  })

  it("checks words: text only, from the allowed values, and any number of them", {
    data <- list(rows = rows())
    data$rows$tags <- list(c("x", "y"), "z")
    expect_match(
      convert_problems(data, made_up),
      "`rows$tags[2][1]` must be words from \"x\", \"y\", not \"z\".",
      fixed = TRUE
    )
    data$rows$tags <- list(1, "x")
    expect_match(convert_problems(data, made_up), "`rows$tags[1]` must be words from", fixed = TRUE)
  })

  it("turns the wrong container into one problem", {
    expect_match(convert_problems("a", made_up), "must be a named list", fixed = TRUE)
  })
})

describe("convert_problems() for a list given as records", {
  it("checks each record of an unnamed list of named lists, with its number in the path", {
    data <- list(rows = list(list(id = "a"), list(id = 5, kind = "z")))
    expect_identical(
      convert_problems(data, made_up),
      "`rows[2]$kind` must be one of \"a\", \"b\", not \"z\"."
    )
    expect_identical(convert_problems(list(rows = list(list(kind = "a"))), made_up), "`rows[1]$id` is required.")
  })

  it("reads a data frame inside a packed object column as the cell it holds", {
    spec <- list(
      rows = field(
        "list",
        fields = list(
          obj = field("object", fields = list(parts = field("list", fields = list(k = field("string", TRUE)))))
        )
      )
    )
    data <- list(rows = data.frame(id = 1:2))
    data$rows$obj <- data.frame(parts = I(list(data.frame(k = "a"), data.frame(j = 1))))
    expect_identical(convert_problems(data, spec), "`rows$obj[2]$parts` needs a column `k`.")
  })
})

describe("convert_problems() for names", {
  it("refuses an unnamed list for an object, and lets an empty list through", {
    expect_match(
      convert_problems(list(rows = rows(), opts = list("grid")), made_up),
      "`opts` must be a named list or a named vector, not list.",
      fixed = TRUE
    )
    expect_identical(convert_problems(list(rows = rows(), opts = list(title = "T")), made_up), character())
    expect_identical(convert_problems(list(rows = rows(), extra = list()), made_up), character())
    spec <- list(opts = field("object", fields = list(title = field("string"))))
    expect_identical(convert_problems(list(opts = list()), spec), character())
  })

  it("refuses the options of the stage map as an unnamed list", {
    data <- map_data()
    data$options <- list("grid")
    error <- expect_error(sm_widget(data), class = "stagemap_error_data")
    expect_match(conditionMessage(error), "`options` must be a named list or a named vector", fixed = TRUE)
  })

  it("refuses a data frame that has a column twice, naming the column", {
    frame <- data.frame(id = c("a", "b"), id2 = c("c", "d"))
    names(frame)[2] <- "id"
    expect_identical(convert_problems(list(rows = frame), made_up), "`rows` has the column `id` more than once.")
    data <- map_data()
    data$cards <- cbind(data$cards, id = "z")
    error <- expect_error(sm_widget(data), class = "stagemap_error_data")
    expect_match(conditionMessage(error), "`cards` has the column `id` more than once.", fixed = TRUE)
  })
})
