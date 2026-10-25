---
paths:
  - "inst/**/*.js"
  - "inst/**/*.css"
---

# The UI engine: JS and CSS

Labels as in `r-code.md` (CRAN / house). Reasons and sources: `docs/standards.md`.

- **CRAN:** source for everything: plain, readable, unminified JS and CSS in `inst/www/`; no build step, no bundler,
  no `node_modules`, no minified files without their source. Everything ships in the package: no CDN, no requests
  to other sites. **house:** no bundled fonts: text uses the host page's font (the Shiny app's bslib theme, the
  Quarto or pkgdown site), read from the page, like the colours.
- **house:** deterministic drawing: seeded RNG, no `Math.random()`, no clock-driven drawing; drawn in code in the
  theme's colours; no AI-generated images.
- **house:** maps are an htmlwidget around stagemap's own engine (#7). The engine has its own API (`mount`,
  `update`, `resize`, `destroy`) and never depends on htmlwidgets; the widget binding calls `mount`, `update` and
  `resize`. Markup comes from a `stagemap_html()` hook that ignores htmlwidgets' `style` argument, so sizes travel as
  `data-*` attributes. stagemap's code never uses `htmlwidgets::JS()` or `onRender()`, so htmlwidgets' runtime
  `eval()` runs only if a user adds them. Reasons: `docs/standards.md`, section 3.
- **house:** one global namespace (`window.stagemap`), guard against loading twice, state kept per element, several
  maps per page, no listeners left behind.
- **house:** in Shiny, the page shows when it is waiting for the server: the widget or control is busy
  (`aria-busy="true"`) from the user's action until the server's answer arrives, and the server stamps what it drew
  (a `data-*` attribute naming the request), so tests and code wait for "not busy and stamped with X". The server
  sends the stamp from `session$onFlushed(..., once = TRUE)`, so it never reaches the page before what it stands for;
  a slow button numbers each click and its output is stamped with that number. A busy button
  gets `aria-disabled="true"` and CSS, not `disabled`, which moves keyboard focus to the page. Style the children of
  Shiny's HTML outputs, not the output itself: it is `display: contents`, so its own CSS does nothing although
  `getComputedStyle()` reports it. After showing a panel that was hidden, call `Shiny.bindAll(panel)`: Shiny may miss
  the change and leave its outputs suspended. When an editor or panel opens, start its controls from the values the
  live widget already uses, not from values the server pushes in: a slow answer would overwrite what the visitor
  typed meanwhile. Copy-to-clipboard copies after the server's answer, not on the click.
- **house:** the engine is versioned with the package (`window.stagemap.version`, passed from R).
- **house:** configuration through `data-*` attributes or a `<script type="application/json">` block. No `eval`
  (except htmlwidgets' runtime, above), `new Function`, inline `<script>`, inline `style=` for layout or `javascript:`
  URLs (stagemap adds no inline script of its own; Shiny itself still uses some).
- **house:** panels follow Bootstrap's CSS variables (`--bs-body-color`, `--bs-body-bg`, `--bs-border-color`) by
  default; public colour hooks use the `--stagemap-*` prefix and win over them; private custom properties use
  `--_stagemap-*`. Follow the page for dark mode
  (`[data-bs-theme]`, then Quarto's
  `quarto-dark`/`quarto-light` body classes); with no signal, light. bslib stays in Suggests.
- **house (WCAG 2.2):** meaning never rests on colour alone (a link kind also has its dash or mark, a status also has
  its text or icon); nodes people can act on are keyboard-focusable with a name; `prefers-reduced-motion` is honoured
  in CSS and JS and R can switch animation off; no automatic animation longer than 5 s unless it can be paused;
  graphics colours keep 3:1 contrast in light and dark.
- **house:** ES2015+ for evergreen browsers (Chrome, Edge, Firefox, Safari); Biome formats and lints (`biome.json`,
  2 spaces, width 120, single quotes); the gate's `biome` step and CI run it.
- **house:** every new file here is listed in `inst/COPYRIGHTS` (see `bundled-files.md`).
- **house:** once the engine exists, record engine changes users notice in `NEWS.md`.
