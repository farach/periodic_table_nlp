# Build the dependency parser used by tasks 18 and 26.
#
# Run by hand, not during a render. Training the parser takes several minutes,
# which is why the model is committed. It learns from the same 500-sentence
# treebank excerpt as the tagger, so the two are directly comparable.
#
# Usage:
#   Rscript data-raw/build-treebank-parser.R

suppressPackageStartupMessages({
  library(udpipe)
  library(readr)
  library(dplyr)
  library(digest)
})

set.seed(20260828)

out_dir <- "data/treebank"
excerpt_path <- file.path(out_dir, "en_ewt-train-excerpt.conllu")
held_out_path <- file.path(out_dir, "en_ewt-held-out.conllu")
parser_path <- file.path(out_dir, "en_ewt-500-parser.udpipe")

stopifnot(file.exists(excerpt_path), file.exists(held_out_path))

invisible(capture.output(
  udpipe_train(
    file = parser_path,
    files_conllu_training = excerpt_path,
    annotation_tokenizer = "none",
    annotation_tagger = "default",
    annotation_parser = "default"
  ),
  type = "message"
))

stopifnot(file.exists(parser_path))

# Score the parser on the held-out sentences the tagger was also scored on.
# Unlabelled attachment is the share of tokens given the correct head word;
# labelled attachment also requires the correct relation name.
read_gold <- function(path) {
  udpipe_read_conllu(path) |>
    as_tibble() |>
    filter(!grepl("[^0-9]", token_id), !is.na(upos)) |>
    transmute(
      sentence_key = sentence_id,
      token_number = as.integer(token_id),
      token,
      gold_head = as.integer(head_token_id),
      gold_rel = dep_rel
    ) |>
    arrange(sentence_key, token_number)
}

gold <- read_gold(held_out_path)
documents <- gold |>
  distinct(sentence_key) |>
  mutate(document = sprintf("s%04d", row_number()))

flat_gold <- gold |>
  left_join(documents, by = "sentence_key") |>
  arrange(document, token_number)

vertical <- flat_gold |>
  group_by(document) |>
  summarise(text = paste(token, collapse = "\n"), .groups = "drop") |>
  arrange(document)

parser <- udpipe_load_model(parser_path)

predicted <- udpipe_annotate(
  parser,
  x = vertical$text,
  doc_id = vertical$document,
  tokenizer = "vertical",
  tagger = "default",
  parser = "default"
) |>
  as.data.frame() |>
  as_tibble() |>
  transmute(
    document = doc_id,
    token_number = as.integer(token_id),
    token,
    head = as.integer(head_token_id),
    rel = dep_rel
  ) |>
  arrange(document, token_number)

stopifnot(
  identical(nrow(predicted), nrow(flat_gold)),
  identical(predicted$document, flat_gold$document),
  identical(predicted$token, flat_gold$token)
)

unlabelled <- mean(predicted$head == flat_gold$gold_head)
labelled <- mean(
  predicted$head == flat_gold$gold_head & predicted$rel == flat_gold$gold_rel
)

score <- tibble(
  measure = c(
    "held_out_tokens",
    "correct_head",
    "unlabelled_attachment",
    "correct_head_and_relation",
    "labelled_attachment"
  ),
  value = c(
    as.character(nrow(flat_gold)),
    as.character(sum(predicted$head == flat_gold$gold_head)),
    format(round(unlabelled, 4), nsmall = 4),
    as.character(
      sum(predicted$head == flat_gold$gold_head & predicted$rel == flat_gold$gold_rel)
    ),
    format(round(labelled, 4), nsmall = 4)
  )
)

score_path <- file.path(out_dir, "parser-held-out-score.csv")
write_csv(score, score_path)

cat("parser scores\n")
print(score)

metadata <- read_csv(
  file.path(out_dir, "treebank-metadata.csv"),
  col_types = cols(.default = col_character())
)

hash_lines <- function(path) {
  digest(
    paste(read_lines(path), collapse = "\n"),
    algo = "sha256",
    serialize = FALSE
  )
}

new_rows <- tibble(
  artifact = c("en_ewt-500-parser.udpipe", "parser-held-out-score.csv"),
  description = c(
    "UDPipe tagger and dependency parser trained on the 500-sentence excerpt",
    "Held-out attachment scores for that parser"
  ),
  source = metadata$source[[1]],
  source_url = metadata$source_url[[1]],
  retrieved_on = metadata$retrieved_on[[1]],
  license = "CC BY-SA 4.0",
  fingerprint = c(
    digest(parser_path, algo = "sha256", file = TRUE),
    hash_lines(score_path)
  )
)

metadata |>
  filter(!artifact %in% new_rows$artifact) |>
  bind_rows(new_rows) |>
  arrange(artifact) |>
  write_csv(file.path(out_dir, "treebank-metadata.csv"))

cat("\nwrote:\n")
print(
  tibble(file = list.files(out_dir, full.names = TRUE)) |>
    mutate(bytes = file.size(file))
)
