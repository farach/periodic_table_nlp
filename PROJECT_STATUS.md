# Project status

**Last updated:** 2026-08-28

## GitHub checkpoints

- [Pull request 1](https://github.com/farach/periodic_table_nlp/pull/1)
  rebuilt the site and published lessons 1-5.
- [Pull request 2](https://github.com/farach/periodic_table_nlp/pull/2)
  merged lessons 6-13, the workforce throughline, author-package integrations,
  additional adversarial review, and development notes in commit
  [`840d6a1`](https://github.com/farach/periodic_table_nlp/commit/840d6a1f1547ca8b86ac15b9abf439809e00d111).

## Reader-facing work

The Quarto site has 13 linked lessons:

- Source data loading, tasks 1-7
- Training data generation, tasks 8-13

Tasks 6-13 share a fictional workforce-research story. Riverton Workforce Lab
collects a saved job board, extracts a training flyer, creates a versioned
annotation codebook, tests active-learning selection, inspects outside data
providers, compares several annotators, creates synthetic candidates, and
stress-tests rule-based weak labels.

The 68 remaining map tiles are visible and marked as planned.

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
- The codebook hash has mutation tests for instructions, schema, examples, and
  version.
- Source HTML, image, transcript, API, and codebook fixtures have stored
  provenance or fingerprints.
- Prose passes separate residue and style-pattern scans.
- Tasks 6-13 received one narrative review and three independent adversarial
  logic reviews. High-confidence findings were corrected.
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

Task 14 is tokenization. It should continue the workforce text where useful and
compare word, sentence, and transformer-era subword tokenization without
treating one token definition as universal.
