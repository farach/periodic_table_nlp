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

The topic map comes from Rob van Zoest's
[Periodic Table of NLP Tasks](https://www.innerdoc.com/periodic-table-of-nlp-tasks/).

## Teaching standard

Published lessons are written for first-time, non-technical readers. Every R
code chunk is executed during the site build, and important outputs are checked
in code. A failed example stops the build.

- [CONTRIBUTING.md](CONTRIBUTING.md) contains the publishing checklist.
- [EDITORIAL_GUIDE.md](EDITORIAL_GUIDE.md) defines the narrative and writing
  review process.
- [RESEARCH_STANDARDS.md](RESEARCH_STANDARDS.md) defines evidence, currency,
  and skeptical-review requirements.
- [MODERNIZATION_NOTES.md](MODERNIZATION_NOTES.md) maps transformer- and
  LLM-era changes onto future lessons.
- [accessibility.qmd](accessibility.qmd) explains the accessibility target,
  automated checks, and remaining manual tests.

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
