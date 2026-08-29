source("R/workforce-codebook.R")

codebook <- workforce_codebook()
recorded_codebook <- workforce_codebook("1.0.0")

rebuild_codebook <- function(
    instructions = codebook$instructions,
    schema = codebook$schema,
    examples = codebook$examples,
    version = codebook$version) {
  foundryR::foundry_codebook(
    name = codebook$name,
    version = version,
    instructions = instructions,
    schema = schema,
    examples = examples
  )
}

same_codebook <- rebuild_codebook()

changed_instructions <- rebuild_codebook(
  instructions = paste(
    codebook$instructions,
    "Added instruction."
  )
)

changed_schema <- codebook$schema
changed_schema$properties$rationale$description <-
  "A revised rationale description"
changed_schema_codebook <- rebuild_codebook(
  schema = changed_schema
)

changed_examples <- rebuild_codebook(
  examples = c(
    codebook$examples,
    list(
      list(
        text = "Added example.",
        label = "other",
        rationale = "Added for a mutation test.",
        uncertainty = "certain"
      )
    )
  )
)

changed_version <- rebuild_codebook(
  version = "1.0.1"
)

stopifnot(
  identical(codebook$hash, same_codebook$hash),
  identical(recorded_codebook$version, "1.0.0"),
  identical(
    recorded_codebook$hash,
    "eb8e5fa0b3176d139fe6ea3f9b70d4cd25ef9631656aae128b512ecd16598da2"
  ),
  !identical(codebook$hash, recorded_codebook$hash),
  !identical(
    codebook$hash,
    changed_instructions$hash
  ),
  !identical(
    codebook$hash,
    changed_schema_codebook$hash
  ),
  !identical(
    codebook$hash,
    changed_examples$hash
  ),
  !identical(
    codebook$hash,
    changed_version$hash
  )
)

sentences <- read.csv(
  "data/workforce/workforce_sentences.csv",
  colClasses = "character",
  check.names = FALSE
)

stopifnot(
  identical(nrow(sentences), 28L),
  identical(
    sentences$sentence_id,
    sprintf("s%03d", 1:28)
  ),
  all(sentences$codebook_hash == recorded_codebook$hash),
  all(
    sentences$codebook_version ==
      recorded_codebook$version
  ),
  all(sentences$transformation == "verbatim"),
  all(sentences$derived == "false")
)

job_sentences <- sentences[
  grepl("^J", sentences$document_id),
]
flyer_sentences <- sentences[
  sentences$document_id == "F001",
]
flyer_transcript <- readLines(
  paste0(
    "data/workforce/",
    "training-flyer-ground-truth.txt"
  ),
  encoding = "UTF-8",
  warn = TRUE
)
transcript_md5 <- digest::digest(
  paste(flyer_transcript, collapse = "\n"),
  algo = "md5",
  serialize = FALSE
)
recorded_ocr <- readLines(
  paste0(
    "data/workforce/",
    "training-flyer-ocr-5.3.2.txt"
  ),
  encoding = "UTF-8",
  warn = TRUE
)
recorded_degraded_ocr <- readLines(
  paste0(
    "data/workforce/",
    "training-flyer-degraded-ocr-5.3.2.txt"
  ),
  encoding = "UTF-8",
  warn = TRUE
)
degraded_ocr_md5 <- digest::digest(
  paste(recorded_degraded_ocr, collapse = "\n"),
  algo = "md5",
  serialize = FALSE
)

stopifnot(
  identical(nrow(job_sentences), 22L),
  identical(nrow(flyer_sentences), 6L),
  identical(flyer_sentences$text, flyer_transcript),
  identical(recorded_ocr, flyer_transcript),
  !identical(recorded_degraded_ocr, flyer_transcript)
)

job_metadata <- read.csv(
  "data/workforce/job-board-metadata.csv",
  colClasses = "character",
  check.names = FALSE
)
flyer_metadata <- read.csv(
  "data/workforce/training-flyer-metadata.csv",
  colClasses = "character",
  check.names = FALSE
)

stopifnot(
  identical(
    digest::digest(
      paste(
        readLines(
          job_metadata$source_file,
          encoding = "UTF-8",
          warn = TRUE
        ),
        collapse = "\n"
      ),
      algo = "md5",
      serialize = FALSE
    ),
    job_metadata$md5
  ),
  identical(
    unname(
      tools::md5sum(
        "data/workforce/training-flyer.png"
      )
    ),
    flyer_metadata$md5[
      flyer_metadata$artifact ==
        "training-flyer.png"
    ]
  ),
  identical(
    transcript_md5,
    flyer_metadata$md5[
      flyer_metadata$artifact ==
        "training-flyer-ground-truth.txt"
    ]
  ),
  identical(
    degraded_ocr_md5,
    flyer_metadata$md5[
      flyer_metadata$artifact ==
        "training-flyer-degraded-ocr-5.3.2.txt"
    ]
  )
)

cat(
  paste0(
    "Workforce data passed: codebook mutation tests, ",
    "28 row-level sources, and stored fingerprints.\n"
  )
)
