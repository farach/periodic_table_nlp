# Follow-ups

**Status on 2026-09-24:** all 81 tiles have lessons. Lessons 69 to 81 arrived in
pull request #19. Every automated gate passes on Windows and on Linux CI. This
file lists what is still open, so the next session can start here.

## Pending for every lesson

- **Manual accessibility review.** Test with a screen reader, at 200 percent
  zoom, and with real forced colours. The automated axe, 320-pixel and caption
  checks pass, but they do not replace this review. `manual_accessibility` in
  `data/lesson_reviews.csv` stays `pending` until a person has done it.
- **Human approval.** `human_approval` is `pending` for every lesson. Only the
  owner changes it.

## Should-fix items left open in lessons 69 to 81

Each item has a suggested fix. The description of pull request #19 lists them
with their review IDs.

- **70:** "the page does not depend on literal wording" overstates, because the
  reason check can stop the build if the answer's wording changes. Suggested:
  "Exact generated text can differ across machines, so every sentence that
  reports a model result is computed from this render."
- **71:** the program-name screen shows TRUE on `request_program` rows by
  construction. Show "not applicable" on those rows, or write the branch as
  TRUE with a comment.
- **73:** "checks their recorded fingerprints" describes a comparison the page
  does not show. Add the recorded fingerprint and a match column, as lesson 78
  does.
- **74:** most of the shorthand in the builder-checks table is unexplained. The
  suggested gloss is in the pull request description.
- **74 builder:** a check-only mode run without its file argument runs the full
  build instead of checking. `DATA_SOURCES.md` says so, and the builder
  follow-ups below include the fix.
- **75:** `identical(nrow(case_results), 9L)` cannot fail at render. Drop it, or
  tie it to the number of `setInputs()` calls.
- **77:** the sentence "splits punctuation away from words" sits next to the
  `america's` example. Suggested: "...splits punctuation away from words,
  except an apostrophe inside a word."
- **81:** the heading "Check seed dependence without reading coordinates"
  contradicts the sentence that compares coordinates. Suggested: "...and checks
  only whether their coordinates are identical, without printing them."
- **81:** `all(edge_set == sort(edge_set))` cannot fail. Delete it.

The optional items are listed in the pull request description. They are small
wording, density and explanation points.

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

Any change to the builder or the collection changes lesson 74's results.
Follow the order the lesson depends on:

1. The builder's checks pass.
2. The collection and its fingerprints are committed.
3. Lesson 74 runs once on the committed collection.
4. Only then are the lesson's hidden result checks updated.

`--negative-controls` and the `git show` route in `DATA_SOURCES.md` read
commits `0a5a5af9`, `a3478085` and `49a9b67a`. Keep them reachable from `main`,
so do not rewrite that history.

## Platform differences to expect

These values differ between Windows and Linux. Each page computes them inline,
so each render states its own value:

- **Lesson 71:** some generated replies are worded differently.
- **Lesson 77:** the letters-only filter drops 369 tokens on Windows and 367 on
  Linux, because of the platform's ICU word-break build.
- **Lesson 78:** the t-SNE neighbour percentages change slightly.

Do not pin these values in a hidden check.
