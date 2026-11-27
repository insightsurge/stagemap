# Start templates for the studio: example and blank.

describe("studio_template()", {
  it("builds the example map, opens with one calc_does fault, and offers calc_dose", {
    tpl <- studio_template("example")
    expect_s3_class(tpl$map, "stagemap_widget")
    expect_identical(tpl$tour, "example")

    doc <- studio_doc(map_parts(tpl$map))
    expect_true(studio_build(doc)$ok)

    opened <- studio_doc_apply(doc, tpl$then)
    expect_false(studio_build(opened)$ok)
    faults <- studio_faults(opened)
    expect_identical(nrow(faults), 1L)
    expect_identical(faults$table, "links")
    expect_identical(faults$field, "to")
    expect_identical(faults$value, "calc_does")

    fixes <- studio_fixes(opened, faults)
    expect_true("use" %in% names(fixes))
    expect_identical(fixes$use$label, "Use \"calc_dose\"")
    fixed <- studio_doc_apply(opened, fixes$use$ops)
    expect_true(studio_build(fixed)$ok)
    expect_identical(nrow(studio_faults(fixed)), 0L)
  })

  it("builds the blank template with one card, one stage and one lane", {
    tpl <- studio_template("blank")
    expect_s3_class(tpl$map, "stagemap_widget")
    expect_null(tpl$tour)
    expect_length(tpl$then, 0L)
    tables <- stage_map_tables(tpl$map)
    expect_identical(nrow(tables$cards), 1L)
    expect_identical(nrow(tables$stages), 1L)
    expect_identical(nrow(tables$lanes), 1L)
  })

  it("checks the template name", {
    expect_error(studio_template("unknown"), "name")
  })
})
