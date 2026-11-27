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

  it("keeps replay identical across randomised repeated cell edits including blanks and returns", {
    old_seed <- if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
      get(".Random.seed", envir = globalenv(), inherits = FALSE)
    } else {
      NULL
    }
    on.exit(
      {
        if (is.null(old_seed)) {
          rm(".Random.seed", envir = globalenv())
        } else {
          assign(".Random.seed", old_seed, envir = globalenv())
        }
      },
      add = TRUE
    )
    set.seed(20261127L)

    cards <- data.frame(
      id = c("a", "b", "c"),
      label = factor(c("Alpha", "Beta", "Gamma")),
      stage = c("s1", "s2", "s2"),
      lane = c("l1", "l1", "l2")
    )
    stages <- data.frame(id = c("s1", "s2"), label = c("Start", "End"), stringsAsFactors = FALSE)
    lanes <- data.frame(id = c("l1", "l2"), label = c("Main", "Side"), stringsAsFactors = FALSE)
    links <- data.frame(from = c("a", "b"), to = c("b", "c"), stringsAsFactors = FALSE)
    map <- stage_map(cards, stages, lanes, title = "Seeded", target = "b") |>
      add_links(links) |>
      add_steps(
        data.frame(id = "st1", label = "Step 1", stage = "s2"),
        changes = data.frame(step = "st1", card = "b", stage = "s2", status = "done")
      ) |>
      stage_map_highlight(c("a", "b"), links = data.frame(from = "a", to = "b"))

    s <- studio_state_new(map)
    seq_n <- 1L
    u_a <- studio_uid_of(s$doc, "cards", "a")
    u_b <- studio_uid_of(s$doc, "cards", "b")
    u_s1 <- studio_uid_of(s$doc, "stages", "s1")
    u_s2 <- studio_uid_of(s$doc, "stages", "s2")

    edit_pool <- list(
      list(table = "cards", uid = u_a, field = "tone", vals = c("good", "warn", "bad", "")),
      list(table = "cards", uid = u_a, field = "label", vals = c("Alpha", "Alpha 2", "Alpha 3", "Alpha")),
      list(table = "cards", uid = u_b, field = "id", vals = c("b", "b_tmp", "", "a", "b_next", "b")),
      list(table = "stages", uid = u_s1, field = "date", vals = c("2026-01-01", "2026-06-15", "")),
      list(table = "stages", uid = u_s2, field = "id", vals = c("s2", "s2_alt", "", "s1", "s2"))
    )

    current_slot <- 1L
    for (step_i in seq_len(180L)) {
      roll <- sample.int(10L, 1L)
      if (roll <= 6L) {
        slot <- edit_pool[[current_slot]]
        val <- sample(slot$vals, 1L)
        ev_cur <- list(
          seq = seq_n,
          type = "edit",
          data = list(table = slot$table, uid = slot$uid, field = slot$field, value = val),
          rev = s$rev
        )
      } else if (roll <= 8L) {
        current_slot <- sample.int(length(edit_pool), 1L)
        slot <- edit_pool[[current_slot]]
        val <- sample(slot$vals, 1L)
        ev_cur <- list(
          seq = seq_n,
          type = "edit",
          data = list(table = slot$table, uid = slot$uid, field = slot$field, value = val),
          rev = s$rev
        )
      } else if (roll == 9L) {
        opt_val <- sample(c("Seeded", "Renamed", "Final"), 1L)
        ev_cur <- list(seq = seq_n, type = "option", data = list(name = "title", value = opt_val), rev = s$rev)
      } else {
        ev_cur <- list(seq = seq_n, type = "undo", data = structure(list(), names = character()), rev = s$rev)
      }
      seq_n <- seq_n + 1L
      s <- studio_step(s, ev_cur)$state
      expect_identical(studio_journal_replay(s$base, s$journal), s$doc)
    }

    while (studio_journal_can_undo(s$journal)) {
      s <- studio_step(
        s,
        list(seq = seq_n, type = "undo", data = structure(list(), names = character()), rev = s$rev)
      )$state
      seq_n <- seq_n + 1L
      expect_identical(studio_journal_replay(s$base, s$journal), s$doc)
    }
    expect_identical(s$doc, s$base)
  })
})
