# Checks the studio's UAT scenarios file (apps/studio/scenarios.csv): structure, ordering and that every `auto`
# scenario of an area whose browser test file exists is named in an `it()` description of that file.

scenario_areas <- c(
  "shell",
  "start",
  "header",
  "journal",
  "inspector",
  "ask",
  "check",
  "map",
  "code",
  "guide",
  "phone",
  "keyboard",
  "leak"
)

scenario_files <- c(
  shell = "test-studio-browser.R",
  start = "test-studio-start-browser.R",
  header = "test-studio-header-browser.R",
  journal = "test-studio-journal-browser.R",
  inspector = "test-studio-inspector-browser.R",
  ask = "test-studio-ask-browser.R",
  check = "test-studio-check-browser.R",
  map = "test-studio-map-browser.R",
  code = "test-studio-code-browser.R",
  guide = "test-studio-guide-browser.R",
  phone = "test-studio-phone-browser.R",
  keyboard = "test-studio-keyboard-browser.R",
  leak = "test-studio-leak-browser.R"
)

# Collects every `it()` description string in `file`.
it_descriptions <- function(file) {
  found <- character()
  walk <- function(expr) {
    if (missing(expr) || !is.call(expr)) {
      return()
    }
    head <- expr[[1]]
    name <- if (is.call(head) && identical(head[[1]], as.name("::"))) as.character(head[[3]]) else deparse(head)
    if (identical(name, "it") && length(expr) >= 2L && is.character(expr[[2]])) {
      found <<- c(found, expr[[2]])
    }
    for (i in seq_along(expr)[-1]) {
      walk(expr[[i]])
    }
  }
  for (expr in parse(file, keep.source = FALSE)) {
    walk(expr)
  }
  found
}

describe("the studio scenarios file", {
  path <- test_path("apps", "studio", "scenarios.csv")
  scenarios <- utils::read.csv(path, stringsAsFactors = FALSE, colClasses = "character")

  it("parses cleanly with the required columns and non-empty cells", {
    expect_named(scenarios, c("id", "area", "title", "kind", "steps", "expected"))
    expect_gt(nrow(scenarios), 0L)
    for (col in names(scenarios)) {
      expect_false(anyNA(scenarios[[col]]), info = col)
      expect_true(all(nzchar(trimws(scenarios[[col]]))), info = col)
    }
  })

  it("uses unique SMS-nnn ids in ascending order, and known areas and kinds", {
    expected_ids <- sprintf("SMS-%03d", seq_len(nrow(scenarios)))
    expect_identical(scenarios$id, expected_ids)
    expect_false(anyDuplicated(scenarios$id) > 0L)
    expect_true(all(scenarios$area %in% scenario_areas))
    expect_true(all(scenarios$kind %in% c("auto", "manual")))
  })

  it("covers every auto scenario in each area whose browser test file exists", {
    expect_true(file.exists(test_path(scenario_files[["shell"]])))
    expect_true(file.exists(test_path(scenario_files[["leak"]])))
    for (area in names(scenario_files)) {
      file <- test_path(scenario_files[[area]])
      if (!file.exists(file)) {
        next
      }
      descriptions <- it_descriptions(file)
      auto_ids <- scenarios$id[scenarios$area == area & scenarios$kind == "auto"]
      expect_gt(length(auto_ids), 0L, label = area)
      missing <- auto_ids[!vapply(auto_ids, function(id) any(grepl(id, descriptions, fixed = TRUE)), logical(1))]
      expect_identical(missing, character(), info = paste(area, "->", basename(file)))
    }
  })

  it("parses test files containing empty call arguments such as df[1, ] and x[, 1]", {
    path_tmp <- withr::local_tempfile(fileext = ".R")
    writeLines(
      c("df <- data.frame(a = 1)", "x <- df[1, ]", "y <- df[, 1]", "it('has [SMS-999]', { expect_true(TRUE) })"),
      path_tmp
    )
    expect_identical(it_descriptions(path_tmp), "has [SMS-999]")
  })
})
