#' Write a map as an SVG image
#'
#' Draw a map in R with a light or dark theme. Both themes have an opaque
#' background, so the image reads the same in a document, slide or page.
#' Meaning never rests on colour alone: link kinds have line patterns and marks,
#' statuses have icons and text, and nodes show their group's name.
#' Custom status words have text without an icon.
#' Link kinds using `"from"` or `"to"` colours show in the legend in the neutral link colour.
#' Link colours taken from groups are darkened or lightened when needed to stay readable;
#' colours set by hand are used as they are.
#'
#' @param map A `stagemap` object.
#' @param file One output path, or `NULL` (the default) to return the image as text.
#'   An existing file is overwritten.
#' @param theme One of `"light"` (the default) or `"dark"`.
#' @returns With `file = NULL`, one character string containing the SVG, visibly.
#'   With a path, writes UTF-8 text and returns the path invisibly.
#' @seealso [stagemap()], [sm_layout()]
#' @export
#' @examples
#' nodes <- data.frame(
#'   id = c("REQ-1", "REQ-2", "TST-1", "RES-1"),
#'   stage = c("Requirement", "Requirement", "Test", "Result"),
#'   lane = c("Safety", "Usability", "Safety", "Safety"),
#'   group = c("Safety", "Usability", "Safety", "Safety"),
#'   status = c("pass", "missing", "pass", "fail")
#' )
#' links <- data.frame(
#'   from = c("REQ-1", "TST-1"), to = c("TST-1", "RES-1"),
#'   kind = c("verifies", "produces")
#' )
#' map <- stagemap(nodes, links) |> sm_stages(c("Requirement", "Test", "Result"))
#' svg <- sm_svg(map)
#' nchar(svg)
#' file <- tempfile(fileext = ".svg")
#' sm_svg(map, file = file)
#' unlink(file)
sm_svg <- function(map, file = NULL, theme = c("light", "dark")) {
  with_stagemap_asserts({
    checkmate::assert_class(map, "stagemap")
    checkmate::assert_string(file, null.ok = TRUE)
    if (!is.null(file)) {
      if (dir.exists(file)) {
        cli::cli_abort("{.arg file} is a folder; give a file path such as {.file map.svg}.", class = "stagemap_error")
      }
      checkmate::assert_path_for_output(file, overwrite = TRUE)
    }
    theme <- if (missing(theme)) "light" else theme
    checkmate::assert_choice(theme, c("light", "dark"))
  })
  palette <- svg_theme(theme[1L])
  layout <- compute_layout(map)
  layout$links$label[!is.na(layout$links$label) & !nzchar(trimws(layout$links$label))] <- NA_character_
  groups <- resolve_groups(map)
  status <- resolve_status(map)
  kinds <- resolve_kinds(map)
  styles <- svg_link_styles(layout, kinds, groups, palette)
  neutral <- is.na(kinds$colour) | kinds$colour %in% c("from", "to")
  kinds$colour[neutral] <- palette$ink_soft
  legend <- svg_legend(layout, groups, kinds, status[status$used, , drop = FALSE], palette)
  label_widths <- text_width(layout$links$label[!is.na(layout$links$label)], 11)
  width <- max(layout$width, legend$width, label_widths + 2 * layout$settings$margin)
  height <- layout$height + legend$height
  body <- c(
    svg_background(width, height, palette),
    svg_lanes(layout, palette),
    svg_stages(layout, palette),
    svg_links(layout, styles, palette, width),
    svg_nodes(map, layout, groups, status, palette),
    legend$lines
  )
  counts <- c(nrow(layout$nodes), nrow(layout$links), nrow(layout$stages))
  title <- paste0(
    "Relation map: ",
    paste(paste(counts, paste0(c("node", "link", "stage"), ifelse(counts == 1L, "", "s"))), collapse = ", ")
  )
  desc <- paste0(
    "Stages: ",
    paste(layout$stages$stage, collapse = ", "),
    ".",
    if (nrow(layout$lanes)) paste0(" Lanes: ", paste(layout$lanes$lane, collapse = ", "), ".")
  )
  checksum <- svg_checksum(paste(c(title, desc, body), collapse = "\n"))
  title_id <- paste0("stagemap-title-", checksum)
  desc_id <- paste0("stagemap-desc-", checksum)
  opening <- svg_tag(
    "svg",
    list(
      xmlns = "http://www.w3.org/2000/svg",
      width = width,
      height = height,
      viewBox = paste(layout_number(c(0, 0, width, height)), collapse = " "),
      role = "img",
      `aria-labelledby` = paste(title_id, desc_id),
      `font-family` = "Helvetica, Arial, sans-serif"
    ),
    ""
  )
  opening <- sub("</svg>$", "", opening)
  svg <- paste0(
    paste(
      c(
        opening,
        svg_tag("title", list(id = title_id), svg_escape(title)),
        svg_tag("desc", list(id = desc_id), svg_escape(desc)),
        svg_markers(rbind(styles, kinds)),
        body,
        "</svg>"
      ),
      collapse = "\n"
    ),
    "\n"
  )
  if (is.null(file)) {
    return(svg)
  }
  con <- base::file(file, open = "wb")
  on.exit(close(con))
  # The string already ends with a newline; do not add a second one.
  writeLines(enc2utf8(svg), con, sep = "", useBytes = TRUE)
  invisible(file)
}

#' Colours for opaque SVG images
#' @noRd
svg_theme <- function(theme) {
  checkmate::assert_choice(theme, c("light", "dark"))
  colours <- if (theme == "light") {
    c(
      "#FFFFFF",
      "#F2F7F9",
      "#E8F0F3",
      "#FFFFFF",
      "#C4D3D9",
      "#6E858D",
      "#172E36",
      "#3C5861",
      "#4E6870",
      "#1D6B45",
      "#A33A30",
      "#7A5A12"
    )
  } else {
    c(
      "#101E22",
      "#15272C",
      "#1A2F35",
      "#172A30",
      "#2F4A52",
      "#6A8891",
      "#E7F3F5",
      "#A9C1C8",
      "#9DB6BD",
      "#7FD6A4",
      "#F2998F",
      "#E8C26A"
    )
  }
  names(colours) <- c(
    "bg",
    "band",
    "band_alt",
    "card",
    "grid",
    "outline",
    "ink",
    "ink_soft",
    "muted",
    "good",
    "bad",
    "warn"
  )
  as.list(colours)
}

#' Compute WCAG relative luminance for an opaque hex colour
#' @noRd
svg_luminance <- function(colour) {
  checkmate::assert_string(colour, pattern = "^#[[:xdigit:]]{6}$")
  channels <- strtoi(substring(colour, c(2L, 4L, 6L), c(3L, 5L, 7L)), base = 16L) / 255
  linear <- ifelse(channels <= 0.04045, channels / 12.92, ((channels + 0.055) / 1.055)^2.4)
  sum(linear * c(0.2126, 0.7152, 0.0722))
}

#' Compute the contrast ratio of two opaque hex colours
#' @noRd
svg_contrast <- function(colour, background) {
  checkmate::assert_string(colour, pattern = "^#[[:xdigit:]]{6}([[:xdigit:]]{2})?$")
  checkmate::assert_string(background, pattern = "^#[[:xdigit:]]{6}$")
  if (nchar(colour) == 9L) {
    channels <- function(hex) strtoi(substring(hex, c(2L, 4L, 6L), c(3L, 5L, 7L)), base = 16L)
    alpha <- strtoi(substr(colour, 8L, 9L), base = 16L) / 255
    mixed <- as.integer(round(channels(colour) * alpha + channels(background) * (1 - alpha)))
    colour <- sprintf("#%02X%02X%02X", mixed[1L], mixed[2L], mixed[3L])
  }
  luminance <- c(svg_luminance(colour), svg_luminance(background))
  (max(luminance) + 0.05) / (min(luminance) + 0.05)
}

#' Mix a group link colour towards the theme ink until it is readable
#' @noRd
svg_link_colour <- function(colour, palette) {
  checkmate::assert_string(colour, pattern = "^#[[:xdigit:]]{6}([[:xdigit:]]{2})?$")
  checkmate::assert_list(palette, names = "unique")
  channels <- function(hex) strtoi(substring(hex, c(2L, 4L, 6L), c(3L, 5L, 7L)), base = 16L)
  original <- channels(colour)
  ink <- channels(palette$ink)
  alpha <- if (nchar(colour) == 9L) strtoi(substr(colour, 8L, 9L), base = 16L) else 255L
  for (step in 0:10) {
    mixed <- as.integer(round(original * (1 - step / 10) + ink * step / 10))
    candidate <- sprintf("#%02X%02X%02X", mixed[1L], mixed[2L], mixed[3L])
    opacity <- as.integer(round(alpha * (1 - step / 10) + 255 * step / 10))
    if (opacity < 255L) {
      candidate <- paste0(candidate, sprintf("%02X", opacity))
    }
    contrast <- vapply(palette[c("bg", "band", "band_alt")], function(bg) svg_contrast(candidate, bg), numeric(1))
    if (all(contrast >= 3)) {
      break
    }
  }
  candidate
}

#' Escape text and attribute values once
#' @noRd
svg_escape <- function(text) {
  checkmate::assert_character(text, any.missing = FALSE)
  text <- gsub("[\u0001-\u0008\u000B\u000C\u000E-\u001F\uFFFE\uFFFF]", "", enc2utf8(text), perl = TRUE)
  for (pair in list(c("&", "&amp;"), c("<", "&lt;"), c(">", "&gt;"), c('"', "&quot;"), c("'", "&apos;"))) {
    text <- gsub(pair[1L], pair[2L], text, fixed = TRUE)
  }
  text
}

#' Construct one element with already escaped child content
#' @noRd
svg_tag <- function(tag, attrs = list(), content = NULL) {
  checkmate::assert_string(tag, min.chars = 1)
  checkmate::assert_list(attrs, names = "unique")
  checkmate::assert_character(content, any.missing = FALSE, null.ok = TRUE)
  attributes <- vapply(
    attrs,
    function(value) {
      svg_escape(if (is.numeric(value)) layout_number(value) else value)
    },
    character(1)
  )
  attributes <- if (length(attrs)) paste0(" ", names(attrs), '="', attributes, '"', collapse = "") else ""
  opening <- paste0("<", tag, attributes)
  if (is.null(content)) paste0(opening, "/>") else paste0(opening, ">", paste(content, collapse = "\n"), "</", tag, ">")
}

#' Draw one piece of text
#' @noRd
svg_text <- function(text, x, y, size, colour, anchor = "start", extra = list()) {
  checkmate::assert_string(text)
  checkmate::assert_number(x, finite = TRUE)
  checkmate::assert_number(y, finite = TRUE)
  checkmate::assert_number(size, lower = 0, finite = TRUE)
  checkmate::assert_string(colour)
  checkmate::assert_choice(anchor, c("start", "middle", "end"))
  checkmate::assert_list(extra, names = "unique")
  svg_tag(
    "text",
    c(
      list(x = x, y = y, `font-size` = size, fill = colour, `text-anchor` = anchor, `dominant-baseline` = "middle"),
      extra
    ),
    svg_escape(text)
  )
}

#' Derive a short stable checksum without integer overflow
#' @noRd
svg_checksum <- function(text) {
  checkmate::assert_string(text)
  value <- 0
  for (code in utf8ToInt(enc2utf8(text))) {
    value <- (value * 31 + code) %% 2147483647
  }
  paste0(layout_number(value))
}

#' Draw the opaque background
#' @noRd
svg_background <- function(width, height, palette) {
  checkmate::assert_number(width, lower = 0, finite = TRUE)
  checkmate::assert_number(height, lower = 0, finite = TRUE)
  checkmate::assert_list(palette, names = "unique")
  svg_tag("rect", list(x = 0, y = 0, width = width, height = height, fill = palette$bg))
}

#' Draw lane rectangles and names from the layout
#' @noRd
svg_lanes <- function(layout, palette) {
  checkmate::assert_class(layout, "stagemap_layout")
  checkmate::assert_list(palette, names = "unique")
  unlist(
    lapply(seq_len(nrow(layout$lanes)), function(i) {
      lane <- layout$lanes[i, ]
      c(
        svg_tag(
          "rect",
          c(as.list(lane[c("x", "y", "width", "height")]), list(fill = if (i %% 2L) palette$band else palette$band_alt))
        ),
        svg_text(
          lane$lane,
          lane$label_x,
          lane$label_y,
          13,
          palette$muted,
          if (layout$direction == "LR") "start" else "middle",
          list(`font-weight` = 600)
        )
      )
    }),
    use.names = FALSE
  )
}

#' Draw stage headings and separators in the gaps
#' @noRd
svg_stages <- function(layout, palette) {
  checkmate::assert_class(layout, "stagemap_layout")
  checkmate::assert_list(palette, names = "unique")
  lr <- layout$direction == "LR"
  stages <- layout$stages
  unlist(
    lapply(seq_len(nrow(stages)), function(i) {
      stage <- stages[i, ]
      heading <- svg_text(
        stage$stage,
        stage$label_x,
        stage$label_y,
        13,
        palette$ink,
        if (lr) "middle" else "start",
        list(`font-weight` = 700)
      )
      if (i == nrow(stages)) {
        return(heading)
      }
      position <- if (lr) {
        (stage$x + stage$width + stages$x[i + 1L]) / 2
      } else {
        (stage$y + stage$height + stages$y[i + 1L]) / 2
      }
      start <- layout$settings$margin + if (lr) layout$settings$header_top else layout$settings$header_left
      end <- if (lr) stage$y + stage$height else stage$x + stage$width
      coords <- if (lr) {
        list(x1 = position, y1 = start, x2 = position, y2 = end)
      } else {
        list(x1 = start, y1 = position, x2 = end, y2 = position)
      }
      c(heading, svg_tag("line", c(coords, list(stroke = palette$grid, `stroke-width` = 1))))
    }),
    use.names = FALSE
  )
}

#' Resolve endpoint colours for each routed link
#' @noRd
svg_link_styles <- function(layout, kinds, groups, palette) {
  checkmate::assert_class(layout, "stagemap_layout")
  checkmate::assert_data_frame(kinds)
  checkmate::assert_data_frame(groups)
  checkmate::assert_list(palette, names = "unique")
  styles <- kinds[match(layout$links$kind, kinds$kind), , drop = FALSE]
  for (i in seq_len(nrow(styles))) {
    colour <- styles$colour[i]
    if (!is.na(colour) && colour %in% c("from", "to")) {
      node <- match(layout$links[[colour]][i], layout$nodes$id)
      colour <- groups$colour[match(layout$nodes$group[node], groups$group)]
      if (!is.na(colour)) {
        colour <- svg_link_colour(colour, palette)
      }
    }
    styles$colour[i] <- if (is.na(colour)) palette$ink_soft else colour
  }
  styles
}

#' Define arrows once per used colour
#' @noRd
svg_markers <- function(styles) {
  checkmate::assert_data_frame(styles)
  colours <- unique(styles$colour[styles$arrow])
  if (!length(colours)) {
    return(character())
  }
  svg_tag(
    "defs",
    content = vapply(
      colours,
      function(colour) {
        svg_tag(
          "marker",
          list(
            id = svg_arrow_id(colour),
            viewBox = "0 0 10 10",
            refX = 9,
            refY = 5,
            markerWidth = 6,
            markerHeight = 6,
            markerUnits = "strokeWidth",
            orient = "auto"
          ),
          svg_tag("path", list(d = "M0 0L10 5L0 10z", fill = colour))
        )
      },
      character(1)
    )
  )
}

#' Name identical arrow definitions identically
#' @noRd
svg_arrow_id <- function(colour) {
  checkmate::assert_string(colour)
  paste0("stagemap-arrow-", tolower(sub("#", "", colour, fixed = TRUE)))
}

# Per-link helper consumes styles resolved from an asserted map.
#' @noRd
svg_stroke <- function(style) {
  patterns <- list(
    solid = numeric(),
    dashed = c(4, 3),
    dotted = c(1, 2.5),
    dotdash = c(1, 2.5, 4, 2.5),
    longdash = c(8, 3),
    twodash = c(2, 2, 6, 2)
  )
  dash <- patterns[[style$line]] * style$width
  c(
    list(fill = "none", stroke = style$colour, `stroke-width` = style$width),
    if (length(dash)) list(`stroke-dasharray` = paste(layout_number(dash), collapse = " ")),
    if (style$line == "dotted") list(`stroke-linecap` = "round"),
    if (style$arrow) list(`marker-end` = paste0("url(#", svg_arrow_id(style$colour), ")"))
  )
}

# Per-link helper consumes computed middle coordinates and resolved styles.
#' @noRd
svg_mark <- function(x, y, style, direction, palette) {
  size <- 7 * style$width / 1.5
  half <- size / 2
  attrs <- list(fill = palette$bg, stroke = style$colour, `stroke-width` = style$width)
  pair <- function(a, b) paste(layout_number(c(a, b)), collapse = " ")
  switch(
    style$mark,
    none = character(),
    circle = svg_tag("circle", c(list(cx = x, cy = y, r = half), attrs)),
    square = svg_tag("rect", c(list(x = x - half, y = y - half, width = size, height = size), attrs)),
    diamond = svg_tag(
      "path",
      c(
        list(
          d = paste("M", pair(x, y - half), "L", pair(x + half, y), "L", pair(x, y + half), "L", pair(x - half, y), "Z")
        ),
        attrs
      )
    ),
    bar = svg_tag(
      "path",
      c(
        list(
          d = if (direction == "LR") {
            paste("M", pair(x, y - half), "L", pair(x, y + half))
          } else {
            paste("M", pair(x - half, y), "L", pair(x + half, y))
          }
        ),
        attrs
      )
    ),
    cross = svg_tag(
      "path",
      c(
        list(
          d = paste(
            "M",
            pair(x - half, y - half),
            "L",
            pair(x + half, y + half),
            "M",
            pair(x - half, y + half),
            "L",
            pair(x + half, y - half)
          )
        ),
        attrs
      )
    )
  )
}

#' Draw routed links, their middle marks and labels
#' @noRd
svg_links <- function(layout, styles, palette, width) {
  checkmate::assert_class(layout, "stagemap_layout")
  checkmate::assert_data_frame(styles)
  checkmate::assert_list(palette, names = "unique")
  checkmate::assert_number(width, lower = 0, finite = TRUE)
  unlist(
    lapply(seq_len(nrow(layout$links)), function(i) {
      link <- layout$links[i, ]
      style <- styles[i, ]
      svg_tag(
        "g",
        content = c(
          svg_tag("title", content = svg_escape(paste0(link$from, " \u2192 ", link$to, " (", link$kind, ")"))),
          svg_tag("path", c(list(d = link$path), svg_stroke(style))),
          svg_mark(link$mid_x, link$mid_y, style, layout$direction, palette),
          if (!is.na(link$label)) {
            svg_link_label(link, style, layout, palette, width)
          }
        )
      )
    }),
    use.names = FALSE
  )
}

# Per-link helper consumes a checked layout, canvas width and resolved style.
#' @noRd
svg_link_label <- function(link, style, layout, palette, width) {
  half <- if (style$mark == "none") 0 else 7 * style$width / 3
  offset <- half + 4
  measured <- text_width(link$label, 11)
  margin <- layout$settings$margin
  right <- width - margin
  y <- link$mid_y
  if (layout$direction == "LR") {
    anchor <- "middle"
    x <- max(margin + measured / 2, min(link$mid_x, right - measured / 2))
    y <- y - offset
  } else {
    anchor <- "start"
    x <- link$mid_x + offset
    if (x + measured > right) {
      anchor <- "end"
      x <- link$mid_x - offset
      x <- max(margin + measured, min(x, right))
    } else {
      x <- max(margin, x)
    }
  }
  svg_text(
    link$label,
    x,
    y,
    11,
    palette$muted,
    anchor,
    list(stroke = palette$bg, `stroke-width` = 3, `paint-order` = "stroke")
  )
}

#' Measure badge text with padding and optional icon space
#' @noRd
svg_badge_width <- function(status) {
  checkmate::assert_data_frame(status)
  text_width(status$text, 11) + ifelse(is.na(status$icon), 10, 22)
}

# Per-badge helper consumes a resolved status row and checked layout sizes.
#' @noRd
svg_badge <- function(status, x, y, height, palette) {
  colour <- palette[[if (status$tone == "neutral") "muted" else status$tone]]
  width <- svg_badge_width(status)
  c(
    svg_tag(
      "rect",
      list(x = x, y = y, width = width, height = height, rx = height / 2, fill = palette$card, stroke = colour)
    ),
    svg_icon(status$icon, x + 5, y + (height - 10) / 2, colour),
    svg_text(status$text, x + if (is.na(status$icon)) 5 else 17, y + height / 2, 11, colour)
  )
}

# Per-badge helper consumes the icon name from resolve_status().
#' @noRd
svg_icon <- function(icon, x, y, colour) {
  if (is.na(icon)) {
    return(character())
  }
  path <- switch(
    icon,
    check = "M1 5L4 8L9 2",
    cross = "M1 1L9 9M1 9L9 1",
    dash = "M1 5L9 5",
    warning = "M5 0L10 9H0ZM5 3V6M5 7V8",
    skip = "M0 1L4 5L0 9M5 1L9 5L5 9"
  )
  svg_tag(
    "path",
    list(
      d = path,
      transform = paste0("translate(", paste(layout_number(c(x, y)), collapse = " "), ")"),
      fill = "none",
      stroke = colour,
      `stroke-width` = 1.3,
      `stroke-linecap` = "round",
      `stroke-linejoin` = "round"
    )
  )
}

#' Shorten footer text while retaining a requested minimum of characters
#' @noRd
svg_truncate <- function(text, width, min_chars = 0L) {
  checkmate::assert_string(text)
  checkmate::assert_number(width, finite = TRUE)
  checkmate::assert_count(min_chars)
  if (text_width(text, 11) <= width) {
    return(text)
  }
  if (min_chars == 0L && text_width("...", 11) > width) {
    return("")
  }
  while (nchar(text) > min_chars && text_width(paste0(text, "..."), 11) > width) {
    text <- substr(text, 1L, nchar(text) - 1L)
  }
  paste0(text, "...")
}

#' Draw node cards and their bottom rows
#' @noRd
svg_nodes <- function(map, layout, groups, status, palette) {
  checkmate::assert_class(map, "stagemap")
  checkmate::assert_class(layout, "stagemap_layout")
  checkmate::assert_data_frame(groups)
  checkmate::assert_data_frame(status)
  checkmate::assert_list(palette, names = "unique")
  settings <- layout$settings
  unlist(
    lapply(seq_len(nrow(layout$nodes)), function(i) {
      node <- layout$nodes[i, ]
      group <- groups[match(node$group, groups$group), , drop = FALSE]
      badge <- status[match(node$status, status$word), , drop = FALSE]
      details <- c(map$nodes$label[i], node$stage, node$lane, node$group, node$status)
      if (map$nodes$label[i] != node$id) {
        details <- c(node$id, details)
      }
      if (!is.na(node$status)) {
        details <- c(details, badge$text)
      }
      lines <- node$label_lines[[1L]]
      bottom <- node$y + node$height - settings$padding - settings$badge_height
      inner_width <- node$width - 2 * settings$padding
      gap <- if (is.na(node$group)) 0 else 8
      if (!is.na(node$status)) {
        limit <- if (is.na(node$group)) inner_width else 0.6 * (inner_width - gap)
        overhead <- if (is.na(badge$icon)) 10 else 22
        badge$text <- svg_truncate(badge$text, limit - overhead)
      }
      badge_width <- if (is.na(node$status)) 0 else svg_badge_width(badge) + gap
      stripe <- if (layout$direction == "LR") {
        list(x = node$x + 1, y = node$y + 6, width = 4, height = node$height - 12)
      } else {
        list(x = node$x + 6, y = node$y + 1, width = node$width - 12, height = 4)
      }
      svg_tag(
        "g",
        content = c(
          svg_tag("title", content = svg_escape(paste(details[!is.na(details)], collapse = "\n"))),
          svg_tag(
            "rect",
            c(
              as.list(node[c("x", "y", "width", "height")]),
              list(rx = 6, fill = palette$card, stroke = palette$outline)
            )
          ),
          if (!is.na(node$group)) svg_tag("rect", c(stripe, list(fill = group$colour))),
          vapply(
            seq_along(lines),
            function(j) {
              # Label anchors are baseline coordinates, unlike centred badges and headers.
              svg_tag(
                "text",
                list(
                  x = node$x + settings$padding,
                  y = node$y + settings$padding + settings$font_size + (j - 1L) * settings$line_height,
                  `font-size` = 13,
                  fill = palette$ink
                ),
                svg_escape(lines[j])
              )
            },
            character(1)
          ),
          if (!is.na(node$status)) svg_badge(badge, node$x + settings$padding, bottom, settings$badge_height, palette),
          if (!is.na(node$group)) {
            svg_text(
              svg_truncate(group$label, inner_width - badge_width, min_chars = 1L),
              node$x + node$width - settings$padding,
              bottom + settings$badge_height / 2,
              11,
              palette$muted,
              "end"
            )
          }
        )
      )
    }),
    use.names = FALSE
  )
}

#' Measure and draw up to three legend sections, wrapping items within each
#' @noRd
svg_legend <- function(layout, groups, kinds, status, palette) {
  checkmate::assert_class(layout, "stagemap_layout")
  checkmate::assert_data_frame(groups)
  checkmate::assert_data_frame(kinds)
  checkmate::assert_data_frame(status)
  checkmate::assert_list(palette, names = "unique")
  margin <- layout$settings$margin
  tables <- list(Groups = groups, Links = kinds, Status = status)
  widths <- list(
    Groups = text_width(groups$label, 12) + 20,
    Links = text_width(kinds$kind, 12) + 40,
    Status = svg_badge_width(status)
  )
  active <- names(tables)[vapply(tables, nrow, integer(1)) > 0L]
  if (!length(active)) {
    return(list(width = 0, height = 0, lines = character()))
  }
  heading_widths <- text_width(active, 12) * 1.1
  width <- max(layout$width, 2 * margin + max(unlist(widths)), 2 * margin + max(heading_widths) + 16)
  y <- layout$height + 8
  lines <- character()
  for (section in active) {
    heading <- text_width(section, 12) * 1.1
    lines <- c(lines, svg_text(section, margin, y + 9, 12, palette$ink, extra = list(`font-weight` = 700)))
    x <- margin + heading + 16
    for (i in seq_len(nrow(tables[[section]]))) {
      item_width <- widths[[section]][i]
      if (x + item_width > width - margin) {
        x <- margin
        y <- y + 18 + 8
      }
      item <- tables[[section]][i, , drop = FALSE]
      item_lines <- switch(
        section,
        Groups = c(
          svg_tag(
            "rect",
            list(x = x, y = y + 3, width = 12, height = 12, fill = item$colour, stroke = palette$outline)
          ),
          svg_text(item$label, x + 20, y + 9, 12, palette$ink)
        ),
        Links = c(
          svg_tag("path", c(list(d = paste("M", layout_number(x), layout_number(y + 9), "h 28")), svg_stroke(item))),
          svg_mark(x + 14, y + 9, item, layout$direction, palette),
          svg_text(item$kind, x + 40, y + 9, 12, palette$ink)
        ),
        Status = svg_badge(item, x, y, layout$settings$badge_height, palette)
      )
      lines <- c(lines, item_lines)
      x <- x + item_width + 16
    }
    y <- y + 18 + 8
  }
  list(width = width, height = y - 8 + margin - layout$height, lines = lines)
}
