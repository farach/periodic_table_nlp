# Build the treebank fixtures and tagger used by task 17.
#
# This script is run by hand, not during a render. It needs local copies of
# the Universal Dependencies English EWT training and development files,
# which are recorded in DATA_SOURCES.md. Training several taggers takes a few
# minutes, which is why the results are committed rather than rebuilt on every
# render.
#
# Usage:
#   Rscript data-raw/build-treebank-tagger.R <train.conllu> <dev.conllu>

suppressPackageStartupMessages({
  library(udpipe)
  library(readr)
  library(dplyr)
  library(purrr)
  library(digest)
})

args <- commandArgs(trailingOnly = TRUE)
stopifnot(
  length(args) == 2L,
  file.exists(args[[1]]),
  file.exists(args[[2]])
)

# UDPipe's tagger training walks the sentences in file order, so the result is
# fixed by the input. The seed is set anyway so that any future step which does
# draw random numbers cannot quietly make the committed artifacts unrepeatable.
set.seed(20260828)

out_dir <- "data/treebank"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

published_sentences <- 500L
curve_sizes <- c(100L, 250L, 500L, 1000L, 2000L)
held_out_sentences <- 200L

treebank_version <- "UD English EWT v2.18, released 2026-05-15"
treebank_url <- "https://github.com/UniversalDependencies/UD_English-EWT"
retrieved_on <- "2026-08-28"

hash_lines <- function(path) {
  digest(
    paste(read_lines(path), collapse = "\n"),
    algo = "sha256",
    serialize = FALSE
  )
}

# CoNLL-U separates sentences with a blank line, so cutting on those breaks
# keeps whole sentences together.
first_sentences <- function(lines, n) {
  breaks <- which(!nzchar(lines))
  stopifnot(length(breaks) >= n)
  lines[seq_len(breaks[n])]
}

count_tokens <- function(path) {
  lines <- read_lines(path)
  sum(
    nzchar(lines) &
      !startsWith(lines, "#") &
      !grepl("^[0-9]+[-.][0-9]+\t", lines)
  )
}

train_lines <- read_lines(args[[1]])
dev_lines <- read_lines(args[[2]])

# --- 1. Committed excerpts --------------------------------------------------

train_path <- file.path(out_dir, "en_ewt-train-excerpt.conllu")
held_out_path <- file.path(out_dir, "en_ewt-held-out.conllu")

write_lines(first_sentences(train_lines, published_sentences), train_path)
write_lines(first_sentences(dev_lines, held_out_sentences), held_out_path)

cat(sprintf(
  "training excerpt: %d sentences, %d tokens\nheld out: %d sentences, %d tokens\n",
  published_sentences,
  count_tokens(train_path),
  held_out_sentences,
  count_tokens(held_out_path)
))

# --- 2. Taggers and the learning curve --------------------------------------

train_tagger <- function(conllu_path, model_path) {
  invisible(capture.output(
    udpipe_train(
      file = model_path,
      files_conllu_training = conllu_path,
      annotation_tokenizer = "none",
      annotation_tagger = "default",
      annotation_parser = "none"
    ),
    type = "message"
  ))
  model_path
}

gold <- udpipe_read_conllu(held_out_path) |>
  as_tibble() |>
  # CoNLL-U also carries multiword spans such as "5-6" and empty nodes such
  # as "5.1". Those describe other rows rather than carrying a tag, so only
  # plain numbered tokens are scored.
  filter(!grepl("[^0-9]", token_id), !is.na(upos)) |>
  transmute(
    sentence_key = sentence_id,
    token_number = as.integer(token_id),
    token,
    gold_upos = upos
  ) |>
  arrange(sentence_key, token_number)

held_out_documents <- gold |>
  distinct(sentence_key) |>
  mutate(document = sprintf("s%04d", row_number()))

gold_flat <- gold |>
  left_join(held_out_documents, by = "sentence_key") |>
  arrange(document, token_number)

# Feed the held-out tokens back one per line so the tagger only tags and never
# re-tokenises. Its score is then about tagging alone.
vertical_gold <- gold_flat |>
  group_by(document) |>
  summarise(text = paste(token, collapse = "\n"), .groups = "drop") |>
  arrange(document)

tag_vertical <- function(model) {
  udpipe_annotate(
    model,
    x = vertical_gold$text,
    doc_id = vertical_gold$document,
    tokenizer = "vertical",
    tagger = "default",
    parser = "none"
  ) |>
    as.data.frame() |>
    as_tibble() |>
    transmute(
      document = doc_id,
      token_number = as.integer(token_id),
      predicted_token = token,
      upos
    ) |>
    arrange(document, token_number)
}

curve <- map(curve_sizes, function(n) {
  conllu <- tempfile(fileext = ".conllu")
  write_lines(first_sentences(train_lines, n), conllu)

  model_path <- if (identical(n, published_sentences)) {
    file.path(out_dir, "en_ewt-500-tagger.udpipe")
  } else {
    tempfile(fileext = ".udpipe")
  }

  train_tagger(conllu, model_path)
  predicted <- tag_vertical(udpipe_load_model(model_path))

  # Both tables are sorted the same way and the tokens were supplied, so a
  # positional comparison is safe once the token sequences are confirmed.
  stopifnot(
    identical(nrow(predicted), nrow(gold_flat)),
    identical(predicted$document, gold_flat$document),
    identical(predicted$predicted_token, gold_flat$token)
  )

  correct <- sum(predicted$upos == gold_flat$gold_upos)
  accuracy <- correct / nrow(gold_flat)

  cat(sprintf(
    "trained on %5d sentences -> %.4f accuracy on held-out tokens\n",
    n,
    accuracy
  ))

  tibble(
    training_sentences = n,
    training_tokens = count_tokens(conllu),
    held_out_tokens = nrow(gold_flat),
    correct_tokens = correct,
    accuracy = round(accuracy, 4)
  )
}) |>
  list_rbind()

curve_path <- file.path(out_dir, "tagger-learning-curve.csv")
write_csv(curve, curve_path)

# --- 3. Provenance ----------------------------------------------------------

metadata <- tibble(
  artifact = c(
    "en_ewt-train-excerpt.conllu",
    "en_ewt-held-out.conllu",
    "en_ewt-500-tagger.udpipe",
    "tagger-learning-curve.csv"
  ),
  description = c(
    sprintf(
      "First %d sentences of the EWT training split",
      published_sentences
    ),
    sprintf(
      "First %d sentences of the EWT development split, used only for scoring",
      held_out_sentences
    ),
    sprintf(
      "UDPipe tagger trained on the %d-sentence excerpt alone",
      published_sentences
    ),
    "Held-out accuracy for taggers trained on 100 to 2000 sentences"
  ),
  source = treebank_version,
  source_url = treebank_url,
  retrieved_on = retrieved_on,
  license = "CC BY-SA 4.0",
  fingerprint = c(
    hash_lines(train_path),
    hash_lines(held_out_path),
    digest(
      file.path(out_dir, "en_ewt-500-tagger.udpipe"),
      algo = "sha256",
      file = TRUE
    ),
    hash_lines(curve_path)
  )
)

write_csv(metadata, file.path(out_dir, "treebank-metadata.csv"))

cat("\nwrote:\n")
print(
  tibble(file = list.files(out_dir, full.names = TRUE)) |>
    mutate(bytes = file.size(file))
)
