# CLAUDE.md

## Project overview

Public teaching site for non-technical readers learning NLP through R. The
81-tile map is a mnemonic, not a scientific taxonomy.

## Commands

Run the complete local gate from the repository root:

```powershell
Remove-Item Env:LC_CTYPE -ErrorAction SilentlyContinue
$env:RENV_CONFIG_SANDBOX_ENABLED = "FALSE"
Rscript -e "renv::restore()"
npm ci
Rscript scripts/check-prose.R
quarto render
Rscript scripts/check-lessons.R
Rscript tests/test-periodic-table.R
Rscript tests/test-workforce-data.R
npm run test:a11y
```

The `LC_CTYPE` cleanup avoids a machine-level Windows warning being promoted
to an error. Lesson chunks intentionally set `options(warn = 2)`.

## Architecture

- `data/periodic_table.csv` is the canonical 81-item map. A linked tile needs
  `status=available`, an HTML path, and `last_reviewed`.
- `_quarto.yml` must list every lesson directory. Adding a page to disk is not
  enough.
- `data/lesson_reviews.csv` is the publishing manifest. File order must match
  the sorted lesson paths used by `scripts/check-lessons.R`.
- Review status fields use exact values such as `passed` and `pending`; do not
  put prose in a status column. `adversarial_rounds` holds the count.
- Every lesson R chunk contains `stopifnot()`. Hidden setup chunks count as
  source chunks but not rendered cells.
- `R/workforce-codebook.R` is the canonical annotation instrument for tasks
  8-13. Its foundryR hash is stored on every reference and crowd-annotation row.
- `data/workforce/workforce_sentences.csv` preserves 22 job-page details and
  six flyer lines verbatim. Do not add inferred wording to `text`.
- `data-raw/create-training-flyer.R` generates the image from the canonical
  six-line transcript. The image and transcript hashes live in
  `training-flyer-metadata.csv`.

## Code style

- Lesson code is tidyverse-first: `readr` to read, `tibble` to construct,
  `dplyr` to reshape, `tidyr` to pivot, `purrr` to iterate, `stringr` for
  strings. Use the native pipe `|>`; never `%>%`.
- Each lesson loads its packages in a visible chunk near the top and asserts
  `all(c(...) %in% loadedNamespaces())`. Do not use `library(tidyverse)`; the
  meta-package is not a dependency, and naming each package teaches which one
  does which job.
- `readr::read_csv()` always takes an explicit `col_types = cols(...)` and a
  deliberate `na =`. Type guessing is never acceptable in a published lesson.
- Keep base R where it is the subject or has no tidyverse equivalent:
  `charToRaw()`, `utf8ToInt()`, `Encoding()`, `iconv()`, `nchar(type =)`,
  `adist()`, and matrix math feeding `irr`.
- `stringr` uses the ICU regex engine, base R with `perl = TRUE` uses PCRE2,
  and base R without it uses TRE. Where a lesson teaches a pattern's
  behaviour, name the engine and verify the claim by running it.
- `scripts/run-lesson.R <path.qmd>` runs one lesson's chunks in order and
  fails on any warning. Use it while editing; `quarto render` is still the gate.

## Editorial patterns

- Lessons start with one human problem, investigate it, expose a limit, and
  resolve only what the evidence supports.
- Tasks 6-13 follow the fictional Riverton Workforce Lab. Keep the same IDs,
  source trail, and limits when extending that story.
- Public lessons never discuss drafting history.
- `scripts/check-prose.R` runs residue and style-pattern scans. It does not
  establish authorship.
- Narrative, adversarial, automated accessibility, manual accessibility, and
  human approval are separate manifest fields. Never convert one into another.
- The home page is reader-facing only. Contributor process belongs in
  `CONTRIBUTING.md`, `EDITORIAL_GUIDE.md`, and `RESEARCH_STANDARDS.md`.
- The task map is the first substantial thing on the home page. Framing and
  argument sit below it.
- The home page argues from reasoning that stays true, not from dated
  empirical findings. Capability studies age out of relevance quickly, so the
  page makes no claim that would need a citation. Lessons still cite sources;
  the home page does not need to because it asserts nothing measurable.

## Things to avoid

- No live API or model call in the render path. Use dated fixtures or
  credential-free package helpers.
- Do not call package teaching fixtures authenticated extracts unless upstream
  IDs or a source digest prove it.
- Do not call reference labels ground truth.
- Do not describe model scores as calibrated probabilities without evidence.
- Do not report only usable weak labels; account for errors, abstentions, and
  conflicts across every row.
- Do not add summary-number pills, gradients, floating cards, glossy shadows,
  hover lift, or decorative motion to the periodic table.
- Planned tiles are static `<div>` elements. Do not give them button semantics,
  `aria-disabled`, or click handlers.
- Color never carries stage or status by itself. Keep stage text and
  solid/dashed status cues.

## Accessibility

- `tests/accessibility.spec.mjs` scans every public page with axe-core and
  checks 320-pixel reflow, captions, keyboard links, focus return, forced
  colors, and reduced motion.
- Wide tables are wrapped at runtime by `accessibility-after-body.html`.
- Automated success does not replace NVDA, JAWS, VoiceOver, keyboard-only, or
  human zoom testing. Those remain pending until recorded otherwise.

## External dependencies

- onet2r, cmapr, huggingfaceR, and foundryR are GitHub dependencies pinned by
  SHA in `renv.lock`.
- Author-package examples must remain credential-free. foundryR codebooks and
  agreement helpers are local; huggingfaceR payload builders do not send data.
- Open Library content is a dated fixture. Rendering must not contact Open
  Library.
- O*NET-shaped material requires the attribution in `DATA_SOURCES.md`.
- renv pins the R tesseract package, not the native OCR engine or English
  language data. CI installs those system packages before `setup-renv`, and
  the OCR lesson reports the native version at run time.
