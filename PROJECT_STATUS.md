# Project status

**Last updated:** 2026-08-29

## GitHub checkpoints

- [Pull request 1](https://github.com/farach/periodic_table_nlp/pull/1)
  rebuilt the site and published lessons 1-5.
- [Pull request 2](https://github.com/farach/periodic_table_nlp/pull/2)
  merged lessons 6-13, the workforce throughline, author-package integrations,
  additional adversarial review, and development notes in commit
  [`840d6a1`](https://github.com/farach/periodic_table_nlp/commit/840d6a1f1547ca8b86ac15b9abf439809e00d111).
- [Pull request 3](https://github.com/farach/periodic_table_nlp/pull/3)
  rewrote every lesson in the tidyverse and rebuilt the home page around the
  task map in commit
  [`c0943e3`](https://github.com/farach/periodic_table_nlp/commit/c0943e3).
- [Pull request 4](https://github.com/farach/periodic_table_nlp/pull/4)
  added the word-parsing stage, tasks 14 to 17, in commit
  [`f0cae28`](https://github.com/farach/periodic_table_nlp/commit/f0cae28).
- [Pull request 5](https://github.com/farach/periodic_table_nlp/pull/5)
  completed tasks 18 to 42, finishing the source-and-training-data stage and
  the whole language-structure stage, in commit
  [`ec542f0`](https://github.com/farach/periodic_table_nlp/commit/ec542f0).

## Reader-facing work

The Quarto site has 62 linked lessons:

- Source data loading, tasks 1-7
- Training data generation, tasks 8-13
- Word parsing, tasks 14-18
- Word processing, tasks 19-23
- Phrases and entities, tasks 24-28
- Entity enrichment, tasks 29-34
- Sentences and paragraphs, tasks 35-38
- Documents, tasks 39-42
- Model development, tasks 43-47
- Classification, tasks 48-52
- Signals and discovery, tasks 53-57
- Similarity, tasks 58-62

That completes the source-and-training-data stage, the whole language-structure
stage, and the models-and-analysis stage. Tasks 6-42 share a fictional
workforce-research story: Riverton Workforce Lab collects a saved job board,
extracts a training flyer, builds a versioned annotation codebook, compares
annotators, then works down through words, phrases, entities, sentences and
whole documents.

Tasks 43-62 change corpus, and say so. Twenty-eight hand-labelled sentences
were the right size for learning to label and the wrong size for learning to
predict, so the modeling lessons move to the 60 US presidential inaugural
addresses that quanteda ships, reshaped into 1,377 paragraphs. The section is
built on one contrast: the same model, features and code predict the era of a
paragraph well above baseline and fail completely at predicting party. Riverton
still appears where invented data is honest, in the spam and intent lessons,
which report no performance number for exactly that reason.

The 19 remaining map tiles are visible and marked as planned.

## Models in use

Two, with deliberately different provenance:

- `data/treebank/en_ewt-500-tagger.udpipe` and `en_ewt-500-parser.udpipe` were
  trained for this site on 500 sentences of the Universal Dependencies English
  Web Treebank, CC BY-SA 4.0. They are weak on purpose: held-out tagging
  accuracy 0.9087, unlabelled attachment 0.7235, labelled attachment 0.6561.
- spaCy `en_core_web_sm` 3.8.0 under spaCy 3.8.7, MIT licensed, reached through
  `spacyr`. Python packages are pinned in `requirements-spacy.txt` and are not
  managed by renv.

Putting the two side by side is a teaching device, not a fair contest, and the
lessons say so.

## Package integration

The lessons execute credential-free functions or fixtures from packages
authored or co-authored by Alex Farach:

- onet2r: archive parsing and occupation-task schema
- cmapr: job-title transition fixture
- huggingfaceR: local task vocabulary and zero-shot payload construction
- foundryR: versioned codebook hashes and agreement measures

GitHub package commits are pinned in `renv.lock` and displayed in the provider
lesson.

## Quality controls

- All R chunks execute during every clean render with warnings treated as
  errors and important expectations asserted.
- Lesson code is tidyverse-first. `readr` reads with explicit column types,
  `dplyr` and `tidyr` reshape, `purrr` iterates, and `stringr` handles strings.
  Base R stays only where it is the subject of a lesson or has no equivalent.
- `scripts/run-lesson.R` executes one lesson's chunks in order and fails on any
  warning, giving a fast check between full renders.
- The codebook hash has mutation tests for instructions, schema, examples, and
  version.
- Source HTML, image, transcript, API, and codebook fixtures have stored
  provenance or fingerprints.
- Prose passes separate residue and style-pattern scans, plus a repetition scan
  that fails when lessons start to read like one template.
- Tasks 6-13 received one narrative review and three independent adversarial
  logic reviews. Tasks 14-42 received one adversarial round each, applied.
- The tidyverse rewrite was attacked by an independent hostile code reviewer.
  Two blocking findings were fixed: package-loading chunks whose assertions
  could not fail, and an assertion silently disabled by readr's default
  treatment of an empty field as `NA`.
- The home page argument was attacked by an independent hostile reviewer across
  three rounds. It now rests on reasoning rather than on capability studies,
  which date quickly, and it makes no claim that would need a citation.
- Every public page is included in axe-core, keyboard, reflow, caption, forced
  colors, and reduced-motion tests.

## Honest limits

- Human editorial approval remains pending.
- Testing with current NVDA, JAWS, or VoiceOver remains pending.
- The Riverton data is synthetic and supports no population claim.
- Author-package fixtures demonstrate interfaces and schemas; they are not
  authenticated provider subsets unless a lesson says otherwise.
- Active-learning, augmentation, and weak-label examples are demonstrations,
  not validated workforce models.

## Next content

Task 43 begins the models-and-analysis stage with training models, which needs
a different kind of lesson: the site has so far avoided fitting anything. Tasks
43 to 47 cover the model lifecycle and are a natural group.
