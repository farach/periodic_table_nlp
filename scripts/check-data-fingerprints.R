# Verify that every committed data artifact still matches its recorded fingerprint.
#
# Several `data-raw/` builders record a SHA-256 or MD5 for what they wrote. Until
# now nothing checked those records, so a committed file could drift from its
# metadata and only be caught later by an opaque assertion failure in a lesson.
#
# Two hash methods are in use across the builders, and the difference matters:
#
#   byte             digest(file = path)
#   line-normalised  digest(paste(read_lines(path), collapse = "\n"))
#
# The line-normalised form is what most builders record, because it is stable
# across a CRLF checkout and an LF checkout. A byte hash of a text file is only
# stable because `.gitattributes` pins `eol=lf`. An earlier audit reported twelve
# stale fingerprints by comparing byte hashes against line-normalised records;
# every one of those was a false alarm. This script therefore accepts a match
# under either method and reports which one matched, so a real drift still fails
# while a method mismatch does not.
#
# Usage: Rscript scripts/check-data-fingerprints.R

suppressWarnings(suppressMessages({
  library(digest)
}))

read_bytes <- function(path) {
  con <- file(path, open = "rb")
  on.exit(close(con), add = TRUE)
  readBin(con, "raw", n = file.size(path))
}

hash_byte <- function(path, algo) digest(file = path, algo = algo)

hash_normalised <- function(path, algo) {
  raw <- read_bytes(path)
  if (any(raw == as.raw(0))) return(NA_character_)
  raw <- raw[raw != as.raw(13)]
  text <- sub("\n$", "", rawToChar(raw))
  digest(text, algo = algo, serialize = FALSE)
}

# Each entry names a metadata file, the column holding the artifact name, the
# column holding the fingerprint, the directory the artifact lives in, and the
# algorithm. `field_value` metadata stores one row per field instead of one row
# per artifact, so it carries an explicit name-to-file map.
sources <- list(
  list(
    metadata = "data/inaugural/inaugural-metadata.csv",
    shape = "artifact", name_column = "artifact",
    hash_column = "fingerprint", dir = "data/inaugural", algo = "sha256"
  ),
  list(
    metadata = "data/inaugural/model-comparison-metadata.csv",
    shape = "artifact", name_column = "artifact",
    hash_column = "fingerprint", dir = "data/inaugural", algo = "sha256"
  ),
  list(
    metadata = "data/inaugural/topic-k-diagnostics-metadata.csv",
    shape = "artifact", name_column = "artifact",
    hash_column = "fingerprint", dir = "data/inaugural", algo = "sha256"
  ),
  list(
    metadata = "data/treebank/treebank-metadata.csv",
    shape = "artifact", name_column = "artifact",
    hash_column = "fingerprint", dir = "data/treebank", algo = "sha256"
  ),
  list(
    metadata = "data/riverton/riverton-reference-metadata.csv",
    shape = "artifact", name_column = "artifact",
    hash_column = "fingerprint", dir = "data/riverton", algo = "sha256"
  ),
  list(
    metadata = "data/riverton/riverton-inbox-metadata.csv",
    shape = "artifact", name_column = "artifact",
    hash_column = "fingerprint", dir = "data/riverton", algo = "sha256"
  ),
  list(
    metadata = "data/wordnet/wordnet-metadata.csv",
    shape = "field_value", dir = "data/wordnet", algo = "sha256",
    map = c(
      sha256_senses = "wordnet-senses.csv",
      sha256_synsets = "wordnet-synsets.csv",
      sha256_members = "wordnet-members.csv",
      sha256_relations = "wordnet-relations.csv"
    )
  ),
  list(
    metadata = "data/word2vec/word2vec-metadata.csv",
    shape = "field_value", dir = "data/word2vec", algo = "sha256",
    map = c(sha256_model = "inaugural-word2vec.bin")
  )
)

failures <- character()
checked <- 0L
methods <- character()

for (source in sources) {
  if (!file.exists(source$metadata)) {
    failures <- c(failures, sprintf("missing metadata file: %s", source$metadata))
    next
  }

  metadata <- read.csv(source$metadata, colClasses = "character", check.names = FALSE)

  if (identical(source$shape, "field_value")) {
    entries <- data.frame(
      name = unname(source$map),
      hash = vapply(
        names(source$map),
        function(field) {
          value <- metadata$value[metadata$field == field]
          if (length(value) == 1L) value else NA_character_
        },
        character(1)
      ),
      stringsAsFactors = FALSE
    )
  } else {
    entries <- data.frame(
      name = metadata[[source$name_column]],
      hash = metadata[[source$hash_column]],
      stringsAsFactors = FALSE
    )
  }

  for (row in seq_len(nrow(entries))) {
    artifact <- entries$name[[row]]
    recorded <- entries$hash[[row]]
    path <- file.path(source$dir, artifact)

    if (is.na(recorded) || !nzchar(recorded)) {
      failures <- c(failures, sprintf("%s has no recorded fingerprint", path))
      next
    }
    if (!file.exists(path)) {
      failures <- c(failures, sprintf("%s is recorded in %s but does not exist", path, source$metadata))
      next
    }

    checked <- checked + 1L
    observed_byte <- hash_byte(path, source$algo)
    observed_norm <- hash_normalised(path, source$algo)

    if (identical(observed_byte, recorded)) {
      methods <- c(methods, "byte")
    } else if (!is.na(observed_norm) && identical(observed_norm, recorded)) {
      methods <- c(methods, "line-normalised")
    } else {
      failures <- c(
        failures,
        sprintf(
          "%s does not match %s\n  recorded        %s\n  byte            %s\n  line-normalised %s",
          path, source$metadata, recorded, observed_byte,
          if (is.na(observed_norm)) "not applicable (binary)" else observed_norm
        )
      )
    }
  }
}

if (length(failures) > 0) {
  cat("Data fingerprint scan failed.\n\n")
  cat(paste(failures, collapse = "\n"), "\n\n")
  cat("Re-run the builder in data-raw/ that produced the file, or correct the metadata.\n")
  quit(status = 1)
}

cat(sprintf(
  "Data fingerprint scan passed: %d artifacts (%d byte, %d line-normalised).\n",
  checked,
  sum(methods == "byte"),
  sum(methods == "line-normalised")
))
