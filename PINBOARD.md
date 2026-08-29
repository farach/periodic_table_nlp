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
- [ ] `scripts/check-repetition.R` only measures openings and whole sentences.
      It cannot see a repeated paragraph shape or a repeated argument. Read a
      run of lessons aloud before adding a new group.
- [ ] The spaCy environment is not managed by renv. If a lesson starts failing
      on a fresh machine, check `.venv-spacy` before suspecting the R code.
