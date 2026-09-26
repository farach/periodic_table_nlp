# Build the speech-grouped next-token study for lessons 63 and 64.
#
# Candidate context lengths are compared on validation speeches. The selected
# model and a predeclared unigram baseline are then scored on untouched test
# speeches. No context crosses a paragraph boundary.
#
# Usage:
#   Rscript data-raw/build-next-token-study.R

options(warn = 2)

suppressPackageStartupMessages({
  library(digest)
  library(dplyr)
  library(purrr)
  library(readr)
  library(rsample)
  library(stringr)
  library(tibble)
  library(tidyr)
})

source("R/inaugural-corpus.R")

out_dir <- "data/inaugural"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

vocabulary_size <- 2500L
candidate_strengths <- c(0.1, 1, 10, 100, 1000, 10000)
token_pattern <- paste0(
  "(?:[a-z]\\.){2,}|",
  "[a-z0-9]+(?:['\\x{2019}][a-z0-9]+)*"
)

paragraphs <- inaugural_paragraphs()
speeches <- paragraphs |>
  distinct(speech_id, era)

set.seed(6301)
development_split <- initial_split(
  speeches,
  prop = 0.8,
  strata = era
)
development_speeches <- training(development_split)
test_speeches <- testing(development_split)

set.seed(6302)
selection_split <- initial_split(
  development_speeches,
  prop = 0.8,
  strata = era
)
training_speeches <- training(selection_split)
validation_speeches <- testing(selection_split)

split_assignments <- bind_rows(
  training_speeches |> mutate(split = "training"),
  validation_speeches |> mutate(split = "validation"),
  test_speeches |> mutate(split = "test")
) |>
  mutate(
    split = factor(
      split,
      levels = c("training", "validation", "test")
    )
  ) |>
  arrange(split, speech_id) |>
  mutate(split = as.character(split))

tokens <- paragraphs |>
  select(paragraph_id, speech_id, paragraph) |>
  inner_join(split_assignments, by = join_by(speech_id)) |>
  mutate(
    token = str_extract_all(
      str_to_lower(paragraph, locale = "en"),
      regex(token_pattern)
    )
  ) |>
  select(-paragraph) |>
  unnest_longer(token) |>
  filter(str_detect(token, "^[a-z]+$")) |>
  mutate(position = row_number(), .by = paragraph_id)

training_vocabulary <- tokens |>
  filter(split == "training") |>
  count(token, sort = TRUE) |>
  slice_head(n = vocabulary_size - 1L) |>
  pull(token)
model_vocabulary <- c(training_vocabulary, "<unk>")

model_tokens <- tokens |>
  mutate(
    model_token = if_else(
      token %in% training_vocabulary,
      token,
      "<unk>"
    )
  ) |>
  arrange(paragraph_id, position) |>
  mutate(
    previous_1 = lag(model_token, 1L),
    previous_2 = lag(model_token, 2L),
    .by = paragraph_id
  )

next_token_rows <- model_tokens |>
  filter(position >= 3L) |>
  transmute(
    paragraph_id,
    speech_id,
    split,
    previous_2,
    previous_1,
    next_token = model_token
  )

training_rows <- filter(next_token_rows, split == "training")
validation_rows <- filter(next_token_rows, split == "validation")
test_rows <- filter(next_token_rows, split == "test")

unigram_counts <- model_tokens |>
  filter(split == "training") |>
  count(model_token, name = "unigram_count")
training_token_total <- sum(unigram_counts$unigram_count)

unigram_probabilities <- tibble(
  model_token = model_vocabulary
) |>
  left_join(unigram_counts, by = join_by(model_token)) |>
  mutate(
    unigram_count = replace_na(unigram_count, 0L),
    unigram_probability = (unigram_count + 1) /
      (training_token_total + length(model_vocabulary))
  )

bigram_counts <- training_rows |>
  count(previous_1, next_token, name = "bigram_count")
previous_1_counts <- training_rows |>
  count(previous_1, name = "previous_1_count")

trigram_counts <- training_rows |>
  count(
    previous_2,
    previous_1,
    next_token,
    name = "trigram_count"
  )
previous_2_1_counts <- training_rows |>
  count(
    previous_2,
    previous_1,
    name = "previous_2_1_count"
  )

score_rows <- function(data, interpolation_strength) {
  data |>
    left_join(
      unigram_probabilities,
      by = join_by(next_token == model_token)
    ) |>
    left_join(
      bigram_counts,
      by = join_by(previous_1, next_token)
    ) |>
    left_join(previous_1_counts, by = join_by(previous_1)) |>
    left_join(
      trigram_counts,
      by = join_by(previous_2, previous_1, next_token)
    ) |>
    left_join(
      previous_2_1_counts,
      by = join_by(previous_2, previous_1)
    ) |>
    mutate(
      across(
        c(
          bigram_count,
          previous_1_count,
          trigram_count,
          previous_2_1_count
        ),
        \(value) replace_na(value, 0L)
      ),
      bigram_probability = (
        bigram_count +
          interpolation_strength * unigram_probability
      ) / (
        previous_1_count +
          interpolation_strength
      ),
      trigram_probability = (
        trigram_count +
          interpolation_strength * bigram_probability
      ) / (
        previous_2_1_count +
          interpolation_strength
      )
    )
}

summarize_unigram <- function(data, split_name) {
  scored <- score_rows(data, interpolation_strength = 1)
  tibble(
    split = split_name,
    model = "unigram",
    context_tokens = 0L,
    interpolation_strength = NA_real_,
    next_token_rows = nrow(scored),
    oov_target_share = mean(scored$next_token == "<unk>"),
    seen_context_share = NA_real_,
    mean_log_loss = -mean(log(scored$unigram_probability)),
    perplexity = exp(mean_log_loss)
  )
}

summarize_context_models <- function(
  data,
  split_name,
  interpolation_strength
) {
  scored <- score_rows(data, interpolation_strength)

  tibble(
    split = split_name,
    model = c("bigram", "trigram"),
    context_tokens = 1:2,
    interpolation_strength = interpolation_strength,
    next_token_rows = nrow(scored),
    oov_target_share = mean(scored$next_token == "<unk>"),
    seen_context_share = c(
      mean(scored$previous_1_count > 0L),
      mean(scored$previous_2_1_count > 0L)
    ),
    mean_log_loss = c(
      -mean(log(scored$bigram_probability)),
      -mean(log(scored$trigram_probability))
    )
  ) |>
    mutate(perplexity = exp(mean_log_loss))
}

validation_results <- bind_rows(
  summarize_unigram(validation_rows, "validation"),
  candidate_strengths |>
    map(\(strength) {
      summarize_context_models(
        validation_rows,
        "validation",
        strength
      )
    }) |>
    list_rbind()
) |>
  arrange(context_tokens, interpolation_strength)

selected_candidate <- validation_results |>
  slice_min(perplexity, n = 1, with_ties = FALSE) |>
  select(model, interpolation_strength)
selected_model <- selected_candidate$model
selected_strength <- selected_candidate$interpolation_strength

validation_results <- validation_results |>
  mutate(
    selected = replace_na(
      model == selected_model &
        interpolation_strength == selected_strength,
      FALSE
    ),
    selection_reason = if_else(
      selected,
      paste(
        "Lowest validation perplexity across context lengths",
        "and interpolation strengths before opening test"
      ),
      ""
    )
  )

test_scored <- score_rows(test_rows, selected_strength)
selected_probability <- test_scored[[
  paste0(selected_model, "_probability")
]]

unigram_top_token <- unigram_probabilities |>
  slice_max(unigram_probability, n = 1, with_ties = FALSE) |>
  pull(model_token)

bigram_prediction_candidates <- bigram_counts |>
  left_join(
    unigram_probabilities,
    by = join_by(next_token == model_token)
  ) |>
  left_join(previous_1_counts, by = join_by(previous_1)) |>
  mutate(
    bigram_probability = (
      bigram_count +
        selected_strength * unigram_probability
    ) / (
      previous_1_count +
        selected_strength
    )
  )

fallback_candidates <- previous_1_counts |>
  transmute(
    previous_1,
    next_token = unigram_top_token,
    previous_1_count
  ) |>
  left_join(
    bigram_counts,
    by = join_by(previous_1, next_token)
  ) |>
  left_join(
    unigram_probabilities,
    by = join_by(next_token == model_token)
  ) |>
  mutate(
    bigram_count = replace_na(bigram_count, 0L),
    bigram_probability = (
      bigram_count +
        selected_strength * unigram_probability
    ) / (
      previous_1_count +
        selected_strength
    )
  )

bigram_candidate_probabilities <- bind_rows(
  bigram_prediction_candidates,
  fallback_candidates
) |>
  arrange(previous_1, next_token, desc(bigram_count)) |>
  distinct(previous_1, next_token, .keep_all = TRUE)

bigram_top_predictions <- bigram_candidate_probabilities |>
  arrange(
    previous_1,
    desc(bigram_probability),
    next_token
  ) |>
  slice_head(n = 1, by = previous_1) |>
  select(
    previous_1,
    bigram_prediction = next_token
  )

trigram_prediction_candidates <- trigram_counts |>
  left_join(
    bigram_candidate_probabilities |>
      select(
        previous_1,
        next_token,
        bigram_probability
      ),
    by = join_by(previous_1, next_token)
  ) |>
  left_join(
    previous_2_1_counts,
    by = join_by(previous_2, previous_1)
  ) |>
  mutate(
    trigram_probability = (
      trigram_count +
        selected_strength * bigram_probability
    ) / (
      previous_2_1_count +
        selected_strength
    )
  )

trigram_fallback_candidates <- previous_2_1_counts |>
  left_join(
    bigram_top_predictions,
    by = join_by(previous_1)
  ) |>
  transmute(
    previous_2,
    previous_1,
    next_token = bigram_prediction,
    previous_2_1_count
  ) |>
  left_join(
    trigram_counts,
    by = join_by(
      previous_2,
      previous_1,
      next_token
    )
  ) |>
  left_join(
    bigram_candidate_probabilities |>
      select(
        previous_1,
        next_token,
        bigram_probability
      ),
    by = join_by(previous_1, next_token)
  ) |>
  mutate(
    trigram_count = replace_na(trigram_count, 0L),
    trigram_probability = (
      trigram_count +
        selected_strength * bigram_probability
    ) / (
      previous_2_1_count +
        selected_strength
    )
  )

trigram_top_predictions <- bind_rows(
  trigram_prediction_candidates,
  trigram_fallback_candidates
) |>
  arrange(
    previous_2,
    previous_1,
    desc(trigram_probability),
    next_token
  ) |>
  slice_head(
    n = 1,
    by = c(previous_2, previous_1)
  ) |>
  select(
    previous_2,
    previous_1,
    trigram_prediction = next_token
  )

test_predictions <- test_scored |>
  left_join(
    bigram_top_predictions,
    by = join_by(previous_1)
  ) |>
  left_join(
    trigram_top_predictions,
    by = join_by(previous_2, previous_1)
  ) |>
  mutate(
    unigram_prediction = unigram_top_token,
    selected_probability = selected_probability
  )

if (selected_model == "bigram") {
  test_predictions <- test_predictions |>
    mutate(selected_prediction = bigram_prediction)
} else {
  test_predictions <- test_predictions |>
    mutate(
      selected_prediction = coalesce(
        trigram_prediction,
        bigram_prediction
      )
    )
}

selected_prediction_is_correct <-
  test_predictions$selected_prediction == test_predictions$next_token
unknown_bucket_correct_share <- sum(
  selected_prediction_is_correct &
    test_predictions$selected_prediction == "<unk>"
) / sum(selected_prediction_is_correct)
known_target_rows <- test_predictions$next_token != "<unk>"
known_target_top_1_accuracy <- mean(
  test_predictions$selected_prediction[known_target_rows] ==
    test_predictions$next_token[known_target_rows]
)

selected_seen_context <- if (selected_model == "bigram") {
  mean(test_scored$previous_1_count > 0L)
} else {
  mean(test_scored$previous_2_1_count > 0L)
}

test_results <- tibble(
  split = "test",
  model = c("uniform", "unigram", selected_model),
  context_tokens = c(
    0L,
    0L,
    match(selected_model, c("unigram", "bigram", "trigram")) - 1L
  ),
  interpolation_strength = c(NA_real_, NA_real_, selected_strength),
  next_token_rows = nrow(test_scored),
  oov_target_share = mean(test_scored$next_token == "<unk>"),
  seen_context_share = c(
    NA_real_,
    NA_real_,
    selected_seen_context
  ),
  mean_log_loss = c(
    log(vocabulary_size),
    -mean(log(test_scored$unigram_probability)),
    -mean(log(selected_probability))
  ),
  perplexity = exp(mean_log_loss),
  top_1_accuracy = c(
    NA_real_,
    mean(
      test_predictions$unigram_prediction ==
        test_predictions$next_token
    ),
    mean(
      test_predictions$selected_prediction ==
        test_predictions$next_token
    )
  ),
  role = c(
    "uniform vocabulary floor",
    "predeclared frequency baseline",
    "validation-selected model"
  )
)

test_by_speech <- test_predictions |>
  summarise(
    unigram_perplexity = exp(
      -mean(log(unigram_probability))
    ),
    selected_perplexity = exp(
      -mean(log(selected_probability))
    ),
    next_token_rows = n(),
    .by = speech_id
  ) |>
  pivot_longer(
    cols = c(
      unigram_perplexity,
      selected_perplexity
    ),
    names_to = "model",
    values_to = "perplexity"
  ) |>
  mutate(
    model = if_else(
      model == "unigram_perplexity",
      "unigram",
      selected_model
    )
  ) |>
  arrange(speech_id, model)

paired_test <- test_by_speech |>
  select(speech_id, model, perplexity) |>
  pivot_wider(
    names_from = model,
    values_from = perplexity
  ) |>
  summarise(
    selected_wins = sum(.data[[selected_model]] < unigram),
    ties = sum(.data[[selected_model]] == unigram),
    selected_losses = sum(.data[[selected_model]] > unigram)
  )

stopifnot(
  identical(nrow(split_assignments), 60L),
  identical(
    as.integer(count(split_assignments, split)$n),
    c(13L, 37L, 10L)
  ) ||
    identical(
      as.integer(count(split_assignments, split)$n),
      c(37L, 10L, 13L)
    ),
  !anyDuplicated(split_assignments$speech_id),
  identical(length(model_vocabulary), vocabulary_size),
  all(next_token_rows$paragraph_id %in% paragraphs$paragraph_id),
  identical(
    as.integer(count(next_token_rows, split)$n),
    c(24337L, 81724L, 25596L)
  ) ||
    identical(
      as.integer(count(next_token_rows, split)$n),
      c(81724L, 25596L, 24337L)
    ),
  identical(nrow(validation_results), 13L),
  identical(selected_model, "trigram"),
  identical(selected_strength, 100),
  validation_results$perplexity[
    validation_results$selected
  ] <
    validation_results$perplexity[
      validation_results$model == "unigram"
    ],
  identical(test_results$model, c("uniform", "unigram", "trigram")),
  test_results$perplexity[
    test_results$model == "trigram"
  ] <
    test_results$perplexity[
      test_results$model == "unigram"
    ],
  !is.na(
    test_results$top_1_accuracy[
      test_results$model == "trigram"
    ]
  ),
  identical(round(unknown_bucket_correct_share, 3), 0.353),
  identical(round(known_target_top_1_accuracy, 3), 0.141),
  sum(unlist(paired_test)) == 13L
)

split_path <- file.path(
  out_dir,
  "next-token-splits.csv"
)
validation_path <- file.path(
  out_dir,
  "next-token-validation.csv"
)
test_path <- file.path(
  out_dir,
  "next-token-test.csv"
)
test_by_speech_path <- file.path(
  out_dir,
  "next-token-test-by-speech.csv"
)

write_csv(split_assignments, split_path)
write_csv(validation_results, validation_path)
write_csv(test_results, test_path)
write_csv(test_by_speech, test_by_speech_path)

hash_file <- function(path) {
  digest(
    paste(read_lines(path), collapse = "\n"),
    algo = "sha256",
    serialize = FALSE
  )
}

metadata <- tibble(
  artifact = basename(c(
    split_path,
    validation_path,
    test_path,
    test_by_speech_path
  )),
  description = c(
    "Speech-level train, validation, and test assignments",
    "Validation perplexity for context-length and interpolation-strength candidates",
    "Untouched-test perplexity and top-1 accuracy for uniform, unigram, and selected models",
    "Per-speech test perplexity for the unigram baseline and selected model"
  ),
  settings = c(
    "development split seed 6301; selection split seed 6302; era-stratified speech rows",
    paste(
      "training-only vocabulary",
      vocabulary_size,
      "tokens; paragraph-bounded contexts; interpolation strengths",
      paste(candidate_strengths, collapse = ",")
    ),
    "test opened after validation selection; same tokenizer and vocabulary; uniform floor 2500",
    "speech-level paired comparison; no bootstrap or population interval"
  ),
  source = "quanteda data_corpus_inaugural, reshaped by R/inaugural-corpus.R",
  license = "Speeches are US government works in the public domain",
  built_on = "2026-09-01",
  fingerprint = vapply(
    c(
      split_path,
      validation_path,
      test_path,
      test_by_speech_path
    ),
    hash_file,
    character(1)
  )
)

metadata_path <- file.path(
  out_dir,
  "next-token-study-metadata.csv"
)
write_csv(metadata, metadata_path)

cat("Next-token validation results:\n")
print(validation_results, width = Inf)
cat("\nNext-token test results:\n")
print(test_results, width = Inf)
cat("\nPaired test-speech result:\n")
print(paired_test, width = Inf)
cat("\nWrote:\n")
print(
  tibble(
    file = c(
      split_path,
      validation_path,
      test_path,
      test_by_speech_path,
      metadata_path
    ),
    bytes = as.numeric(file.size(file))
  ),
  width = Inf
)
