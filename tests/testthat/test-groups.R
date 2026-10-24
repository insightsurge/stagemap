describe("sm_groups() and resolve_groups()", {
  it("stores normalised colours and labels, merging each vector by name", {
    map <- stagemap(data.frame(
      id = c("REQ-1", "REQ-2", "TST-1", "RES-1"),
      stage = c("Requirement", "Requirement", "Test", "Result"),
      group = c("Safety", "Usability", "Safety", NA)
    ))
    expect_identical(
      resolve_groups(map),
      data.frame(group = c("Safety", "Usability"), colour = c("#E69F00", "#56B4E9"), label = c("Safety", "Usability"))
    )
    changed <- map |>
      sm_groups(colours = c(Safety = "red"), labels = c(Safety = "Safety checks")) |>
      sm_groups(colours = c(Usability = "#abc8ff80"), labels = c(Usability = "Ease of use")) |>
      sm_groups(colours = c(Safety = "#abc"))
    expect_identical(
      changed$groups,
      list(
        colours = c(Safety = "#AABBCC", Usability = "#ABC8FF80"),
        labels = c(Safety = "Safety checks", Usability = "Ease of use")
      )
    )
    expect_identical(
      resolve_groups(changed),
      data.frame(
        group = c("Safety", "Usability"),
        colour = c("#AABBCC", "#ABC8FF80"),
        label = c("Safety checks", "Ease of use")
      )
    )
    expect_identical(sm_groups(changed), changed)
    expect_true(withVisible(sm_groups(map))$visible)
    expect_identical(sm_groups(map)$groups, list(colours = character(), labels = character()))
    expect_identical(format(map)[3], "Groups (2): Safety, Usability")
    expect_identical(resolve_groups(sm_groups(map, colours = c(Safety = "red")))$colour, c("#FF0000", "#E69F00"))
    expect_error(sm_groups(map, labels = c(Safety = "")), "labels", class = "stagemap_error")
    expect_error(sm_groups(map, labels = c(Safety = " \t\n")), "labels", class = "stagemap_error")
    expect_identical(resolve_groups(sm_groups(map, labels = c(Safety = " Safety ")))$label, c(" Safety ", "Usability"))
  })

  it("cycles the palette over groups without a set colour", {
    map <- stagemap(data.frame(id = as.character(1:10), stage = "S", group = letters[1:10]))
    expect_identical(
      resolve_groups(map)$colour,
      c("#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7", "#999999", "#E69F00", "#56B4E9")
    )
    plain <- stagemap(data.frame(id = "a", stage = "S"))
    empty <- data.frame(group = character(), colour = character(), label = character())
    expect_identical(resolve_groups(plain), empty)
    expect_identical(resolve_groups(stagemap(data.frame(id = "a", stage = "S", group = NA))), empty)
    expect_error(sm_groups(plain), "no.*group.*column", class = "stagemap_error")
  })

  it("warns about unused keys while retaining them", {
    map <- stagemap(data.frame(id = "a", stage = "S", group = "g"))
    expect_warning(
      changed <- sm_groups(map, colours = c(other = "red"), labels = c(other = "Other")),
      "other",
      class = "stagemap_warning_unused"
    )
    expect_identical(changed$groups$colours, c(other = "#FF0000"))
    expect_identical(changed$groups$labels, c(other = "Other"))
    expect_identical(resolve_groups(changed)$group, "g")
  })

  it("rejects bad maps, vectors, names and colours", {
    map <- stagemap(data.frame(id = "a", stage = "S", group = "g"))
    expect_error(sm_groups(NULL), "map", class = "stagemap_error")
    expect_error(resolve_groups(NULL), "map")
    for (bad in list(1, NA_character_, "red", c(g = "red", g = "blue"), structure("red", names = ""), c(" " = "red"))) {
      expect_error(sm_groups(map, colours = bad), "colours", class = "stagemap_error")
      expect_error(sm_groups(map, labels = bad), "labels", class = "stagemap_error")
    }
    expect_error(sm_groups(map, colours = c(g = "")), "colours", class = "stagemap_error")
    expect_error(sm_groups(map, colours = c(g = "invalid-colour")), "colours.*invalid-colour", class = "stagemap_error")
    expect_error(sm_groups(map, colours = c(g = "from")), "colours.*from", class = "stagemap_error")
  })
})
