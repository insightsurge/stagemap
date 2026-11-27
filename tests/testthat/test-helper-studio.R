# Argument checks and pure helpers for helper-studio.R.

describe("the studio fixtures", {
  it("builds studio_small() as full_map() with its title", {
    small <- studio_small()
    expect_s3_class(small, "stagemap_widget")
    tables <- stage_map_tables(small)
    expect_identical(nrow(tables$cards), 4L)
    expect_identical(sm_widget_data(small)$options$title, "A small piece of work")
    expect_error(studio_small(title = c("a", "b")), "title")
  })

  it("builds studio_large() with 120 cards in 8 stages and 5 lanes, 150 links of 2 kinds, 1 zone and 4 steps", {
    large <- studio_large()
    expect_s3_class(large, "stagemap_widget")
    tables <- stage_map_tables(large)
    expect_identical(tables$cards$id, sprintf("c%03d", 1:120))
    expect_identical(nrow(tables$stages), 8L)
    expect_identical(nrow(tables$lanes), 5L)
    expect_identical(nrow(tables$links), 150L)
    expect_identical(nrow(tables$kinds), 2L)
    expect_identical(nrow(tables$zones), 1L)
    expect_identical(nrow(tables$steps), 4L)
    expect_identical(nrow(tables$changes), 4L)
    cell_counts <- as.integer(table(tables$cards$stage, tables$cards$lane))
    expect_true(all(cell_counts == 3L))
  })

  it("builds studio_steps() with three steps on full_map()", {
    steps <- studio_steps()
    expect_s3_class(steps, "stagemap_widget")
    tables <- stage_map_tables(steps)
    expect_identical(nrow(tables$cards), 4L)
    expect_identical(nrow(tables$steps), 3L)
  })
})

describe("the studio helper argument checks", {
  fake_app <- structure(new.env(), class = c("AppDriver", "R6"))

  it("checks studio_driver() arguments before starting Chrome", {
    expect_error(studio_driver(fixture = "unknown"), "fixture")
    expect_error(studio_driver(copy_wait_ms = 0), "copy_wait_ms")
    expect_error(studio_driver(env = "not_env"), "env")
  })

  it("checks AppDriver arguments on every browser helper", {
    expect_error(studio_root("x"), "app")
    expect_error(studio_wait_drawn("x"), "app")
    expect_error(studio_wait_step("x"), "app")
    expect_error(studio_do("x", "1"), "app")
    expect_error(studio_do(fake_app, ""), "js")
    expect_error(studio_stamp("x"), "app")
    expect_error(studio_wait_map("x", 0L), "app")
    expect_error(studio_wait_map(fake_app, -1L), "since")
    expect_error(studio_section("x", "header"), "app")
    expect_error(studio_section(fake_app, "unknown"), "name")
    expect_error(studio_type("x", ".sms-title", "a"), "app")
    expect_error(studio_type(fake_app, "", "a"), "selector")
    expect_error(studio_type(fake_app, ".sms-title", 1), "text")
    expect_error(studio_title_sent("x", "a"), "app")
    expect_error(studio_title_sent(fake_app, 1), "text")
    expect_error(studio_press("x", "Tab"), "app")
    expect_error(studio_press(fake_app, ""), "key")
    expect_error(studio_press(fake_app, "z", modifiers = "bad"), "modifiers")
    expect_error(studio_press(fake_app, "Tab", code = ""), "code")
    expect_error(studio_press(fake_app, "Tab", key_code = -1), "key_code")
    expect_error(studio_click_real("x", ".sms"), "app")
    expect_error(studio_click_real(fake_app, ""), "selector")
    expect_error(studio_emulate("x", "width", 375), "app")
    expect_error(studio_emulate(fake_app, "", "reduce"), "feature")
    expect_error(studio_emulate(fake_app, "width", 0), "px")
    expect_error(studio_emulate(fake_app, "width", "375px"), "px")
    expect_error(studio_emulate(fake_app, "prefers-reduced-motion", 1), "value")
    expect_error(record_studio_events("x"), "app")
    expect_error(studio_sent("x"), "app")
    expect_error(hold_studio_events("x"), "app")
    expect_error(release_studio_events("x"), "app")
    expect_error(release_studio_events(fake_app, reverse = "no"), "reverse")
    expect_error(record_studio_wire("x"), "app")
    expect_error(drop_studio_connection("x"), "app")
    expect_error(reconnect_studio("x"), "app")
    expect_error(hold_studio_messages("x"), "app")
    expect_error(release_studio_messages("x"), "app")
    expect_error(release_studio_messages(fake_app, reverse = "no"), "reverse")
    expect_error(wait_studio_held("x", "events"), "app")
    expect_error(wait_studio_held(fake_app, "other"), "what")
    expect_error(wait_studio_held(fake_app, "events", n = 0L), "n")
    expect_error(studio_wait_held("x", 1L), "app")
    expect_error(studio_wait_held(fake_app, 0L), "seq")
    expect_error(stub_studio_clipboard("x"), "app")
    expect_error(stub_studio_clipboard(fake_app, item = "yes"), "item")
    expect_error(stub_studio_clipboard(fake_app, text = "yes"), "text")
    expect_error(stub_studio_clipboard(fake_app, exec = "yes"), "exec")
    expect_error(studio_copied("x"), "app")
    expect_error(studio_wait_copy("x"), "app")
    expect_error(studio_open_code("x"), "app")
    expect_error(studio_console("x"), "app")
    expect_error(expect_studio_clean("x"), "app")
    expect_error(expect_studio_clean(fake_app, closed = "yes"), "closed")
    expect_error(expect_studio_clean(fake_app, ignore = 1), "ignore")
    expect_error(studio_counts("x"), "app")
  })

  it("checks string builders and returns valid JS snippets", {
    expect_error(studio_type_js("", "a"), "selector")
    expect_error(studio_type_js(".sms-title", 1), "text")
    expect_error(studio_title_js(1), "text")
    expect_error(studio_click_js(""), "selector")
    expect_match(studio_type_js(".sms-title", "Hi"), "InputEvent", fixed = TRUE)
    expect_match(studio_click_js(".sms-done"), ".click()", fixed = TRUE)
    expect_match(studio_count_shim(), "__smsCounts", fixed = TRUE)
  })

  it("includes brace-containing error messages and app logs in studio_abort_draw()", {
    fake_logs_app <- structure(
      list2env(list(
        get_logs = function() {
          data.frame(location = "chromote", level = "error", message = "R error {detail}")
        }
      )),
      class = c("AppDriver", "R6")
    )
    err <- simpleError("timeout waiting for (() => { return false; })")
    expect_error(
      studio_abort_draw(fake_logs_app, err),
      "timeout waiting for \\(\\(\\) => \\{ return false; \\}\\).*R error \\{detail\\}"
    )
    expect_error(studio_abort_draw("x", err), "app")
    expect_error(studio_abort_draw(fake_logs_app, "err"), "e")
  })

  it("merges emulated media features per session without dropping earlier features", {
    key <- "test-session-merge"
    on.exit(rm(list = key, envir = studio_emulated_media), add = TRUE)
    first <- studio_merge_media(key, "forced-colors", "active")
    expect_identical(first, list(list(name = "forced-colors", value = "active")))
    second <- studio_merge_media(key, "prefers-reduced-motion", "reduce")
    expect_identical(
      second,
      list(
        list(name = "forced-colors", value = "active"),
        list(name = "prefers-reduced-motion", value = "reduce")
      )
    )
    updated <- studio_merge_media(key, "forced-colors", "none")
    expect_identical(
      updated,
      list(
        list(name = "forced-colors", value = "none"),
        list(name = "prefers-reduced-motion", value = "reduce")
      )
    )
    expect_error(studio_merge_media("", "a", "b"), "key")
    expect_error(studio_merge_media(key, "", "b"), "feature")
    expect_error(studio_merge_media(key, "a", 1), "value")
  })
})
