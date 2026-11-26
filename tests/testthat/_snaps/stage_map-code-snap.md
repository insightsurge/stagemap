# stage_map_code() snapshots / writes the code of the full test map

    Code
      stage_map_code(full_map())
    Output
      library(stagemap)
      
      cards <- data.frame(
        id = c("a", "b", "c", "d"),
        label = c("Draft", "Review", "Publish", "Archive"),
        stage = c("write", "check", "check", "ship"),
        lane = c("docs", "docs", "code", "code"),
        status = c("done", "running", "waiting", "waiting"),
        zone = c(NA, "sign", "sign", NA),
        owner = c("Ann", "Bo", "Cy", "Di")
      )
      stages <- data.frame(
        id = c("write", "check", "ship"),
        label = c("Write", "Check", "Ship"),
        text = c("Where the words are made.", NA, NA)
      )
      lanes <- data.frame(id = c("docs", "code"), label = c("Docs", "Code"))
      links <- data.frame(
        from = c("a", "b", "c"),
        to = c("b", "c", "d"),
        kind = c("hand", "hand", NA)
      )
      kinds <- data.frame(id = "hand", label = "Handed over", line = "dashed")
      zones <- data.frame(
        id = "sign",
        label = "Needs sign-off",
        note = "Two people read it."
      )
      
      stage_map(cards, stages, lanes) |>
        add_links(links, kinds = kinds) |>
        add_zones(zones)

# stage_map_code() snapshots / writes the code of a map with every layer and every argument it can take

    Code
      stage_map_code(map)
    Output
      library(stagemap)
      
      cards <- data.frame(
        id = c("a", "b", "c", "d"),
        label = c("Draft", "Review", "Publish", "Archive"),
        stage = c("write", "check", "check", "ship"),
        lane = c("docs", "docs", "code", "code"),
        status = c("done", "running", "waiting", "waiting"),
        zone = c(NA, "sign", "sign", NA),
        owner = c("Ann", "Bo", "Cy", "Di")
      )
      stages <- data.frame(
        id = c("write", "check", "ship"),
        label = c("Write", "Check", "Ship"),
        text = c("Where the words are made.", NA, NA)
      )
      lanes <- data.frame(id = c("docs", "code"), label = c("Docs", "Code"))
      links <- data.frame(
        from = c("a", "b", "c"),
        to = c("b", "c", "d"),
        kind = c("hand", "hand", NA)
      )
      kinds <- data.frame(id = "hand", label = "Handed over", line = "dashed")
      zones <- data.frame(
        id = "sign",
        label = "Needs sign-off",
        note = "Two people read it."
      )
      steps <- data.frame(
        id = c("one", "two"),
        label = c("Start", "Move on"),
        stage = c("write", "check")
      )
      changes <- data.frame(step = "two", card = "a", stage = "check")
      variants <- data.frame(
        id = c("full", "docs"),
        label = c("Full release", "Docs only")
      )
      
      stage_map(
        cards,
        stages,
        lanes,
        title = "Every layer",
        variant = "full",
        statuses = c(done = "Pass"),
        cell_columns = 2,
        panels = FALSE,
        width = "100%",
        height = "480px"
      ) |>
        add_links(links, kinds = kinds) |>
        add_zones(zones) |>
        add_steps(steps, changes = changes, intro = "How the notes were written") |>
        add_variants(variants) |>
        stage_map_highlight(c("a", "b"), links = data.frame(from = "a", to = "b"))

