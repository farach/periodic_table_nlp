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
python -m venv .venv-spacy
.venv-spacy/Scripts/python -m pip install -r requirements-spacy.txt
npm ci
Rscript scripts/check-prose.R
Rscript scripts/check-repetition.R
Rscript scripts/check-resubstitution.R
Rscript scripts/check-data-fingerprints.R
quarto render
Rscript scripts/check-lessons.R
Rscript tests/test-periodic-table.R
Rscript tests/test-workforce-data.R
npm run test:a11y
```

The `LC_CTYPE` cleanup avoids a machine-level Windows warning being promoted
to an error. Lesson chunks intentionally set `options(warn = 2)`. The Python
environment is needed once; on macOS and Linux the pip path is
`.venv-spacy/bin/python`.

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
- `data/treebank/` holds a 500-sentence Universal Dependencies excerpt, a
  200-sentence held-out excerpt, and a tagger trained on the first of those.
  `data-raw/build-treebank-tagger.R` rebuilds them and takes several minutes,
  so the results are committed. All of it is CC BY-SA 4.0 and keeps that
  licence. The pre-trained UDPipe models are CC BY-SA-NC and must not be used.
- `.gitattributes` marks `*.udpipe` as binary. A model file whose bytes change
  would break the fingerprint recorded in `treebank-metadata.csv`.
- `scripts/check-lessons.R` and `tests/accessibility.spec.mjs` discover lessons
  from any `N_*` directory rather than a hard-coded list. Adding a stage does
  not require editing them.
- `R/inaugural-corpus.R` is the canonical corpus for tasks 43-62.
  `inaugural_paragraphs()` returns 1,377 paragraphs of at least 25 words from
  the 60 US presidential inaugural addresses quanteda ships, with
  `paragraph_id`, `speech_id`, `year`, `president`, `party`, and `era`. Every
  lesson in that range sources it so they agree on what a paragraph is. The
  speeches are US government works in the public domain. The Riverton corpus of
  28 sentences stays in place for tasks 1-42; it is too small to train or
  evaluate anything, which task 43 explains rather than hides.
- `data/inaugural/` holds the 60-model split study behind tasks 43, 44, 45 and
  51. `data-raw/build-inaugural-study.R` rebuilds it by hand. Lessons read the
  committed CSVs and fit at most one model live.
- `data/wordnet/` holds a 38-lemma extract of Open English WordNet 2024 for
  task 58, built by `data-raw/build-wordnet-extract.R`. The source is CC BY 4.0
  and the attribution is recorded in `wordnet-metadata.csv` and
  `DATA_SOURCES.md`. The 103 MB source XML is cached in `data-raw/.cache/`,
  which is gitignored; never download it at render time.
- `R/permutation-null.R` supplies the shared null for tasks 53-57. Those methods
  return a confident answer for any input, so a number from them means nothing
  until you know what the same procedure returns on shuffled data. Use
  `permutation_null()` rather than writing a bespoke null per lesson.
- `data/word2vec/` holds the pinned embedding for task 61, built by
  `data-raw/build-word2vec-model.R`. `word2vec::word2vec()` is not bitwise
  reproducible on this package version: across five fits with the same seed and
  `threads = 1L`, similarity values moved by about 0.03 but the neighbour
  ORDER changed every time. A lesson printing neighbour words would print
  different words on every render, so the model is trained once and committed.
  `.gitattributes` marks `*.bin` binary so the fingerprint stays valid.
- CI needs system libraries that are easy to forget: `libgsl-dev` for
  topicmodels, `libxml2-dev` for xml2, `libsodium-dev` for sodium via
  plumber and pins, and `libprotobuf-dev` plus `protobuf-compiler` for cld3.
  A package added to `renv.lock` is installed on CI whether or not a lesson
  renders it, so its system dependencies must be present.
- Run `renv::snapshot()` after installing anything. `dependencies.R` only tells
  renv what to look for; it does not update the lockfile. Twenty-four modeling
  packages were once added to `dependencies.R` without a snapshot, which would
  have failed CI at the first `renv::restore()`.
- `scripts/check-resubstitution.R` fails the build when a lesson hands the same
  data frame to `fit()` and to `predict()`. Two lessons shipped that mistake in
  a first draft and both produced numbers that looked like results. A lesson
  that shows resubstitution deliberately must mark the line
  `# resubstitution-ok: <reason>` and say so to the reader.
- `scripts/check-data-fingerprints.R` verifies every committed artifact against
  the hash its builder recorded. Two hash methods are in use and the difference
  matters: most builders record
  `digest(paste(read_lines(p), collapse = "\n"))`, which survives a CRLF
  checkout, while a few record `digest(file = p)`, which is only stable because
  `.gitattributes` pins `eol=lf`. The gate accepts either and reports which
  matched. Comparing the wrong method produces a convincing false alarm; an
  audit once reported twelve stale fingerprints that way and every one was
  wrong.

## Code style

- Lesson code is tidyverse-first: `readr` to read, `tibble` to construct,
  `dplyr` to reshape, `tidyr` to pivot, `purrr` to iterate, `stringr` for
  strings. Use the native pipe `|>`; never `%>%`.
- Use the standard text packages where they are the natural tool.
  `tidytext::unnest_tokens()` for going from documents to tokens, `quanteda`
  where a corpus or document-feature matrix reads better, `ggplot2` for a chart
  that earns its place.
- spaCy is reached through `spacyr`. Lessons call
  `source("R/use-spacy.R"); use_project_spacy()` and nothing else; the helper
  owns the Python path, the warning suppression, and the startup message. Call
  `spacy_finalize()` at the end. Python packages are pinned in
  `requirements-spacy.txt`, not in `renv.lock`.
- Two models with different provenance are in play. The udpipe models under
  `data/treebank/` were trained here on 500 sentences and are deliberately
  weak. The spaCy pipeline is a released model. Comparing them is a teaching
  device; never present it as a fair contest.
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
- `scripts/check-repetition.R` fails when more than four lessons share a
  four-word opening or more than three share an identical sentence. Many
  lessons written from one brief will drift into a template, and a reader who
  notices the template stops trusting the voice. The fictionality disclosure is
  exempt because a standard notice should read the same everywhere.
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
- `tokenizers.bpe::bpe()` writes its model to the working directory unless you
  pass `model_path`. Always pass an explicit `tempfile()`.
- `bpe_encode(type = "subwords")` rebuilds the surface text and therefore hides
  unknown pieces. Count unknowns from `type = "ids"` against the `<UNK>` id.
- Do not call package teaching fixtures authenticated extracts unless upstream
  IDs or a source digest prove it.
- Do not call reference labels ground truth.
- Do not describe model scores as calibrated probabilities without evidence.
- Do not report only usable weak labels; account for errors, abstentions, and
  conflicts across every row.
- Never score a model on the rows it was fitted to. `scripts/check-resubstitution.R`
  catches the obvious shape, but it is a textual heuristic and will miss a data
  frame aliased under a new name. A score that beats its own baseline by a
  surprising margin deserves suspicion before celebration.
- Do not slice a monitoring report by a variable the label is derived from.
  `era` comes from `year`, so a per-decade accuracy is a one-class recall and
  is near-perfect by construction.
- Do not present a score from author-written data as evidence about the world.
  It can show that code runs and that a metric responds to a change; it cannot
  show that a method works.
- Do not treat a difference between two results as real when it is smaller than
  the spread across replicates of the same experiment.
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
- `cld3` links against protobuf at run time, so CI also installs
  `libprotobuf-dev` and `protobuf-compiler`. Without them `renv::restore()`
  fails on Linux only, while Windows is fine. Cross-platform package
  requirements are the class of failure that local testing cannot catch.
- `hunspell` is different: it bundles `en_US` and `en_GB` inside the package,
  so the dictionary is pinned by the package version and does not depend on a
  system install. Verified in 3.0.6.
