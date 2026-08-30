# Compare a small set of text classifiers without touching the final test set.
#
# The published lesson creates the same split and folds live, then reads the
# committed comparison. Fitting 14 candidate settings across five grouped folds
# takes long enough that it belongs here rather than in a site render.
#
# The design has two levels:
#   1. One speech-level split (seed 4301) holds 14 speeches aside for the final
#      check.
#   2. Five grouped folds inside the remaining 46 speeches compare candidates
#      and tuning values. Every paragraph from one speech stays in one fold.
#
# Usage:
#   Rscript data-raw/build-model-comparison.R

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(tibble)
  library(purrr)
  library(readr)
  library(rsample)
  library(recipes)
  library(textrecipes)
  library(parsnip)
  library(workflows)
  library(tune)
  library(yardstick)
  library(glmnet)
  library(ranger)
  library(digest)
})

source("R/inaugural-corpus.R")

out_dir <- "data/inaugural"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

paragraphs <- inaugural_paragraphs()

set.seed(4301)
era_split <- group_initial_split(
  paragraphs,
  group = speech_id,
  prop = 0.75
)
era_training <- training(era_split)
era_testing <- testing(era_split)

set.seed(4310)
era_folds <- group_vfold_cv(
  era_training,
  group = speech_id,
  v = 5,
  strata = era,
  balance = "groups"
)

fold_summary <- map2(
  era_folds$splits,
  era_folds$id,
  \(split, fold_id) {
    analysis_rows <- analysis(split)
    assessment_rows <- assessment(split)

    tibble(
      fold = fold_id,
      analysis_speeches = n_distinct(analysis_rows$speech_id),
      assessment_speeches = n_distinct(assessment_rows$speech_id),
      assessment_paragraphs = nrow(assessment_rows),
      before_1900 = sum(assessment_rows$era == "before 1900"),
      later_1900 = sum(assessment_rows$era == "1900 or later")
    )
  }
) |>
  list_rbind()

text_recipe <- recipe(era ~ paragraph, data = era_training) |>
  step_tokenize(paragraph) |>
  step_stopwords(paragraph) |>
  step_tokenfilter(paragraph, max_tokens = 500) |>
  step_tfidf(paragraph)

ridge_spec <- logistic_reg(
  penalty = tune(),
  mixture = 0
) |>
  set_engine("glmnet")

lasso_spec <- logistic_reg(
  penalty = tune(),
  mixture = 1
) |>
  set_engine("glmnet")

forest_spec <- rand_forest(
  mtry = tune(),
  min_n = tune(),
  trees = 300
) |>
  set_engine(
    "ranger",
    importance = "none",
    num.threads = 1,
    # ranger's internal seed is separate from R's set.seed() in tune_candidate().
    seed = 4313
  ) |>
  set_mode("classification")

metrics <- metric_set(bal_accuracy, accuracy)
control <- control_grid(save_pred = FALSE, verbose = FALSE)

tune_candidate <- function(specification, grid, seed) {
  set.seed(seed)

  workflow() |>
    add_recipe(text_recipe) |>
    add_model(specification) |>
    tune_grid(
      resamples = era_folds,
      grid = grid,
      metrics = metrics,
      control = control
    )
}

ridge_results <- tune_candidate(
  ridge_spec,
  tibble(penalty = c(0.01, 0.1, 1, 10)),
  seed = 4311
)

lasso_results <- tune_candidate(
  lasso_spec,
  tibble(penalty = c(0.0001, 0.001, 0.01, 0.1)),
  seed = 4312
)

forest_results <- tune_candidate(
  forest_spec,
  crossing(
    mtry = c(25L, 100L, 250L),
    min_n = c(5L, 20L)
  ),
  seed = 4313
)

collect_candidate <- function(results, candidate, family) {
  collect_metrics(results) |>
    mutate(
      candidate = candidate,
      family = family,
      .before = 1
    )
}

model_comparison_long <- bind_rows(
  collect_candidate(
    ridge_results,
    "ridge logistic",
    "regularized logistic regression"
  ),
  collect_candidate(
    lasso_results,
    "lasso logistic",
    "regularized logistic regression"
  ),
  collect_candidate(
    forest_results,
    "random forest",
    "random forest"
  )
)

model_comparison <- model_comparison_long |>
  select(
    candidate,
    family,
    penalty,
    mtry,
    min_n,
    .metric,
    mean,
    std_err
  ) |>
  pivot_wider(
    names_from = .metric,
    values_from = c(mean, std_err),
    names_glue = "{.value}_{.metric}"
  ) |>
  arrange(desc(mean_bal_accuracy), candidate, penalty, mtry, min_n) |>
  mutate(
    rank = row_number(),
    selected = candidate == "ridge logistic" & penalty == 0.01,
    selection_reason = if_else(
      selected,
      paste(
        "Highest mean balanced accuracy;",
        "keeps the linear model used for explanation"
      ),
      ""
    )
  ) |>
  select(
    rank,
    candidate,
    family,
    penalty,
    mtry,
    min_n,
    mean_bal_accuracy,
    std_err_bal_accuracy,
    mean_accuracy,
    std_err_accuracy,
    selected,
    selection_reason
  )

comparison_path <- file.path(out_dir, "model-comparison.csv")
folds_path <- file.path(out_dir, "model-comparison-folds.csv")

write_csv(
  model_comparison |>
    mutate(
      across(
        c(
          mean_bal_accuracy,
          std_err_bal_accuracy,
          mean_accuracy,
          std_err_accuracy
        ),
        \(value) round(value, 6)
      )
    ),
  comparison_path,
  na = ""
)
write_csv(fold_summary, folds_path, na = "")

hash_lines <- function(path) {
  digest(
    paste(read_lines(path), collapse = "\n"),
    algo = "sha256",
    serialize = FALSE
  )
}

metadata <- tibble(
  artifact = c(
    "model-comparison.csv",
    "model-comparison-folds.csv"
  ),
  description = c(
    paste(
      "Five-fold grouped-CV comparison inside the training speeches;",
      "the final 14 test speeches are untouched"
    ),
    "Paragraph and speech counts for the five assessment folds"
  ),
  settings = c(
    paste(
      "split seed 4301; fold seed 4310; 5 folds grouped by speech_id and",
      "stratified by era; 500 tf-idf tokens; balanced accuracy primary;",
      "ridge penalties 0.01,0.1,1,10;",
      "lasso penalties 0.0001,0.001,0.01,0.1;",
      "random forest 300 trees, mtry 25,100,250, min_n 5,20"
    ),
    "46 training speeches; balance='groups'; final test speeches=14"
  ),
  source = "quanteda data_corpus_inaugural, reshaped by R/inaugural-corpus.R",
  license = "Speeches are US government works in the public domain",
  built_on = "2026-08-30",
  fingerprint = c(
    hash_lines(comparison_path),
    hash_lines(folds_path)
  )
)

write_csv(
  metadata,
  file.path(out_dir, "model-comparison-metadata.csv"),
  na = ""
)

stopifnot(
  identical(nrow(era_training), 1042L),
  identical(nrow(era_testing), 335L),
  identical(n_distinct(era_training$speech_id), 46L),
  identical(n_distinct(era_testing$speech_id), 14L),
  identical(nrow(era_folds), 5L),
  all(fold_summary$before_1900 > 0L),
  all(fold_summary$later_1900 > 0L),
  identical(nrow(model_comparison), 14L),
  identical(sum(model_comparison$selected), 1L)
)

cat("\nTop candidates by grouped-fold balanced accuracy:\n")
print(
  model_comparison |>
    select(
      rank,
      candidate,
      penalty,
      mtry,
      min_n,
      mean_bal_accuracy,
      std_err_bal_accuracy,
      selected
    ) |>
    slice_head(n = 8)
)

cat("\nWrote:\n")
print(
  tibble(
    file = c(
      comparison_path,
      folds_path,
      file.path(out_dir, "model-comparison-metadata.csv")
    ),
    bytes = file.size(file)
  )
)
