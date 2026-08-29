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
- `data/workforce/training-flyer.png`

They contain no real workers, applicants, employers, customers, or research
participants. Their purpose is to make code and research-design problems small
enough to inspect. They must not be used to make claims about a population.

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

## Hugging Face Hub

Hugging Face hosts datasets from many contributors. Dataset cards can state a
license, language, size, and known limitations:
<https://huggingface.co/docs/hub/datasets-cards>.

There is no single license or consent determination for every Hub dataset.
Researchers must inspect the card, repository files, source provenance, and
applicable terms before downloading or transmitting data.
