# Session notes, 2026-09-23 (systems and information visualization)

## What shipped

Tasks 69 to 81, thirteen lessons across the last two map groups. Every tile on
the map now opens a lesson.

- `14_systems/`: relation extraction, question answering, chatbot dialogue,
  semantic search indexing, knowledge base population, e-discovery and media
  monitoring.
- `15_information_visualization/`: an interactive app, annotated text, word
  clouds, word embedding plots, timelines, maps, and knowledge graphs.

## How the work was organized

An adaptive iterative research council (`finish-table-2026-09-23`) ran six
pre-draft evidence authorities (extraction and graphs, retrieval and question
answering, dialogue and review, apps and annotation, visual evidence, runtime
and provenance), a dossier editor, a separate final integrator, and a
learner-skeptic who saw only frozen artifacts. Six writer agents drafted the
lessons from frozen designs. The implementation owner integrated shared files
and never judged release readiness. Seven independent audits of the frozen
draft produced 100 normalized candidates; the integrator ruled Pause, authorized
one bounded repair pass with ten blocking items, and required independent
closure before the pull request.

## Decisions worth remembering

- **One frozen handbook for tasks 70-72.** Passages, question probes with
  expected actions, and exhaustive search judgments were written and
  fingerprinted before any lesson retrieved or generated. Lesson 70's
  paraphrased child-care question shares no content word with its gold passage,
  so lesson 72 can open on a real lexical miss.
- **A sentence-embedding model through the existing manifests.**
  `sentence-transformers/all-MiniLM-L6-v2` is pinned by revision with nine
  hashed files. The huggingfaceR feature-extraction pipeline plus R mean pooling
  reproduces direct torch pooling exactly for one text per call; `R/use-nlg.R`
  now skips generation settings for encoder-only models.
- **Twelve lockfile records, none changed.** shiny, ggwordcloud, Rtsne, and maps
  entered `renv.lock` with eight dependencies. ggraph, uwot, ggrepel, and
  mapproj were rejected. The first Windows snapshot rewrote the whole lockfile
  with CRLF endings; `.gitattributes` now pins `renv.lock` to LF.
- **A finished map has no planned tiles.** The home page derives its counts from
  the task map, and the planned-tile key and instructions appear only when a
  planned tile exists. The accessibility suite asserts absence instead of
  skipping.
- **Linux CI on the frozen draft, before repairs.** A workflow_dispatch run on
  the draft branch rendered all 83 pages on Linux, so the cross-platform risks
  (Qwen text, embedding margins, t-SNE, PCA signs, word-cloud fit) were settled
  before the repair pass rather than after it.

## Defects the council caught

The ones worth remembering, because each looked finished on the rendered page:

1. **Answer key shown as method output.** Lesson 69's "extracted triples" table
   was the reference key minus one row. The real extractor returned nothing: a
   `transmute()` overwrote a column before copying it, and dplyr data masking
   resolved `sentence_id` to spaCy's own column inside a filter.
2. **A premise screen that read the answer key** (lesson 70), a server-results
   table typed by hand (lesson 75), and knowledge-graph edges typed by hand with
   an unstated year (lessons 73 and 81).
3. **A constructed collection that its own sweep could not see through.** Lesson
   74's review records first carried label-ordered IDs, then came from 40 base
   texts, then from one dominant sentence frame that separated the classes with
   balanced accuracy 0.94 while the builder's sweep passed. An elusion seed was
   also changed after samples were inspected and had to be restored.
4. **Prose that outlived the data.** Lesson 74 quoted keyword counts and a
   sampled miss from an earlier build of its collection.
5. **Checks that cannot fail.** A batch-versus-single embedding check compared
   two identical code paths; seed checks compared objects with copies of
   themselves.
6. **Position as identity.** Lesson 80's hand review labels were keyed by
   `row_number()`.
7. **Series shape.** All thirteen pages opened with a first name and closed by
   naming the same person again; the automated repetition gate passed because
   the four-word openings differed.

## Permanent rules

The new rules are recorded in `CONTRIBUTING.md` under "Rules from the systems
and visualization lessons" and in the pull-request checklist.
