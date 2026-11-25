# The map in these tests: cards "a" and "b" in stage "s" and lane "l", each table a layer or a column can name.
describe("the join checks", {
  data_error <- function(code) expect_error(code, class = "stagemap_error_data")

  it("refuses a card whose stage or lane is not in its table, naming the ids and the fix", {
    error <- data_error(slim(cards = data.frame(id = c("a", "b"), label = "A", stage = c("s", "zz"), lane = "l")))
    expect_match(conditionMessage(error), "cards$stage", fixed = TRUE)
    expect_match(conditionMessage(error), "\"zz\"", fixed = TRUE)
    expect_match(conditionMessage(error), "stages$id", fixed = TRUE)
    error <- data_error(slim(cards = data.frame(id = "a", label = "A", stage = "s", lane = "nowhere")))
    expect_match(conditionMessage(error), "lanes$id", fixed = TRUE)
    expect_match(conditionMessage(error), "\"nowhere\"", fixed = TRUE)
  })

  it("names stage_map() as the function the user called", {
    cards <- data.frame(id = "a", label = "A", stage = "zz", lane = "l")
    error <- expect_error(
      stage_map(cards, data.frame(id = "s", label = "S"), data.frame(id = "l", label = "L")),
      class = "stagemap_error_data"
    )
    expect_identical(error$call[[1]], quote(stage_map))
  })

  it("lists every join problem in one error", {
    error <- data_error(slim(cards = data.frame(id = "a", label = "A", stage = "x", lane = "y"), target = "q"))
    for (path in c("cards$stage", "cards$lane", "target")) {
      expect_match(conditionMessage(error), path, fixed = TRUE)
    }
  })

  it("refuses a link whose from or to is not a card", {
    error <- data_error(add_links(small(), data.frame(from = c("a", "ghost"), to = c("b", "b"))))
    expect_match(conditionMessage(error), "links$from", fixed = TRUE)
    expect_match(conditionMessage(error), "\"ghost\"", fixed = TRUE)
    expect_match(conditionMessage(error), "cards$id", fixed = TRUE)
    expect_identical(error$call[[1]], quote(add_links))
    error <- data_error(add_links(small(), data.frame(from = "a", to = "ghost")))
    expect_match(conditionMessage(error), "links$to", fixed = TRUE)
    expect_no_error(add_links(small(), data.frame(from = "a", to = "b")))
  })

  it("compares ids as text: 7 and \"7\" are the same card, but \"a\" and \"A\" are not", {
    map <- slim(cards = data.frame(id = c(7, 8), label = "A", stage = "s", lane = "l"))
    expect_no_error(add_links(map, data.frame(from = "7", to = 8)))
    data_error(add_links(small(), data.frame(from = "A", to = "b")))
    data_error(add_links(small(), data.frame(from = " a", to = "b")))
  })

  it("reports an empty string as a bad id in a single-id column, but ignores empty pieces of a variants list", {
    error <- data_error(slim(cards = data.frame(id = "a", label = "A", stage = "", lane = "l")))
    expect_match(conditionMessage(error), "cards$stage", fixed = TRUE)
    expect_match(conditionMessage(error), "\"\"", fixed = TRUE)
    data_error(add_links(small(), data.frame(from = "", to = "a")))
    expect_no_error(
      add_variants(
        slim(cards = data.frame(id = "a", label = "A", stage = "s", lane = "l", variants = "v1, ,")),
        data.frame(id = "v1", label = "V1")
      )
    )
    expect_error(column_ids("a", NA), "split")
  })

  it("refuses a link kind that the kinds lack, and a kind given with no kinds", {
    kinds <- data.frame(id = "k", label = "K")
    error <- data_error(add_links(small(), data.frame(from = "a", to = "b", kind = "zz"), kinds = kinds))
    expect_match(conditionMessage(error), "links$kind", fixed = TRUE)
    expect_match(conditionMessage(error), "kinds$id", fixed = TRUE)
    error <- data_error(add_links(small(), data.frame(from = "a", to = "b", kind = "k")))
    expect_match(conditionMessage(error), "no `kinds` were given", fixed = TRUE)
    expect_match(conditionMessage(error), "add_links()", fixed = TRUE)
    expect_no_error(add_links(small(), data.frame(from = "a", to = "b", kind = c("k")), kinds = kinds))
    expect_no_error(add_links(small(), data.frame(from = "a", to = "b", kind = NA_character_)))
  })

  it("refuses a card's zone that the zones lack, whichever comes first, and leaves a map with no zones alone", {
    cards <- data.frame(id = "a", label = "A", stage = "s", lane = "l", zone = c("zz"))
    zones <- data.frame(id = "z", label = "Z")
    error <- data_error(add_zones(slim(cards = cards), zones))
    expect_match(conditionMessage(error), "cards$zone", fixed = TRUE)
    expect_match(conditionMessage(error), "\"zz\"", fixed = TRUE)
    expect_match(conditionMessage(error), "zones$id", fixed = TRUE)
    expect_no_error(slim(cards = cards))
    expect_no_error(add_zones(slim(cards = transform(cards, zone = "z")), zones))
  })

  it("refuses the variants of a card or a link that the variants lack, cut at commas and trimmed", {
    cards <- data.frame(id = c("a", "b"), label = "A", stage = "s", lane = "l", variants = c("v1,v2", "v1, zz"))
    variants <- data.frame(id = c("v1", "v2"), label = c("V1", "V2"))
    error <- data_error(add_variants(slim(cards = cards), variants))
    expect_match(conditionMessage(error), "cards$variants", fixed = TRUE)
    expect_match(conditionMessage(error), "\"zz\"", fixed = TRUE)
    expect_no_match(conditionMessage(error), "v1", fixed = TRUE)
    ok <- transform(cards, variants = c("v1,v2", " v2 , v1,"))
    expect_no_error(add_variants(slim(cards = ok), variants))
    links <- data.frame(from = "a", to = "b", variants = "v1, nope")
    error <- data_error(add_links(add_variants(small(), variants), links))
    expect_match(conditionMessage(error), "links$variants", fixed = TRUE)
    expect_no_error(add_links(small(), links))
  })

  it("refuses a link's step that the steps lack, in either order, and leaves a map with no steps alone", {
    steps <- data.frame(id = "p", label = "P")
    links <- data.frame(from = "a", to = "b", step = "zz")
    error <- data_error(add_links(add_steps(small(), steps), links))
    expect_match(conditionMessage(error), "links$step", fixed = TRUE)
    expect_match(conditionMessage(error), "steps$id", fixed = TRUE)
    error <- data_error(add_steps(add_links(small(), links), steps))
    expect_match(conditionMessage(error), "links$step", fixed = TRUE)
    expect_identical(error$call[[1]], quote(add_steps))
    expect_no_error(add_links(small(), links))
    expect_no_error(add_steps(add_links(small(), transform(links, step = "p")), steps))
  })

  it("refuses a step's stage that the map does not have", {
    steps <- data.frame(id = "p", label = "P", stage = c("zz"))
    error <- data_error(add_steps(small(), steps))
    expect_match(conditionMessage(error), "steps$stage", fixed = TRUE)
    expect_match(conditionMessage(error), "stages$id", fixed = TRUE)
    expect_no_error(add_steps(small(), transform(steps, stage = "s")))
  })

  it("refuses a target that is not a card, and a variant that is not a variant once variants arrive", {
    error <- data_error(slim(target = "zz"))
    expect_match(conditionMessage(error), "target", fixed = TRUE)
    expect_match(conditionMessage(error), "\"zz\"", fixed = TRUE)
    expect_no_error(slim(target = "a", layout = "levels"))
    variants <- data.frame(id = "v1", label = "V1")
    expect_no_error(slim(variant = "v1"))
    error <- data_error(add_variants(slim(variant = "zz"), variants))
    expect_match(conditionMessage(error), "variant", fixed = TRUE)
    expect_match(conditionMessage(error), "variants$id", fixed = TRUE)
    expect_no_error(add_variants(slim(variant = "v1"), variants))
  })
})

describe("the checks for an id given twice", {
  data_error <- function(code) expect_error(code, class = "stagemap_error_data")

  it("refuses a card, a stage or a lane given twice", {
    error <- data_error(slim(cards = data.frame(id = c("a", "a"), label = "A", stage = "s", lane = "l")))
    expect_match(conditionMessage(error), "cards$id", fixed = TRUE)
    expect_match(conditionMessage(error), "\"a\"", fixed = TRUE)
    error <- data_error(slim(stages = data.frame(id = c("s", "s"), label = "S")))
    expect_match(conditionMessage(error), "stages$id", fixed = TRUE)
    error <- data_error(slim(lanes = data.frame(id = c("l", "l"), label = "L")))
    expect_match(conditionMessage(error), "lanes$id", fixed = TRUE)
  })

  it("refuses a kind, a zone, a step or a variant given twice, naming the layer's function", {
    twice <- function(id) data.frame(id = c(id, id), label = "X")
    error <- data_error(add_links(small(), data.frame(from = "a", to = "b"), kinds = twice("k")))
    expect_match(conditionMessage(error), "kinds$id", fixed = TRUE)
    expect_identical(error$call[[1]], quote(add_links))
    expect_match(conditionMessage(data_error(add_zones(small(), twice("z")))), "zones$id", fixed = TRUE)
    expect_match(conditionMessage(data_error(add_steps(small(), twice("p")))), "steps$id", fixed = TRUE)
    expect_match(conditionMessage(data_error(add_variants(small(), twice("v")))), "variants$id", fixed = TRUE)
  })

  it("compares ids as text, so \"a\" and \"A\" are two ids and 7 given twice is one", {
    expect_no_error(slim(cards = data.frame(id = c("a", "A"), label = "A", stage = "s", lane = "l")))
    data_error(slim(cards = data.frame(id = c(7, 7), label = "A", stage = "s", lane = "l")))
  })

  it("lets an id be given once in two tables", {
    expect_no_error(slim(cards = data.frame(id = "s", label = "A", stage = "s", lane = "l")))
  })
})

describe("the check for empty and blank ids", {
  data_error <- function(code) expect_error(code, class = "stagemap_error_data")

  it("refuses an empty or blank id in the cards, stages and lanes tables, naming the table and the row", {
    error <- data_error(slim(cards = data.frame(id = c("a", ""), label = "A", stage = "s", lane = "l")))
    expect_match(conditionMessage(error), "cards$id[2]", fixed = TRUE)
    error <- data_error(slim(cards = data.frame(id = c("a", "  "), label = "A", stage = "s", lane = "l")))
    expect_match(conditionMessage(error), "cards$id[2]", fixed = TRUE)
    error <- data_error(slim(cards = data.frame(id = "a", label = "A", stage = "s", lane = ""), lanes = NULL))
    expect_match(conditionMessage(error), "cards$lane[1]", fixed = TRUE)
    error <- data_error(slim(cards = data.frame(id = "a", label = "A", stage = "", lane = "l"), stages = NULL))
    expect_match(conditionMessage(error), "cards$stage[1]", fixed = TRUE)
    error <- data_error(slim(stages = data.frame(id = c("s", " "), label = "S")))
    expect_match(conditionMessage(error), "stages$id[2]", fixed = TRUE)
    error <- data_error(slim(lanes = data.frame(id = c("l", ""), label = "L")))
    expect_match(conditionMessage(error), "lanes$id[2]", fixed = TRUE)
  })

  it("refuses an empty or blank id in the links, kinds, zones, variants and steps tables", {
    expect_match(
      conditionMessage(data_error(add_links(small(), data.frame(from = "a", to = " ")))),
      "links$to[1]",
      fixed = TRUE
    )
    expect_match(
      conditionMessage(data_error(add_links(small(), data.frame(from = "a", to = "b", kind = "")))),
      "links$kind[1]",
      fixed = TRUE
    )
    expect_match(
      conditionMessage(data_error(add_links(
        small(),
        data.frame(from = "a", to = "b"),
        kinds = data.frame(id = "", label = "K")
      ))),
      "kinds$id[1]",
      fixed = TRUE
    )
    expect_match(
      conditionMessage(data_error(add_zones(small(), data.frame(id = "", label = "Z")))),
      "zones$id[1]",
      fixed = TRUE
    )
    expect_match(
      conditionMessage(data_error(add_variants(small(), data.frame(id = " ", label = "V")))),
      "variants$id[1]",
      fixed = TRUE
    )
    expect_match(
      conditionMessage(data_error(add_steps(small(), data.frame(id = "", stage = "s", label = "Step")))),
      "steps$id[1]",
      fixed = TRUE
    )
  })

  it("still takes a blank cell as missing where the column is optional, and whole numbers of any size as ids", {
    expect_no_error(slim(cards = data.frame(id = "a", label = "A", stage = "s", lane = "l", zone = NA_character_)))
    cards <- data.frame(id = c(3e9, 1e12), label = c("A", "B"), stage = "s", lane = "l")
    map <- stage_map(cards) |> add_links(data.frame(from = 3e9, to = 1e12))
    expect_identical(data_of(map)$links, list(list(from = "3000000000", to = "1000000000000")))
  })
})
