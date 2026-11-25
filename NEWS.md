# stagemap 0.0.0.9000

* The first R API (`stagemap()`, the `sm_*()` functions that set stages, lanes, kinds, groups, status and layout, `sm_svg()`, `sm_trace()`, `sm_orphans()` and `sm_missing()`) is replaced by a rebuild as an `htmlwidgets` widget with a bundled JavaScript engine; this is before the first release (#57).

* `stage_map()` draws cards placed in stages and lanes, with a legend, the details of a card, a side panel for a stage and the notes of zones; `panels = FALSE` hides those three. It takes `layout` from the layouts the engine lists and `dismiss = "no_outside"` by default. Columns the engine has no field for stay in the widget's R data and are not sent to it (#65).
* `add_links()` adds links between cards and the kinds of link; an empty data frame adds none (#65).
* `add_zones()` adds labelled outlines around groups of cards (#65).
* `add_steps()` adds steps to play through, with the changes each step makes to cards, and brings the step player (#65).
* `add_variants()` adds the variants a reader switches between (#65).
* `stage_map()` takes its table as `cards`, and `code_lines` marks the lines of a stage's or step's code; `map` is the first argument of `add_links()`, `add_zones()`, `add_steps()` and `add_variants()` (#67).
* `stages` and `lanes` can be left out: they are taken from the cards' `stage` and `lane` columns. `layout`, `motion`, `legend`, `cell_columns` and `bundle_links` have real defaults and no longer take `NULL`; a blank status label is refused (#67).
* Ids that do not join (a card's stage or lane, a link's cards, kind, step or variants, a card's zone, a step's stage, `target`, `variant`) and an id given twice in a table stop with an error of class `stagemap_error_data` that names the ids, when the second table arrives, in either order. The id checks of `changes` in `add_steps()` use the same class (#67).
* `add_variants()`, the `"levels"` and `"dates"` layouts, `target` and `variant` are marked experimental, with a badge in the help pages (#67).
* `stage_map_output()`, `render_stage_map()` and `stage_map_proxy()` put a map in a Shiny app. The server reads `input$<id>_selected` (the selected card ids), `input$<id>_pick` (the reader's last pick), `input$<id>_state` (what the map holds) and, experimental, `input$<id>_hovered` (#72).
* Six verbs change a map that is already drawn: `stage_map_select()`, `stage_map_highlight()`, and, experimental, `stage_map_show()`, `stage_map_hide()`, `stage_map_enable()` and `stage_map_disable()`. `stage_map_highlight()` also takes a `stage_map()` widget and lights cards from the first draw; `stage_map()` has no `highlight` argument (#72).
* A render function given a promise of a map draws it once the promise resolves (#72).
