#' Fixed sizes shared by layout and drawing code
#' @noRd
layout_sizes <- function() {
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
}

#' Compute the sole layout contract used by drawing code
#' @noRd
compute_layout <- function(map) {
  checkmate::assert_class(map, "stagemap")
  settings <- c(list(direction = "LR", order = "auto", spacing = 1), layout_sizes())
  for (name in names(map$options$layout)) {
    settings[[name]] <- map$options$layout[[name]]
  }
  state <- layout_items(map, settings)
  if (settings$order == "auto") {
    state <- layout_order(state)
  }
  result <- layout_place(state)
  result$links <- layout_links(state, result)
  result$settings <- settings
  structure(result, class = "stagemap_layout")
}

#' Build cells and adjacent-stage segments, keeping original row indices
#' @noRd
layout_items <- function(map, settings) {
  checkmate::assert_class(map, "stagemap")
  checkmate::assert_list(settings, names = "unique")
  stages <- resolve_stages(map)
  lanes <- resolve_lanes(map)
  n <- nrow(map$nodes)
  lines <- lapply(
    map$nodes$label,
    wrap_label,
    width = settings$node_width - 2 * settings$padding,
    size = settings$font_size
  )
  status <- if ("status" %in% names(map$nodes)) map$nodes$status else rep(NA_character_, n)
  group <- if ("group" %in% names(map$nodes)) map$nodes$group else rep(NA_character_, n)
  # The bottom row holds the status badge and the group's name, so group is not shown by colour alone.
  height <- 2 *
    settings$padding +
    lengths(lines) * settings$line_height +
    (!is.na(status) | !is.na(group)) * (settings$badge_height + settings$badge_gap)
  lr <- settings$direction == "LR"
  items <- data.frame(
    stage = match(map$nodes$stage, stages),
    lane = if (length(lanes)) match(map$nodes$lane, lanes) else rep(1L, n),
    stage_size = if (lr) rep(settings$node_width, n) else height,
    cross_size = if (lr) height else rep(settings$node_width, n)
  )
  chains <- vector("list", nrow(map$links))
  segments <- data.frame(from = integer(), to = integer())
  for (i in seq_len(nrow(map$links))) {
    from <- match(map$links$from[i], map$nodes$id)
    to <- match(map$links$to[i], map$nodes$id)
    first <- items$stage[from]
    last <- items$stage[to]
    virtual <- integer()
    if (abs(last - first) > 1L) {
      between <- seq.int(first, last)[-c(1L, abs(last - first) + 1L)]
      virtual <- nrow(items) + seq_along(between)
      items <- rbind(
        items,
        data.frame(
          stage = between,
          lane = rep(items$lane[from], length(between)),
          stage_size = rep(0, length(between)),
          cross_size = rep(settings$slot * settings$spacing, length(between))
        )
      )
    }
    chain <- c(from, virtual, to)
    chains[[i]] <- chain
    if (first != last) {
      # Like dagre, treat backward edges as reversed during ordering; retain their direction for routing.
      if (first > last) {
        chain <- rev(chain)
      }
      segments <- rbind(segments, data.frame(from = chain[-length(chain)], to = chain[-1L]))
    }
  }
  cells <- vector("list", length(stages) * max(1L, length(lanes)))
  for (stage in seq_along(stages)) {
    for (lane in seq_len(max(1L, length(lanes)))) {
      cell <- (stage - 1L) * max(1L, length(lanes)) + lane
      cells[[cell]] <- which(items$stage == stage & items$lane == lane)
    }
  }
  list(
    map = map,
    settings = settings,
    stages = stages,
    lanes = lanes,
    items = items,
    cells = cells,
    chains = chains,
    segments = segments,
    lines = lines
  )
}

#' Measure cell stacks and place their centres on the cross axis
#' @noRd
layout_cross <- function(state) {
  checkmate::assert_list(state, names = "unique")
  settings <- state$settings
  nl <- max(1L, length(state$lanes))
  empty <- if (settings$direction == "LR") 2 * settings$padding + settings$line_height else settings$node_width
  bands <- rep(empty, nl)
  gap <- settings$node_gap * settings$spacing
  for (cell in state$cells) {
    if (!length(cell)) {
      next
    }
    lane <- state$items$lane[cell[1L]]
    bands[lane] <- max(bands[lane], sum(state$items$cross_size[cell]) + (length(cell) - 1L) * gap)
  }
  stage_header <- if (settings$direction == "LR") settings$header_top else settings$header_left
  starts <- settings$margin + stage_header + c(0, cumsum(bands + settings$lane_gap * settings$spacing)[-nl])
  centres <- numeric(nrow(state$items))
  for (cell in state$cells) {
    if (!length(cell)) {
      next
    }
    sizes <- state$items$cross_size[cell]
    centres[cell] <- starts[state$items$lane[cell[1L]]] + c(0, cumsum(sizes + gap)[-length(cell)]) + sizes / 2
  }
  list(bands = bands, starts = starts, centres = centres)
}

#' Count strictly inverted pairs of segments between adjacent stages
#' @noRd
layout_crossings <- function(state) {
  checkmate::assert_list(state, names = "unique")
  positions <- layout_cross(state)$centres
  segments <- state$segments
  total <- 0L
  for (stage in seq_len(max(0L, length(state$stages) - 1L))) {
    edges <- which(state$items$stage[segments$from] == stage)
    for (i in seq_along(edges)) {
      others <- edges[seq_along(edges) > i]
      a <- edges[i]
      total <- total +
        sum(
          (positions[segments$from[a]] - positions[segments$from[others]]) *
            (positions[segments$to[a]] - positions[segments$to[others]]) <
            0
        )
    }
  }
  total
}

#' Alternate stable sweeps and retain only the best order seen
#' @noRd
layout_order <- function(state) {
  checkmate::assert_list(state, names = "unique")
  ns <- length(state$stages)
  if (ns < 2L || !nrow(state$segments)) {
    return(state)
  }
  best <- state
  score <- layout_crossings(state)
  idle <- 0L
  for (sweep in seq_len(24L)) {
    down <- sweep %% 2L == 1L
    stages <- if (down) seq.int(2L, ns) else seq.int(ns - 1L, 1L)
    for (stage in stages) {
      positions <- layout_cross(state)$centres
      edges <- state$segments
      moving <- if (down) edges$to else edges$from
      fixed <- if (down) edges$from else edges$to
      for (cell_id in which(vapply(
        state$cells,
        function(cell) {
          length(cell) > 0L && state$items$stage[cell[1L]] == stage
        },
        logical(1)
      ))) {
        cell <- state$cells[[cell_id]]
        barycentres <- vapply(
          cell,
          function(item) {
            neighbours <- fixed[moving == item]
            if (length(neighbours)) mean(positions[neighbours]) else NA_real_
          },
          numeric(1)
        )
        slots <- which(!is.na(barycentres))
        # Dagre's barycentre sweeps guide the ordering. Unconnected slots and tied items keep their order.
        cell[slots] <- cell[slots][order(barycentres[slots], seq_along(slots), method = "radix")]
        state$cells[[cell_id]] <- cell
      }
    }
    current <- layout_crossings(state)
    if (current < score) {
      best <- state
      score <- current
      idle <- 0L
    } else {
      idle <- idle + 1L
    }
    if (idle >= 4L) break
  }
  best
}

#' Map stage and cross axes to drawing rectangles, including headers
#' @noRd
layout_place <- function(state) {
  checkmate::assert_list(state, names = "unique")
  settings <- state$settings
  lr <- settings$direction == "LR"
  cross <- layout_cross(state)
  ns <- length(state$stages)
  stage_sizes <- vapply(
    seq_len(ns),
    function(stage) {
      sizes <- state$items$stage_size[state$items$stage == stage]
      max(c(if (lr) settings$node_width else 2 * settings$padding + settings$line_height, sizes))
    },
    numeric(1)
  )
  lane_header <- if (!length(state$lanes)) {
    0
  } else if (lr) {
    settings$header_left
  } else {
    settings$header_top
  }
  starts <- settings$margin + lane_header + c(0, cumsum(stage_sizes + settings$stage_gap * settings$spacing)[-ns])
  centres <- starts + stage_sizes / 2
  stage_end <- starts[ns] + stage_sizes[ns]
  # Only arcs in the last stage need room beyond the existing stage gaps.
  if (
    any(vapply(
      state$chains,
      function(chain) {
        state$items$stage[chain[1L]] == ns && state$items$stage[chain[length(chain)]] == ns
      },
      logical(1)
    ))
  ) {
    stage_end <- stage_end + settings$stage_gap * settings$spacing / 2
  }
  cross_end <- cross$starts[length(cross$bands)] + cross$bands[length(cross$bands)]
  # These closures transpose already checked coordinates and round every output coordinate.
  rectangle <- function(s, c, ds, dc) {
    if (lr) {
      data.frame(x = round(s, 2), y = round(c, 2), width = round(ds, 2), height = round(dc, 2))
    } else {
      data.frame(x = round(c, 2), y = round(s, 2), width = round(dc, 2), height = round(ds, 2))
    }
  }
  anchor <- function(s, c) {
    if (lr) {
      data.frame(label_x = round(s, 2), label_y = round(c, 2))
    } else {
      data.frame(label_x = round(c, 2), label_y = round(s, 2))
    }
  }
  n <- nrow(state$map$nodes)
  real <- seq_len(n)
  items <- state$items[real, , drop = FALSE]
  nodes <- data.frame(
    id = state$map$nodes$id,
    stage = as.character(state$map$nodes$stage),
    lane = if (length(state$lanes)) as.character(state$map$nodes$lane) else rep(NA_character_, n)
  )
  nodes <- cbind(
    nodes,
    rectangle(
      centres[items$stage] - items$stage_size / 2,
      cross$centres[real] - items$cross_size / 2,
      items$stage_size,
      items$cross_size
    )
  )
  nodes$label_lines <- state$lines
  nodes$status <- if ("status" %in% names(state$map$nodes)) state$map$nodes$status else rep(NA_character_, n)
  nodes$group <- if ("group" %in% names(state$map$nodes)) state$map$nodes$group else rep(NA_character_, n)
  # Public order is the real-node position across the whole stage; virtual points do not consume an order number.
  nodes$order <- integer(n)
  for (stage in seq_len(ns)) {
    rows <- which(items$stage == stage)
    rows <- rows[order(cross$centres[rows], method = "radix")]
    nodes$order[rows] <- seq_along(rows)
  }
  stages <- cbind(
    data.frame(stage = state$stages),
    rectangle(starts, rep(settings$margin, ns), stage_sizes, rep(cross_end - settings$margin, ns)),
    anchor(centres, rep(settings$margin + if (lr) settings$header_top / 2 else settings$header_inset, ns))
  )
  nl <- length(state$lanes)
  lanes <- cbind(
    data.frame(lane = state$lanes),
    rectangle(
      rep(settings$margin + lane_header, nl),
      cross$starts[seq_len(nl)],
      rep(stage_end - settings$margin - lane_header, nl),
      cross$bands[seq_len(nl)]
    ),
    anchor(
      rep(settings$margin + if (lr) settings$header_inset else settings$header_top / 2, nl),
      (cross$starts + cross$bands / 2)[seq_len(nl)]
    )
  )
  list(
    direction = settings$direction,
    width = round(if (lr) stage_end + settings$margin else cross_end + settings$margin, 2),
    height = round(if (lr) cross_end + settings$margin else stage_end + settings$margin, 2),
    nodes = nodes,
    stages = stages,
    lanes = lanes
  )
}

#' Format path numbers with a fixed decimal point and no trailing zeros
#' @noRd
layout_number <- function(x) {
  checkmate::assert_numeric(x, any.missing = FALSE, finite = TRUE)
  result <- formatC(round(x, 2), format = "f", digits = 2, decimal.mark = ".")
  result <- sub("\\.$", "", sub("0+$", "", result))
  result[result == "-0"] <- "0"
  result
}

#' Spread link ends along shared node sides using their next points
#' @noRd
layout_spread_anchors <- function(state, cross, anchors) {
  checkmate::assert_list(state, names = "unique")
  checkmate::assert_numeric(cross, len = nrow(state$items), any.missing = FALSE, finite = TRUE)
  checkmate::assert_data_frame(anchors, any.missing = FALSE)
  n <- nrow(anchors)
  # Freeze neighbouring anchors so the order of processing sides cannot affect their ranking.
  ends <- data.frame(
    node = c(anchors$from, anchors$to),
    side = c(ifelse(anchors$route == "backward", "entry", "exit"), ifelse(anchors$route == "forward", "entry", "exit")),
    link = rep(seq_len(n), 2L),
    next_cross = c(anchors$end, anchors$start)
  )
  for (i in seq_len(n)) {
    chain <- state$chains[[i]]
    if (length(chain) > 2L) {
      ends$next_cross[i] <- cross[chain[2L]]
      ends$next_cross[n + i] <- cross[chain[length(chain) - 1L]]
    }
  }
  positions <- c(anchors$start, anchors$end)
  groups <- paste(ends$node, ends$side, sep = ":", recycle0 = TRUE)
  for (group in unique(groups)) {
    rows <- which(groups == group)
    k <- length(rows)
    if (k == 1L) {
      next
    }
    rows <- rows[order(ends$next_cross[rows], ends$link[rows], method = "radix")]
    node <- ends$node[rows[1L]]
    step <- min(12 * state$settings$spacing, (state$items$cross_size[node] - 8) / (k - 1L))
    positions[rows] <- cross[node] + (seq_len(k) - (k + 1) / 2) * step
  }
  anchors$start <- positions[seq_len(n)]
  anchors$end <- positions[n + seq_len(n)]
  anchors
}

#' Spread anchors on shared sides and nest same-stage arcs by their span
#' @noRd
layout_link_anchors <- function(state, cross) {
  checkmate::assert_list(state, names = "unique")
  checkmate::assert_numeric(cross, len = nrow(state$items), any.missing = FALSE, finite = TRUE)
  from <- vapply(state$chains, function(chain) chain[1L], integer(1))
  to <- vapply(state$chains, function(chain) chain[length(chain)], integer(1))
  first <- state$items$stage[from]
  last <- state$items$stage[to]
  route <- ifelse(first < last, "forward", ifelse(first > last, "backward", "same"))
  start <- cross[from] + ifelse(route == "backward", state$items$cross_size[from] / 4, 0)
  end <- cross[to] + ifelse(route == "backward", state$items$cross_size[to] / 4, 0)
  anchors <- layout_spread_anchors(
    state,
    cross,
    data.frame(from = from, to = to, route = route, start = start, end = end)
  )
  half_gap <- state$settings$stage_gap * state$settings$spacing / 2
  bulge <- rep(half_gap, length(from))
  same <- which(route == "same")
  for (stage in unique(first[same])) {
    rows <- same[first[same] == stage]
    rows <- rows[order(abs(anchors$end[rows] - anchors$start[rows]), rows, method = "radix")]
    bulge[rows] <- half_gap * (0.35 + 0.65 * seq_along(rows) / length(rows))
  }
  anchors$bulge <- bulge
  anchors
}

#' Route links through straight stage slots and compute the middle mark
#' @noRd
layout_links <- function(state, placed) {
  checkmate::assert_list(state, names = "unique")
  checkmate::assert_list(placed, names = "unique")
  result <- state$map$links[c("from", "to", "kind", "label")]
  n <- nrow(result)
  result$route <- rep("forward", n)
  result$path <- character(n)
  result$mid_x <- numeric(n)
  result$mid_y <- numeric(n)
  result$end_x <- numeric(n)
  result$end_y <- numeric(n)
  lr <- state$settings$direction == "LR"
  cross <- layout_cross(state)$centres
  anchors <- layout_link_anchors(state, cross)
  stages <- placed$stages
  stage_start <- if (lr) stages$x else stages$y
  stage_size <- if (lr) stages$width else stages$height
  centres <- stage_start + stage_size / 2
  # Per-link closures consume the checked map and its computed coordinates.
  xy <- function(point) if (lr) point else rev(point)
  pair <- function(point) paste(layout_number(xy(point)), collapse = " ")
  for (i in seq_len(n)) {
    chain <- state$chains[[i]]
    from <- anchors$from[i]
    to <- anchors$to[i]
    first <- state$items$stage[from]
    last <- state$items$stage[to]
    route <- anchors$route[i]
    result$route[i] <- route
    sign <- if (route == "backward") -1 else 1
    start <- c(centres[first] + sign * state$items$stage_size[from] / 2, anchors$start[i])
    end <- c(centres[last] - sign * state$items$stage_size[to] / 2, anchors$end[i])
    if (route == "same") {
      end[1L] <- centres[last] + state$items$stage_size[to] / 2
    }
    points <- rbind(start)
    straight <- logical()
    # Shorter nodes in TB need a straight lead to the row edge so curves stay in the gaps.
    if (route != "same" && state$items$stage_size[from] < stage_size[first]) {
      points <- rbind(points, c(centres[first] + sign * stage_size[first] / 2, start[2L]))
      straight <- c(straight, TRUE)
    }
    if (length(chain) > 2L) {
      for (item in chain[-c(1L, length(chain))]) {
        stage <- state$items$stage[item]
        entry <- c(centres[stage] - sign * stage_size[stage] / 2, cross[item])
        exit <- c(centres[stage] + sign * stage_size[stage] / 2, cross[item])
        points <- rbind(points, entry, exit)
        straight <- c(straight, FALSE, TRUE)
      }
    }
    target_inset <- route != "same" && state$items$stage_size[to] < stage_size[last]
    if (target_inset) {
      points <- rbind(points, c(centres[last] - sign * stage_size[last] / 2, end[2L]))
      straight <- c(straight, FALSE)
    }
    points <- rbind(points, end)
    straight <- c(straight, target_inset)
    path <- paste("M", pair(start))
    middle <- ceiling((nrow(points) - 1L) / 2)
    for (segment in seq_len(nrow(points) - 1L)) {
      a <- points[segment, ]
      b <- points[segment + 1L, ]
      if (straight[segment]) {
        path <- paste0(path, " L ", pair(b))
        mark <- xy((a + b) / 2)
      } else {
        midpoint <- if (route == "same") {
          max(a[1L], b[1L]) + anchors$bulge[i]
        } else {
          (a[1L] + b[1L]) / 2
        }
        c1 <- c(midpoint, a[2L])
        c2 <- c(midpoint, b[2L])
        path <- paste0(path, " C ", pair(c1), ", ", pair(c2), ", ", pair(b))
        mark <- xy((a + 3 * c1 + 3 * c2 + b) / 8)
      }
      if (segment == middle) {
        result$mid_x[i] <- round(mark[1L], 2)
        result$mid_y[i] <- round(mark[2L], 2)
      }
    }
    result$path[i] <- path
    end <- xy(end)
    result$end_x[i] <- round(end[1L], 2)
    result$end_y[i] <- round(end[2L], 2)
  }
  result
}
