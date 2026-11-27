# Start templates for the studio: "example" (a dosing calculator traceability map with one broken link added after
# building the map, plus its six-step tour) and "blank" (one card, one stage, one lane).

# Returns `list(map, then, tour)` for `name` ("example" or "blank").
studio_template <- function(name) {
  checkmate::assert_choice(name, c("example", "blank"))
  switch(name, example = studio_template_example(), blank = studio_template_blank())
}

studio_template_example <- function() {
  stages <- data.frame(
    id = c("req", "fn", "test", "res"),
    label = c("Requirement", "Function", "Test", "Result"),
    text = c(
      "What the calculator must do.",
      "The R functions that do it.",
      "Checks written against each function.",
      "What the last run said."
    ),
    stringsAsFactors = FALSE
  )
  lanes <- data.frame(
    id = c("stat", "prog", "qa"),
    label = c("Statistics", "Programming", "Quality"),
    stringsAsFactors = FALSE
  )
  cards <- data.frame(
    id = c(
      "scale_weight",
      "round_tenth",
      "refuse_neg",
      "log_calls",
      "calc_dose",
      "check_weight",
      "round_dose",
      "test_scale",
      "test_neg",
      "test_round",
      "test_large",
      "run_pass",
      "run_fail"
    ),
    label = c(
      "Doses scale with weight",
      "Round to 0.1 mg",
      "Refuse negative weights",
      "Log every call",
      "calc_dose()",
      "check_weight()",
      "round_dose()",
      "Doubling weight doubles the dose",
      "Negative weight stops",
      "Rounds half up",
      "Very large weight stays finite",
      "Run 41: 2 of 2 pass",
      "Run 41: 1 failed"
    ),
    stage = c(
      "req",
      "req",
      "req",
      "req",
      "fn",
      "fn",
      "fn",
      "test",
      "test",
      "test",
      "test",
      "res",
      "res"
    ),
    lane = c(
      "stat",
      "stat",
      "prog",
      "prog",
      "prog",
      "prog",
      "stat",
      "qa",
      "qa",
      "stat",
      "prog",
      "qa",
      "qa"
    ),
    status = c(
      "done",
      "done",
      "done",
      "waiting",
      "done",
      "done",
      "running",
      "done",
      "done",
      "waiting",
      "failed",
      "done",
      "failed"
    ),
    sub = c("Ana", "Ana", "Ben", "Ben", "Cho", "Cho", "Dev", "Eli", "Eli", "Dev", "Fran", NA, NA),
    zone = c(rep(NA_character_, 11L), "evidence", "evidence"),
    stringsAsFactors = FALSE
  )
  links <- data.frame(
    from = c(
      "scale_weight",
      "refuse_neg",
      "round_tenth",
      "calc_dose",
      "check_weight",
      "calc_dose",
      "test_scale",
      "test_neg",
      "test_large"
    ),
    to = c(
      "calc_dose",
      "check_weight",
      "round_dose",
      "test_scale",
      "test_neg",
      "test_large",
      "run_pass",
      "run_pass",
      "run_fail"
    ),
    kind = c(NA, NA, NA, "tested", "tested", "tested", "result", "result", "result"),
    stringsAsFactors = FALSE
  )
  kinds <- data.frame(
    id = c("tested", "result"),
    label = c("Tested by", "Gave result"),
    line = c("dashed", "dotted"),
    stringsAsFactors = FALSE
  )
  zones <- data.frame(
    id = "evidence",
    label = "Run evidence",
    note = "Kept for the audit file.",
    stringsAsFactors = FALSE
  )
  map <- stage_map(cards, stages, lanes, title = "Dose calculator validation") |>
    add_links(links, kinds = kinds) |>
    add_zones(zones)
  then <- list(list(
    op = "insert",
    table = "links",
    row = list(from = "test_round", to = "calc_does", kind = "tested"),
    after = NULL
  ))
  list(map = map, then = then, tour = "example")
}

studio_template_blank <- function() {
  map <- stage_map(
    data.frame(id = "first", label = "First card", stage = "start", lane = "main", stringsAsFactors = FALSE),
    data.frame(id = "start", label = "Start", stringsAsFactors = FALSE),
    data.frame(id = "main", label = "Main", stringsAsFactors = FALSE)
  )
  list(map = map, then = list(), tour = NULL)
}
