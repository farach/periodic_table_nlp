# Session notes, 2026-09-26 (map routes, map width, and the guide link)

## What changed

- **Ways into the map.** Pull request #9, opened on 2026-08-29, replaced the
  twelve group links under the map with three routes: reading the lessons as a
  course, solving one problem by stage, and looking one task up. `main` had
  moved on since then, so the branch was brought up to date. The only conflict
  was in `index.qmd`, and `main`'s `route_prompt` helper went with the line it
  built.
- **Map width.** The rule that fits all fifteen columns without scrolling is a
  container query at 118rem, not a 1200px viewport query. On this site and on
  workforcefutures.net the content column is 1,120 px wide at every desktop
  width, so the map now scrolls sideways with full-size tiles. Before, it
  squeezed them into 68 px columns with 9.7 px labels. The fitted layout no
  longer shrinks the tile text either, because a 118rem container already
  holds full-size tiles.
- **Tests.** The accessibility test that required the whole map to fit a
  1600 px window is replaced by two tests. The first checks that on a desktop
  the tiles stay at least 7.5rem wide, the page does not widen, and the map
  scrolls with its buttons. The second widens the map's container past 118rem
  and checks that the map then fits, the tile text keeps its size, and the
  buttons that can no longer do anything are hidden.
- **Guide link.** The "Start here" box above the map now links to
  `using-language-models.qmd`. Before, the home page linked to it only from a
  paragraph far below the map, and the lesson sidebar that lists it is not
  shown on the home page. `tests/test-periodic-table.R` checks that the link
  comes before the map.

## Decisions worth remembering

- The guide is not a tile. The table holds the 81 tasks, and the guide applies
  across many of them, so it is linked from the box readers see before the map.
- workforcefutures.net renders this site with an overlay profile,
  `quarto/_quarto-wf.yml` in farach/workforcefutures. Quarto adds the overlay's
  navbar entries to this project's rather than replacing them, so the live
  navbar shows both this project's GitHub link and the overlay's GitHub icon.
