# Periodic Table of NLP Tasks in R

This repository contains the source for a plain-language teaching site about
natural language processing in R. The canonical published site is
<https://workforcefutures.net/learn/nlp/>. The lessons use small examples,
explain technical terms when they appear, and show the output produced by the
code. The home page rebuilds the 81-task periodic table as an accessible map.
Finished tiles open lessons; planned tiles show where the project is going.

## Lessons

The canonical map and publishing manifest currently identify 42 available
lessons. This list is checked against `data/periodic_table.csv`.

- **Source data loading (1-7):**
  [encoding](1_source_data_loading/01-bits-to-character-encoding.qmd),
  [pattern matching](1_source_data_loading/02-manual-typewriting.qmd),
  [structured files](1_source_data_loading/03-loading-structured-datafile.qmd),
  [corpora](1_source_data_loading/04-generating-a-corpus.qmd),
  [APIs](1_source_data_loading/05-loading-from-api.qmd),
  [web scraping](1_source_data_loading/06-text-and-file-scraping.qmd), and
  [OCR](1_source_data_loading/07-text-extraction-and-ocr.qmd).
- **Training data generation (8-13):**
  [manual annotation](2_training_data_generation/08-manual-annotation.qmd),
  [active learning](2_training_data_generation/09-annotation-with-active-learning.qmd),
  [provider schemas](2_training_data_generation/10-training-data-providers.qmd),
  [multiple annotators](2_training_data_generation/11-crowdsourcing-annotation.qmd),
  [augmentation](2_training_data_generation/12-textual-data-augmentation.qmd), and
  [rule-based labels](2_training_data_generation/13-rule-based-training-data.qmd).
- **Word parsing (14-18):**
  [tokenization](3_word_parsing/14-tokenization.qmd),
  [vocabularies](3_word_parsing/15-vocabulary-building.qmd),
  [morphology](3_word_parsing/16-morphological-tagging.qmd),
  [part-of-speech tagging](3_word_parsing/17-part-of-speech-tagging.qmd), and
  [dependency parsing](3_word_parsing/18-dependency-parsing.qmd).
- **Word processing (19-23):**
  [stemming](4_word_processing/19-stemming.qmd),
  [lemmatization](4_word_processing/20-lemmatization.qmd),
  [normalization](4_word_processing/21-normalization.qmd),
  [spell checking](4_word_processing/22-spell-checking.qmd), and
  [negation](4_word_processing/23-negation-recognition.qmd).
- **Phrases and entities (24-28):**
  [n-grams](5_phrases_and_entities/24-n-grams.qmd),
  [phrase matching](5_phrases_and_entities/25-rule-based-phrase-matching.qmd),
  [noun chunks](5_phrases_and_entities/26-dependency-noun-chunks.qmd),
  [named entities](5_phrases_and_entities/27-named-entity-recognition.qmd), and
  [abbreviations](5_phrases_and_entities/28-abbreviation-finding.qmd).
- **Entity enrichment (29-34):**
  [prices](6_entity_enrichment/29-price-parsing.qmd),
  [geocoding](6_entity_enrichment/30-geocoding.qmd),
  [time expressions](6_entity_enrichment/31-temporal-parsing.qmd),
  [entity linking](6_entity_enrichment/32-named-entity-linking.qmd),
  [coreference](6_entity_enrichment/33-coreference-resolution.qmd), and
  [de-identification](6_entity_enrichment/34-text-de-identification.qmd).
- **Sentences and paragraphs (35-38):**
  [sentence boundaries](7_sentences_and_paragraphs/35-sentence-segmentation.qmd),
  [paragraph boundaries](7_sentences_and_paragraphs/36-paragraph-segmentation.qmd),
  [grammar checks](7_sentences_and_paragraphs/37-grammar-checking.qmd), and
  [readability](7_sentences_and_paragraphs/38-readability-scoring.qmd).
- **Documents (39-42):**
  [deduplication](8_documents/39-deduplication.qmd),
  [raw-text cleaning](8_documents/40-raw-text-cleaning.qmd),
  [metadata](8_documents/41-metadata-extraction.qmd), and
  [language identification](8_documents/42-language-identification.qmd).

The topic map comes from Rob van Zoest's
[Periodic Table of NLP Tasks](https://www.innerdoc.com/periodic-table-of-nlp-tasks/).

## Teaching standard

Lessons marked available in the source are written for first-time,
non-technical readers. Every R code chunk is executed during the site build,
and important outputs are checked in code. A failed example stops the build.

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

## Build the site

Install R 4.6.1, Python 3.12, Node.js 22, and Quarto 1.9.38. Then run:

```powershell
Remove-Item Env:LC_CTYPE -ErrorAction SilentlyContinue
$env:RENV_CONFIG_SANDBOX_ENABLED = "FALSE"
Rscript -e "renv::restore()"
python -m venv .venv-spacy
.venv-spacy/Scripts/python -m pip install -r requirements-spacy.txt
npm ci
npx playwright install chromium
Rscript scripts/check-prose.R
Rscript scripts/check-repetition.R
quarto render
Rscript scripts/check-lessons.R
Rscript tests/test-periodic-table.R
Rscript tests/test-workforce-data.R
npm run test:a11y
```

On macOS and Linux, install the Python requirements with
`.venv-spacy/bin/python -m pip install -r requirements-spacy.txt`. Native
dependencies for OCR, PDF processing, and `cld3` are listed in the render
workflow.

The automated accessibility suite uses axe-core and browser interaction tests
across every page. It does not replace manual testing with screen readers,
keyboard-only navigation, zoom, and forced-colors mode.

Use `quarto preview` for local development. Quarto writes the generated site
to `_site/`.

Package versions are recorded in `renv.lock` and
`requirements-spacy.txt`. The source documents and configuration are tracked;
generated site files and local environments are not. CI uploads the exact
rendered `_site` artifact for inspection but does not deploy it. Deployment to
the canonical host is managed outside this repository.
