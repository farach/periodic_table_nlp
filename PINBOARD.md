# Pinboard

## Unfinished Tasks

- [ ] Complete human editorial approval for lessons 1-42.
- [ ] Test the site with a current screen reader used by the intended audience.
- [ ] Test manual browser zoom at 200% and 400% with keyboard-only navigation.
- [ ] Begin task 43, training models, which opens the models-and-analysis
      stage and is the first lesson that has to fit something.
- [ ] Decide whether later map group names should be revised after each lesson
      exposes their limits.
- [ ] Watch for the assertion pattern the code review caught: a check that
      cannot fail still satisfies the build gate, which only greps for
      `stopifnot(`.
- [ ] Watch for the second pattern, found in task 15: an assertion pinned to
      observed output proves the output is stable, not that the prose describes
      it correctly. `bpe_encode(type = "subwords")` hid unknown tokens for a
      whole draft.
- [ ] Watch for the third pattern, found across tasks 29 to 38: a lesson that
      writes its own test cases and then scores itself on them. Seven did it
      without saying so. Every such score now carries a disclosure.
- [ ] Watch for the fourth pattern, found in the first drafts of tasks 47 and
      50: fitting on a dataset and then calling `predict()` on that same
      dataset. Task 47 predicted over all 1,377 paragraphs from a model trained
      on 1,042 of them and reported slice accuracies up to 1.000 against a real
      held-out score of 0.8209. Task 50 fitted on all 60 invented messages and
      reported recall of exactly 1.000 for all five classes. Both looked
      plausible in a report. Grep every new lesson for `predict(` and check what
      data it is handed.
- [ ] Watch for the fifth pattern, found in task 47: slicing a monitoring
      report by a variable the label is derived from. `era` is defined by year,
      so a per-decade accuracy is a one-class recall and is near-perfect by
      construction. Ask what a slice's class composition is before reporting a
      score for it.
- [ ] A number that beats the committed baseline deserves suspicion before
      celebration. Both leaks above surfaced as scores that were too good, not
      as errors.
- [ ] Watch for the sixth pattern, found in task 54: a result that is exactly
      what chance predicts, reported as a finding. An overlap of 0 between three
      chosen sentences and the first three is the modal outcome under random
      selection. `R/permutation-null.R` exists so this question gets asked.
- [ ] Watch for the seventh pattern, found in the spam fixture: author-written
      classes separating on something the author did not intend. All 16 scam
      messages lacked a first-person pronoun, so a two-word grammatical rule
      scored 0.9167 with perfect recall and no scam vocabulary at all. The
      builder now sweeps superficial features and refuses to write the file if
      any one of them reaches 0.80 accuracy or 0.95 recall. Distinguish a
      shortcut that reflects how the data was made, which is a defect, from one
      that reflects how the world works, which is a shallow but real signal.
- [ ] Watch for the eighth pattern, found in task 62: a demonstration with no
      control. Two occurrences of `bank` scored 0.3466 apart and that was read
      as the model separating word senses. Two occurrences of the SAME sense in
      different grammatical roles score 0.3447, and the same sense in the same
      role scores 0.9422. The model separates syntactic role, not meaning,
      because it was trained to tag and parse. Always ask what the same
      measurement gives when the thing you are claiming is absent.
- [ ] `renv::snapshot()` is a separate step from editing `dependencies.R`.
      Twenty-four modeling packages were added to `dependencies.R` and would
      have failed CI at the first `renv::restore()`. Check `renv.lock` by name
      after installing anything.
- [ ] A package in `renv.lock` is installed on CI whether or not a lesson uses
      it, so its system libraries must be in the workflow. topicmodels needs
      libgsl-dev, xml2 needs libxml2-dev, sodium needs libsodium-dev.
- [ ] Float assertions need a tolerance. A value that comes through a Python
      tensor or a BLAS can differ in its last digits between Windows and a
      Linux runner, so six decimal places in a `stopifnot()` is a CI failure
      waiting to happen.
- [ ] Stable assertions do not prove stable output. Task 61's similarity bands
      were identical across five fits while the neighbour WORDS changed every
      time, so the checks passed while the rendered table drifted. When a check
      summarises a result, confirm the displayed result is stable too, not just
      the summary.
- [ ] quanteda's `President` docvar is a surname. Four surnames cover two people
      each, so the corpus has 60 speeches by 40 people. Anything grouping by
      person must use the full name that `inaugural_paragraphs()` builds.
- [ ] `scripts/check-repetition.R` only measures openings and whole sentences.
      It cannot see a repeated paragraph shape or a repeated argument. Read a
      run of lessons aloud before adding a new group.
- [ ] The spaCy environment is not managed by renv. If a lesson starts failing
      on a fresh machine, check `.venv-spacy` before suspecting the R code.
