# Manual review: choosing topic count

Lesson 55 originally stated that changing `k` changes the topic model, then
offered no method for deciding which values deserved attention. The lesson used
five topics because five had already been typed into the model call.

## Rules carried forward

1. There is no criterion-free optimal topic count. State which property a
   diagnostic measures and which direction is preferred.
2. Use more than one diagnostic. Predictive fit, coherence, exclusivity,
   stability, and human usefulness can disagree.
3. Choose diagnostics before reading the topic words. Picking the model with the
   easiest labels after inspecting all outputs is post-hoc selection.
4. Build vocabulary and corpus-level preprocessing on training documents when a
   diagnostic uses held-out text.
5. Fit several random starts for each candidate value. One start can make a
   topic count look better or worse by accident.
6. State the document unit. More, shorter documents do not pose the same
   modeling problem as fewer, longer documents.
7. Distinguish the topic model from the fitting algorithm. VEM and Gibbs are
   different ways to estimate LDA; CTM, STM, seeded LDA, and supervised LDA
   change the model or the question.
8. Keep the expensive grid in `data-raw/`; fit and inspect the selected model
   live in the lesson.

## What the diagnostics found

`data-raw/build-topic-k-diagnostics.R` fits values 3 through 8 under seeds 42,
7, and 2024. It uses a speech-level holdout and a vocabulary built only from
the training speeches.

- `k = 3` has the lowest held-out perplexity and the highest adjusted top-word
  exclusivity.
- `k = 5` has the highest mean semantic coherence.
- The existing seed comparison shows that `k = 5` is reasonably repeatable on
  this corpus.

The lesson keeps five topics because coherence is strongest and seed stability
is acceptable. Three topics would also be defensible for a task that valued
held-out prediction or concentrated topic vocabularies more heavily. The result
is a documented choice, not an optimum certified by the software.
