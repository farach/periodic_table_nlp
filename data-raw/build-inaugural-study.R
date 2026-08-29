# Run the split-scheme study used by the model-evaluation lessons.
#
# Run by hand, not during a render. Fitting 60 models takes several minutes,
# which is why the results are committed. Lessons still fit a model live so a
# reader sees real execution; this file supplies the repeated-resample table
# that a single fit cannot honestly stand in for.
#
# Usage:
#   Rscript data-raw/build-inaugural-study.R

suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
  library(purrr)
  library(readr)
  library(rsample)
  library(recipes)
  library(textrecipes)
  library(parsnip)
  library(workflows)
  library(yardstick)
  library(digest)
})

source("R/inaugural-corpus.R")

out_dir <- "data/inaugural"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

paragraphs <- inaugural_paragraphs()

repeats <- 10L
proportion <- 0.75
max_tokens <- 500L
penalty <- 0.01

cat(sprintf(
  "paragraphs %d, speeches %d, people %d, surnames %d\n",
  nrow(paragraphs),
  n_distinct(paragraphs$speech_id),
  n_distinct(paragraphs$president),
  n_distinct(paragraphs$surname)
))

fit_once <- function(train, test, outcome) {
  formula <- as.formula(paste(outcome, "~ paragraph"))
  truth <- rlang::sym(outcome)

  rec <- recipe(formula, data = train) |>
    step_tokenize(paragraph) |>
    step_stopwords(paragraph) |>
    step_tokenfilter(paragraph, max_tokens = max_tokens) |>
    step_tfidf(paragraph)

  wf <- workflow() |>
    add_recipe(rec) |>
    add_model(
      logistic_reg(penalty = penalty, mixture = 0) |>
        set_engine("glmnet")
    )

  predictions <- augment(fit(wf, data = train), new_data = test)

  # Two trivial rules, because they answer different questions. The deployable
  # rule always predicts the class that was largest in TRAINING, which is what a
  # team could actually ship. The oracle rule is the share of the largest class
  # in TEST, which nobody can know in advance but which bounds what accuracy
  # means on this particular split. Under a group split the test mix is not the
  # corpus mix, so a fixed corpus baseline is the wrong comparison.
  train_counts <- table(train[[outcome]])
  train_majority_class <- names(sort(train_counts, decreasing = TRUE))[1]
  test_counts <- table(test[[outcome]])

  # A one-number rule: split on paragraph length, with the cut point and the
  # direction both chosen on training data only.
  length_cut <- stats::median(train$paragraph_words)
  levs <- levels(train[[outcome]])
  best_length_acc <- -Inf
  for (flip in c(FALSE, TRUE)) {
    lo <- if (flip) levs[2] else levs[1]
    hi <- if (flip) levs[1] else levs[2]
    train_pred <- ifelse(train$paragraph_words <= length_cut, lo, hi)
    acc <- mean(train_pred == as.character(train[[outcome]]))
    if (acc > best_length_acc) {
      best_length_acc <- acc
      best_dir <- c(lo = lo, hi = hi)
    }
  }
  length_pred <- factor(
    ifelse(test$paragraph_words <= length_cut, best_dir[["lo"]], best_dir[["hi"]]),
    levels = levs
  )

  tibble(
    accuracy = accuracy(predictions, truth = !!truth, estimate = .pred_class)$.estimate,
    bal_accuracy = bal_accuracy(predictions, truth = !!truth, estimate = .pred_class)$.estimate,
    train_majority_accuracy = mean(test[[outcome]] == train_majority_class),
    test_majority_rate = max(test_counts) / sum(test_counts),
    length_rule_accuracy = mean(length_pred == test[[outcome]]),
    test_rows = nrow(test),
    test_speeches = n_distinct(test$speech_id)
  )
}

# Three ways to divide the same rows. Each removes one more kind of overlap
# between what the model learns from and what it is scored on.
make_split <- function(data, scheme, outcome, seed) {
  set.seed(seed)
  switch(
    scheme,
    paragraph = initial_split(
      data,
      prop = proportion,
      strata = !!rlang::sym(outcome)
    ),
    speech = group_initial_split(data, group = speech_id, prop = proportion),
    president = group_initial_split(
      data,
      group = president,
      prop = proportion
    )
  )
}

# The era task uses every paragraph. The party task can only use paragraphs
# whose speech carries a Democratic or Republican label, which drops 180 rows
# from the earliest speeches. Those two row sets are not the same, so the study
# also runs era restricted to the party rows. Without that arm, a comparison
# between the two tasks is confounded by which paragraphs each one saw.
party_rows <- paragraphs |>
  filter(party %in% c("Democratic", "Republican"))

tasks <- list(
  era = list(data = paragraphs |> mutate(outcome = era), outcome = "era"),
  era_party_rows = list(
    data = party_rows |> mutate(outcome = era),
    outcome = "era"
  ),
  party = list(
    data = party_rows |> mutate(party = factor(party)),
    outcome = "party"
  )
)

study <- imap(tasks, function(spec, task_name) {
  scored <- spec$data
  outcome_column <- spec$outcome

  map(c("paragraph", "speech", "president"), function(scheme) {
    map(seq_len(repeats), function(index) {
      split <- make_split(scored, scheme, outcome_column, 1000L + index)
      fit_once(training(split), testing(split), outcome_column) |>
        mutate(
          task = task_name,
          split_scheme = scheme,
          replicate = index,
          .before = 1
        )
    }) |>
      list_rbind()
  }) |>
    list_rbind()
}) |>
  list_rbind()

baselines <- imap(tasks, function(spec, task_name) {
  column <- spec$data[[spec$outcome]]
  tibble(
    task = task_name,
    outcome = spec$outcome,
    rows = length(column),
    speeches = n_distinct(spec$data$speech_id),
    people = n_distinct(spec$data$president),
    largest_class = names(sort(table(column), decreasing = TRUE))[1],
    baseline_accuracy = round(max(table(column)) / length(column), 4)
  )
}) |>
  list_rbind()

study_path <- file.path(out_dir, "split-study.csv")
baseline_path <- file.path(out_dir, "baselines.csv")

write_csv(
  study |>
    mutate(across(
      c(
        accuracy, bal_accuracy, train_majority_accuracy,
        test_majority_rate, length_rule_accuracy
      ),
      ~ round(.x, 4)
    )),
  study_path
)
write_csv(baselines, baseline_path)

cat("\nsummary\n")
print(as.data.frame(
  study |>
    summarise(
      model = round(mean(accuracy), 4),
      bal = round(mean(bal_accuracy), 4),
      train_majority = round(mean(train_majority_accuracy), 4),
      test_majority = round(mean(test_majority_rate), 4),
      length_rule = round(mean(length_rule_accuracy), 4),
      min = round(min(accuracy), 4),
      max = round(max(accuracy), 4),
      .by = c(task, split_scheme)
    )
))
cat("\nbaselines\n")
print(as.data.frame(baselines))

hash_lines <- function(path) {
  digest(
    paste(read_lines(path), collapse = "\n"),
    algo = "sha256",
    serialize = FALSE
  )
}

metadata <- tibble(
  artifact = c("split-study.csv", "baselines.csv"),
  description = c(
    sprintf(
      "Per-replicate model accuracy, balanced accuracy, two trivial-rule baselines and a paragraph-length rule, for %d resamples of each split scheme across three tasks",
      repeats
    ),
    "Largest-class accuracy, row, speech and person counts for each task"
  ),
  settings = sprintf(
    "glmnet logistic regression, penalty %s, mixture 0, tf-idf over %d tokens, %.0f%% training, seeds %d-%d; president grouping uses the full name, not the surname",
    penalty,
    max_tokens,
    proportion * 100,
    1001L,
    1000L + repeats
  ),
  source = "quanteda data_corpus_inaugural, 60 speeches 1789-2025 by 40 people",
  license = "Speeches are US government works in the public domain",
  built_on = "2026-08-29",
  fingerprint = c(hash_lines(study_path), hash_lines(baseline_path))
)

write_csv(metadata, file.path(out_dir, "inaugural-metadata.csv"))

cat("\nwrote:\n")
print(
  tibble(file = list.files(out_dir, full.names = TRUE)) |>
    mutate(bytes = file.size(file))
)
