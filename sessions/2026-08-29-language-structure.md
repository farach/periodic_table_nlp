# Session notes, 2026-08-29 (language structure)

## What shipped

Tasks 18 to 42, twenty-five lessons across five new map groups. That closes the
source-and-training-data stage and the whole language-structure stage. The site
now has 42 lessons and 231 executed R chunks.

- `3_word_parsing/` gained dependency parsing.
- `4_word_processing/` stemming, lemmatization, normalization, spell checking,
  negation.
- `5_phrases_and_entities/` n-grams, phrase matching, noun chunks, named
  entity recognition, abbreviations.
- `6_entity_enrichment/` prices, geocoding, temporal parsing, entity linking,
  coreference, de-identification.
- `7_sentences_and_paragraphs/` sentence and paragraph segmentation, grammar
  checking, readability.
- `8_documents/` deduplication, cleaning, metadata, language identification.

## The package decision that changed everything

The site owner overruled an earlier constraint that excluded ggplot2,
tidyverse, quanteda, tidytext and spacyr. That constraint was wrong. A site
teaching NLP in R that avoids tidytext and quanteda looks like it does not know
the field.

`tidytext`, `quanteda`, `quanteda.textstats`, `ggplot2`, `cld2`, `cld3` and
`stringdist` were straightforward. **spaCy was the consequential one.**

### How spaCy is wired in

spaCy is Python, so it sits outside `renv.lock`:

- `requirements-spacy.txt` pins spaCy 3.8.7 and `en_core_web_sm` 3.8.0.
- A project-local venv at `.venv-spacy/`, gitignored.
- `R/use-spacy.R` owns the Python path, the warning suppression and the
  startup message. Lessons call `source("R/use-spacy.R"); use_project_spacy()`
  and nothing more.
- CI adds `actions/setup-python` and installs from the requirements file before
  rendering. Nothing downloads during a render.

Two things made it worth the dependency. **The model is MIT licensed**, unlike
the pre-trained UDPipe models, so output derived from it can be published
freely. And it gives a real comparison: lesson 20 puts the deliberately weak
500-sentence UDPipe model beside spaCy on the same words, and the gap is
visible rather than asserted.

Verified before committing: `spacy_parse()` returns `identical()` output across
runs.

## Defects adversarial review caught

Five hostile reviews ran across the twenty-five lessons. The ones that mattered:

1. **A real bug.** Lesson 29's price parser silently corrupted any number of
   four or more digits without a thousands separator: `$38000 a year` parsed as
   `380`. Fixed; the score moved from 12 to 13.
2. **A number that was wrong three ways.** Lesson 38 reported a Flesch score of
   32.81, which conventionally means very difficult, for plain job-board
   sentences. Its 22 "sentences" were an artefact of an undisclosed
   preprocessing choice, and its own syllable counter was wrong on 9 of 30
   words while the output carried two decimal places. After disclosure and
   correction the score is about 56.
3. **A cause the code contradicted.** Lesson 36 attributed the paragraph
   collapse to the wrong mechanism.
4. **Circular disambiguation.** Lesson 30 supplied its own answer and then
   asserted that the answer was the answer.
5. **Answer keys written by the same hand as the rule.** Seven lessons scored
   themselves against their own examples without saying so. A perfect score on
   your own test cases is evidence of nothing, and the pages now say it.

## The template problem, measured

Every reviewer independently flagged that the lessons read like one template.
Rather than argue about it, I measured it: **24 of 42 lessons opened with the
identical four words, "The Riverton Workforce Lab".**

`scripts/check-repetition.R` is now a build gate. It fails when more than four
lessons share a four-word opening or more than three share an identical
sentence. The fictionality disclosure is exempt, because a standard notice
should read the same everywhere.

All 42 openings were rewritten to open on a moment, an object, a number, or the
state the previous lesson left behind. The gate passes.

This is the check worth keeping. Prose scanning for banned words catches
vocabulary; it cannot see structure. Twenty-five lessons from one brief will
converge on a shape, and the shape is what a reader notices first.

## Other decisions worth remembering

- The udpipe dependency parser is a second committed model, 2.8 MB, trained by
  `data-raw/build-treebank-parser.R`. Held-out unlabelled attachment 0.7235,
  labelled 0.6561, against the tagger's 0.9087. Parsing is harder than tagging
  and the numbers say so.
- `data/riverton/` holds invented reference files for geocoding and entity
  linking, with a deliberate duplicate place name and a deliberate ambiguous
  alias. Built by `data-raw/build-riverton-reference.R`, MIT.
- `hunspell` bundles its own `en_US` dictionary, so it is pinned by the package
  version. That is different from tesseract, whose engine comes from apt.
- A scrollable code block that is not keyboard focusable fails WCAG. The
  runtime fix in `accessibility-after-body.html` now covers `div.sourceCode`,
  not only output blocks.
- Quarto's `quarto render a.qmd b.qmd` with relative paths from different
  directories fails with `withBinaryFile: does not exist`. That is a CLI quirk,
  not a project problem. The gate is `quarto render` with no arguments.
