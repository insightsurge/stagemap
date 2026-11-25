# The contract's id, markdown, scalar, ids and icon types, tested through the converter with made-up specs
# (helper-spec.R).
types <- list(
  rows = field(
    "list",
    TRUE,
    fields = list(
      id = field("id", TRUE),
      text = field("markdown"),
      label = field("scalar"),
      ref = field("id"),
      icon = field("icon"),
      refs = field("ids")
    )
  )
)

describe("the id type", {
  it("accepts text, a factor and whole numbers, and writes them all as text", {
    rows <- data.frame(id = c(7, 100000), ref = factor(c("a", "b")))
    expect_identical(convert_problems(list(rows = rows), types), character())
    sent <- as_list(convert_json(list(rows = rows), types))
    expect_identical(sent$rows[[1]]$id, "7")
    expect_identical(sent$rows[[2]]$id, "100000")
    expect_identical(sent$rows[[2]]$ref, "b")
  })

  it("refuses a number that is not whole, and one that is not finite, naming the row", {
    problems <- convert_problems(list(rows = data.frame(id = c(1, 1.5, Inf))), types)
    expect_length(problems, 1L)
    expect_match(
      problems,
      "`rows$id[2, 3]` must be an id (text that is not blank, or a whole number), not \"1.5\".",
      fixed = TRUE
    )
  })

  it("refuses empty and blank text, naming the rows, and takes whole numbers of any size", {
    problems <- convert_problems(list(rows = data.frame(id = c("a", "", "  ", "\t"))), types)
    expect_length(problems, 1L)
    expect_match(problems, "`rows$id[2, 3, 4]` must be an id (text that is not blank", fixed = TRUE)
    expect_match(problems, "not \"\".", fixed = TRUE)
    problems <- convert_problems(list(rows = data.frame(id = "a", refs = I(list(c("x", " "))))), types)
    expect_match(problems, "must be ids", fixed = TRUE)
    expect_match(convert_problems(list(rows = data.frame(id = factor(c("a", "")))), types), "rows$id[2]", fixed = TRUE)

    rows <- data.frame(id = c(3e9, 1e12, 2^53))
    expect_identical(convert_problems(list(rows = rows), types), character())
    sent <- as_list(convert_json(list(rows = rows), types))
    expect_identical(sent$rows[[1]]$id, "3000000000")
    expect_identical(sent$rows[[2]]$id, "1000000000000")
  })

  it("leaves NA to the required check, not the blank check", {
    problems <- convert_problems(list(rows = data.frame(id = c("a", NA))), types)
    expect_match(problems, "is required but has NA", fixed = TRUE)
    expect_false(any(grepl("not blank", problems, fixed = TRUE)))
  })

  it("refuses a logical column that holds values, and counts one of NA as left out", {
    expect_match(
      convert_problems(list(rows = data.frame(id = c("a", "b"), ref = c(TRUE, FALSE))), types),
      "`rows$ref` must be an id",
      fixed = TRUE
    )
    expect_identical(convert_problems(list(rows = data.frame(id = "a", ref = NA)), types), character())
  })
})

describe("the markdown type", {
  it("accepts text and a factor, writes them as text, and refuses a number", {
    rows <- data.frame(id = c("a", "b"), text = factor(c("*one*", "two")))
    expect_identical(convert_problems(list(rows = rows), types), character())
    expect_identical(as_list(convert_json(list(rows = rows), types))$rows[[1]]$text, "*one*")
    expect_match(
      convert_problems(list(rows = data.frame(id = "a", text = 5)), types),
      "`rows$text` must be text (a character vector or a factor), not numeric.",
      fixed = TRUE
    )
  })
})

describe("the scalar type", {
  it("accepts text and finite numbers, and writes both as text, so a join on it holds", {
    rows <- data.frame(id = c("a", "b"), label = c(2024, 2025))
    expect_identical(convert_problems(list(rows = rows), types), character())
    sent <- as_list(convert_json(list(rows = rows), types))
    expect_identical(c(sent$rows[[1]]$label, sent$rows[[2]]$label), c("2024", "2025"))
    expect_identical(convert_problems(list(rows = data.frame(id = "a", label = "full")), types), character())
  })

  it("refuses a number that is not finite, and a logical value", {
    expect_match(
      convert_problems(list(rows = data.frame(id = c("a", "b"), label = c(1, Inf))), types),
      "`rows$label[2]` must be text or a finite number",
      fixed = TRUE
    )
    expect_match(
      convert_problems(list(rows = data.frame(id = "a", label = TRUE)), types),
      "must be text or a finite number, not logical",
      fixed = TRUE
    )
  })
})

describe("the icon and ids types", {
  it("write an icon name as text, and ids as an array even with one id", {
    data <- list(rows = data.frame(id = "a", icon = "check"))
    data$rows$refs <- list(7)
    expect_identical(convert_problems(data, types), character())
    sent <- as_list(convert_json(data, types))
    expect_identical(sent$rows[[1]]$icon, "check")
    expect_identical(sent$rows[[1]]$refs, list("7"))
  })

  it("refuse ids that are not whole numbers or text", {
    data <- list(rows = data.frame(id = "a"))
    data$rows$refs <- list(c(1, 1.5))
    expect_match(convert_problems(data, types), "`rows$refs[1][2]` must be ids", fixed = TRUE)
  })
})

describe("the words and date types", {
  it("write a Date as text and refuse a date in another form", {
    spec <- list(day = field("date"))
    expect_identical(as_list(convert_json(list(day = as.Date("2026-03-02")), spec))$day, "2026-03-02")
    expect_match(convert_problems(list(day = "3 March"), spec), "`day` must be a Date, or text like", fixed = TRUE)
    expect_match(convert_problems(list(day = 5), spec), "not numeric", fixed = TRUE)
  })
})

describe("the contract's own types", {
  it("have a rule for every type the data, the options and the commands use", {
    used <- function(fields) {
      unlist(lapply(fields, function(field) c(field$type, used(field$fields))))
    }
    contract <- kit_contract()
    commands <- unlist(lapply(contract$command_data, function(command) used(list(command$data))))
    needed <- unique(c(used(contract$data), used(list(contract$options)), commands))
    # `none` is a command that takes no data; `json` becomes `any`, and object and list are the converter's own.
    known <- c(names(type_rules), "object", "list", "json", "none")
    expect_true(length(needed) > 5L)
    expect_identical(setdiff(needed, known), character())
  })

  it("read a `json` field as any JSON", {
    expect_identical(normalise_field(list(type = "json"))$type, "any")
    expect_identical(
      convert_problems(list(free = list(a = 1)), list(free = normalise_field(list(type = "json")))),
      character()
    )
  })
})

describe("the id check of an argument", {
  it("takes text, a factor and whole numbers of any size, as one value or many", {
    expect_true(check_id_values("a"))
    expect_true(check_id_values(factor(c("a", "b"))))
    expect_true(check_id_values(c(7L, 3e9, 1e12)))
    expect_true(check_id_values(character()))
    expect_true(check_id_values(1e12, len = 1L))
    expect_no_error(assert_id_values(NULL, "x", null_ok = TRUE))
    expect_identical(assert_id_values("a", "x", len = 1L), "a")
  })

  it("refuses NA, empty and blank text, fractions, other types and the wrong length, naming the argument", {
    refused <- list(
      NA_character_,
      NA_real_,
      c("a", NA),
      "",
      c("a", "   "),
      1.5,
      Inf,
      TRUE,
      list("a"),
      NULL
    )
    for (value in refused) {
      expect_false(isTRUE(check_id_values(value)), info = deparse(value))
      expect_error(assert_id_values(value, "my_id"), "my_id")
    }
    expect_error(assert_id_values(c("a", "b"), "my_id", len = 1L), "length 1")
    expect_error(assert_id_values(NULL, "my_id"), "my_id")
    expect_error(assert_id_values("a", ""), "label")
  })

  it("names the function the user called when it is given the call", {
    caller <- function() assert_id_values("", "my_id", call = rlang::current_env())
    error <- expect_error(caller(), "my_id")
    expect_identical(as.character(error$call[[1]]), "caller")
  })
})
