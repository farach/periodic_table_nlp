# Learner-centered completeness review

## Scope

An adaptive iterative research council reviewed all 62 published lessons after
the topic-count revision merged. Five reviewers covered disjoint lesson ranges;
five more reviewed learner sequencing, R pedagogy, evidence methods, cognitive
accessibility, and adversarial omissions. A separate dossier editor normalized
claims, and a blinded integrator authorized only bounded changes.

The frozen test was not “could this lesson contain more?” A revision had to
prevent a specific learner error, fit without displacing the named NLP task, and
have executable or authoritative support.

## Findings that changed lessons

- Lesson 5 now executes a prepared httr2 request against a local mock instead of
  merely describing `req_perform()`.
- Lesson 15 retains source IDs and compares whole-word and BPE coverage under
  the same lowercase policy and word-token unit.
- Lesson 16 points contextual feature bundles to lesson 18 and the task map now
  calls the page morphological analysis rather than morphological tagging.
- Lessons 43-45 distinguish grouped pilot data, grid boundaries, paired
  resample evidence, class-aware metrics, coefficient scale, and outcome
  direction.
- Lesson 47 labels its historical drift calculation as training-heavy and its
  regex tokenization as an approximation of the fitted recipe.
- Lesson 48 chooses one orientation per shortcut, shows the majority baseline,
  and refuses to rank an in-sample hand rule against an out-of-sample model.
- Lessons 49-52 tighten label provenance, method names, visible probability
  output, configuration comparability, keyed joins, dictionary glob semantics,
  deployable baselines, and undefined precision.
- Lesson 55 replaces a uniform-vocabulary stability null with a
  frequency-preserving allocation null and separates topic-count selection from
  full-corpus repeatability.
- Lesson 56 names its denominator as alphabetic tokens.
- Lesson 62 limits its syntax-versus-sense statement to four illustrative
  probes.
- The lesson 61 review record now matches the artifact's 134,419 cleaned
  training tokens.

## Findings rejected after verification

- Lesson 56's `per_thousand[-1]` was alleged to remove the lowest rate. In R,
  negative index 1 removes the first element; after descending sort, the code
  already removes the peak.
- Lesson 57's `.by_group = TRUE` is a harmless no-op in that pipeline. Removing
  it solely for style did not pass the learner-harm test.
- New model families, calibration chapters, BPE surveys, a second morphology
  pipeline, time-series machinery, another topic-model family, a WSD benchmark,
  formal proofs, and a course-wide glossary were all rejected as unnecessary.

## Permanent review rules

1. Hold unit, denominator, case policy, tokenizer, and preprocessing constant
   before comparing rates.
2. Retain source IDs through extraction and join derived values by key, even
   when row order currently happens to align.
3. Put a deployable same-split baseline beside every model score and label
   whether each comparator is in-sample or out-of-sample.
4. Read paired wins, ties, and losses before making universal claims from
   resample means.
5. Preserve nuisance structure in a null model. A check run only for a selected
   parameter cannot justify selecting it over untested alternatives.
6. Define the object or metric before asking learners to interpret it.
7. Prefer one correction, sentence, table, or link over adding a neighboring
   textbook chapter.

These rules are also recorded in `CONTRIBUTING.md`,
`EDITORIAL_GUIDE.md`, and the pull-request checklist.
