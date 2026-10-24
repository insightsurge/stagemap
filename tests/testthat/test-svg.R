svg_example_map <- function() {
  nodes <- data.frame(
    id = c("REQ-1", "REQ-2", "TST-1", "RES-1"),
    stage = c("Requirement", "Requirement", "Test", "Result"),
    lane = c("Safety", "Usability", "Safety", "Safety"),
    group = c("Safety", "Usability", "Safety", "Safety"),
    status = c("pass", "missing", "pass", "fail")
  )
  links <- data.frame(
    from = c("REQ-1", "TST-1"),
    to = c("TST-1", "RES-1"),
    kind = c("verifies", "produces"),
    label = c("checked", NA_character_)
  )
  stagemap(nodes, links) |> sm_stages(c("Requirement", "Test", "Result"))
}

svg_count <- function(text, pattern) {
  checkmate::assert_string(text)
  checkmate::assert_string(pattern)
  matches <- gregexpr(pattern, text, fixed = TRUE)[[1L]]
  sum(matches > 0L)
}

svg_attribute <- function(element, attribute) {
  checkmate::assert_character(element, any.missing = FALSE)
  checkmate::assert_string(attribute)
  sub(paste0('.* ', attribute, '="([^"]*)".*'), "\\1", element)
}

svg_elements <- function(svg, pattern) {
  checkmate::assert_string(svg)
  checkmate::assert_string(pattern)
  regmatches(svg, gregexpr(pattern, svg))[[1L]]
}

describe("sm_svg()", {
  it("checks the map, output path and theme", {
    map <- svg_example_map()
    expect_error(sm_svg(NULL), "map", class = "stagemap_error")
    for (bad in list(1, NA_character_, character(), c("a", "b"))) {
      expect_error(sm_svg(map, file = bad), "file", class = "stagemap_error")
    }
    directory <- withr::local_tempdir()
    expect_error(sm_svg(map, file = directory), "file.*is a folder; give a file path", class = "stagemap_error")
    expect_error(sm_svg(map, file = file.path(directory, "absent", "map.svg")), "file", class = "stagemap_error")
    for (bad in list("sepia", NULL, NA_character_, 1, c("light", "dark"))) {
      expect_error(sm_svg(map, theme = bad), "Assertion on 'theme'", class = "stagemap_error")
    }
  })

  it("returns one visible, stable string with balanced elements and accessible names", {
    map <- svg_example_map()
    result <- withVisible(sm_svg(map))
    svg <- result$value
    expect_true(result$visible)
    expect_type(svg, "character")
    expect_length(svg, 1L)
    expect_true(startsWith(svg, "<svg "))
    expect_true(endsWith(svg, "</svg>\n"))
    expect_true(grepl('xmlns="http://www.w3.org/2000/svg"', svg, fixed = TRUE))
    expect_true(grepl('role="img" aria-labelledby="stagemap-title-', svg, fixed = TRUE))
    expect_true(grepl("Relation map: 4 nodes, 2 links, 3 stages", svg, fixed = TRUE))
    expect_true(grepl("Stages: Requirement, Test, Result. Lanes: Safety, Usability.", svg, fixed = TRUE))
    for (tag in c("g", "text", "marker")) {
      opening <- if (tag == "g") "<g>" else paste0("<", tag, " ")
      expect_gt(svg_count(svg, opening), 0)
      expect_equal(svg_count(svg, opening), svg_count(svg, paste0("</", tag, ">")))
    }
    expect_identical(sm_svg(map), svg)
    expect_identical(sm_svg(svg_example_map()), svg)
    expect_true(grepl("REQ-1 \u2192 TST-1 (verifies)", svg, fixed = TRUE))
    expect_true(grepl('paint-order="stroke"', svg, fixed = TRUE))
    expect_true(grepl('font-family="Helvetica, Arial, sans-serif"', svg, fixed = TRUE))
  })

  it("writes the same UTF-8 bytes, overwrites a file and returns its path invisibly", {
    map <- svg_example_map()
    directory <- withr::local_tempdir()
    path <- file.path(directory, "map.svg")
    writeLines("old contents", path)
    result <- withVisible(sm_svg(map, file = path))
    expect_false(result$visible)
    expect_identical(result$value, path)
    expected <- enc2utf8(sm_svg(map))
    expect_identical(readBin(path, what = "raw", n = file.info(path)$size), charToRaw(expected))
  })

  it("draws each wrapped label line at the baseline supplied by the layout settings", {
    label <- "A long label that needs several lines inside a node"
    map <- stagemap(data.frame(id = "a", stage = "A", label = label))
    layout <- compute_layout(map)
    lines <- layout$nodes$label_lines[[1L]]
    expect_gt(length(lines), 1)
    svg <- sm_svg(map)
    for (i in seq_along(lines)) {
      baseline <- layout$nodes$y +
        layout$settings$padding +
        layout$settings$font_size +
        (i - 1L) * layout$settings$line_height
      expected <- paste0('y="', layout_number(baseline), '" font-size="13" fill="#172E36">', lines[i], '</text>')
      expect_true(grepl(expected, svg, fixed = TRUE))
    }
  })

  it("uses opaque light and dark backgrounds with stable theme-specific names", {
    map <- svg_example_map()
    light <- sm_svg(map)
    dark <- sm_svg(map, theme = "dark")
    expect_true(grepl('fill="#FFFFFF"', light, fixed = TRUE))
    expect_true(grepl('fill="#101E22"', dark, fixed = TRUE))
    expect_true(grepl('fill="#F2F7F9"', light, fixed = TRUE))
    expect_true(grepl('fill="#E8F0F3"', light, fixed = TRUE))
    expect_true(grepl('fill="#15272C"', dark, fixed = TRUE))
    expect_true(grepl('fill="#1A2F35"', dark, fixed = TRUE))
    expect_false(identical(light, dark))
    expect_identical(dark, sm_svg(map, theme = "dark"))
    expect_false(identical(
      sub('.*aria-labelledby="([^"]+)".*', "\\1", light),
      sub('.*aria-labelledby="([^"]+)".*', "\\1", dark)
    ))
  })

  it("measures known contrast ratios and keeps outlines readable in both themes", {
    expect_equal(svg_contrast("#000000", "#FFFFFF"), 21)
    expect_equal(svg_contrast("#777777", "#FFFFFF"), 4.478, tolerance = 0.001)
    expect_equal(svg_contrast("#FFFFFF", "#000000"), 21)
    expect_equal(svg_contrast("#00000000", "#FFFFFF"), 1)
    expect_equal(svg_luminance("#000000"), 0)
    expect_equal(svg_luminance("#FFFFFF"), 1)
    for (theme in c("light", "dark")) {
      palette <- svg_theme(theme)
      expect_identical(palette$outline, if (theme == "light") "#6E858D" else "#6A8891")
      expect_identical(palette$grid, if (theme == "light") "#C4D3D9" else "#2F4A52")
      for (background in palette[c("bg", "band", "band_alt", "card")]) {
        expect_gte(svg_contrast(palette$outline, background), 3)
      }
      adjusted <- svg_link_colour("#F0E442", palette)
      expect_match(adjusted, "^#[0-9A-F]{6}$")
      for (background in palette[c("bg", "band", "band_alt")]) {
        expect_gte(svg_contrast(adjusted, background), 3)
      }
      expect_identical(svg_link_colour(adjusted, palette), adjusted)
      transparent <- svg_link_colour("#F0E44200", palette)
      for (background in palette[c("bg", "band", "band_alt")]) {
        expect_gte(svg_contrast(transparent, background), 3)
      }
    }
    expect_error(svg_luminance("red"), "colour")
    expect_error(svg_contrast("red", "#FFFFFF"), "colour")
    expect_error(svg_contrast("#FFFFFF", "red"), "background")
    expect_error(svg_link_colour("red", svg_theme("light")), "colour")
    expect_error(svg_link_colour("#FFFFFF", NULL), "palette")
  })

  it("uses readable group link strokes, arrows and marks while keeping raw stripes and swatches", {
    nodes <- data.frame(id = c("a", "b"), stage = c("A", "B"), group = "yellow")
    map <- stagemap(nodes, data.frame(from = "a", to = "b", kind = "relates")) |>
      sm_groups(colours = c(yellow = "#F0E442"))
    for (theme in c("light", "dark")) {
      palette <- svg_theme(theme)
      for (endpoint in c("from", "to")) {
        changed <- sm_kinds(map, relates = sm_kind(colour = endpoint, mark = "circle"))
        svg <- sm_svg(changed, theme = theme)
        routed <- svg_elements(svg, '<path d="M [^>]+/>')[1L]
        colour <- svg_attribute(routed, "stroke")
        for (background in palette[c("bg", "band", "band_alt")]) {
          expect_gte(svg_contrast(colour, background), 3)
        }
        expect_true(grepl(paste0('marker-end="url(#', svg_arrow_id(colour), ')"'), routed, fixed = TRUE))
        expect_true(grepl(paste0('fill="', colour, '"'), svg, fixed = TRUE))
        mark <- svg_elements(svg, "<circle [^>]*/>")[1L]
        expect_identical(svg_attribute(mark, "stroke"), colour)
        rectangles <- svg_elements(svg, "<rect [^>]*/>")
        expect_equal(sum(svg_attribute(rectangles, "fill") == "#F0E442"), 3)
      }
      manual <- sm_kinds(map, relates = sm_kind(colour = "#F0E442"))
      expect_true(grepl('stroke="#F0E442"', sm_svg(manual, theme = theme), fixed = TRUE))
    }
  })

  it("scales all line patterns by width and rounds dotted caps", {
    map <- stagemap(
      data.frame(id = c("a", "b"), stage = c("A", "B")),
      data.frame(from = "a", to = "b", kind = "relates")
    )
    patterns <- c(
      solid = "",
      dashed = "8 6",
      dotted = "2 5",
      dotdash = "2 5 8 5",
      longdash = "16 6",
      twodash = "4 4 12 4"
    )
    for (line in names(patterns)) {
      svg <- sm_svg(sm_kinds(map, relates = sm_kind(line = line, width = 2, arrow = FALSE)))
      if (line == "solid") {
        expect_false(grepl("stroke-dasharray", svg, fixed = TRUE))
      } else {
        expect_true(grepl(paste0('stroke-dasharray="', patterns[[line]], '"'), svg, fixed = TRUE))
      }
      if (line == "dotted") {
        expect_true(grepl('stroke-linecap="round"', svg, fixed = TRUE))
      }
      expect_false(grepl("marker-end", svg, fixed = TRUE))
      expect_false(grepl("<marker ", svg, fixed = TRUE))
      expect_false(grepl("<defs", svg, fixed = TRUE))
      expect_true(grepl('stroke-width="2"', svg, fixed = TRUE))
    }
  })

  it("draws each middle mark at the computed midpoint in both directions", {
    map <- stagemap(
      data.frame(id = c("a", "b"), stage = c("A", "B")),
      data.frame(from = "a", to = "b", kind = "relates")
    )
    for (direction in c("LR", "TB")) {
      for (mark in c("circle", "square", "diamond", "bar", "cross")) {
        changed <- map |> sm_layout(direction = direction) |> sm_kinds(relates = sm_kind(mark = mark, width = 3))
        layout <- compute_layout(changed)
        x <- layout$links$mid_x
        y <- layout$links$mid_y
        pair <- function(a, b) paste(layout_number(c(a, b)), collapse = " ")
        expected <- switch(
          mark,
          circle = paste0('<circle cx="', layout_number(x), '" cy="', layout_number(y), '" r="7"'),
          square = paste0('<rect x="', layout_number(x - 7), '" y="', layout_number(y - 7), '" width="14" height="14"'),
          diamond = paste("M", pair(x, y - 7), "L", pair(x + 7, y), "L", pair(x, y + 7), "L", pair(x - 7, y), "Z"),
          bar = if (direction == "LR") {
            paste("M", pair(x, y - 7), "L", pair(x, y + 7))
          } else {
            paste("M", pair(x - 7, y), "L", pair(x + 7, y))
          },
          cross = paste(
            "M",
            pair(x - 7, y - 7),
            "L",
            pair(x + 7, y + 7),
            "M",
            pair(x - 7, y + 7),
            "L",
            pair(x + 7, y - 7)
          )
        )
        expect_true(grepl(expected, sm_svg(changed), fixed = TRUE))
      }
    }
  })

  it("uses endpoint group colours and shares only identical marker definitions", {
    nodes <- data.frame(id = c("a", "b", "c"), stage = c("A", "B", "C"), group = c("one", "two", NA))
    links <- data.frame(from = c("a", "b", "c"), to = c("b", "c", "a"), kind = c("first", "second", "third"))
    map <- stagemap(nodes, links) |>
      sm_groups(colours = c(one = "#123456", two = "#ABCDEF"))
    from <- map |>
      sm_kinds(first = sm_kind(colour = "from"), second = sm_kind(colour = "from"), third = sm_kind(colour = "from"))
    svg <- sm_svg(from)
    adjusted <- svg_link_colour("#ABCDEF", svg_theme("light"))
    for (colour in c("#123456", adjusted, "#3C5861")) {
      expect_true(grepl(paste0('stroke="', colour, '"'), svg, fixed = TRUE))
      expect_true(grepl(paste0('id="', svg_arrow_id(colour), '"'), svg, fixed = TRUE))
    }
    to <- map |>
      sm_kinds(first = sm_kind(colour = "to"), second = sm_kind(colour = "to"), third = sm_kind(colour = "to"))
    styles <- svg_link_styles(compute_layout(to), resolve_kinds(to), resolve_groups(to), svg_theme("light"))
    expect_identical(styles$colour, c(adjusted, "#3C5861", "#123456"))
    expect_true(grepl(paste0('marker-end="url(#', svg_arrow_id(adjusted), ')"'), sm_svg(to), fixed = TRUE))
    same <- map |>
      sm_kinds(
        first = sm_kind(colour = "#123456"),
        second = sm_kind(colour = "#123456"),
        third = sm_kind(colour = "#123456")
      )
    expect_equal(svg_count(sm_svg(same), "<marker "), 1)
    expect_true(grepl('fill="#123456"', sm_svg(same, theme = "dark"), fixed = TRUE))
  })

  it("draws five built-in icons and a custom badge without an icon", {
    nodes <- data.frame(id = letters[1:6], stage = "A", status = c("pass", "fail", "missing", "warn", "skip", "review"))
    map <- stagemap(nodes) |> sm_status(review = "In review")
    svg <- sm_svg(map)
    icons <- c("M1 5L4 8L9 2", "M1 1L9 9M1 9L9 1", "M1 5L9 5", "M5 0L10 9H0ZM5 3V6M5 7V8", "M0 1L4 5L0 9M5 1L9 5L5 9")
    for (icon in icons) {
      expect_equal(svg_count(svg, paste0('d="', icon, '"')), 2)
    }
    for (text in c("Pass", "Fail", "Missing", "Warning", "Skipped", "In review")) {
      expect_equal(svg_count(svg, paste0(">", text, "</text>")), 2)
    }
    expect_equal(svg_count(svg, "transform="), 10)
    expect_true(grepl('stroke="#1D6B45"', svg, fixed = TRUE))
    expect_true(grepl('stroke="#A33A30"', svg, fixed = TRUE))
    expect_true(grepl('stroke="#7A5A12"', svg, fixed = TRUE))
    expect_true(grepl('stroke="#4E6870"', svg, fixed = TRUE))
  })

  it("uses neutral legend samples for endpoint colours while keeping the links' group colours", {
    nodes <- data.frame(id = c("a", "b"), stage = c("A", "B"), group = c("one", "two"))
    links <- data.frame(from = c("a", "b"), to = c("b", "a"), kind = c("first", "second"))
    map <- stagemap(nodes, links) |>
      sm_groups(colours = c(one = "#123456", two = "#ABCDEF")) |>
      sm_kinds(first = sm_kind(colour = "from"), second = sm_kind(colour = "to"))
    for (theme in c("light", "dark")) {
      svg <- sm_svg(map, theme = theme)
      paths <- svg_elements(svg, "<path [^>]*/>")
      samples <- paths[grepl('h 28"', paths, fixed = TRUE)]
      expect_length(samples, 2L)
      neutral <- if (theme == "light") "#3C5861" else "#A9C1C8"
      expect_identical(svg_attribute(samples, "stroke"), rep(neutral, 2))
      expect_identical(
        svg_attribute(samples, "marker-end"),
        rep(paste0("url(#stagemap-arrow-", tolower(sub("#", "", neutral, fixed = TRUE)), ")"), 2)
      )
      expect_true(grepl(
        paste0('id="stagemap-arrow-', tolower(sub("#", "", neutral, fixed = TRUE)), '"'),
        svg,
        fixed = TRUE
      ))
      routed <- paths[grepl('d="M ', paths, fixed = TRUE) & !grepl('h 28"', paths, fixed = TRUE)]
      expect_identical(svg_attribute(routed, "stroke"), rep(svg_link_colour("#123456", svg_theme(theme)), 2))
    }
  })

  it("centres text-only badges and removes icon space on nodes and in the legend", {
    map <- stagemap(data.frame(id = c("a", "b"), stage = "A", status = c("pass", "draft"))) |>
      sm_status(pass = "Draft", draft = "Draft")
    svg <- sm_svg(map)
    pills <- svg_elements(svg, '<rect [^>]*rx="9"[^>]*/>')
    texts <- svg_elements(svg, '<text [^>]*>Draft</text>')
    expect_length(pills, 4L)
    expect_length(texts, 4L)
    widths <- as.numeric(svg_attribute(pills, "width"))
    expect_equal(widths, rep(text_width("Draft", 11) + c(22, 10), 2), tolerance = 0.01)
    expect_equal(widths[c(1, 3)] - widths[c(2, 4)], c(12, 12))
    expect_equal(as.numeric(svg_attribute(texts, "x")) - as.numeric(svg_attribute(pills, "x")), c(17, 5, 17, 5))
  })

  it("keeps TB labels within the canvas and moves a rightmost label to the left of its mark", {
    nodes <- data.frame(id = letters[1:4], stage = c("A", "A", "B", "B"), lane = c("Left", "Right", "Left", "Right"))
    labels <- c("short", "A label beside the rightmost link")
    map <- stagemap(nodes, data.frame(from = c("a", "b"), to = c("c", "d"), label = labels)) |>
      sm_layout(direction = "TB") |>
      sm_kinds(link = sm_kind(mark = "cross"))
    svg <- sm_svg(map)
    layout <- compute_layout(map)
    canvas_width <- as.numeric(svg_attribute(svg_elements(svg, "<svg [^>]*>"), "width"))
    for (i in seq_along(labels)) {
      element <- svg_elements(svg, paste0('<text [^>]*>', labels[i], '</text>'))
      expect_length(element, 1L)
      x <- as.numeric(svg_attribute(element, "x"))
      anchor <- svg_attribute(element, "text-anchor")
      measured <- text_width(labels[i], 11)
      left <- if (anchor == "end") x - measured else x
      right <- if (anchor == "end") x else x + measured
      expect_gte(left, layout$settings$margin - 0.01)
      expect_lte(right, canvas_width - layout$settings$margin + 0.01)
      expect_identical(anchor, if (i == 1L) "start" else "end")
      expect_equal(abs(x - layout$links$mid_x[i]), 7.5, tolerance = 0.01)
    }
  })

  it("places LR labels above cross marks and shifts labels inside either canvas edge", {
    nodes <- data.frame(id = c("a", "b"), stage = "A")
    map <- stagemap(nodes, data.frame(from = "a", to = "b", label = "Label beside a cross")) |>
      sm_kinds(link = sm_kind(mark = "cross", width = 3))
    for (direction in c("LR", "TB")) {
      changed <- sm_layout(map, direction = direction)
      svg <- sm_svg(changed)
      layout <- compute_layout(changed)
      element <- svg_elements(svg, '<text [^>]*>Label beside a cross</text>')
      x <- as.numeric(svg_attribute(element, "x"))
      measured <- text_width("Label beside a cross", 11)
      width <- as.numeric(svg_attribute(svg_elements(svg, "<svg [^>]*>"), "width"))
      anchor <- svg_attribute(element, "text-anchor")
      left <- switch(anchor, middle = x - measured / 2, end = x - measured, start = x)
      expect_gte(left, layout$settings$margin - 0.01)
      expect_lte(left + measured, width - layout$settings$margin + 0.01)
      if (direction == "LR") {
        expect_equal(as.numeric(svg_attribute(element, "y")), layout$links$mid_y - 11, tolerance = 0.01)
        expect_identical(anchor, "middle")
        expect_lt(x, layout$links$mid_x)
      }
    }
    # A long label near the first stage must also stay inside the left margin.
    label <- paste(rep("wide", 20), collapse = " ")
    map <- stagemap(
      data.frame(id = c("a", "b"), stage = c("A", "B")),
      data.frame(from = "a", to = "b", label = label)
    ) |>
      sm_stages(c("A", "B", "C", "D"))
    svg <- sm_svg(map)
    element <- svg_elements(svg, paste0('<text [^>]*>', label, '</text>'))
    x <- as.numeric(svg_attribute(element, "x"))
    expect_equal(x - text_width(label, 11) / 2, compute_layout(map)$settings$margin, tolerance = 0.01)
  })

  it("shows the group's legend label on nodes and shortens names beside badges", {
    map <- stagemap(data.frame(id = c("a", "b"), stage = c("A", "B"), group = "one", status = c(NA, "pass"))) |>
      sm_groups(labels = c(one = "Group name"))
    svg <- sm_svg(map)
    expect_equal(svg_count(svg, ">Group name</text>"), 3)
    expect_true(grepl('text-anchor="end"', svg, fixed = TRUE))
    long <- sm_groups(map, labels = c(one = "A very long group name that cannot fit on the card"))
    expect_true(grepl("...</text>", sm_svg(long), fixed = TRUE))
    wide_badge <- sm_status(long, pass = "A badge that takes all available space")
    expect_false(grepl('text-anchor="end" dominant-baseline="middle"></text>', sm_svg(wide_badge), fixed = TRUE))
    expect_identical(svg_truncate("Name", 0), "")
    expect_identical(svg_truncate("Name", 100), "Name")
    expect_identical(svg_truncate("Name", 0, min_chars = 1L), "N...")
  })

  it("fits long status badges beside visible group names and keeps full legend and title texts", {
    full <- "Awaiting second reviewer sign-off"
    for (word in c("awaiting", "pass")) {
      for (group in c("Team", NA_character_)) {
        map <- stagemap(data.frame(id = "a", label = "Node label", stage = "A", group = group, status = word))
        words <- setNames(list(full), word)
        map <- do.call(sm_status, c(list(map), words))
        layout <- compute_layout(map)
        node_svg <- svg_nodes(map, layout, resolve_groups(map), resolve_status(map), svg_theme("light"))
        pill <- svg_elements(node_svg, '<rect [^>]*rx="9"[^>]*/>')
        expect_length(pill, 1L)
        width <- as.numeric(svg_attribute(pill, "width"))
        x <- as.numeric(svg_attribute(pill, "x"))
        inner <- layout$nodes$width - 2 * layout$settings$padding
        expect_lte(width, if (is.na(group)) inner else 0.6 * (inner - 8))
        expect_gte(x, layout$nodes$x + layout$settings$padding)
        expect_lte(x + width, layout$nodes$x + layout$nodes$width - layout$settings$padding)
        expect_true(grepl("...</text>", node_svg, fixed = TRUE))
        expect_true(grepl(paste0("\n", full, "</title>"), node_svg, fixed = TRUE))
        expect_true(grepl(paste0(">", full, "</text>"), sm_svg(map), fixed = TRUE))
        if (!is.na(group)) {
          expect_true(grepl(">Team</text>", node_svg, fixed = TRUE))
          expect_lte(width + 8 + text_width("Team", 11), inner)
        }
        expect_equal(svg_count(node_svg, "transform="), if (word == "pass") 1 else 0)
      }
    }
    short <- stagemap(data.frame(id = "a", stage = "A", group = "Team", status = "pass"))
    layout <- compute_layout(short)
    node_svg <- svg_nodes(short, layout, resolve_groups(short), resolve_status(short), svg_theme("light"))
    pill <- svg_elements(node_svg, '<rect [^>]*rx="9"[^>]*/>')
    expect_equal(as.numeric(svg_attribute(pill, "width")), text_width("Pass", 11) + 22, tolerance = 0.01)
    expect_true(grepl(">Pass</text>", node_svg, fixed = TRUE))
    expect_true(grepl(">Team</text>", node_svg, fixed = TRUE))
    expect_error(svg_truncate("Name", 10, min_chars = -1), "min_chars")
  })

  it("omits blank link labels and starts a differently labelled node title with its id", {
    nodes <- data.frame(id = c("node-a", "node-b"), stage = c("A", "B"), label = c("First node", "node-b"))
    for (label in c("", " \t ", NA_character_)) {
      map <- stagemap(nodes, data.frame(from = "node-a", to = "node-b", label = label))
      svg <- sm_svg(map)
      expect_false(grepl('paint-order="stroke"', svg, fixed = TRUE))
      expect_true(grepl("<title>node-a\nFirst node\nA</title>", svg, fixed = TRUE))
      expect_true(grepl("<title>node-b\nB</title>", svg, fixed = TRUE))
    }
  })

  it("includes only legend sections with content and wraps items without clipping the background", {
    bare <- stagemap(data.frame(id = "a", stage = "A")) |> sm_status(pass = "Unused")
    bare_svg <- sm_svg(bare)
    expect_false(grepl(">Groups</text>", bare_svg, fixed = TRUE))
    expect_false(grepl(">Links</text>", bare_svg, fixed = TRUE))
    expect_false(grepl(">Status</text>", bare_svg, fixed = TRUE))
    expect_true(grepl("Relation map: 1 node, 0 links, 1 stage", bare_svg, fixed = TRUE))
    layout <- compute_layout(bare)
    expect_true(grepl(paste0('height="', layout_number(layout$height), '"'), bare_svg, fixed = TRUE))
    for (field in c("group", "status")) {
      nodes <- data.frame(id = "a", stage = "A")
      nodes[[field]] <- if (field == "group") "Team" else "pass"
      svg <- sm_svg(stagemap(nodes))
      expect_identical(grepl(">Groups</text>", svg, fixed = TRUE), field == "group")
      expect_identical(grepl(">Status</text>", svg, fixed = TRUE), field == "status")
      expect_false(grepl(">Links</text>", svg, fixed = TRUE))
    }
    nodes <- data.frame(id = paste0("n", 1:12), stage = "A", group = paste("Group", 1:12))
    map <- stagemap(nodes)
    layout <- compute_layout(map)
    legend <- svg_legend(
      layout,
      resolve_groups(map),
      resolve_kinds(map),
      resolve_status(map)[FALSE, ],
      svg_theme("light")
    )
    expect_gt(legend$height, 18 + 8 + layout$settings$margin)
    expect_true(all(vapply(
      paste("Group", 1:12),
      function(label) {
        grepl(paste0(">", label, "</text>"), sm_svg(map), fixed = TRUE)
      },
      logical(1)
    )))
    large <- sm_groups(map, labels = c("Group 1" = paste(rep("Wide", 30), collapse = " ")))
    larger_layout <- compute_layout(large)
    larger_legend <- svg_legend(
      larger_layout,
      resolve_groups(large),
      resolve_kinds(large),
      resolve_status(large)[FALSE, ],
      svg_theme("light")
    )
    expect_gt(larger_legend$width, larger_layout$width)
    expect_true(grepl(paste0('width="', layout_number(larger_legend$width), '"'), sm_svg(large), fixed = TRUE))
    expect_true(grepl(">Groups</text>", sm_svg(svg_example_map()), fixed = TRUE))
    expect_true(grepl(">Links</text>", sm_svg(svg_example_map()), fixed = TRUE))
    expect_true(grepl(">Status</text>", sm_svg(svg_example_map()), fixed = TRUE))
  })

  it("escapes user text in labels, titles, stages, lanes, kinds and legend names", {
    special <- '<&"\''
    escaped <- "&lt;&amp;&quot;&apos;"
    nodes <- data.frame(
      id = c("a<&", "b"),
      label = c(special, "b"),
      stage = c(special, "B"),
      lane = special,
      group = special,
      status = special
    )
    links <- data.frame(from = "a<&", to = "b", kind = special, label = special)
    svg <- sm_svg(stagemap(nodes, links))
    expect_gte(svg_count(svg, escaped), 8)
    expect_true(grepl("a&lt;&amp; \u2192 b (&lt;&amp;&quot;&apos;)", svg, fixed = TRUE))
    expect_false(grepl(special, svg, fixed = TRUE))
    expect_identical(svg_escape(">"), "&gt;")
    expect_identical(svg_escape("x\001y"), "xy")
    expect_identical(svg_escape("x\ty"), "x\ty")
    expect_identical(svg_escape("x\u0008\u000B\u000C\u000E\u001F\uFFFE\uFFFFy"), "xy")
    unicode <- stagemap(data.frame(id = "a", stage = "A", label = "caf\u00e9"))
    expect_true(grepl("caf\u00e9", sm_svg(unicode), fixed = TRUE))
  })

  it("draws the layout's lane bands, headings, separators and node coordinates in each direction", {
    for (direction in c("LR", "TB")) {
      map <- svg_example_map() |> sm_layout(direction = direction)
      svg <- sm_svg(map)
      layout <- compute_layout(map)
      for (stage in c("Requirement", "Test", "Result")) {
        expect_true(grepl(paste0(">", stage, "</text>"), svg, fixed = TRUE))
      }
      expect_equal(svg_count(svg, 'fill="#F2F7F9"'), 1)
      expect_equal(svg_count(svg, 'fill="#E8F0F3"'), 1)
      expect_equal(svg_count(svg, "<line "), 2)
      for (i in seq_len(nrow(layout$nodes))) {
        node <- layout$nodes[i, ]
        expected <- paste0(
          '<rect x="',
          layout_number(node$x),
          '" y="',
          layout_number(node$y),
          '" width="',
          layout_number(node$width),
          '" height="',
          layout_number(node$height),
          '" rx="6"'
        )
        expect_true(grepl(expected, svg, fixed = TRUE))
      }
      expect_true(grepl(layout$links$path[1L], svg, fixed = TRUE))
      expect_true(grepl('stroke-width="3" paint-order="stroke"', svg, fixed = TRUE))
      expected <- if (direction == "LR") 'width="4"' else 'height="4"'
      expect_true(grepl(expected, svg, fixed = TRUE))
    }
  })
})
