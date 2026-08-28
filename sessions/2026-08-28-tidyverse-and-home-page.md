# Session notes, 2026-08-28 (later)

## What changed

Two requests from the site owner, and the review fallout from both.

### Tidyverse rewrite

All thirteen lessons and `index.qmd` moved from base R to `readr`, `dplyr`,
`tibble`, `tidyr`, `purrr` and `stringr`, using the native pipe. Four agents
worked in parallel on separate lesson batches, which produced measurable style
drift that a later review had to clean up.

Decisions worth remembering:

- No `library(tidyverse)`. Naming each package teaches which one does which
  job, and the meta-package would slow CI for no reader benefit.
- Every `read_csv()` carries an explicit `col_types` and a deliberate `na`.
  Column types are a teaching point in lesson 3, so guessing is not allowed
  anywhere.
- Base R stays where it is the subject of a lesson (`charToRaw`, `utf8ToInt`,
  `Encoding`, `iconv`, `nchar(type =)`) or where nothing equivalent exists
  (`adist`, matrix work feeding `irr`).
- `stringr` uses ICU, base R uses TRE or PCRE2 with `perl = TRUE`. Confirmed
  the difference is real (`\w+` on "café" gives "caf" under PCRE2 and "café"
  under ICU) but changes no current result. Lesson 2 already names the engine.

### Home page

Rewritten three times against a hostile reviewer, then restructured once more
after owner feedback.

The final shape: short opening, the task map, the "What this map is" caveat,
then "Why these lessons exist", then one housekeeping block.

The important reversal: an intermediate draft argued from ten cited studies
(PNAS, *Science*, EMNLP, NeurIPS, *Nature Machine Intelligence*, the EU AI
Act). The owner rejected that approach because every study described 2023-era
systems, and the failures they document may be solved by later systems. The
page now argues from reasoning that does not expire, and makes no claim that
would need a citation. Lessons still cite sources; the home page does not need
to, because it asserts nothing measurable.

## Defects the reviews caught

Worth reading before the next change, because several would have shipped.

1. **Thirteen chunks asserted nothing.** Each lesson gained a package chunk
   ending in `stopifnot(all(c(...) %in% loadedNamespaces()))`. `library()`
   already errors on a missing package, so that is true by construction.
   `scripts/check-lessons.R` only greps for the text `stopifnot(`, so all
   thirteen passed the gate. The build cannot detect this class of problem.
2. **An assertion was silently disabled.** Lesson 11 checked for blank reviewer
   rationales with `nzchar()`. Switching from `read.csv(colClasses =
   "character")` to `read_csv()` turned an empty field from `""` into `NA`, and
   `nzchar(NA)` is `TRUE`. Audit every assertion that depends on a value being
   an empty string whenever a loader changes.
3. **A truncation guard vanished.** `readLines(warn = TRUE)` aborted the render
   under `options(warn = 2)` on a file with no final newline. `read_lines()` is
   silent. Explicit line-count assertions replace it.
4. **Lesson 4's token counter changed its answer.** `str_squish()` plus an ICU
   split reported one token for an empty document and three for a string with a
   non-breaking space. That function is the lesson's definition of a token.
5. **Package attach notices rendered onto thirteen public pages.** Quarto does
   not honour `message` under `execute:`. It has to go under `knitr:
   opts_chunk:`. This had been leaking and no gate caught it.
6. **Prose ran at about 150 characters per line** on the home page, because the
   `max-width` rule only matched direct children of `main.content` and Quarto
   wraps sections in `<section>`. Fixed with a shared `38rem` measure.

## Reviewer notes worth keeping

The home page reviewer made two structural criticisms that shaped the result:

- Citing a paper for the half that supports you and dropping the half that does
  not is straw-manning by omission. The Dell'Acqua paper was being used to argue
  a reader could learn to see the model's competence boundary, when the paper's
  finding is that the consultants in it could not.
- An argument built so no evidence can touch it is not robust, it is
  uninformative. The current page states this openly: it names which parts of
  the job do not disappear, and says plainly that it cannot tell you how large
  each one is.

## State

PR #3 merged to `main` as `c0943e3`. All gates green: 26 prose files, 15
rendered pages, 84 executed R chunks, periodic table and workforce data tests,
26 accessibility tests. No published number moved.
