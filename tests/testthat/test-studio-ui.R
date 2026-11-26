# The studio's page from R: the skeleton, its dependency and the boot JSON.

# The values of the attribute `name` in `html`.
attr_values <- function(html, name) {
  found <- regmatches(html, gregexpr(sprintf("\\s%s=\"([^\"]*)\"", name), html))[[1]]
  sub(sprintf("^\\s%s=\"([^\"]*)\"$", name), "\\1", found)
}

describe("studio_ui()", {
  skip_if_not_installed("shiny")
  delayedAssign("html", htmltools::renderTags(studio_ui("studio"))$html)

  it("gives every element a unique id, all inside the module's namespace", {
    ids <- attr_values(html, "id")
    expect_gt(length(ids), 10L)
    expect_false(anyDuplicated(ids) > 0L)
    expect_true(all(startsWith(ids, "studio-")))
    expect_true(all(c("studio-map", "studio-title", "studio-room-code", "studio-inspector") %in% ids))
  })

  it("points every aria-controls and aria-labelledby at an element of the page", {
    ids <- attr_values(html, "id")
    expect_true(all(attr_values(html, "aria-controls") %in% ids))
    expect_true(all(attr_values(html, "aria-labelledby") %in% ids))
    expect_setequal(attr_values(html, "aria-controls"), paste0("studio-room-", c("map", "ask", "check", "code")))
  })

  it("has no inline script and no inline style of its own: its only script is the boot JSON", {
    scripts <- regmatches(html, gregexpr("<script[^>]*>", html))[[1]]
    expect_identical(scripts, "<script type=\"application/json\" class=\"sms-boot\">")
    # The one style attribute is the size htmlwidgets writes on the map's own container
    styled <- regmatches(html, gregexpr("<[^>]*\\sstyle=[^>]*>", html))[[1]]
    expect_length(styled, 1L)
    expect_match(styled, "id=\"studio-map\"", fixed = TRUE)
  })

  it("writes a boot JSON with the words, the settings and the engine's event names", {
    boot_text <- sub(".*<script type=\"application/json\" class=\"sms-boot\">(.*?)</script>.*", "\\1", html)
    boot <- jsonlite::fromJSON(boot_text, simplifyVector = FALSE)
    expect_named(boot, c("labels", "copy_wait_ms", "hold_ms", "events", "done"))
    expect_identical(boot$copy_wait_ms, 5000L)
    expect_identical(boot$hold_ms, 450L)
    expect_identical(boot$events, list(select = "stagemap:select", hover = "stagemap:hover"))
    expect_true(all(vapply(boot$labels, function(label) nzchar(label), logical(1))))
  })

  it("takes the page's settings into the boot JSON", {
    page <- htmltools::renderTags(studio_ui("other", list(copy_wait_ms = 300, hold_ms = 0)))$html
    expect_match(page, "\"copy_wait_ms\":300,\"hold_ms\":0", fixed = TRUE)
    expect_match(page, "data-sms-ns=\"other-\"", fixed = TRUE)
  })

  it("has a title field whose edits are option events for the title, which Shiny leaves alone", {
    field <- regmatches(html, regexpr("<input[^>]*>", html))
    expect_match(field, "data-shiny-no-bind-input", fixed = TRUE)
    event <- jsonlite::fromJSON(gsub("&quot;", "\"", attr_values(field, "data-sms-event")), simplifyVector = FALSE)
    expect_identical(event, list(type = "option", data = list(name = "title")))
  })

  it("starts with the rooms, the inspector, the journal and the start card hidden, and the rooms and tray inert", {
    for (part in c("sms-journal", "sms-start", "sms-inspector", "sms-room")) {
      tags <- regmatches(html, gregexpr(sprintf("<[a-z]+ class=\"%s\"[^>]*>", part), html))[[1]]
      expect_true(length(tags) > 0L && all(grepl(" hidden", tags)), info = part)
    }
    expect_length(regmatches(html, gregexpr("<section class=\"sms-room\"[^>]* inert", html))[[1]], 4L)
    expect_match(html, "<div class=\"sms-tray\" id=\"studio-tray\" inert>", fixed = TRUE)
  })

  it("is in English", {
    expect_identical(attr(studio_ui("studio"), "lang"), "en")
  })

  it("checks its arguments", {
    expect_error(studio_ui(""), "id")
    expect_error(studio_ui("studio", list(hold = 1)), "options")
  })
})

describe("the parts of the page", {
  it("check their arguments", {
    ns <- function(id) id
    expect_error(studio_ui_top("ns"), "ns")
    expect_error(studio_ui_room(ns, "", "Title"), "name")
    expect_error(studio_ui_room(ns, "code", ""), "title")
    expect_error(studio_ui_room(ns, "code", "R code", head = "x"), "head")
    expect_error(studio_ui_room(ns, "code", "R code", body = "x"), "body")
    expect_error(studio_ui_block("ns"), "ns")
    expect_error(studio_boot("x"), "options")
    expect_error(studio_json("x"), "x")
  })
})

describe("studio_options()", {
  it("fills in the defaults", {
    expect_identical(studio_options(list()), list(copy_wait_ms = 5000L, hold_ms = 450L))
    expect_identical(studio_options(list(hold_ms = 0)), list(copy_wait_ms = 5000L, hold_ms = 0L))
  })

  it("refuses an unknown setting, a wait of zero and a negative hold", {
    expect_error(studio_options(list(wait = 1)), "options")
    expect_error(studio_options(list(copy_wait_ms = 0)), "copy_wait_ms")
    expect_error(studio_options(list(hold_ms = -1)), "hold_ms")
    expect_error(studio_options("x"), "options")
  })
})

describe("studio_dependency()", {
  it("is one dependency named stagemap-studio, at the package's version, with a module script", {
    dependency <- studio_dependency()
    expect_identical(dependency$name, "stagemap-studio")
    expect_identical(dependency$version, as.character(utils::packageVersion("stagemap")))
    rendered <- htmltools::renderDependencies(list(dependency), srcType = "file")
    expect_match(rendered, "<script src=\"[^\"]*studio.js\" type=\"module\"></script>")
  })

  it("ships every file it names", {
    dependency <- studio_dependency()
    files <- c(dependency$script[[1]]$src, dependency$stylesheet)
    expect_true(all(file.exists(file.path(dependency$src$file, files))))
    expect_true(dependency$all_files)
  })
})
