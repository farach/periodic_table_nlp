# Train the word2vec model used by task 61, once, and commit the result.
#
# `word2vec::word2vec()` is not bitwise reproducible on this package version.
# Setting a seed and `threads = 1L` still leaves the nearest-neighbour lists
# changing between fits: across five fits on this corpus the similarity values
# moved by about 0.03, which is small, but the ORDER of the neighbours changed
# every time. A lesson that prints neighbour words would therefore print
# different words on every render, and nothing on the page could be checked.
#
# So the fit happens here, by hand, and the lesson loads the saved model. The
# instability is not hidden; task 61 reports it and explains why the model is
# pinned.
#
# Usage (from the repository root):
#   Rscript data-raw/build-word2vec-model.R

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
  library(tibble)
  library(quanteda)
  library(word2vec)
  library(digest)
})

source("R/inaugural-corpus.R")

out_dir <- "data/word2vec"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

paragraphs <- inaugural_paragraphs()

# word2vec splits on whitespace and expects text that is already lowercased with
# punctuation removed. Skipping this leaves rows such as `peace.` and `peace,`
# competing for the same word's evidence.
training_text <- tokens(
  str_to_lower(paragraphs$paragraph),
  remove_punct = TRUE,
  remove_numbers = TRUE
) |>
  vapply(paste, character(1), collapse = " ")

settings <- list(
  type = "skip-gram",
  dim = 50L,
  window = 5L,
  iter = 5L,
  min_count = 5L,
  threads = 1L
)

set.seed(6100)
model <- word2vec(
  x = training_text,
  type = settings$type,
  dim = settings$dim,
  window = settings$window,
  iter = settings$iter,
  min_count = settings$min_count,
  threads = settings$threads
)

model_path <- file.path(out_dir, "inaugural-word2vec.bin")
write.word2vec(model, file = model_path)

# Confirm the saved model reloads and answers the same way the fitted one does.
reloaded <- read.word2vec(model_path)
check_fitted <- predict(model, newdata = "freedom", type = "nearest", top_n = 5L)[[1]]
check_reloaded <- predict(reloaded, newdata = "freedom", type = "nearest", top_n = 5L)[[1]]
stopifnot(
  identical(check_fitted$term2, check_reloaded$term2),
  isTRUE(all.equal(check_fitted$similarity, check_reloaded$similarity))
)

embedding <- as.matrix(reloaded)
vocabulary <- rownames(embedding)

total_tokens <- sum(str_count(training_text, "\\S+"))
punctuation_rows <- sum(str_detect(vocabulary, "[[:punct:]]"))

metadata <- tibble(
  field = c(
    "source", "licence", "generator", "built_on",
    "algorithm", "dimensions", "window", "iterations", "minimum_count", "threads",
    "training_documents", "training_tokens", "vocabulary_rows",
    "punctuation_rows", "unique_pairs", "reproducibility", "sha256_model"
  ),
  value = c(
    "quanteda data_corpus_inaugural, reshaped by R/inaugural-corpus.R",
    "Speeches are US government works in the public domain",
    "data-raw/build-word2vec-model.R",
    "2026-08-29",
    settings$type,
    as.character(settings$dim),
    as.character(settings$window),
    as.character(settings$iter),
    as.character(settings$min_count),
    as.character(settings$threads),
    as.character(length(training_text)),
    as.character(total_tokens),
    as.character(nrow(embedding)),
    as.character(punctuation_rows),
    as.character(choose(nrow(embedding), 2)),
    paste(
      "word2vec is not bitwise reproducible on this package version.",
      "Across five fits with the same seed the neighbour order changed every time,",
      "so this model is trained once here and committed."
    ),
    digest(file = model_path, algo = "sha256")
  )
)

write_csv(metadata, file.path(out_dir, "word2vec-metadata.csv"), na = "")

cat("wrote", model_path, "(", file.size(model_path), "bytes )\n\n")
print(as.data.frame(metadata), right = FALSE)
