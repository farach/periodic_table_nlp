# Pinboard

## Unfinished Tasks

- [ ] Complete human editorial approval for lessons 1-13.
- [ ] Test the site with a current screen reader used by the intended audience.
- [ ] Test manual browser zoom at 200% and 400% with keyboard-only navigation.
- [ ] Begin task 14 with word and transformer-era subword tokenization.
- [ ] Decide whether later map group names should be revised after each lesson
      exposes their limits.
- [ ] Add ggplot2 when the first lesson needs a chart. It is deliberately not a
      dependency yet.
- [ ] Watch for the assertion pattern the code review caught: a check that
      cannot fail still satisfies the build gate, which only greps for
      `stopifnot(`.
- [ ] Watch for the second pattern, found in task 15: an assertion pinned to
      observed output proves the output is stable, not that the prose describes
      it correctly. `bpe_encode(type = "subwords")` hid unknown tokens for a
      whole draft.
- [ ] Decide whether task 18, dependency parsing, is worth a second UDPipe
      artifact, since a parser model is larger than the tagger.
