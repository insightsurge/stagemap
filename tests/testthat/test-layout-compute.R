# Read the path commands so geometry checks use the actual drawing contract.
path_segments <- function(path) {
  checkmate::assert_string(path)
  tokens <- strsplit(gsub(",", " ", path, fixed = TRUE), "[[:space:]]+")[[1L]]
  point <- as.numeric(tokens[2:3])
  position <- 4L
  segments <- list()
  while (position <= length(tokens)) {
    command <- tokens[position]
    count <- if (command == "C") 6L else 2L
    coordinates <- matrix(as.numeric(tokens[seq.int(position + 1L, position + count)]), ncol = 2, byrow = TRUE)
    end <- coordinates[nrow(coordinates), ]
    segments[[length(segments) + 1L]] <- list(command = command, start = point, points = coordinates, end = end)
    point <- end
    position <- position + count + 1L
  }
  segments
}

describe("compute_layout()", {
  it("returns the drawing contract and fixed sizes with the default geometry", {
    map <- stagemap(data.frame(id = c("a", "b"), stage = c("A", "B")))
    layout <- compute_layout(map)
    expect_s3_class(layout, "stagemap_layout")
    expect_named(layout, c("direction", "width", "height", "nodes", "stages", "lanes", "links", "settings"))
    expect_named(
      layout$nodes,
      c(
        "id",
        "stage",
        "lane",
        "x",
        "y",
        "width",
        "height",
        "label_lines",
        "status",
        "group",
        "order"
      )
    )
    expect_named(layout$stages, c("stage", "x", "y", "width", "height", "label_x", "label_y"))
    expect_named(layout$lanes, c("lane", "x", "y", "width", "height", "label_x", "label_y"))
    expect_named(layout$links, c("from", "to", "kind", "label", "route", "path", "mid_x", "mid_y", "end_x", "end_y"))
    expect_identical(layout$direction, "LR")
    expect_equal(layout$nodes$x, c(16, 256))
    expect_equal(layout$nodes$y, c(48, 48))
    expect_equal(layout$nodes$width, c(168, 168))
    expect_equal(layout$nodes$height, c(37, 37))
    expect_equal(layout$width, 440)
    expect_equal(layout$height, 101)
    expect_equal(nrow(layout$lanes), 0)
    expect_equal(nrow(layout$links), 0)
    expect_true(all(is.na(layout$nodes$lane)))
    expect_true(all(is.na(layout$nodes$status)))
    expect_true(all(is.na(layout$nodes$group)))
    expect_identical(layout$nodes$label_lines, list("a", "b"))
    expect_identical(
      layout$settings[c("direction", "order", "spacing")],
      list(direction = "LR", order = "auto", spacing = 1)
    )
    expect_identical(layout$settings[names(layout_sizes())], layout_sizes())
    expect_identical(
      layout_sizes(),
      list(
        node_width = 168,
        padding = 10,
        font_size = 13,
        line_height = 17,
        badge_height = 18,
        badge_gap = 6,
        stage_gap = 72,
        node_gap = 16,
        lane_gap = 24,
        slot = 12,
        header_top = 32,
        header_left = 120,
        header_inset = 8,
        margin = 16
      )
    )
  })

  it("places stage columns to the right and stage rows down, keeping bands separate", {
    nodes <- data.frame(
      id = c("a", "b", "c", "d", "e"),
      stage = c("A", "A", "B", "B", "B"),
      lane = c("X", "Y", "X", "Y", "X"),
      group = c("one", "two", "one", "two", NA_character_),
      label = c("Short", "Short", "A long label that needs several lines of text to fit", "Short", "Short"),
      status = c("pass", NA, NA, "fail", NA)
    )
    for (direction in c("LR", "TB")) {
      map <- stagemap(nodes) |> sm_layout(direction = direction)
      layout <- compute_layout(map)
      stages <- layout$stages
      lanes <- layout$lanes
      if (direction == "LR") {
        expect_gt(stages$x[2L], stages$x[1L])
        expect_gte(lanes$y[2L], lanes$y[1L] + lanes$height[1L])
        expect_equal(lanes$label_x, rep(24, 2))
      } else {
        expect_gt(stages$y[2L], stages$y[1L])
        expect_gte(lanes$x[2L], lanes$x[1L] + lanes$width[1L])
        expect_equal(lanes$label_y, rep(32, 2))
      }
      drawn <- layout$nodes
      expect_identical(drawn$id, nodes$id)
      expect_identical(drawn$group, nodes$group)
      expect_identical(drawn$status, nodes$status)
      expect_equal(drawn$height[1L] - drawn$height[5L], 24)
      expect_gt(length(drawn$label_lines[[3L]]), 1L)
      for (i in seq_len(nrow(drawn))) {
        stage <- stages[match(drawn$stage[i], stages$stage), ]
        lane <- lanes[match(drawn$lane[i], lanes$lane), ]
        for (box in list(stage, lane)) {
          expect_gte(drawn$x[i], box$x)
          expect_gte(drawn$y[i], box$y)
          expect_lte(drawn$x[i] + drawn$width[i], box$x + box$width + 0.01)
          expect_lte(drawn$y[i] + drawn$height[i], box$y + box$height + 0.01)
        }
      }
      expect_true(all(drawn$x >= 0 & drawn$y >= 0))
      expect_true(all(drawn$x + drawn$width <= layout$width))
      expect_true(all(drawn$y + drawn$height <= layout$height))
      for (table in list(drawn, stages, lanes)) {
        for (name in intersect(c("x", "y", "width", "height", "label_x", "label_y"), names(table))) {
          expect_identical(table[[name]], round(table[[name]], 2))
        }
      }
    }
    plain <- compute_layout(stagemap(nodes[c("id", "stage")]) |> sm_layout("TB"))
    expect_gt(plain$stages$y[2L], plain$stages$y[1L])
    expect_equal(nrow(plain$lanes), 0)
  })

  it("keeps all nodes outside the top and left header strips, with anchors inside the strips", {
    nodes <- data.frame(
      id = paste0("n", seq_len(9L)),
      stage = rep(c("A", "B", "C"), each = 3L),
      lane = rep(c("X", "Y", "Z"), 3L),
      status = rep(c("pass", NA_character_, NA_character_), 3L)
    )
    for (with_lanes in c(FALSE, TRUE)) {
      data <- if (with_lanes) nodes else nodes[c("id", "stage", "status")]
      for (direction in c("LR", "TB")) {
        layout <- compute_layout(stagemap(data) |> sm_layout(direction))
        stages <- layout$stages
        lanes <- layout$lanes
        if (direction == "LR") {
          headers <- data.frame(x = stages$x, y = 16, width = stages$width, height = 32)
          expect_equal(stages$label_x, stages$x + stages$width / 2)
          expect_equal(stages$label_y, rep(32, 3L))
          expect_true(all(layout$nodes$y >= 48))
          expect_true(all(layout$nodes$x >= if (with_lanes) 136 else 16))
          if (with_lanes) {
            headers <- rbind(headers, data.frame(x = 16, y = lanes$y, width = 120, height = lanes$height))
            expect_equal(lanes$label_x, rep(24, 3L))
            expect_equal(lanes$label_y, lanes$y + lanes$height / 2)
          }
        } else {
          headers <- data.frame(x = 16, y = stages$y, width = 120, height = stages$height)
          expect_equal(stages$label_x, rep(24, 3L))
          expect_equal(stages$label_y, stages$y + stages$height / 2)
          expect_true(all(layout$nodes$x >= 136))
          expect_true(all(layout$nodes$y >= if (with_lanes) 48 else 16))
          if (with_lanes) {
            headers <- rbind(headers, data.frame(x = lanes$x, y = 16, width = lanes$width, height = 32))
            expect_equal(lanes$label_x, lanes$x + lanes$width / 2)
            expect_equal(lanes$label_y, rep(32, 3L))
          }
        }
        for (i in seq_len(nrow(headers))) {
          header <- headers[i, ]
          drawn <- layout$nodes
          expect_true(all(
            drawn$x + drawn$width <= header$x |
              drawn$x >= header$x + header$width |
              drawn$y + drawn$height <= header$y |
              drawn$y >= header$y + header$height
          ))
        }
      }
    }
  })

  it("uses the documented link column order for empty and non-empty link tables", {
    nodes <- data.frame(id = c("a", "b"), stage = c("A", "B"))
    columns <- c("from", "to", "kind", "label", "route", "path", "mid_x", "mid_y", "end_x", "end_y")
    for (direction in c("LR", "TB")) {
      empty <- compute_layout(stagemap(nodes) |> sm_layout(direction))$links
      linked <- compute_layout(stagemap(nodes, data.frame(from = "a", to = "b")) |> sm_layout(direction))$links
      expect_identical(names(empty), columns)
      expect_identical(names(linked), columns)
      expect_equal(nrow(empty), 0)
      for (name in c("mid_x", "mid_y", "end_x", "end_y")) {
        expect_identical(empty[[name]], numeric())
      }
    }
  })

  it("keeps declared empty stages and lanes, including factor levels", {
    nodes <- data.frame(id = "a", stage = factor("A", c("A", "B")), lane = factor("X", c("X", "Y")))
    for (direction in c("LR", "TB")) {
      layout <- compute_layout(stagemap(nodes) |> sm_layout(direction))
      expect_identical(layout$stages$stage, c("A", "B"))
      expect_identical(layout$lanes$lane, c("X", "Y"))
      expect_true(all(layout$stages$width > 0 & layout$stages$height > 0))
      expect_true(all(layout$lanes$width > 0 & layout$lanes$height > 0))
      explicit <- stagemap(nodes) |> sm_stages(c("B", "A", "C")) |> sm_lanes(c("Y", "X", "Z"))
      drawn <- compute_layout(explicit |> sm_layout(direction))
      expect_identical(drawn$stages$stage, c("B", "A", "C"))
      expect_identical(drawn$lanes$lane, c("Y", "X", "Z"))
    }
  })

  it("scales all four kinds of gap and keeps node sizes fixed", {
    nodes <- data.frame(id = c("a", "b", "c"), stage = c("A", "A", "C"), lane = c("X", "X", "Y"))
    map <- stagemap(nodes, data.frame(from = "a", to = "c")) |> sm_stages(c("A", "B", "C"))
    for (direction in c("LR", "TB")) {
      small_map <- map |> sm_layout(direction, "data", 0.5)
      large_map <- map |> sm_layout(direction, "data", 2)
      small <- compute_layout(small_map)
      large <- compute_layout(large_map)
      expect_identical(large$nodes$width, small$nodes$width)
      expect_identical(large$nodes$height, small$nodes$height)
      expect_gt(large$width, small$width)
      expect_gt(large$height, small$height)
      axis <- if (direction == "LR") "x" else "y"
      dimension <- if (direction == "LR") "width" else "height"
      cross_axis <- if (direction == "LR") "y" else "x"
      cross_dimension <- if (direction == "LR") "height" else "width"
      expect_equal(large$stages[[axis]][2L] - sum(large$stages[[axis]][1L], large$stages[[dimension]][1L]), 144)
      expect_equal(
        large$nodes[[cross_axis]][2L] -
          sum(large$nodes[[cross_axis]][1L], large$nodes[[cross_dimension]][1L]),
        32
      )
      expect_equal(
        large$lanes[[cross_axis]][2L] -
          sum(large$lanes[[cross_axis]][1L], large$lanes[[cross_dimension]][1L]),
        48
      )
      settings <- c(list(direction = direction, order = "data", spacing = 2), layout_sizes())
      state <- layout_items(large_map, settings)
      expect_equal(state$items$cross_size[nrow(state$items)], 24)
    }
  })

  it("removes a crossing, keeps disconnected slots and retains ties stably", {
    nodes <- data.frame(id = c("a", "b", "c", "d"), stage = c("A", "A", "B", "B"))
    links <- data.frame(from = c("a", "b"), to = c("d", "c"))
    map <- stagemap(nodes, links)
    for (direction in c("LR", "TB")) {
      data <- compute_layout(map |> sm_layout(direction, "data"))
      auto <- compute_layout(map |> sm_layout(direction, "auto"))
      expect_equal(data$nodes$order, c(1, 2, 1, 2))
      expect_equal(auto$nodes$order, c(1, 2, 2, 1))
      settings <- c(list(direction = direction, order = "auto", spacing = 1), layout_sizes())
      state <- layout_items(map, settings)
      expect_equal(layout_crossings(state), 1)
      expect_equal(layout_crossings(layout_order(state)), 0)
    }
    nodes <- data.frame(id = c("a", "b", "c", "d", "e"), stage = c("A", "A", "B", "B", "B"))
    map <- stagemap(nodes, data.frame(from = c("a", "b"), to = c("e", "c")))
    expect_equal(compute_layout(map)$nodes$order, c(1, 2, 3, 2, 1))
    tied <- stagemap(nodes, data.frame(from = c("a", "a"), to = c("c", "e")))
    expect_equal(compute_layout(tied)$nodes$order, c(1, 2, 1, 2, 3))
  })

  it("is identical on repeated calls and after rebuilding in both directions", {
    nodes <- data.frame(
      id = c("a", "b", "c", "d"),
      stage = c("A", "B", "C", "C"),
      lane = c("X", "Y", "X", "X")
    )
    links <- data.frame(from = c("a", "d", "c", "b"), to = c("c", "a", "d", "c"), label = c("long", NA, "same", NA))
    for (direction in c("LR", "TB")) {
      map <- stagemap(nodes, links) |> sm_layout(direction)
      rebuilt <- stagemap(nodes, links) |> sm_layout(direction)
      expect_identical(compute_layout(map), compute_layout(map))
      expect_identical(compute_layout(map), compute_layout(rebuilt))
    }
  })

  it("checks the entry point and every internal helper argument", {
    expect_error(compute_layout(NULL), "map")
    expect_error(layout_items(NULL, list()), "map")
    expect_error(layout_items(stagemap(data.frame(id = "a", stage = "A")), NULL), "settings")
    expect_error(layout_cross(NULL), "state")
    expect_error(layout_crossings(NULL), "state")
    expect_error(layout_order(NULL), "state")
    expect_error(layout_place(NULL), "state")
    expect_error(layout_link_anchors(NULL, numeric()), "state")
    checked_state <- list(items = data.frame(stage = 1L))
    for (bad in list("1", NA_real_, Inf, numeric())) {
      expect_error(layout_link_anchors(checked_state, bad), "cross")
    }
    expect_error(layout_links(NULL, list()), "state")
    expect_error(layout_links(list(checked = TRUE), NULL), "placed")
    expect_error(layout_number("1"), "x")
    expect_error(layout_number(NA_real_), "x")
    expect_error(layout_number(Inf), "x")
  })
})

describe("link paths", {
  it("spreads parallel anchors in link order within each route and node pair", {
    nodes <- data.frame(id = c("a", "b", "c"), stage = c("A", "B", "B"))
    links <- data.frame(
      from = c("a", "b", "a", "a", "b"),
      to = c("b", "a", "c", "b", "a"),
      kind = c("x", "x", "x", "y", "y")
    )
    # Interleave another pair and the reverse route to check that each group has its own offsets.
    for (direction in c("LR", "TB")) {
      layout <- compute_layout(stagemap(nodes, links) |> sm_layout(direction, "data", spacing = 1.5))
      cross_axis <- if (direction == "LR") 2L else 1L
      position <- if (direction == "LR") layout$nodes$y else layout$nodes$x
      size <- if (direction == "LR") layout$nodes$height else layout$nodes$width
      expect_identical(layout$links$route, c("forward", "backward", "forward", "forward", "backward"))
      expect_length(unique(layout$links$path), 5L)
      for (i in seq_len(nrow(links))) {
        segment <- path_segments(layout$links$path[i])[[1L]]
        from <- match(links$from[i], nodes$id)
        to <- match(links$to[i], nodes$id)
        ends <- c(from, to)
        anchors <- c(segment$start[cross_axis], segment$end[cross_axis])
        expect_true(all(anchors >= position[ends] + 4))
        expect_true(all(anchors <= position[ends] + size[ends] - 4))
        base <- position[ends] + size[ends] * if (i %in% c(2L, 5L)) 0.75 else 0.5
        # A 9 px step gives offsets -4.5 and 4.5; the unrelated pair stays centred.
        offset <- c(-4.5, -4.5, 0, 4.5, 4.5)[i]
        expect_equal(anchors, base + offset)
      }
    }
  })

  it("clamps crowded parallel anchors at least four pixels inside both nodes", {
    nodes <- data.frame(id = c("a", "b"), stage = c("A", "B"))
    for (direction in c("LR", "TB")) {
      for (backward in c(FALSE, TRUE)) {
        links <- data.frame(from = if (backward) "b" else "a", to = if (backward) "a" else "b", kind = letters[1:13])
        layout <- compute_layout(stagemap(nodes, links) |> sm_layout(direction, "data", spacing = 4))
        axis <- if (direction == "LR") 2L else 1L
        position <- if (direction == "LR") layout$nodes$y else layout$nodes$x
        size <- if (direction == "LR") layout$nodes$height else layout$nodes$width
        from <- if (backward) 2L else 1L
        to <- if (backward) 1L else 2L
        paths <- lapply(layout$links$path, path_segments)
        starts <- vapply(paths, function(path) path[[1L]]$start[axis], numeric(1))
        ends <- vapply(paths, function(path) path[[1L]]$end[axis], numeric(1))
        expect_equal(range(starts), c(position[from] + 4, position[from] + size[from] - 4))
        expect_equal(range(ends), c(position[to] + 4, position[to] + size[to] - 4))
      }
    }
  })

  it("keeps the single-link paths unchanged", {
    nodes <- data.frame(id = c("a", "b"), stage = c("A", "B"))
    forward <- compute_layout(stagemap(nodes, data.frame(from = "a", to = "b")))
    backward <- compute_layout(stagemap(nodes, data.frame(from = "b", to = "a")))
    nodes$stage <- "A"
    same <- compute_layout(stagemap(nodes, data.frame(from = "a", to = "b")))
    expect_identical(forward$links$path, "M 184 66.5 C 220 66.5, 220 66.5, 256 66.5")
    expect_identical(backward$links$path, "M 256 75.75 C 220 75.75, 220 75.75, 184 75.75")
    expect_identical(same$links$path, "M 184 66.5 C 220 66.5, 220 119.5, 184 119.5")
  })

  it("gives parallel long links separate straight slots in every intervening stage", {
    nodes <- data.frame(id = c("a", "b"), stage = c("A", "D"))
    for (direction in c("LR", "TB")) {
      for (order in c("auto", "data")) {
        for (backward in c(FALSE, TRUE)) {
          links <- data.frame(from = if (backward) "b" else "a", to = if (backward) "a" else "b", kind = c("x", "y"))
          map <- stagemap(nodes, links) |> sm_stages(c("A", "B", "C", "D")) |> sm_layout(direction, order)
          layout <- compute_layout(map)
          axis <- if (direction == "LR") 2L else 1L
          paths <- lapply(layout$links$path, path_segments)
          for (slot in c(2L, 4L)) {
            expect_identical(paths[[1L]][[slot]]$command, "L")
            expect_identical(paths[[2L]][[slot]]$command, "L")
            expect_gte(abs(paths[[1L]][[slot]]$start[axis] - paths[[2L]][[slot]]$start[axis]), 12)
            for (path in paths) {
              expect_equal(path[[slot]]$start[axis], path[[slot]]$end[axis])
            }
          }
        }
      }
    }
  })

  it("groups opposite same-stage directions by their unordered node pair", {
    nodes <- data.frame(id = c("a", "b"), stage = "A")
    links <- data.frame(from = c("a", "b"), to = c("b", "a"))
    layout <- compute_layout(stagemap(nodes, links) |> sm_layout(order = "data"))
    paths <- lapply(layout$links$path, path_segments)
    centres <- layout$nodes$y + layout$nodes$height / 2
    expect_equal(paths[[1L]][[1L]]$start[2L], centres[1L] - 3)
    expect_equal(paths[[1L]][[1L]]$end[2L], centres[2L] - 3)
    expect_equal(paths[[2L]][[1L]]$start[2L], centres[2L] + 3)
    expect_equal(paths[[2L]][[1L]]$end[2L], centres[1L] + 3)
  })

  it("gives longer same-stage spans larger bulges and breaks tied spans by link order", {
    nodes <- data.frame(id = c("a", "b", "c", "d"), stage = "A", lane = c("X", "X", "X", "Y"))
    links <- data.frame(from = c("b", "a"), to = c("d", "c"))
    for (direction in c("LR", "TB")) {
      for (tied in c(FALSE, TRUE)) {
        data <- if (tied) nodes[c("id", "stage")] else nodes
        layout <- compute_layout(stagemap(data, links) |> sm_layout(direction, "data"))
        axis <- if (direction == "LR") 1L else 2L
        cross_axis <- 3L - axis
        paths <- lapply(layout$links$path, path_segments)
        spans <- vapply(
          paths,
          function(path) abs(path[[1L]]$end[cross_axis] - path[[1L]]$start[cross_axis]),
          numeric(1)
        )
        bulges <- vapply(paths, function(path) path[[1L]]$points[1L, axis] - path[[1L]]$start[axis], numeric(1))
        if (tied) {
          expect_equal(spans[1L], spans[2L])
          expect_equal(bulges, c(24.3, 36))
        } else {
          expect_gt(spans[1L], spans[2L])
          expect_equal(bulges, c(36, 24.3))
        }
      }
    }
  })

  it("adds room and extends lane bands only for same-stage arcs in the last stage", {
    nodes <- data.frame(id = c("a", "b", "c", "d"), stage = c("A", "A", "B", "B"), lane = "X")
    for (direction in c("LR", "TB")) {
      plain <- compute_layout(stagemap(nodes) |> sm_layout(direction, "data"))
      first <- compute_layout(stagemap(nodes, data.frame(from = "a", to = "b")) |> sm_layout(direction, "data"))
      last <- compute_layout(stagemap(nodes, data.frame(from = "c", to = "d")) |> sm_layout(direction, "data"))
      size <- if (direction == "LR") "width" else "height"
      position <- if (direction == "LR") "x" else "y"
      axis <- if (direction == "LR") 1L else 2L
      expect_equal(first[[size]], plain[[size]])
      expect_equal(first$lanes[[size]], plain$lanes[[size]])
      expect_equal(last[[size]], plain[[size]] + 36)
      expect_equal(last$lanes[[size]], plain$lanes[[size]] + 36)
      arc <- path_segments(last$links$path)[[1L]]
      # Both anchors share the exit edge; the cubic reaches its furthest point halfway along it.
      furthest <- (arc$start[axis] + 3 * sum(arc$points[1:2, axis]) + arc$end[axis]) / 8
      expect_gte(last$lanes[[position]] + last$lanes[[size]], furthest)
      expect_equal(last$lanes[[position]] + last$lanes[[size]], last[[size]] - 16)
    }
  })

  it("uses exit and entry edges and the cubic midpoint for forward and backward links", {
    nodes <- data.frame(id = c("a", "b"), stage = c("A", "B"))
    links <- data.frame(from = c("a", "b"), to = c("b", "a"), kind = c("out", "back"), label = c("Go", NA))
    for (direction in c("LR", "TB")) {
      layout <- compute_layout(stagemap(nodes, links) |> sm_layout(direction))
      expect_identical(layout$links$route, c("forward", "backward"))
      expect_identical(layout$links[c("from", "to", "kind", "label")], links)
      a <- layout$nodes[1L, ]
      b <- layout$nodes[2L, ]
      if (direction == "LR") {
        start <- c(a$x + a$width, a$y + a$height / 2)
        end <- c(b$x, b$y + b$height / 2)
        back_start <- c(b$x, b$y + 3 * b$height / 4)
        back_end <- c(a$x + a$width, a$y + 3 * a$height / 4)
      } else {
        start <- c(a$x + a$width / 2, a$y + a$height)
        end <- c(b$x + b$width / 2, b$y)
        back_start <- c(b$x + 3 * b$width / 4, b$y)
        back_end <- c(a$x + 3 * a$width / 4, a$y + a$height)
      }
      expect_true(startsWith(layout$links$path[1L], paste("M", paste(layout_number(start), collapse = " "))))
      expect_true(startsWith(layout$links$path[2L], paste("M", paste(layout_number(back_start), collapse = " "))))
      expect_equal(c(layout$links$end_x[1L], layout$links$end_y[1L]), round(end, 2))
      expect_equal(c(layout$links$end_x[2L], layout$links$end_y[2L]), round(back_end, 2))
      expect_equal(c(layout$links$mid_x[1L], layout$links$mid_y[1L]), round((start + end) / 2, 2))
      expect_equal(c(layout$links$mid_x[2L], layout$links$mid_y[2L]), round((back_start + back_end) / 2, 2))
      expect_false(identical(layout$links$path[1L], layout$links$path[2L]))
    }
  })

  it("routes same-stage arcs from exit to exit and keeps their bulge inside the drawing", {
    nodes <- data.frame(id = c("a", "b"), stage = c("A", "A"))
    for (direction in c("LR", "TB")) {
      layout <- compute_layout(stagemap(nodes, data.frame(from = "a", to = "b")) |> sm_layout(direction))
      link <- layout$links
      expect_identical(link$route, "same")
      expect_length(gregexpr("C", link$path, fixed = TRUE)[[1L]], 1L)
      a <- layout$nodes[1L, ]
      b <- layout$nodes[2L, ]
      if (direction == "LR") {
        expect_equal(link$end_x, b$x + b$width)
        expect_equal(link$end_y, b$y + b$height / 2)
        expect_equal(link$mid_x, a$x + a$width + 27)
        expect_equal(link$mid_y, (a$y + b$y) / 2 + a$height / 2)
        expect_lte(link$mid_x, layout$width - 16)
      } else {
        expect_equal(link$end_y, b$y + b$height)
        expect_equal(link$end_x, b$x + b$width / 2)
        expect_equal(link$mid_y, a$y + a$height + 27)
        expect_lte(link$mid_y, layout$height - 16)
      }
    }
  })

  it("routes long links across each intervening stage in source-lane order", {
    nodes <- data.frame(id = c("a", "b"), stage = c("A", "D"), lane = c("X", "Y"))
    links <- data.frame(from = c("a", "b"), to = c("b", "a"))
    map <- stagemap(nodes, links) |> sm_stages(c("A", "B", "C", "D"))
    for (direction in c("LR", "TB")) {
      layout <- compute_layout(map |> sm_layout(direction))
      expect_identical(layout$nodes$id, nodes$id)
      expect_equal(vapply(gregexpr("C", layout$links$path, fixed = TRUE), length, integer(1)), c(3L, 3L))
      expect_equal(vapply(gregexpr("L", layout$links$path, fixed = TRUE), length, integer(1)), c(2L, 2L))
      expect_identical(layout$links$route, c("forward", "backward"))
      settings <- c(list(direction = direction, order = "data", spacing = 1), layout_sizes())
      state <- layout_items(map, settings)
      expect_equal(state$items$stage[3:6], c(2, 3, 3, 2))
      expect_equal(state$items$lane[3:6], c(1, 1, 2, 2))
      centres <- layout_cross(state)$centres
      for (i in 1:2) {
        virtual <- state$chains[[i]][2:3]
        segments <- path_segments(layout$links$path[i])
        expect_identical(vapply(segments, `[[`, character(1), "command"), c("C", "L", "C", "L", "C"))
        expected_slots <- vector("list", 2L)
        for (j in seq_along(virtual)) {
          item <- virtual[j]
          stage <- state$items$stage[item]
          points <- if (direction == "LR") {
            rbind(
              c(layout$stages$x[stage], centres[item]),
              c(layout$stages$x[stage] + layout$stages$width[stage], centres[item])
            )
          } else {
            rbind(
              c(centres[item], layout$stages$y[stage]),
              c(centres[item], layout$stages$y[stage] + layout$stages$height[stage])
            )
          }
          if (i == 2L) {
            points <- points[2:1, , drop = FALSE]
          }
          expected_slots[[j]] <- points
          expect_equal(segments[[2L * j]]$start, round(points[1L, ], 2))
          expect_equal(segments[[2L * j]]$end, round(points[2L, ], 2))
        }
        # Of five segments, the middle one is the curve between the two straight slots.
        middle <- (expected_slots[[1L]][2L, ] + expected_slots[[2L]][1L, ]) / 2
        expect_equal(c(layout$links$mid_x[i], layout$links$mid_y[i]), round(middle, 2))
        axis <- if (direction == "LR") 1L else 2L
        for (segment in segments[c(1L, 3L, 5L)]) {
          midpoint <- (segment$start[axis] + segment$end[axis]) / 2
          expect_equal(segment$points[1:2, axis], rep(midpoint, 2L))
        }
      }
    }
  })

  it("keeps passing links inside their slots and outside node boxes in the middle stage", {
    nodes <- data.frame(id = c("a", "m1", "m2", "z"), stage = c("A", "B", "B", "C"), lane = "X")
    links <- data.frame(from = c("a", "z"), to = c("z", "a"))
    for (with_lanes in c(FALSE, TRUE)) {
      data <- if (with_lanes) nodes else nodes[c("id", "stage")]
      for (direction in c("LR", "TB")) {
        for (order in c("auto", "data")) {
          map <- stagemap(data, links) |> sm_layout(direction, order, spacing = 1.5)
          layout <- compute_layout(map)
          settings <- c(list(direction = direction, order = order, spacing = 1.5), layout_sizes())
          state <- layout_items(map, settings)
          if (order == "auto") {
            state <- layout_order(state)
          }
          centres <- layout_cross(state)$centres
          axis <- if (direction == "LR") 1L else 2L
          cross_axis <- if (direction == "LR") 2L else 1L
          stage_start <- if (direction == "LR") layout$stages$x[2L] else layout$stages$y[2L]
          stage_size <- if (direction == "LR") layout$stages$width[2L] else layout$stages$height[2L]
          boxes <- layout$nodes[layout$nodes$stage == "B", ]
          box_start <- if (direction == "LR") boxes$y else boxes$x
          box_size <- if (direction == "LR") boxes$height else boxes$width
          for (i in 1:2) {
            segments <- path_segments(layout$links$path[i])
            expect_identical(vapply(segments, `[[`, character(1), "command"), c("C", "L", "C"))
            slot <- segments[[2L]]
            expect_equal(sort(c(slot$start[axis], slot$end[axis])), c(stage_start, stage_start + stage_size))
            positions <- c(slot$start[cross_axis], slot$end[cross_axis])
            centre <- centres[state$chains[[i]][2L]]
            expect_equal(positions, rep(centre, 2L))
            # A 12 px slot at spacing 1.5 has a 9 px half-width.
            expect_true(all(abs(positions - centre) <= 9))
            expect_true(all(positions[1L] < box_start | positions[1L] > box_start + box_size))
            expect_equal(c(layout$links$mid_x[i], layout$links$mid_y[i]), round((slot$start + slot$end) / 2, 2))
            # A cubic stays inside its control points' bounds: neither gap curve enters stage B.
            for (segment in segments[c(1L, 3L)]) {
              coordinates <- rbind(segment$start, segment$points)[, axis]
              expect_true(max(coordinates) <= stage_start || min(coordinates) >= stage_start + stage_size)
            }
          }
        }
      }
    }
  })

  it("uses straight leads for shorter nodes in TB so all curves stay between stage rows", {
    nodes <- data.frame(
      id = c("a", "tall_a", "middle", "z", "tall_z"),
      stage = c("A", "A", "B", "C", "C"),
      status = c(NA_character_, "pass", NA_character_, NA_character_, "pass")
    )
    links <- data.frame(from = c("a", "z"), to = c("z", "a"))
    layout <- compute_layout(stagemap(nodes, links) |> sm_layout("TB", "data"))
    for (i in 1:2) {
      segments <- path_segments(layout$links$path[i])
      expect_identical(vapply(segments, `[[`, character(1), "command"), c("L", "C", "L", "C", "L"))
      first <- if (i == 1L) 1L else 3L
      last <- if (i == 1L) 3L else 1L
      exit <- layout$stages$y[first] + if (i == 1L) layout$stages$height[first] else 0
      entry <- layout$stages$y[last] + if (i == 1L) 0 else layout$stages$height[last]
      expect_equal(segments[[1L]]$end[2L], exit)
      expect_equal(segments[[5L]]$start[2L], entry)
      middle_entry <- layout$stages$y[2L] + if (i == 1L) 0 else layout$stages$height[2L]
      middle_exit <- layout$stages$y[2L] + if (i == 1L) layout$stages$height[2L] else 0
      expect_equal(segments[[2L]]$start[2L], exit)
      expect_equal(segments[[2L]]$end[2L], middle_entry)
      expect_equal(segments[[4L]]$start[2L], middle_exit)
      expect_equal(segments[[4L]]$end[2L], entry)
      for (segment in segments[c(2L, 4L)]) {
        limits <- range(c(segment$start[2L], segment$end[2L]))
        expect_true(all(segment$points[, 2L] >= limits[1L] & segment$points[, 2L] <= limits[2L]))
      }
      for (segment in segments[c(1L, 3L, 5L)]) {
        expect_equal(segment$start[1L], segment$end[1L])
      }
      expect_equal(
        c(layout$links$mid_x[i], layout$links$mid_y[i]),
        round((segments[[3L]]$start + segments[[3L]]$end) / 2, 2)
      )
    }
  })

  it("formats rounded path numbers independently of the decimal option", {
    withr::local_options(OutDec = ",")
    expect_identical(layout_number(c(0, -0.001, 1, 1.2, 1.234, -2.5)), c("0", "0", "1", "1.2", "1.23", "-2.5"))
    expect_identical(layout_number(numeric()), character())
  })
})

describe("compute_layout() node heights", {
  it("reserves the bottom row for a status or a group", {
    nodes <- data.frame(
      id = c("plain", "status", "group", "both"),
      stage = "S",
      status = c(NA, "pass", NA, "fail"),
      group = c(NA, NA, "g", "g")
    )
    heights <- compute_layout(stagemap(nodes))$nodes$height
    sizes <- layout_sizes()
    expect_identical(heights[2:4] - heights[1], rep(sizes$badge_height + sizes$badge_gap, 3))
  })
})
