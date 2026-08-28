# Periodic Table of NLP Tasks in R

This repository contains a plain-language teaching site about natural language
processing in R. The lessons use small examples, explain technical terms when
they appear, and show the output produced by the code. The home page rebuilds
the 81-task periodic table as an accessible map. Finished tiles open lessons;
planned tiles show where the project is going.

## Lessons

- [How computers store text](1_source_data_loading/01-bits-to-character-encoding.qmd)
- [Finding patterns in text](1_source_data_loading/02-manual-typewriting.qmd)
- [Loading a structured data file](1_source_data_loading/03-loading-structured-datafile.qmd)
- [Building a text corpus](1_source_data_loading/04-generating-a-corpus.qmd)
- [Loading data from an API](1_source_data_loading/05-loading-from-api.qmd)
- [Collecting text from a web page](1_source_data_loading/06-text-and-file-scraping.qmd)
- [Extracting text from an image](1_source_data_loading/07-text-extraction-and-ocr.qmd)
- [Turning reading decisions into labels](2_training_data_generation/08-manual-annotation.qmd)
- [Choosing which examples to label next](2_training_data_generation/09-annotation-with-active-learning.qmd)
- [Choosing an outside data provider](2_training_data_generation/10-training-data-providers.qmd)
- [Working with several annotators](2_training_data_generation/11-crowdsourcing-annotation.qmd)
- [Creating additional training examples](2_training_data_generation/12-textual-data-augmentation.qmd)
- [Labeling text with written rules](2_training_data_generation/13-rule-based-training-data.qmd)

The topic map comes from Rob van Zoest's
[Periodic Table of NLP Tasks](https://www.innerdoc.com/periodic-table-of-nlp-tasks/).

## Teaching standard

Published lessons are written for first-time, non-technical readers. Every R
code chunk is executed during the site build, and important outputs are checked
in code. A failed example stops the build.

The workforce lessons use
[onet2r](https://farach.github.io/onet2r/),
[cmapr](https://farach.github.io/cmapr/),
[huggingfaceR](https://farach.github.io/huggingfaceR/), and
[foundryR](https://farach.github.io/foundryR/), all authored or co-authored by
Alex Farach. Credential-free package fixtures and request builders keep the
published examples executable.

- [CONTRIBUTING.md](CONTRIBUTING.md) contains the publishing checklist.
- [EDITORIAL_GUIDE.md](EDITORIAL_GUIDE.md) defines the narrative and writing
  review process.
- [RESEARCH_STANDARDS.md](RESEARCH_STANDARDS.md) defines evidence, currency,
  and skeptical-review requirements.
- [MODERNIZATION_NOTES.md](MODERNIZATION_NOTES.md) maps transformer- and
  LLM-era changes onto future lessons.
- [accessibility.qmd](accessibility.qmd) explains the accessibility target,
  automated checks, and remaining manual tests.
- [DATA_SOURCES.md](DATA_SOURCES.md) records teaching fixtures, external
  sources, licenses, and required attribution.
- [PROJECT_STATUS.md](PROJECT_STATUS.md) records completed work, package use,
  quality gates, and current limits.
- [PINBOARD.md](PINBOARD.md) lists the next human reviews and lesson work.

## Build the site

Install R and Quarto, then run:

```powershell
Rscript -e "renv::restore()"
npm ci
npx playwright install chromium
Rscript scripts/check-prose.R
quarto render
Rscript scripts/check-lessons.R
Rscript tests/test-periodic-table.R
Rscript tests/test-workforce-data.R
npm run test:a11y
```

The automated accessibility suite uses axe-core and browser interaction tests
across every page. It does not replace manual testing with screen readers,
keyboard-only navigation, zoom, and forced-colors mode.

Use `quarto preview` for local development. Quarto writes the generated site
to `_site/`.

Package versions are recorded in `renv.lock`. The source documents and
configuration are tracked; generated site files and the local `renv` library
are not. The lockfile records R 4.6.1, and the render workflow pins Quarto
1.9.38.
