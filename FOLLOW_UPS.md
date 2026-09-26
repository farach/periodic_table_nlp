# Follow-ups

**Status on 2026-09-25:** all 81 tiles have lessons, and the guide page
`using-language-models.qmd` covers model-assisted analysis. This session moved
table-formatting code out of the reader's view, gave every figure one design
system, redesigned the charts in lessons 75 to 81, clarified lessons 69 to 81,
and added a dated research pass on language models used as research
instruments. `sessions/2026-09-25-figures-and-model-assisted-analysis.md`
describes the work. This file lists what is still open, so the next session can
start here.

## Pending for every lesson

- **Manual accessibility review.** Test with a screen reader, at 200 percent
  zoom, and with real forced colours. The automated axe, 320-pixel and caption
  checks pass, but they do not replace this review. `manual_accessibility` in
  `data/lesson_reviews.csv` stays `pending` until a person has done it.
- **Human approval.** `human_approval` is `pending` for every lesson. Only the
  owner changes it.
- **Linux render of this branch.** Run the render workflow and read lessons 44,
  47, 77 to 81, and the guide from its artifact. The figures now draw with
  ragg and a bundled font, so their layout should match Windows closely, but
  this has not been seen on Linux yet.

## Resolved from pull request #19

K04 in lesson 70, K07 in lesson 71, K12 and K13 in lesson 73, K32 and K34 in lesson 74,
the row-count check in lesson 75, the apostrophe wording in lesson 77, and the
heading and the check that could not fail in lesson 81 are fixed. K03 and K05
in lesson 70 and K33 in lesson 74 no longer apply, because the sentence-building
helpers they describe now sit in hidden chunks. K20's four words for lesson 75
are in place.

## Still open from pull request #19

- **74 builder:** a check-only mode run without its file argument runs the full
  build instead of checking. `DATA_SOURCES.md` says so, and the builder
  follow-ups below include the fix.
- The remaining optional items in the pull request description, such as K11,
  K35, and K36, are small wording and disclosure points.

## Lesson 74 collection builder

`data-raw/build-riverton-review-collection.R` was frozen once lesson 74 had its
first run on the committed collection. A later pull request can:

- stop with a usage message on missing or unrecognized arguments;
- drop the review-process comment prefixes, such as `# N46-4:`, and the word
  "quarantined";
- fix the stale comment "Core and frame features exist only here";
- hash the monitoring stream before writing it;
- skip any frame whose words already begin the note, which would stop records
  such as "Please note: Please ...";
- give the two frame checks, CK-D1 and CK-D2, descriptive names.

Any change to the builder or the collection changes lesson 74's results and the
guide page's cached labels. Follow the order the lesson depends on:

1. The builder's checks pass.
2. The collection and its fingerprints are committed.
3. Lesson 74 runs once on the committed collection.
4. Only then are the lesson's hidden result checks updated.
5. The guide's labels are rebuilt with `data-raw/build-llm-review-labels.R`,
   and its hidden checks are updated from that run.

`--negative-controls` and the `git show` route in `DATA_SOURCES.md` read
commits `0a5a5af9`, `a3478085` and `49a9b67a`. Keep them reachable from `main`,
so do not rewrite that history.

## Guide page and its cached run

- `data-raw/build-llm-review-labels.R` labels all 240 records with the pinned
  local model. It is slow on machines without native PyTorch support. Rebuild
  it only when the prompt, the collection, or the model changes, and commit the
  labels and metadata together.
- The guide reruns eight saved answers during every render and reports how
  many match. A Linux render may report a different count from Windows; do not
  pin it in a hidden check.

## Longer chunks that stay visible

Lesson 71's state-update chunk and lesson 72's BM25, dense-vector, and fusion
chunks are still long, but they are the method each lesson teaches, so they
were left visible. A later pass could split each into smaller steps with prose
between them.

## Platform differences to expect

These values differ between Windows and Linux. Each page computes them inline,
so each render states its own value:

- **Lesson 71:** some generated replies are worded differently.
- **Lesson 77:** the letters-only filter drops 369 tokens on Windows and 367 on
  Linux, because of the platform's ICU word-break build.
- **Lesson 78:** the t-SNE neighbour percentages and panel counts change
  slightly.
- **Guide page:** the number of rerun answers that match the saved run.

Do not pin these values in a hidden check.

## Other open work in the repository

- **Pull request #9** ("Offer three ways into the map, and size it from its
  container", branch `guidance-routes`) is open from 2026-08-29. It conflicts
  with `main` in `index.qmd` and `periodic-table.css`, because the finished map
  dropped the planned-tile key. Rebase it or close it.
