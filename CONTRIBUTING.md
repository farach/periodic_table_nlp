# Contributing

This project teaches natural language processing to people who may be new to R,
programming, or both. A lesson succeeds when a reader understands the idea and
knows when it is useful.

Read [EDITORIAL_GUIDE.md](EDITORIAL_GUIDE.md) before drafting and
[RESEARCH_STANDARDS.md](RESEARCH_STANDARDS.md) before making technical claims.
Use [MODERNIZATION_NOTES.md](MODERNIZATION_NOTES.md) to identify tasks that
need current transformer, retrieval, inference, or evaluation research.

The canonical task map is `data/periodic_table.csv`. An available tile needs an
HTML lesson path and a review date. `_quarto.yml` must include every lesson
directory; adding a file alone does not publish it. `data/lesson_reviews.csv`
is the publishing manifest and must remain in sorted lesson-path order.

## Write for the reader

- Begin with a problem the reader can recognize.
- Use everyday language before introducing a technical term.
- Define each technical term close to its first use.
- Keep examples small enough to check by eye.
- Explain what the code does and what its output means.
- Put optional implementation detail after the main explanation.
- End with a short list of ideas the reader should remember.
- Give the lesson a restrained narrative arc with a person, a need, a
  complication, and a useful resolution.

Public pages must stand on their own. Draft history belongs in Git, not in a
lesson. Do not refer to earlier drafts, previous versions, rewrites, or what a
chapter used to say.

## Review writing in multiple rounds

Automated classifiers cannot prove that a person or a machine wrote a passage.
This project checks for visible writing habits and residue instead.

1. Run `Rscript scripts/check-prose.R` for machine residue and common style
   patterns.
2. Run `Rscript scripts/check-repetition.R`. It checks exact repeated sentences
   and repeated four-word openings; it does not detect a repeated paragraph
   shape or argument.
3. Read the lesson aloud and remove stiff phrasing, repeated structures, and
   unnecessary setup.
4. Ask an independent editor to challenge the voice, narrative, and clarity.
5. Run a separate skeptical review of every factual claim and source.
6. Proofread the final rendered page without editing while reading.

Record every round in the pull request checklist. A tool passing is not a
substitute for editorial judgment.

## Run every example

Every published code chunk must have output produced by a real execution.

1. Keep code evaluation enabled and caching disabled.
2. Use deterministic inputs. Set a seed before any random operation.
   Record the RNG kind and software version when a generated artifact depends
   on them.
3. Add an assertion for each important expected result.
4. Render the entire site after changing code or package versions.
5. Treat errors, unexpected output, and unexplained warnings as publishing
   blockers.
6. Run command-line snippets exactly as written before publishing them.

## Write code in the tidyverse style

Lesson code uses the tidyverse: `readr` to read files, `tibble` to build
tables, `dplyr` to reshape them, `tidyr` to pivot, `purrr` to iterate, and
`stringr` for strings. Use the native pipe `|>`.

Follow the [tidyverse style guide](https://style.tidyverse.org/). Before
committing, run:

```powershell
Rscript scripts/check-r-style.R
```

That command uses `styler` in dry-run mode and fails when any lesson would be
changed. In RStudio, use the **Style active file** add-in or run
`styler::style_file("path/to/lesson.qmd")` to apply the same rules. Review the
diff afterwards; formatting should never change what the code computes.

Use the standard text packages where they are the natural tool rather than
hand-rolling equivalents: `tidytext::unnest_tokens()` to go from documents to
tokens, `quanteda` where a corpus or document-feature matrix reads more
clearly, and `ggplot2` for a chart that earns its place.

- Load packages by name in a visible chunk near the top of the lesson and
  assert that they attached. Do not use `library(tidyverse)`; naming each
  package shows the reader which one does which job.
- Give `readr::read_csv()` an explicit `col_types = cols(...)` and a deliberate
  `na =`. Column types are a teaching point, so never rely on type guessing.
- Keep base R where it is the subject of the lesson or has no tidyverse
  equivalent, such as `charToRaw()`, `Encoding()`, `iconv()`, and matrix work
  handed to another package.
- `stringr` uses the ICU regular expression engine. Base R uses TRE, or PCRE2
  with `perl = TRUE`. When a lesson explains how a pattern behaves, say which
  engine produced that behaviour and confirm it by running the code.
- Keep one row per source record through extraction, with the source identifier
  and original text attached. Use a list-column when one record can produce
  several matches. Flatten or collapse records only when the question truly
  asks for a corpus-wide result, and give that operation a name such as
  `collect_unique_order_ids()` that makes the loss of row boundaries explicit.
- A row position from `seq_along()` is a display number, not a durable ID.
  Preserve identifiers supplied by the source. Name first-match columns
  `first_date` or `first_email` when another match could exist.
- For model comparisons, create the final test split first. Compare and tune
  candidates only inside the training data, using grouped folds when several
  rows come from one source document. Open the final test set once, after the
  candidate and settings are fixed.
- Label candidate selection, final testing, and robustness resampling as
  different operations. A repeated holdout is not another untouched test set.
  Keep the candidate set small enough that each model adds a distinct teaching
  point.
- Monitoring code must reuse the fitted preprocessing choices, including the
  same tokenizer, stop-word source, and vocabulary definition.
- While editing, run one lesson at a time with
  `Rscript scripts/run-lesson.R <path>`. It executes every chunk in order and
  fails on any warning. The full render remains the gate before publishing.

## Set up spaCy once

Some lessons use spaCy through the spacyr package. spaCy is a Python library,
so it lives outside `renv.lock` and has to be installed separately:

```bash
python -m venv .venv-spacy
.venv-spacy/bin/python -m pip install -r requirements-spacy.txt
```

On Windows the second path is `.venv-spacy/Scripts/python`. Versions are
pinned, and both spaCy and the English pipeline are MIT licensed.

Before the first render, restore the R environment as well:

```powershell
Remove-Item Env:LC_CTYPE -ErrorAction SilentlyContinue
$env:RENV_CONFIG_SANDBOX_ENABLED = "FALSE"
Rscript -e "renv::restore()"
```

In a lesson, the entire setup is:

```r
library(spacyr)
source("R/use-spacy.R")
pipeline <- use_project_spacy()
```

The helper finds that environment, quiets the library's startup output, and
stops with instructions if the environment is missing. Nothing is downloaded
during a render. Call `spacy_finalize()` when the lesson is done with it.

The project-level Quarto settings execute every R chunk and stop on errors. The
GitHub Actions workflow restores the locked R environment and renders every
page on each pull request.

## Make the page accessible

- Use headings in a logical order.
- Give informative images meaningful alt text.
- Introduce tables in the surrounding text and use clear column names.
- Do not rely on color alone to communicate meaning.
- Use descriptive link text instead of "click here."
- Check keyboard navigation, focus visibility, and the page at 200% zoom.
- Run `npm run test:a11y` after rendering the site.
- Test with a real screen reader before public release; an automated scan does
  not reproduce a person's experience.
- Keep automated accessibility, manual accessibility, narrative review,
  adversarial review, and human approval as separate status fields.

## Check factual claims

Use the evidence hierarchy and claim labels in
[RESEARCH_STANDARDS.md](RESEARCH_STANDARDS.md). Link to primary research or
official documentation in a final "Sources" section, but explain the fact in
the lesson rather than expecting readers to interpret the source themselves.

For fast-moving topics, record when the research was checked. Separate
established knowledge, current practice, emerging methods, and speculation.
Search for evidence that contradicts the lesson before publishing it.

State the language and scope of any language-dependent claim. For this
English-language curriculum, use the BCP 47 tag `en` and do not imply that a
result transfers to other languages, scripts, regions, or domains without
evidence.

## Preserve data and model provenance

- Do not call package teaching fixtures authenticated extracts unless upstream
  identifiers or a source digest establish that status.
- Do not call reference labels ground truth.
- Do not describe model scores as calibrated probabilities without evidence.
- Account for errors, abstentions, and conflicts across every weak-label row.
- Keep live API and model calls out of the render path; use dated fixtures or
  credential-free package helpers.
- Treat models under `data/treebank/` as deliberately small teaching models.
  Do not present comparisons with released pipelines as fair contests.

## Keep project invariants intact

- Every R chunk in a lesson is covered by `stopifnot()`, either inside the chunk
  or in an `#| include: false` verification chunk placed directly after it.
  Prefer the second form. Assertions are a build guarantee, not reading matter,
  and they were once 18 percent of the visible code on the site, sitting between
  each computation and the table it produced. Moving them removed 3,613 lines
  from the reader's view without weakening a single check: the hidden chunk runs
  in order, sees the same objects, and still stops the render.
  An assertion nested inside a loop or a function body stays where it is, since
  hoisting it out of scope breaks it.
  Hidden setup chunks count as source chunks even when they do not produce a
  rendered cell.
- `R/workforce-codebook.R` is the canonical annotation instrument for tasks
  8-13. Keep its foundryR hash on reference and crowd-annotation rows.
- Preserve the 22 job-page details and six flyer transcript lines in
  `data/workforce/workforce_sentences.csv` verbatim. Do not add inferred wording
  to `text`.
- Rebuild the flyer only with `data-raw/create-training-flyer.R`; its image and
  transcript hashes belong in `training-flyer-metadata.csv`.
- Treebank excerpts and locally trained models are committed because rebuilding
  them takes several minutes. Preserve their CC BY-SA 4.0 license and recorded
  fingerprints. Do not replace them with non-commercial pretrained UDPipe
  models.
- Mark model files as binary. A line-ending or byte change invalidates the
  fingerprint in `data/treebank/treebank-metadata.csv`.
- Pass an explicit temporary `model_path` to `tokenizers.bpe::bpe()`. Count
  unknown pieces from `bpe_encode(type = "ids")`; the `subwords` display
  reconstructs surface text and can hide unknown IDs.
- Keep `data/openlibrary-nlp-search.json` as a dated fixture. Rendering must not
  contact Open Library or any other live service.
- The R `tesseract` package does not install the native OCR engine or language
  data. `cld3` also needs protobuf on Linux. Keep those native dependencies in
  CI. Hunspell is different: its English dictionaries are bundled with the R
  package.
- Planned map tiles remain static `div` elements. Do not add button semantics,
  `aria-disabled`, or click handlers. Stage and status must never depend on
  color alone.

## Review before publishing

- [ ] A first-time reader can explain why the lesson matters.
- [ ] The narrative helps memory without inventing drama or evidence.
- [ ] Technical terms are defined in plain language.
- [ ] Every code chunk has been executed.
- [ ] Important outputs have explicit assertions.
- [ ] The full site renders without an error.
- [ ] Links, headings, tables, and image descriptions have been checked.
- [ ] The page contains no drafting history or references to prior versions.
- [ ] All writing-review and research-review rounds are recorded.
- [ ] Manual accessibility and human approval are recorded independently from
      automated checks.
