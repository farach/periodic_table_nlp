# Data sources and licenses

This repository is licensed under the MIT License. Data and material obtained
from another source retain their own licenses and attribution requirements.

## Author-created teaching data

The files below are fictional and were created for this project:

- `data/customer_feedback.csv`
- `data/help_articles/`
- `data/workforce/job-board.html`
- `data/workforce/workforce_sentences.csv`
- `data/workforce/crowd_annotations.csv`
- `data/workforce/training-flyer-ground-truth.txt`
- `data/workforce/training-flyer-ocr-5.3.2.txt`
- `data/workforce/training-flyer-degraded-ocr-5.3.2.txt`
- `data/workforce/training-flyer-metadata.csv`
- `data/workforce/training-flyer.png`
- `data/riverton/`, including the reference entities, aliases, gazetteer,
  language samples, inbox, handbook, question-answering probes, search
  judgments, review collection, and monitoring stream

They contain no real workers, applicants, employers, customers, or research
participants. Their purpose is to make code and research-design problems small
enough to inspect. They must not be used to make claims about a population.

### Riverton handbook, review collection, and monitoring stream

Lessons 70 to 72 read one invented fall-program handbook for the Riverton
Skills Centre. `data-raw/build-riverton-handbook.R` writes three files together,
before any lesson retrieves or generates anything:

- `riverton-handbook.csv`: 15 short passages with durable passage IDs;
- `riverton-handbook-questions.csv`: six question-answering probes with an
  expected action (answer, abstain, or flag a false premise), a gold passage,
  and acceptable short answers; and
- `riverton-search-judgments.csv`: a relevance judgment for every pair of 8
  search queries and 15 passages.

Lesson 74 reads `riverton-review-collection.csv`, a constructed collection of
240 fictional records for one review request (records about hiding Calder Yard
inspection delays, changing inspection logs, or deleting related messages; 36
are author-labelled responsive), and `riverton-monitoring-stream.csv`, 24
fictional dated items with arrival order, explicit syndicated near-duplicates,
and ambiguous Riverton mentions. `data-raw/build-riverton-review-collection.R`
writes both. Every row carries an `author_note` marking it as fictional, and a
`near_duplicate_of` column names the original of each deliberate near-duplicate.
Each record is a short note wrapped in one of 12 frames, such as "Reminder:" at
the start or "Thanks." at the end, and each frame holds exactly 3 responsive and
17 non-responsive records. Record IDs are assigned after seeded permutations and
never appear in the text.

Frames are assigned by one fixed rule, with no random draw. Within each class,
the builder splits the notes into those that match the keyword rule and the
rest, and it places the matching notes first. Each group is taken in order of
the SHA-256 digest of the note's text. Each note gets the frame that has the
fewest notes from its group so far. A tie goes to the lower-numbered frame, and a
frame that already holds its full share for the class is skipped. A
near-duplicate pair is placed as one unit, at the position of its member with the
smaller digest, and shares one frame. In the committed collection, the frame
counts within each group differ by at most one.

The builder refuses to write the files when base-text variety falls below its
declared threshold, or when any surface check reaches positive F1 of 0.60 or
balanced accuracy of 0.75. It stops if any check returns a missing value. Its
checks cover:

- single values, and value sets learned on half the records and tested on the
  other half (20 seeded splits), of record features: length, punctuation,
  pronouns, digits, month, weekday, record-ID digit and order, date rank, file
  position, construction-ID order, first word, first two words, first three
  tokens, sentence count, colon, source type, sender role, and subject;
- the first word, first two words, first three tokens, and colon of each
  record's core note, and the frame itself;
- each frame paired with the first word of the core note, both as label-free
  rules that flag rare pairs and as a pair ranker learned on half the records;
- the frames among records that match the keyword rule and among records that
  do not, judged on balanced accuracy;
- the 20 most frequent tokens outside the review request's own topic words;
- two out-of-fold rankers, each fitted with `glmnet` ridge and lasso and scored
  by stratified five-fold cross-validation under three fold seeds, at the top 36
  records. One ranker sees counts of every word on the snowball stop-word list,
  and the other sees format cues (length, punctuation, capitalization, and
  digits);
- a frame-only ranker; and
- a cap of 15 percent on any frame or core opening among non-responsive
  records.

`--sweep-only` runs the record-level checks on any collection file.
`--negative-controls` confirms that they refuse four earlier versions of the
collection: the ones committed at `0a5a5af9`, `a3478085`, and `49a9b67a`, and an
intermediate version from the final revision, which the function-word ranker
refuses.

The same person wrote these records, their questions, their reference answers,
their relevance judgments, and the lessons that score against them. They are
disclosed teaching fixtures, not independent benchmarks or ground truth. The
handbook, its questions, and its judgments were written and fingerprinted before
any lesson retrieved or generated anything. The review collection was not. It
was revised several times during development to remove shortcuts:

- a record-ID shortcut;
- repeated templates;
- a dominant sentence frame;
- department names as first words;
- non-responsive notes generated from a template grid, whose function words
  separated the classes; and
- frames assigned in construction order, which let a frame together with a
  note's first word, and the frame among keyword matches, carry label
  information.

Lesson 74 was executed on earlier versions of the collection, including one
intermediate version during the final revision, and the outputs of those runs
were discarded. The final non-responsive everyday notes were written by a writer
who had not seen any lesson 74 output. That writer revised the first draft once
before the collection was committed, to vary record length more naturally and to
remove the repeated situations the writer had been told about. Two reviews of
the committed collection, made before lesson 74 ran on it, then found more notes
that described the same situation as another record, and found the
construction-order frame assignment. A checks commit then added the two frame
checks. One corrective commit replaced every member but one of each repeated
group those reviews listed and reassigned the frames by the rule above. No other
note was reworded, and three groups of records outside the correction still
describe overlapping situations. Neither the writer's drafts nor the corrected
collection was run through lesson 74 before it was committed, and the published
results come from the first execution on the corrected collection.

The builder's metadata records its seeds:

- the base seed 7401 and the row-shuffle seed 7403;
- the date, record-ID, and stream-ID seeds, each chosen by a rule written in
  the builder;
- the split-half seeds 7501 to 7520; and
- the ranker fold seeds 7601, 7602, and 7603.

The lesson's single elusion sample uses the predeclared seed 7401. During
drafting, that seed was briefly changed to 7402 after development draws had
been inspected. It was restored to 7401 before the draft was frozen.

`riverton-handbook-metadata.csv` and `riverton-review-collection-metadata.csv`
record row counts, class counts, and line-normalised SHA-256 fingerprints that
`scripts/check-data-fingerprints.R` verifies.

## Bing Liu opinion lexicon

Some lessons access the Bing Liu positive/negative opinion lexicon through the
tidytext package. The lexicon was created for product-review sentiment research
by Minqing Hu and Bing Liu:
<https://www.cs.uic.edu/~liub/FBS/sentiment-analysis.html>.

The source page requests citation and describes research-use terms rather than a
general open-data licence. Applying it to political speeches or fictional
service comments is a domain-mismatch teaching example, not a validation of
sentiment in those settings.

## Open Library fixture

`data/openlibrary-nlp-search.json` contains work-level catalog records returned
by the Open Library Search API. Its metadata file records the request, retrieval
time, and fingerprint.

The Internet Archive states that it does not assert new proprietary rights over
the Open Library database, while warning that existing rights may vary by
contribution and jurisdiction:
<https://openlibrary.org/developers/licensing>.

## Package teaching fixtures

The lessons execute fixtures bundled with these packages:

- [onet2r](https://github.com/farach/onet2r), MIT
- [cmapr](https://github.com/farach/cmapr), MIT
- [huggingfaceR](https://github.com/farach/huggingfaceR), MIT
- [foundryR](https://github.com/farach/foundryR), MIT

A package fixture demonstrates an interface or schema. Unless a lesson provides
upstream identifiers and an authentication check, it must not be described as
an exact extract from the provider's full dataset.

## Tesseract OCR

Task 7 reads text from `data/workforce/training-flyer.png`, an image this
project generates from its own transcript by `data-raw/create-training-flyer.R`.
The OCR engine is [Tesseract](https://github.com/tesseract-ocr/tesseract) and
the R binding is the
[tesseract package](https://docs.ropensci.org/tesseract/), both under the
Apache License 2.0. The English language data `eng.traineddata` is distributed
by the Tesseract project under the same licence.

No Tesseract artifact is committed to this repository. The engine and its
language data are installed on the machine that renders the site, which is why
the workflow installs `tesseract-ocr` and `tesseract-ocr-eng`. Because the
source image is author-created, the recognised text carries no third-party
rights.

Tesseract output depends on the engine version. `training-flyer-metadata.csv`
records the version that produced the committed transcript, and the lesson
compares recognised text against `training-flyer-ground-truth.txt` rather than
treating OCR output as correct by default.

## United States presidential inaugural addresses
Tasks 43 to 64 use `quanteda::data_corpus_inaugural`, the 60 inaugural addresses
delivered between 1789 and 2025. Tasks 75, 77, 80, and 81 read the same
paragraphs, and task 78 plots the word2vec model trained on them. The speeches
are works of the United States federal government and are in the public domain;
quanteda packages and distributes them, and quanteda itself is GPL-3.

`R/inaugural-corpus.R` is the only place the corpus is reshaped. It splits each
speech on blank lines, keeps blocks of at least 25 words, and returns 1,377
paragraphs with `paragraph_id`, `speech_id`, `year`, `president`, `surname`,
`party`, `era`, `paragraph_words`, and `paragraph`. Two details matter for
anyone reading results built on it:

- The `President` docvar quanteda supplies is a **surname**. Four surnames cover
  two people each: Adams, Harrison, Roosevelt, and Bush. The corpus holds 60
  speeches by **40 people**, and a count of 36 is a count of surnames. The helper
  builds a full name from the `FirstName` and `President` docvars so that
  grouping by person does not merge John Adams with John Quincy Adams, or
  Theodore Roosevelt with Franklin Roosevelt.
- The 25-word filter removes salutations and headings, so any lesson that
  reassembles a speech from these paragraphs is working with a reconstruction
  rather than the delivered text. The share of words dropped is not constant
  across the period, because paragraph length falls sharply over time.

`data/inaugural/` holds a committed resampling study generated by
`data-raw/build-inaugural-study.R`, which runs by hand rather than at render.
It records, for each replicate, the model's accuracy and balanced accuracy
alongside two trivial-rule baselines and a paragraph-length rule, so that no
score in the lessons is reported without something to compare it against.

The same directory holds `model-comparison.csv` and
`model-comparison-folds.csv`, generated by
`data-raw/build-model-comparison.R`. The comparison uses five folds grouped by
speech inside the training set. It compares ridge and lasso logistic regression
with a random forest, across 14 settings, without reading the final 14 test
speeches. `model-comparison-metadata.csv` records the seeds, grids, model
settings, source, license, and SHA-256 fingerprints.

`topic-k-diagnostic-runs.csv` and `topic-k-diagnostics.csv` compare topic
counts 3 through 8 under three VEM starts. The vocabulary is built from
training speeches only. Semantic coherence and adjusted top-word exclusivity
are computed on training paragraphs; perplexity is computed on held-out
speeches. `data-raw/build-topic-k-diagnostics.R` rebuilds the files, and
`topic-k-diagnostics-metadata.csv` records settings and fingerprints.

The next-token study uses speech-level training, validation, and test splits.
It builds a training-only 2,500-token vocabulary, evaluates paragraph-bounded
contexts, and chooses context length and interpolation strength on validation
speeches before opening the test set. The split holds out speeches rather than
speakers, so presidents with multiple inaugurals can appear in more than one
split. `data-raw/build-next-token-study.R` writes the split, validation, test,
and paired-speech files. `next-token-study-metadata.csv` records settings,
source, license, and SHA-256 fingerprints for those four artifacts.

Party labels in this corpus span 236 years and do not describe a stable thing
across that range. Lessons use them only as a data column, never as a
description of any party, president, or policy.

## United States state names, centres, and boundaries

Task 80 matches state names from `datasets::state.name` and places reviewed
state symbols at `datasets::state.center`. Both are distributed with R's
`datasets` package. The R documentation gives the source as the U.S.
Department of Commerce, Bureau of the Census, *Statistical Abstract of the
United States* (1977) and *County and City Data Book*. The centres are
approximate, the documentation says Alaska and Hawaii are placed just off the
West Coast for compact map drawing, and the data have no District of Columbia
entry. The lesson therefore draws no Alaska or Hawaii symbol.

The basemap comes from the `maps` package state database (maps 3.4.3, GPL-2),
read through `ggplot2::map_data("state")` without attaching `maps`. Its
documentation says the database was generated from U.S. Census data. It covers
the lower 48 states and the District of Columbia; the boundary vintage is not
stated. The lesson does not use it for historical boundaries or exact areas.

## O*NET attribution

This project includes information that uses an O*NET-shaped onet2r teaching
fixture.

This project includes information from
[O*NET Resource Center](https://www.onetcenter.org/) by the U.S. Department of
Labor, Employment and Training Administration (USDOL/ETA). Used under the
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) license. O*NET® is a
trademark of USDOL/ETA. Alex Farach has modified or added information.
USDOL/ETA has not approved, endorsed, or tested these modifications.

Official license and attribution instructions:
<https://www.onetcenter.org/license_db.html>.

## CMap

The full CMap dataset is published under CC BY 4.0:
<https://doi.org/10.5281/zenodo.15260189>.

The cmapr example file used in this site does not include upstream identifiers
or validation status. The lessons treat it as a package teaching fixture, not
as an authenticated sample or evidence about career mobility.

## Task map

The task names and groupings are adapted from Rob van Zoest's
[Periodic Table of NLP Tasks](https://www.innerdoc.com/periodic-table-of-nlp-tasks/).

That page carries no licence statement and invites reuse. The individual task
names are standard terminology in the field. The grouping decisions, wording,
interface, data file, and lessons in this repository are separate work and
carry this repository's MIT licence. If the original author asks for different
terms, this project will follow them.

Checked 28 August 2026.

## Universal Dependencies English treebank

`data/treebank/` holds material derived from the Universal Dependencies English
Web Treebank, version 2.18, released 2026-05-15:
<https://github.com/UniversalDependencies/UD_English-EWT>.

- `en_ewt-train-excerpt.conllu` is the first 500 sentences of the training
  split.
- `en_ewt-held-out.conllu` is the first 200 sentences of the development split
  and is used only for scoring.
- `en_ewt-500-tagger.udpipe` is a part-of-speech tagger trained on that
  500-sentence excerpt alone, using `data-raw/build-treebank-tagger.R`.
- `tagger-learning-curve.csv` records held-out accuracy for taggers trained on
  100 to 2000 sentences.
- `treebank-metadata.csv` records the source, retrieval date, licence, and a
  SHA-256 fingerprint for each file.

The treebank is published under
[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). The excerpts
and the trained tagger are derived from it and carry the same licence and
share-alike requirement, which is separate from this repository's MIT licence.

The pre-trained UDPipe models distributed through `udpipe_download_model()` are
**not** used here. Most of them, including the full English model, carry a
CC BY-SA-NC licence, and this project does not publish output derived from
material restricted to non-commercial use.

## spaCy and its English pipeline

Some lessons use [spaCy](https://spacy.io/) through the
[spacyr](https://cran.r-project.org/package=spacyr) package. spaCy is a Python
library, so R reaches it through reticulate. Both spaCy and the
`en_core_web_sm` pipeline are published under the MIT licence, which is why
output derived from them can appear here.

Versions are pinned in `requirements-spacy.txt`: spaCy 3.8.7 and
`en_core_web_sm` 3.8.0. `R/use-spacy.R` finds the project's Python environment
and starts the pipeline, and stops with setup instructions if it is missing.
Nothing is downloaded while a page renders.

The UDPipe models in `data/treebank/` were trained in this repository on the
documented 500-sentence excerpt and are deliberately weak teaching models.
Comparisons with the released spaCy pipeline demonstrate provenance and domain
effects; they are not fair model contests.

The pipeline was trained on written web text. It has never seen the invented
names in this project, and the lessons show it making mistakes on them. Those
mistakes are reported as evidence about domain mismatch, not as defects in the
package.

## Open English WordNet extract

`data/wordnet/` contains a 38-lemma extract from
[Open English WordNet 2024](https://en-word.net/), generated by
`data-raw/build-wordnet-extract.R` from the Open English WordNet XML release.
The committed CSV files cover senses, synsets, synset members, hypernym and
hyponym relations, and source metadata.

Open English WordNet is used under the
[Creative Commons Attribution 4.0 International licence](https://creativecommons.org/licenses/by/4.0/).
The metadata file records the source URL, source version, attribution text,
artifact counts, and SHA-256 fingerprints for the committed extract files.

## Hugging Face Hub

Hugging Face hosts datasets from many contributors. Dataset cards can state a
license, language, size, and known limitations:
<https://huggingface.co/docs/hub/datasets-cards>.

There is no single license or consent determination for every Hub dataset.
Researchers must inspect the card, repository files, source provenance, and
applicable terms before downloading or transmitting data.

## Local generation models

Lessons 65 through 68, 70, 71, and 72 prepare three public model snapshots
before rendering. `data/nlg-models.csv` records their immutable revisions, task
scope, model-card links, and review date. `data/nlg-model-files.csv` binds every
recorded weight, tokenizer, vocabulary/merge, SentencePiece, configuration, and
generation-configuration file to the same model ID and revision, with its
exact byte count and SHA-256 fingerprint.

- `Helsinki-NLP/opus-mt-en-fr` at revision
  `dd7f6540a7a48a7f4db59e5c0b9c42c8eea67f18` is an English-to-French
  Marian translation model under Apache-2.0.
- `Qwen/Qwen2.5-1.5B-Instruct` at revision
  `989aa7980e4cf806f80c7fef2b1adb7bc71aa306` is an instruction-tuned
  causal language model under Apache-2.0. The lessons use it for small,
  constructed summarization, paraphrasing, multi-section generation,
  question-answering, and dialogue demonstrations.
- `sentence-transformers/all-MiniLM-L6-v2` at revision
  `1110a243fdf4706b3f48f1d95db1a4f5529b4d41` is a six-layer sentence-embedding
  model under Apache-2.0. Its model card says it was fine-tuned with a
  contrastive objective on a concatenation of public datasets totalling more
  than one billion sentence pairs, that training sequences were limited to 128
  tokens, and that input longer than 256 word pieces is truncated by default.
  Lesson 72 uses it to embed the constructed handbook passages. Besides the
  weights and tokenizer, the manifest records the model's pooling, module, and
  sequence-length configuration files because the lesson reads them.

The model cards document software provenance and intended use, but they do not
establish that generated lesson outputs are correct. The lessons preserve
visible omissions and unsupported additions and keep human factual, bilingual,
and prose review pending. Constructed records are teaching probes, not random
held-out benchmarks, and unknown pretraining overlap prevents a claim that the
models have never seen similar wording.

Model weights are downloaded by `scripts/setup-nlg-models.py` into the ignored
`data-raw/.cache/nlg-models/` directory. They are not redistributed in this
repository. Setup verifies every recorded file after download or cache restore,
and an existing mismatched snapshot fails closed rather than being repaired by
a silent redownload. The R loader repeats that verification before loading.
Rendering sets Hugging Face and Transformers offline modes and fails if a
prepared snapshot is absent or changed.
