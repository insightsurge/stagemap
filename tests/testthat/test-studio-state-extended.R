skip_unless_extended()

# Extended replay test on studio_large()-sized data (120 cards, 8 stages, 5 lanes, 150 links, 2 kinds, 1 zone,
# 4 steps), with 300 mixed events.

build_large_fixture <- function() {
  stages <- data.frame(
    id = paste0("s", 1:8),
    label = paste("Stage", 1:8),
    stringsAsFactors = FALSE
  )
  lanes <- data.frame(
    id = paste0("l", 1:5),
    label = paste("Lane", 1:5),
    stringsAsFactors = FALSE
  )
  n_cards <- 120L
  idx <- seq_len(n_cards) - 1L
  statuses <- c("done", "running", "waiting", "failed", "skipped")
  cards <- data.frame(
    id = paste0("c", seq_len(n_cards)),
    label = paste("Card", seq_len(n_cards)),
    stage = paste0("s", (idx %% 8L) + 1L),
    lane = paste0("l", ((idx %/% 8L) %% 5L) + 1L),
    status = statuses[(idx %% 5L) + 1L],
    zone = ifelse(idx %% 12L == 0L, "z1", NA_character_),
    stringsAsFactors = FALSE
  )
  n_links <- 150L
  l_idx <- seq_len(n_links)
  from_i <- ((l_idx - 1L) %% (n_cards - 1L)) + 1L
  to_i <- ((from_i + ((l_idx - 1L) %/% (n_cards - 1L)) + 1L - 1L) %% n_cards) + 1L
  links <- data.frame(
    from = paste0("c", from_i),
    to = paste0("c", to_i),
    kind = ifelse(l_idx %% 2L == 0L, "k1", "k2"),
    stringsAsFactors = FALSE
  )
  kinds <- data.frame(
    id = c("k1", "k2"),
    label = c("Kind 1", "Kind 2"),
    line = c("dashed", "dotted"),
    stringsAsFactors = FALSE
  )
  zones <- data.frame(id = "z1", label = "Zone 1", stringsAsFactors = FALSE)
  steps <- data.frame(
    id = paste0("st", 1:4),
    label = paste("Step", 1:4),
    stage = paste0("s", 1:4),
    stringsAsFactors = FALSE
  )
  stage_map(cards, stages, lanes, title = "Large fixture") |>
    add_links(links, kinds = kinds) |>
    add_zones(zones) |>
    add_steps(steps)
}

describe("extended replay on large studio data", {
  it("replays identically across 300 mixed events and undoes back to base", {
    large <- build_large_fixture()
    s <- studio_state_new(large)
    seq_n <- 1L
    ev <- function(type, data = structure(list(), names = character())) {
      out <- list(seq = seq_n, type = type, data = data, rev = s$rev)
      seq_n <<- seq_n + 1L
      out
    }

    t0 <- proc.time()[["elapsed"]]
    for (i in seq_len(300L)) {
      op_kind <- (i - 1L) %% 6L
      event <- if (op_kind == 0L) {
        u <- s$doc$tables$cards$.studio_uid[[((i - 1L) %% 100L) + 1L]]
        ev("edit", list(table = "cards", uid = u, field = "label", value = paste("Edited", i)))
      } else if (op_kind == 1L) {
        ev("option", list(name = "title", value = paste("Title", i)))
      } else if (op_kind == 2L) {
        ev("add", list(table = "cards"))
      } else if (op_kind == 3L) {
        u <- s$doc$tables$stages$.studio_uid[[1L]]
        by <- if ((i %/% 6L) %% 2L == 0L) 1L else -1L
        ev("move", list(table = "stages", uid = u, by = by))
      } else if (op_kind == 4L) {
        u <- s$doc$tables$links$.studio_uid[[((i - 1L) %% 100L) + 1L]]
        ev("link_reverse", list(uid = u))
      } else {
        ev("undo")
      }
      s <- studio_step(s, event)$state
      expect_identical(studio_journal_replay(s$base, s$journal), s$doc)
    }

    while (studio_journal_can_undo(s$journal)) {
      s <- studio_step(s, ev("undo"))$state
      expect_identical(studio_journal_replay(s$base, s$journal), s$doc)
    }
    elapsed <- proc.time()[["elapsed"]] - t0
    cat(sprintf("studio large 300-event replay + full undo: %.3f s\n", elapsed))
    expect_identical(s$doc, s$base)
  })
})
