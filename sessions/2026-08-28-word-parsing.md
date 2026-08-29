# Session notes, 2026-08-28 (word parsing)

## What shipped

Tasks 14 to 17 opened a third stage on the map, `3_word_parsing/`:
tokenization, vocabulary building, morphological tagging, and part-of-speech
tagging. All four continue the Riverton Workforce Lab story on the same 28
sentences.

## Decisions worth remembering

**Everything stays offline.** `tokenizers.bpe` trains a byte-pair model on
local text in under a second, and `hunspell` ships its own dictionary, so both
run in the render. UDPipe cannot: training a tagger on 500 sentences takes
about 42 seconds and on 2000 about 205, so `data-raw/build-treebank-tagger.R`
builds the artifacts by hand and they are committed. That follows the existing
precedent of `data-raw/create-training-flyer.R`.

**The pre-trained UDPipe models are CC BY-SA-NC.** This was discovered only
after downloading one and generating a comparison fixture from it. That fixture
was deleted. Publishing output derived from non-commercial material in an MIT
repository would have contradicted the site's own provenance lessons. The
replacement is better anyway: a learning curve computed entirely from CC BY-SA
treebank data, which shows what more labelled data buys and ties directly back
to lessons 8 to 13.

**A learning curve beats a model comparison.** Held-out accuracy at 100, 250,
500, 1000 and 2000 training sentences: 0.8238, 0.8725, 0.9087, 0.9284, 0.9429.
The reader spent six lessons hand-labelling 28 sentences; this shows what 500
buys. That is the strongest connection in the set.

## The defect that nearly shipped

Lesson 15 originally claimed a subword model produced **zero unknown tokens**
on held-out text. It was false, and the build could not see it because the
assertion matched the observed output.

`bpe_encode(model, x, type = "subwords")` reconstructs the surface string. It
prints the original characters even where the model emitted the unknown id.
`type = "ids"` shows the truth: 7 of 91 pieces were unknown.

The adversarial reviewer caught it without running anything, by noticing that
the asserted output contained the capital letters `I`, `V`, `K`, `H` and `U`,
while the 22 training sentences contain only `A C E N O P R S T W`. A byte-pair
model cannot build a piece from a character it has never seen. Verified in
about five minutes once the question was asked.

Two lessons here:

1. An assertion pinned against observed output proves the output is stable, not
   that it means what the prose says it means. `check-lessons.R` cannot detect
   this class of error, and neither can a render.
2. Check what a display function is showing you. `type = "subwords"` is a
   convenience that hides the model's own decisions. The corrected lesson now
   teaches exactly this, and it is better than the version that was wrong.

## Other corrections from the same review

- "Web text" was really 13 political weblog posts from 2003 to 2006, with 11
  more of the same in the training excerpt. Naming the genre strengthened the
  domain-transfer argument rather than weakening it.
- An accuracy figure with no baseline is uninterpretable. A most-frequent-tag
  lookup scores 3178/4007; the tagger scores 3641/4007. The gap, about 11.6
  points, is the real result. Excluding punctuation and determiners, which are
  22 percent of tokens, both fall.
- Five unreplicated points on one curve cannot establish that returns on
  labelled data fall off, and each step also adds new blog posts, so more data
  and broader coverage arrive together.
- Hunspell splitting `requires` into `re` + `quire` is not a real etymology.
  `require` came into English whole, from French.
- Lesson 16 is named after a task it does not perform: morphological tagging
  normally means labelling features in context, which needs a sentence.

## Infrastructure

Adding a stage used to require editing three hand-maintained lists.
`scripts/check-lessons.R` and `tests/accessibility.spec.mjs` now discover
lessons from any numbered directory, and the tile-count assertions derive from
what rendered. `.gitattributes` marks `*.udpipe` as binary so the committed
model's fingerprint survives Git.

## State

PR #4 merged to `main` as `f0cae28`. All gates green: 31 prose files, 19
rendered pages, 108 executed R chunks, periodic table and workforce tests, 30
accessibility tests, and CI passing on Ubuntu, which is what proves the binary
model and the CoNLL-U excerpts survive line-ending normalisation.

Seventeen of eighty-one tiles now open a lesson.
