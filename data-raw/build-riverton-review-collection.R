# Build the fictional Riverton review collection used by task 74.
#
# Run by hand, not during a render. Everything here is invented for teaching.
# No real legal matter, company, person, source, or news item is described.
#
# Usage:
#   Rscript data-raw/build-riverton-review-collection.R
#   Rscript data-raw/build-riverton-review-collection.R --sweep-only <collection.csv>
#   Rscript data-raw/build-riverton-review-collection.R --negative-controls <intermediate.csv>
#
# The two check-only modes write nothing. --sweep-only runs the record-level
# surface sweep on any collection CSV and exits 1 if a check refuses it.
# --negative-controls runs the same sweep on the collections committed at
# 0a5a5af9, a3478085 and 49a9b67a and on a quarantined intermediate
# collection, and exits 0 only if all four are refused.

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tibble)
  library(tidyr)
  library(purrr)
  library(stringr)
  library(digest)
  library(glmnet)
  library(tidytext)
})

args <- commandArgs(trailingOnly = TRUE)

# ---- Fixed request, keyword rule, and request-topic exclusion ----------------
# These three definitions are unchanged from commit a3478085. The topic
# exclusion applies only to the request's content words in the frequent-token
# check; it never removes a stop word from the function-word ranker.

review_request <- paste(
  "Find records about hiding safety inspection delays, changing inspection",
  "logs, or deleting inspection-related messages for the Calder Yard contract."
)

keyword_terms <- c(
  "inspection",
  "inspect",
  "delete",
  "deleted",
  "delay",
  "delayed",
  "log",
  "Calder Yard"
)

keyword_regex_text <- paste0(
  "\\b(",
  paste(keyword_terms[keyword_terms != "Calder Yard"], collapse = "|"),
  ")\\b|\\bCalder Yard\\b"
)

request_topic_terms <- c(
  str_to_lower(keyword_terms, locale = "en"),
  "hiding", "safety", "altering", "changing", "inspection",
  "inspections", "information", "records", "record", "messages",
  "calder", "yard", "contract", "delete", "deleted", "delay",
  "delayed", "log", "logs"
)

# ---- Surface sweep shared by the builder and the check-only modes -----------
# The builder refuses to write when any check reaches positive F1 >= 0.60 or
# balanced accuracy >= 0.75. Any NA diagnostic stops the builder.

refusal_f1 <- 0.60
refusal_ba <- 0.75
heldout_split_seeds <- 7501:7520
ranker_fold_seeds <- c(7601L, 7602L, 7603L)

snowball_stop_words <- tidytext::stop_words |>
  filter(lexicon == "snowball") |>
  distinct(word) |>
  pull(word)

stopifnot(
  length(snowball_stop_words) > 100L,
  !any(request_topic_terms %in% snowball_stop_words)
)

metric_from_prediction <- function(predicted, truth) {
  tp <- sum(predicted & truth)
  fp <- sum(predicted & !truth)
  fn <- sum(!predicted & truth)
  tn <- sum(!predicted & !truth)
  precision <- if_else(tp + fp == 0L, 0, tp / (tp + fp))
  recall <- if_else(tp + fn == 0L, 0, tp / (tp + fn))
  tibble(
    positive_f1 = if_else(
      precision + recall == 0,
      0,
      2 * precision * recall / (precision + recall)
    ),
    balanced_accuracy = (
      if_else(tp + fn == 0L, 0, tp / (tp + fn)) +
        if_else(tn + fp == 0L, 0, tn / (tn + fp))
    ) / 2
  )
}

score_binary_feature <- function(data, feature_name) {
  values <- data[[feature_name]]
  truth <- data$reference_responsive

  map_dfr(sort(unique(values)), \(feature_value) {
    equal <- values == feature_value
    bind_rows(
      metric_from_prediction(equal, truth) |>
        mutate(positive_when_feature_is = "present"),
      metric_from_prediction(!equal, truth) |>
        mutate(positive_when_feature_is = "absent")
    ) |>
      mutate(feature_value = as.character(feature_value))
  }) |>
    arrange(desc(positive_f1), desc(balanced_accuracy)) |>
    slice(1) |>
    mutate(feature = feature_name, auc = NA_real_)
}

heldout_grouped_rule <- function(data, feature_name, seeds = heldout_split_seeds) {
  values <- data[[feature_name]]
  truth <- data$reference_responsive
  map_dfr(seeds, \(seed) {
    set.seed(seed)
    fit_ids <- c(
      sample(which(truth), floor(sum(truth) / 2)),
      sample(which(!truth), floor(sum(!truth) / 2))
    )
    assess_ids <- setdiff(seq_along(truth), fit_ids)
    fit_positive <- sum(truth[fit_ids])
    fit_negative <- sum(!truth[fit_ids])
    positive_values <- tibble(value = values[fit_ids], is_positive = truth[fit_ids]) |>
      group_by(value) |>
      summarise(
        contribution = sum(is_positive) / fit_positive - sum(!is_positive) / fit_negative,
        .groups = "drop"
      ) |>
      filter(contribution > 0) |>
      pull(value)
    metric_from_prediction(values[assess_ids] %in% positive_values, truth[assess_ids])
  }) |>
    summarise(
      positive_f1 = mean(positive_f1),
      balanced_accuracy = mean(balanced_accuracy)
    ) |>
    mutate(
      feature = feature_name,
      feature_value = "value set learned on half, scored on the other half",
      positive_when_feature_is = "in learned set",
      auc = NA_real_
    )
}

stratified_folds <- function(truth, seed, folds = 5L) {
  set.seed(seed)
  fold_id <- integer(length(truth))
  fold_id[truth] <- sample(rep(seq_len(folds), length.out = sum(truth)))
  fold_id[!truth] <- sample(rep(seq_len(folds), length.out = sum(!truth)))
  fold_id
}

ordered_folds <- function(truth, folds = 5L) {
  fold_id <- integer(length(truth))
  fold_id[truth] <- rep(seq_len(folds), length.out = sum(truth))
  fold_id[!truth] <- rep(seq_len(folds), length.out = sum(!truth))
  fold_id
}

auc_from_scores <- function(scores, truth) {
  score_rank <- rank(scores)
  positives <- sum(truth)
  negatives <- sum(!truth)
  (sum(score_rank[truth]) - positives * (positives + 1) / 2) / (positives * negatives)
}

# Out-of-fold glmnet logistic ranker: ridge and lasso, penalty chosen by
# cv.glmnet inside each training fold, stratified 5-fold outer scoring under
# the three fixed fold seeds, decision at the top sum(truth) scores.
held_out_glmnet_ranker <- function(x, truth, feature_name, seeds = ranker_fold_seeds) {
  top_n <- sum(truth)
  runs <- expand_grid(seed = seeds, alpha = c(0, 1))
  pmap_dfr(runs, \(seed, alpha) {
    outer_fold <- stratified_folds(truth, seed)
    scores <- numeric(length(truth))
    for (fold in sort(unique(outer_fold))) {
      fit_rows <- outer_fold != fold
      fit <- cv.glmnet(
        x = x[fit_rows, , drop = FALSE],
        y = as.integer(truth[fit_rows]),
        family = "binomial",
        alpha = alpha,
        foldid = ordered_folds(truth[fit_rows])
      )
      scores[!fit_rows] <- as.numeric(predict(
        fit,
        newx = x[!fit_rows, , drop = FALSE],
        s = "lambda.min",
        type = "response"
      ))
    }
    predicted <- logical(length(truth))
    predicted[order(-scores, seq_along(scores))[seq_len(top_n)]] <- TRUE
    metric_from_prediction(predicted, truth) |>
      mutate(
        feature = feature_name,
        feature_value = paste0(if (alpha == 0) "ridge" else "lasso", ", fold seed ", seed),
        positive_when_feature_is = paste0("top ", top_n, " out-of-fold scores"),
        auc = auc_from_scores(scores, truth)
      )
  })
}

function_word_matrix <- function(text) {
  tokens <- tokenizers::tokenize_words(
    str_replace_all(text, "\u2019", "'"),
    lowercase = TRUE,
    strip_punct = TRUE
  )
  counts <- t(vapply(
    tokens,
    \(token) as.numeric(table(factor(token[token %in% snowball_stop_words], levels = snowball_stop_words))),
    numeric(length(snowball_stop_words))
  ))
  colnames(counts) <- snowball_stop_words
  counts
}

format_cue_matrix <- function(text) {
  cbind(
    words = str_count(text, "\\S+"),
    characters = nchar(text),
    commas = str_count(text, ","),
    semicolons = str_count(text, ";"),
    colons = str_count(text, ":"),
    question_marks = str_count(text, "\\?"),
    apostrophes = str_count(text, "['\u2019]"),
    periods = str_count(text, "\\."),
    hyphens = str_count(text, "-"),
    capitalized_words = str_count(text, "\\b[A-Z][a-z]+"),
    all_caps_tokens = str_count(text, "\\b[A-Z]{2,}\\b"),
    digits = str_count(text, "[0-9]"),
    sentences = str_count(text, "[.!?](\\s|$)")
  )
}

record_feature_names <- c(
  "length_band",
  "punctuation_band",
  "first_person_pronoun",
  "has_digit",
  "month",
  "weekday",
  "id_last_digit",
  "doc_id_order_band",
  "date_rank_band",
  "shuffled_file_position_band",
  "construction_id_order_band",
  "sentence_frame",
  "first_word",
  "first_two_words",
  "sentence_count",
  "has_colon",
  "source_type",
  "sender_role",
  "subject"
)

record_level_features <- function(data) {
  position <- if ("file_position" %in% names(data)) data$file_position else seq_len(nrow(data))
  construction_number <- if ("construction_id" %in% names(data)) {
    as.integer(str_extract(data$construction_id, "\\d+"))
  } else {
    position
  }
  data |>
    mutate(
      doc_id_number = as.integer(str_extract(doc_id, "\\d+")),
      word_count = str_count(text, "\\S+"),
      length_band = case_when(
        word_count <= quantile(word_count, 1 / 3) ~ "short",
        word_count <= quantile(word_count, 2 / 3) ~ "middle",
        TRUE ~ "long"
      ),
      punctuation_band = case_when(
        str_detect(text, "\\?") ~ "question",
        str_detect(text, ";|:") ~ "punctuated",
        TRUE ~ "plain"
      ),
      first_person_pronoun = str_detect(
        text,
        regex("\\b(I|me|my|we|us|our)\\b", ignore_case = TRUE)
      ),
      has_digit = str_detect(text, "\\d"),
      month = format(as.Date(doc_date), "%m"),
      weekday = weekdays(as.Date(doc_date)),
      id_last_digit = str_sub(doc_id, -1),
      doc_id_order_band = ntile(doc_id_number, 5),
      date_rank_band = ntile(as.numeric(as.Date(doc_date)), 5),
      shuffled_file_position_band = ntile(position, 5),
      construction_id_order_band = ntile(construction_number, 5),
      sentence_frame = coalesce(str_extract(text, "^\\S+\\s+\\S+\\s+\\S+"), "no frame"),
      first_word = coalesce(word(text, 1), "no word"),
      first_two_words = coalesce(str_squish(str_extract(text, "^\\S+\\s+\\S+")), "no frame"),
      sentence_count = str_count(text, "[.!?](\\s|$)"),
      has_colon = str_detect(text, fixed(":"))
    )
}

# ---- Frames, and the frame checks CK-D1 and CK-D2 -----------------------------
# The 12 record frames (moved here from the collection section so that the
# check-only modes can identify frames from committed text). A record's frame
# is read from its text by prefix and suffix; the builder asserts that this
# reading equals its own frame assignment.

record_frames <- tibble(
  frame_id = sprintf("F%02d", 1:12),
  frame_template = c(
    "{core}",
    "Reminder: {core}",
    "Ticket note: {core}",
    "Forwarding from intake: {core}",
    "Per scheduling: {core}",
    "Monday update: {core}",
    "Chat at noon: {core}",
    "{core} Thanks.",
    "{core} Call me if anything is unclear.",
    "Following up: {core}",
    "Please note: {core}",
    "For today: {core}"
  )
)

frame_parts <- record_frames |>
  mutate(
    prefix = str_replace(frame_template, fixed("{core}"), "\u0001") |> str_remove("\u0001.*$"),
    suffix = str_replace(frame_template, fixed("{core}"), "\u0001") |> str_remove("^.*\u0001")
  )

split_frame <- function(text) {
  affixed <- frame_parts |>
    filter(frame_id != "F01") |>
    arrange(desc(nchar(prefix) + nchar(suffix)))
  map_dfr(text, \(record) {
    match <- affixed |>
      filter(
        startsWith(record, prefix),
        endsWith(record, suffix),
        nchar(record) > nchar(prefix) + nchar(suffix)
      )
    if (nrow(match) == 0L) {
      return(tibble(frame_id = "F01", core = record))
    }
    tibble(
      frame_id = match$frame_id[[1]],
      core = substr(record, nchar(match$prefix[[1]]) + 1L, nchar(record) - nchar(match$suffix[[1]]))
    )
  })
}

# Expected-value metrics at a top-n cut: records above the cut count as
# predicted responsive; when the cut falls inside a block of tied scores, each
# tied record counts with probability (slots left) / (block size).
expected_cut_metrics <- function(scores, truth, top_n = sum(truth)) {
  threshold <- sort(scores, decreasing = TRUE)[[top_n]]
  above <- scores > threshold
  tied <- scores == threshold
  slots_left <- top_n - sum(above)
  prob <- as.numeric(above)
  prob[tied] <- slots_left / sum(tied)
  tp <- sum(prob[truth])
  fp <- sum(prob[!truth])
  fn <- sum(1 - prob[truth])
  tn <- sum(1 - prob[!truth])
  tibble(
    positive_f1 = if (tp == 0) 0 else 2 * tp / (2 * tp + fp + fn),
    balanced_accuracy = (tp / (tp + fn) + tn / (tn + fp)) / 2
  )
}

# Held-out value ranker: stratified 5-fold under the fixed fold seeds; a
# record's score is its value's smoothed responsive rate in the training
# folds, (n_pos + 2p) / (n + 2), and an unseen value scores the training
# prevalence p.
held_out_value_ranker <- function(values, truth, feature_name, seeds = ranker_fold_seeds) {
  map_dfr(seeds, \(seed) {
    outer_fold <- stratified_folds(truth, seed)
    scores <- numeric(length(truth))
    for (fold in sort(unique(outer_fold))) {
      fit_rows <- outer_fold != fold
      prevalence <- mean(truth[fit_rows])
      rates <- tibble(value = values[fit_rows], is_positive = truth[fit_rows]) |>
        group_by(value) |>
        summarise(score = (sum(is_positive) + 2 * prevalence) / (n() + 2), .groups = "drop")
      held <- values[!fit_rows]
      scores[!fit_rows] <- coalesce(rates$score[match(held, rates$value)], prevalence)
    }
    expected_cut_metrics(scores, truth) |>
      mutate(
        feature = feature_name,
        feature_value = paste0("fold seed ", seed),
        positive_when_feature_is = paste0("top ", sum(truth), " held-out scores, expected-value ties"),
        auc = auc_from_scores(scores, truth)
      )
  })
}

# CK-D1: the pair (frame, first word of the core), lowercased.
frame_opening_checks <- function(frame_id, core, truth) {
  opening <- str_to_lower(coalesce(word(core, 1), "no word"), locale = "en")
  pair <- paste(frame_id, opening, sep = " | ")
  pair_count <- as.integer(table(pair)[pair])
  rarity <- map_dfr(1:4, \(k) {
    metric_from_prediction(pair_count <= k, truth) |>
      mutate(
        feature = "frame_opening_rarity",
        feature_value = paste0("pair occurs at most ", k, " times (no labels used)"),
        positive_when_feature_is = "rare pair",
        auc = NA_real_
      )
  })
  bind_rows(
    rarity,
    held_out_value_ranker(pair, truth, "frame_opening_pair_ranker")
  ) |>
    mutate(
      check = "CK-D1 frame and core opening",
      refuses = positive_f1 >= refusal_f1 | balanced_accuracy >= refusal_ba
    )
}

# CK-D2: the frame within keyword strata (whole-word rule on the core). Fixed
# rules are scored in both directions; only balanced accuracy is thresholded.
frame_keyword_strata_checks <- function(frame_id, core, truth) {
  keyword_match <- str_detect(core, regex(keyword_regex_text, ignore_case = TRUE))
  strata <- map_dfr(c(TRUE, FALSE), \(stratum) {
    rows <- which(keyword_match == stratum)
    frames <- frame_id[rows]
    stratum_truth <- truth[rows]
    stopifnot(length(rows) >= 10L, any(stratum_truth), any(!stratum_truth))
    stratum_label <- if (stratum) "keyword-match stratum" else "no-match stratum"
    rules <- c(
      list("has an affix" = frames != "F01"),
      setNames(
        lapply(sort(unique(frames)), \(frame) frames == frame),
        paste("frame", sort(unique(frames)))
      )
    )
    fixed_rules <- imap_dfr(rules, \(predicted, rule_name) {
      forward <- metric_from_prediction(predicted, stratum_truth)
      reverse <- metric_from_prediction(!predicted, stratum_truth)
      best <- if (forward$balanced_accuracy >= reverse$balanced_accuracy) forward else reverse
      best |>
        mutate(
          feature = paste0("frame_rule, ", stratum_label),
          feature_value = rule_name,
          positive_when_feature_is = "better direction, max(BA, 1 - BA)",
          auc = NA_real_
        )
    })
    ranker <- held_out_value_ranker(frames, stratum_truth, paste0("frame_ranker, ", stratum_label))
    bind_rows(fixed_rules, ranker)
  }) |>
    mutate(
      check = "CK-D2 frame within keyword strata",
      refuses = balanced_accuracy >= refusal_ba
    )
  conjunction <- metric_from_prediction(keyword_match & frame_id != "F01", truth) |>
    mutate(
      check = "CK-D2 reported only",
      feature = "keyword_match_and_affixed",
      feature_value = "whole collection",
      positive_when_feature_is = "keyword match and affixed frame",
      auc = NA_real_,
      refuses = FALSE
    )
  bind_rows(strata, conjunction)
}

surface_sweep <- function(data, extra_features = character()) {
  stopifnot(all(c("doc_id", "doc_date", "text", "reference_responsive") %in% names(data)))
  data <- data |>
    mutate(reference_responsive = as.logical(reference_responsive))
  features <- record_level_features(data)
  feature_names <- c(intersect(record_feature_names, names(features)), extra_features)
  stopifnot(!anyNA(features[feature_names]), !anyNA(features$reference_responsive))

  single_value <- map_dfr(feature_names, \(name) score_binary_feature(features, name)) |>
    mutate(check = "single value")

  heldout_names <- feature_names[
    vapply(features[feature_names], \(value) n_distinct(value) >= 3L, logical(1))
  ]
  heldout <- map_dfr(heldout_names, \(name) heldout_grouped_rule(features, name)) |>
    mutate(check = "held-out value set")

  frequent_terms <- tibble(term = str_extract_all(str_to_lower(data$text, locale = "en"), "[a-z]+")) |>
    unnest_longer(term) |>
    filter(!term %in% request_topic_terms) |>
    count(term, sort = TRUE) |>
    slice_head(n = 20) |>
    pull(term)
  frequent_tokens <- map_dfr(frequent_terms, \(term) {
    token_name <- paste0("token_", make.names(term))
    token_data <- features |>
      mutate("{token_name}" := str_detect(
        str_to_lower(text, locale = "en"),
        regex(paste0("\\b", term, "\\b"))
      ))
    score_binary_feature(token_data, token_name)
  }) |>
    mutate(check = "frequent non-topic token")

  function_words <- held_out_glmnet_ranker(
    function_word_matrix(data$text),
    data$reference_responsive,
    "function_word_ranker"
  ) |>
    mutate(check = "held-out function-word ranker")

  format_cues <- held_out_glmnet_ranker(
    format_cue_matrix(data$text),
    data$reference_responsive,
    "format_cue_ranker"
  ) |>
    mutate(check = "held-out format-cue ranker")

  framed <- split_frame(data$text)
  frame_opening <- frame_opening_checks(framed$frame_id, framed$core, data$reference_responsive)
  frame_within_keyword <- frame_keyword_strata_checks(framed$frame_id, framed$core, data$reference_responsive)

  result <- bind_rows(single_value, heldout, frequent_tokens, function_words, format_cues) |>
    mutate(refuses = positive_f1 >= refusal_f1 | balanced_accuracy >= refusal_ba) |>
    bind_rows(frame_opening, frame_within_keyword) |>
    select(check, feature, feature_value, positive_when_feature_is, positive_f1, balanced_accuracy, auc, refuses)
  stopifnot(!anyNA(result$positive_f1), !anyNA(result$balanced_accuracy), !anyNA(result$refuses))
  result
}

read_committed_collection <- function(commit) {
  path <- tempfile(fileext = ".csv")
  status <- system2(
    "git",
    c("show", paste0(commit, ":data/riverton/riverton-review-collection.csv")),
    stdout = path
  )
  stopifnot(identical(status, 0L))
  read_csv(path, show_col_types = FALSE, na = c("", "NA"))
}

print_sweep <- function(result, label) {
  cat("\nSweep:", label, "\n")
  print(
    result |>
      group_by(check) |>
      summarise(
        max_positive_f1 = round(max(positive_f1), 3),
        max_balanced_accuracy = round(max(balanced_accuracy), 3),
        max_auc = if (all(is.na(auc))) NA_real_ else round(max(auc[!is.na(auc)]), 3),
        refusing = sum(refuses),
        .groups = "drop"
      ),
    n = Inf,
    width = Inf
  )
  refusing <- result |> filter(refuses)
  if (nrow(refusing) > 0L) {
    cat("Refusing checks:\n")
    print(
      refusing |>
        mutate(across(c(positive_f1, balanced_accuracy, auc), \(value) round(value, 3))),
      n = Inf,
      width = Inf
    )
  }
  invisible(result)
}

# Check-only mode: sweep any collection CSV, write nothing, exit 1 on refusal.
if (length(args) == 2L && identical(args[[1]], "--sweep-only")) {
  sweep_result <- surface_sweep(read_csv(args[[2]], show_col_types = FALSE, na = c("", "NA")))
  print_sweep(sweep_result, args[[2]])
  quit(status = if (any(sweep_result$refuses)) 1L else 0L)
}

# Negative controls: the sweep must refuse the collections committed at
# 0a5a5af9, a3478085 and 49a9b67a and the quarantined intermediate collection
# whose path is given. The function-word ranker must be among the checks that
# refuse the intermediate collection, and CK-D1 and CK-D2 must each be among
# the checks that refuse 49a9b67a. Writes nothing; exits 0 only if all hold.
if (length(args) == 2L && identical(args[[1]], "--negative-controls")) {
  controls <- list(
    "committed at 0a5a5af9" = read_committed_collection("0a5a5af9"),
    "committed at a3478085" = read_committed_collection("a3478085"),
    "intermediate collection" = read_csv(args[[2]], show_col_types = FALSE, na = c("", "NA")),
    "committed at 49a9b67a" = read_committed_collection("49a9b67a")
  )
  control_results <- imap(controls, \(data, label) print_sweep(surface_sweep(data), label))
  refused <- map_lgl(control_results, \(result) any(result$refuses))
  refused_by <- function(label, check_name) {
    any(control_results[[label]]$refuses & control_results[[label]]$check == check_name)
  }
  function_word_refuses <- refused_by("intermediate collection", "held-out function-word ranker")
  ck_d1_refuses <- refused_by("committed at 49a9b67a", "CK-D1 frame and core opening")
  ck_d2_refuses <- refused_by("committed at 49a9b67a", "CK-D2 frame within keyword strata")
  cat("\nRefused:", paste(names(refused), refused, sep = " = ", collapse = "; "), "\n")
  cat("Function-word ranker refuses the intermediate collection:", function_word_refuses, "\n")
  cat("CK-D1 refuses 49a9b67a:", ck_d1_refuses, "\n")
  cat("CK-D2 refuses 49a9b67a:", ck_d2_refuses, "\n")
  quit(status = if (all(refused) && function_word_refuses && ck_d1_refuses && ck_d2_refuses) 0L else 1L)
}

set.seed(7401)
RNGkind(kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")

out_dir <- "data/riverton"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

author_note <- paste(
  "Constructed teaching record: this row is fictional and does not describe",
  "a real person, organisation, case, or media item."
)

roles <- c(
  "operations coordinator",
  "maintenance lead",
  "safety clerk",
  "contract analyst",
  "program manager",
  "warehouse supervisor",
  "records assistant",
  "shift planner"
)

source_types <- c("email", "chat", "memo", "ticket", "meeting note", "call note")
subject_pool <- c(
  "operations note",
  "schedule follow-up",
  "records question",
  "desk update",
  "supervisor note",
  "routing item",
  "training room note",
  "visitor follow-up",
  "support ticket",
  "supply note",
  "payroll question",
  "transit update"
)

# record_frames is defined with the frame checks at the top of this file.

make_review_rows <- function(texts,
                             responsive,
                             subtype,
                             start_index,
                             near_duplicate_of = NA_character_) {
  row_count <- length(texts)
  reference_reason <- if (responsive && str_detect(subtype, "keyword")) {
    "contains at least one predeclared keyword and is responsive to the request"
  } else if (responsive) {
    "uses indirect wording about hiding the requested inspection problem"
  } else {
    "does not concern hiding inspection delays, changing logs, or deleting related messages"
  }

  tibble(
    construction_id = sprintf("ROW-%04d", start_index + seq_len(row_count) - 1L),
    record_type = "review",
    doc_date = as.Date("2026-03-01") +
      ((start_index + seq_len(row_count) * 5L) %% 88L),
    source_type = source_types[
      ((start_index + seq_len(row_count) - 2L) %% length(source_types)) + 1L
    ],
    sender_role = roles[
      ((start_index + seq_len(row_count) + 1L) %% length(roles)) + 1L
    ],
    subject = subject_pool[
      ((start_index + seq_len(row_count) - 2L) %% length(subject_pool)) + 1L
    ],
    review_request = review_request,
    reference_responsive = responsive,
    reference_reason = reference_reason,
    construction_subtype = subtype,
    near_duplicate_of = near_duplicate_of,
    core_text = texts,
    author_note = author_note
  )
}

responsive_keyword_texts <- c(
  "Hold the Calder Yard inspection log until the client packet is final.",
  "Please delete the chat about the missed inspection window before export.",
  "The safety inspection delay should stay out of the weekly Calder Yard summary.",
  "Move the inspection notes to the side folder and send the clean log to the contract team.",
  "If the inspector asks about Tuesday, say the log is still being reconciled.",
  "Do not mention the delayed guardrail check in the Calder Yard update.",
  "Delete my message about the inspection gap after you copy the dates.",
  "The contract file should show the inspection as pending, not delayed.",
  "Keep the Calder Yard delay in draft notes until after the visit.",
  "Please change the inspection log wording before the records export.",
  "The Calder Yard inspection gap belongs in my private notes, not the shared file.",
  "Remove the delayed inspection line from the packet before records reviews it.",
  "The old log shows the missed check; send the revised Calder Yard version.",
  "Please keep the inspection delay out of the client-facing timeline.",
  "After you copy the guardrail dates, delete the note about the late check.",
  "The Calder Yard summary should not mention that the inspection was missed.",
  "Move the draft inspection log to my folder and share only the cleaned copy.",
  "Do not upload the message chain about the delayed inspection.",
  "The file export should hide the late safety check until we settle the wording.",
  "Please replace the Calder Yard log with the version that skips Tuesday.",
  "The draft says the inspection was late; delete that line before the packet goes out.",
  "Keep the missed-check note out of the records room until after the walkthrough.",
  "The inspection record should read pending, not delayed, for Calder Yard.",
  "Please remove my message about changing the inspection date."
)

responsive_mismatch_texts <- c(
  "Keep the red binder off the shared table until the visitor leaves.",
  "Use the clean timeline in the client packet and park the rough one elsewhere.",
  "The side folder has the version with the missing Tuesday stop.",
  "Please scrub the yard note before the noon packet goes out.",
  "Tell records the rough chronology is a working copy and not ready to share.",
  "The orange tab has the gap; send the white tab if anyone asks today.",
  "Do not put the Tuesday problem in the customer packet yet.",
  "The draft route sheet tells too much about the missed check."
)

responsive_near_originals <- c(
  "Set the marked route sheet aside until the customer visit is over.",
  "Keep the rough yard timeline out of the shared packet today."
)
responsive_near_copies <- c(
  "Set aside the marked route sheet until after the customer visit.",
  "Keep the rough yard timeline away from the shared packet today."
)

keyword_false_hit_texts <- c(
  "The classroom inspection drill note belongs in the training folder, not the Calder Yard file.",
  "Please delete the duplicate lunch order from the event spreadsheet.",
  "The maintenance log for Room 104 shows the sink repair was completed.",
  "The delayed chair shipment arrived at the front desk this afternoon.",
  "The safety inspection newsletter is an outreach item for new students.",
  "Calder Yard is listed on the volunteer cleanup map, not the contract file.",
  "The inspector role in the training exercise is assigned to Marcus.",
  "Do not delete the orientation photos; communications asked for them.",
  "The invoice log matches the accounting export after the vendor correction.",
  "The library delayed our poster print job until next week.",
  "Please attach the log of projector loans to the equipment ticket.",
  "The inspection sticker sample is only for the classroom demonstration.",
  "A visitor asked where to inspect donated laptops before class.",
  "The transit delay notice should go on the bulletin board.",
  "The Calder room key is missing from the facilities log.",
  "The fire inspection reminder was copied to all classroom leads."
)

nonresponsive_near_originals <- c(
  "The sample sticker for the classroom drill belongs in the training folder.",
  "The duplicate sandwich order should be removed from the event sheet.",
  "The bus delay flyer should go on the lobby bulletin board.",
  "The Room 104 sink repair note belongs in the maintenance binder."
)
nonresponsive_near_copies <- c(
  "The classroom drill sticker sample belongs in the training folder.",
  "Please remove the duplicate sandwich order from the event sheet.",
  "The delayed bus flyer belongs on the lobby bulletin board.",
  "The maintenance binder should include the Room 104 sink repair note."
)

nonresponsive_needed <- 204L -
  length(keyword_false_hit_texts) -
  length(nonresponsive_near_originals) -
  length(nonresponsive_near_copies)
nonresponsive_everyday_texts <- c(
  "Please refill the badge sleeves before the Tuesday visitor group arrives, then restock the reception tray.",
  "Please ask maintenance about the squeaky hinge in the east hallway before tonight's open clinic.",
  "Please keep the forklift practice cones by the south wall so the morning route stays clear.",
  "Please send me the final attendance count before catering closes.",
  "Please place the first-aid posters where students can see them during orientation check-in.",
  "Please tell the instructors that the annex door code changed for the next two evenings.",
  "Please add more chairs to the résumé workshop before noon.",
  "Please move the surplus binders out of the hallway cabinet before visitors use that corridor.",
  "Please gather leftover notebooks after the financial coaching session and return them to intake.",
  "Please send the updated classroom seating chart to reception so arrivals can be directed quickly.",
  "Please prepare the accessible seating area before the graduation rehearsal and leave two aisle spaces.",
  "Please make sure the classroom plants get water before Monday, especially the ones near the window.",
  "Please leave the attendance binder on the instructor podium for the evening substitute.",
  "Please check the thermostat before the afternoon computer lesson because Room 104 was cold yesterday.",
  "Please bring the spare projector bulb to the seminar room and note where the ladder is stored.",
  "The east entrance mat is curling again. Maintenance can tape it down.",
  "The bus pass envelope is short by three cards for Monday pickup, so reception may need extras.",
  "The cafeteria menu changed because the soup warmer is out again and the vendor switched sides.",
  "The supply cabinet has gloves and goggles; two apron packs are unopened.",
  "The new chair pads make the computer room less noisy during typing practice.",
  "The main hallway bulletin board needs fresh tape along the edges before the job fair flyers go up.",
  "The visitor badge printer is back online after a paper jam; Marcus tested three sample cards.",
  "The front ramp is clear, but the salt bucket is low near the automatic doors.",
  "The training room smells like paint because the trim was touched up after yesterday's scuff marks.",
  "The route notice should stay on the lobby board through Sunday for the weekend learners.",
  "The copier tray squeaks, but it still feeds the handouts without crumpling the pages.",
  "The courtyard benches are dry enough for lunch seating today if the wind stays calm.",
  "The safety vest rack needs six medium sizes for visitors before the manufacturer tour.",
  "The restroom sign near the annex should point guests downstairs during the plumbing work.",
  "The catering invoice matches the headcount from the employer breakfast and includes the fruit trays.",
  "Keep the room setup map with Dana today; she has the volunteer list.",
  "Keep the borrowed headsets in the cabinet after each webinar, with charging cables wrapped separately.",
  "Keep the orange table signs with outreach materials. They match the flyers.",
  "Keep the portable fan away from the doorway cord until facilities brings the floor cover.",
  "Keep the fruit trays covered until the job fair opens and the employer tables are staffed.",
  "Keep the braille ruler in the tutoring drawer for the accessibility workshop.",
  "Keep the recycling cart outside after the community meeting because the custodial closet is full.",
  "Keep the visitor vests together before the manufacturer tour and sort out the torn straps.",
  "Keep the donated laptops in pairs with their chargers until the refurbishment team arrives.",
  "Keep wet umbrellas in the bin by reception, not under the sign-in table.",
  "Keep the welcome signs near the west bulletin board until the hallway display is finished.",
  "Keep the extra bus passes with reception until Friday for learners joining midweek.",
  "Keep the workshop name tents near the registration table for pickup.",
  "Keep the employer panel folders beside the lunch table until the moderator arrives.",
  "Keep my draft agenda in the shared planning folder while I confirm speaker times.",
  "Move the classroom keys to Priya at the front desk tonight before the substitute arrives.",
  "Move the cart downstairs after the morning computer class, and leave the elevator clear.",
  "Move the blue visitor stickers beside the reception tablet for the afternoon tour group.",
  "Move the projector remote back to the media cabinet; Owen needs it.",
  "Move the room booking sheet out of the hallway cabinet and into the coordinator tray.",
  "Move the bus maps to the afternoon childcare table before families arrive.",
  "Move the lab tablets to the charging shelf before closing so tomorrow's group starts ready.",
  "Move the spare chargers beside the loaner laptop case after checking their labels.",
  "Move the hand sanitizer refill beside the classroom sink before the evening cohort arrives.",
  "Move the translation cards to the library event folder with the bilingual flyers.",
  "Move the portable whiteboard back after the job fair and wipe off the employer notes.",
  "Move the sign-in tablet to reception before the workshop so arrivals can check themselves in.",
  "Move the donated coats to the storage room this afternoon and keep adult sizes separate.",
  "Move the name cards from the east classroom after class and save the unused blanks.",
  "Move the spare podium to the annex before orientation if the main lectern stays loose.",
  "If anyone asks, the shuttle can wait. The cohort is almost ready.",
  "If the speaker arrives early, send them to reception and offer the green room key.",
  "If catering calls back, confirm the allergy cards are ready and ask about serving spoons.",
  "If the copier jams again, use the staff room machine for the intake packets.",
  "If the volunteer roster changes, call Marta before lunch so badges can be reprinted.",
  "If rain continues, put extra mats near the lobby doors and move the brochure stand.",
  "If the portal times out, save the student form again; call IT after that.",
  "If Fiona confirms availability, update the mentor roster before the newsletter draft closes.",
  "If the room warms up, open the side windows during the afternoon practice block.",
  "If the speaker case is empty, check my office shelf for the spare microphone.",
  "If the table layout works, send it to the program manager before the setup crew leaves.",
  "If the annex fills up, use the small lab and post a note by reception.",
  "If the vendor arrives late, have them unload by reception instead of blocking the dock.",
  "If the printer stalls, ask Omar about the paper tray and switch to plain stock.",
  "If the weather call comes, follow the phone tree and update the lobby sign.",
  "Do not leave the storage closet unlocked. The evening group uses that hall.",
  "Do not move the coffee urn until the panel ends and the room clears.",
  "Do not place the floor fan against the hallway monitor stand because it wobbles.",
  "Do not lend headsets without writing down the learner's name and return time.",
  "Do not stack chairs beside the ramp before visitors leave the graduation rehearsal.",
  "Do not use the side entrance while repairs are underway near the loading bay.",
  "Do not put the craft box away until childcare finishes the welcome poster.",
  "Do not send the workshop invite without the new room and revised start time.",
  "Do not store clean towels on the lower supply shelf while the mop bucket dries.",
  "Do not leave old flyers on the west bulletin board after the calendar changes.",
  "Do not close the seminar door until the fan stops and the paint smell fades.",
  "Do not mix the blue folders with payroll forms; Lila sorted them.",
  "Do not forget the decaf order for the morning panel or the extra cups.",
  "Do not move the appointment cards from the front counter before walk-in hours end.",
  "Do not return the placards before the parking tour ends and guests leave.",
  "I left my notes for the résumé clinic on Clara's chair before the printer stopped.",
  "I sent the grant workshop agenda to Nell. She will print copies for mentors.",
  "I found a grey umbrella under the third row table and tagged it for reception.",
  "I will bring the sign holders back after the hallway fair if the cart is free.",
  "I updated the volunteer call sheet after three people swapped shifts for Saturday.",
  "I put the spare aprons beside the teaching kitchen sink for the baking class.",
  "I shared the bus schedule with the afternoon childcare group before dismissal.",
  "I can cover the front desk until Marta returns. Send calls to me.",
  "I placed a quiet keyboard in the study booth for tomorrow's typing clinic.",
  "I answered the vendor's question about where to unload snacks during the rain.",
  "I can revise the scholarship clinic roster once Theo sends the interpreter list.",
  "I marked which donated laptops still need chargers and which have cracked cases.",
  "I gave the new volunteer a tour of the storage room and showed the key hook.",
  "I cleaned the whiteboard after the numeracy class ended and saved the marker caps.",
  "I placed replacement batteries beside the portable speaker case for the auditorium setup.",
  "Ask someone to bring the rolling coat rack upstairs. The lobby hooks are full.",
  "The shuttle can carry the evening mentors today if they meet by the library.",
  "Ask someone to unlock the storage closet before the safety drill and check the cones.",
  "The evening roster can include the new child-care volunteer after Marta confirms clearance.",
  "Ask someone to check whether the lab tablets charged overnight before learners sign them out.",
  "The payroll desk can resend the stipend question; Omar missed the first note.",
  "Ask someone to confirm the guest speaker's preferred display adapter before the auditorium setup.",
  "Ask someone to print the workshop feedback forms on green paper for the instructor.",
  "The supply order can include more left-handed scissors this month for the youth class.",
  "Ask grounds about the puddle by the bike rack before the evening rain starts.",
  "Can the Friday workshop use the seminar room instead if the projector works?",
  "Can someone collect the feedback slips from the west classroom after practice?",
  "Can the catering team set aside nut-free cookies for the evening class?",
  "Can someone send me the list of available interview rooms before mentors choose slots?",
  "Can the front desk hold my classroom packet until Carlos arrives for setup?",
  "We need more badge clips before the open house starts. Reception is low.",
  "We have enough tea and sugar for the evening class, but the cups are low.",
  "We should set out bus maps near the intake table before the new learners arrive.",
  "We received the paper shipment after the morning rush and stacked it near copying.",
  "We need the room change notice sent to all mentors before the calendar reminder.",
  "We can use the annex classroom for the health workshop if the chairs are returned.",
  "We found the mop closet key under the supply cart; facilities has it now.",
  "We should replace the empty soap dispenser by the lab sink before the food class.",
  "We welcomed visitors from the college after lunch and gave them orange lanyards.",
  "We need fresh consent forms for the afternoon queue because the tray is nearly empty.",
  "We should remind mentors to return keys before leaving Thursday and sign the clipboard.",
  "We have two open seats in the tax form clinic after one cancellation.",
  "We can start the employer panel after the lunch break once microphones are tested.",
  "We should sort certificates before the completion ceremony by program and last name.",
  "We need more appointment cards for walk-in learners at the front counter.",
  "Use the clean seating chart for the résumé workshop. The old copy is smudged.",
  "Use the yellow tabs for completion folders today, not the archived labels.",
  "Use the lapel microphone if the instructor needs it during the auditorium welcome.",
  "Use the annex printer for badge labels while the front tablet updates.",
  "Use the new stop name on the shuttle notice for Monday pickup.",
  "Use the labelled bin for goggles after practice, and wipe the straps first.",
  "Use the blue folders for translation cards and flyers at the outreach table.",
  "Use the longer cord for the sign-in tablet so the stand reaches the outlet.",
  "Use the loading dock for furniture deliveries during carpet cleaning.",
  "Use the clean serving tongs for the fruit trays once the covers come off.",
  "Use the portable whiteboard for the job fair line and write employer names clearly.",
  "Use the front tablet for badge photos this week because the kiosk camera flickers.",
  "Use the library partner's headcount for Thursday outreach when packing materials.",
  "Use the resource room if the health workshop needs quieter seating.",
  "Use my desk copy of the table layout if the printed plan disappears.",
  "Tell reception that the side-door buzzer is quiet again after the battery swap.",
  "Tell payroll that the stipend batch cleared after correction and the duplicate row is gone.",
  "Tell the front desk about the blue scarf from security before lost-and-found pickup.",
  "Tell the instructor that the practice file opens cleanly on the classroom laptops.",
  "Tell transit that the shuttle stop moves across the street Monday because of paving.",
  "Tell the opening team about the lobby heater if it is still running at 7:45.",
  "Tell the vendor to park the flower delivery by the side awning.",
  "Tell childcare that the craft box needs more glue sticks before the poster activity.",
  "Tell the career team that the apprenticeship brochures arrived in the mailroom.",
  "Tell IT that the password portal will restart at noon; learners are waiting.",
  "Tell facilities the courtyard hose bib is dripping near the planter boxes.",
  "Tell mentors that the Friday reminder includes the bus entrance map.",
  "Tell catering that the afternoon seminar needs vegetarian wraps and chilled water.",
  "Tell operations that the loading bay is closed Thursday while the railing is repaired.",
  "Tell the program manager that the childcare corner needs another rug.",
  "After the morning shift refill the badge sleeves at reception.",
  "After visitor hours check the east gate buzzer again. It sounded faint.",
  "After the duplicate spelling is fixed print the evening roster.",
  "After the delivery arrives count the mismatched folder boxes.",
  "After the help desk call restart the admissions voicemail greeting.",
  "After the literacy webinar collect the borrowed tablets and plug them in.",
  "After the employer breakfast wipe the name tents and pack the table numbers.",
  "After the tenant workshop return the folding chairs to the upstairs closet.",
  "After the storm close the lab windows and check the plants.",
  "After the manufacturer tour count the visitor vests again.",
  "After the forum stack chairs away from the ramp.",
  "After the pottery demo rinse the folding tables and stack the clay mats.",
  "After the lunch break open the employer panel room.",
  "After the weather closure test update the phone tree.",
  "After the campus walk collect the borrowed umbrellas from reception."
)
stopifnot(length(nonresponsive_everyday_texts) == nonresponsive_needed)

review_collection <- bind_rows(
  make_review_rows(
    responsive_keyword_texts,
    TRUE,
    "keyword responsive",
    1L
  ),
  make_review_rows(
    responsive_mismatch_texts,
    TRUE,
    "vocabulary mismatch responsive",
    25L
  ),
  make_review_rows(
    responsive_near_originals,
    TRUE,
    "near duplicate responsive original",
    33L
  ),
  make_review_rows(
    responsive_near_copies,
    TRUE,
    "near duplicate responsive copy",
    35L,
    near_duplicate_of = c("ROW-0033", "ROW-0034")
  ),
  make_review_rows(
    keyword_false_hit_texts,
    FALSE,
    "keyword false hit",
    37L
  ),
  make_review_rows(
    nonresponsive_near_originals,
    FALSE,
    "near duplicate not responsive original",
    53L
  ),
  make_review_rows(
    nonresponsive_near_copies,
    FALSE,
    "near duplicate not responsive copy",
    57L,
    near_duplicate_of = c("ROW-0053", "ROW-0054", "ROW-0055", "ROW-0056")
  ),
  make_review_rows(
    nonresponsive_everyday_texts,
    FALSE,
    "not responsive",
    61L
  )
)

stopifnot(
  nrow(review_collection) == 240L,
  sum(review_collection$reference_responsive) == 36L
)

# N46-4: frames are shared by both classes and contain no keyword term and no
# request-topic word. "logged" is also barred from frames.
frame_forbidden_terms <- c(request_topic_terms, "logged")

frame_terms <- record_frames |>
  transmute(term = str_extract_all(str_to_lower(frame_template, locale = "en"), "[a-z]+")) |>
  unnest_longer(term, values_to = "term") |>
  filter(term != "core") |>
  pull(term) |>
  unique()

stopifnot(
  !any(frame_terms %in% frame_forbidden_terms),
  !any(str_detect(record_frames$frame_template, regex(keyword_regex_text, ignore_case = TRUE)))
)

allocate_frames <- function(row_count, frames, capacity, paired_rows = list()) {
  assignment <- rep(NA_character_, row_count)
  class_rows <- if (row_count == length(responsive_rows)) responsive_rows else nonresponsive_rows
  cores <- review_collection$core_text[class_rows]
  core_digest <- map_chr(
    cores,
    \(core) digest(core, algo = "sha256", serialize = FALSE)
  )
  keyword_match <- str_detect(cores, regex(keyword_regex_text, ignore_case = TRUE))
  paired_lookup <- rep(NA_integer_, row_count)
  if (length(paired_rows) > 0L) {
    for (pair_index in seq_along(paired_rows)) {
      rows <- paired_rows[[pair_index]]
      stopifnot(length(rows) == 2L, length(unique(keyword_match[rows])) == 1L)
      paired_lookup[rows] <- pair_index
    }
  }

  units <- tibble(
    unit_id = seq_len(row_count),
    row = seq_len(row_count),
    unit = coalesce(paired_lookup, seq_len(row_count) + length(paired_rows)),
    digest = core_digest,
    keyword_match = keyword_match
  ) |>
    group_by(unit) |>
    summarise(
      rows = list(row),
      size = n(),
      digest = min(digest),
      keyword_match = first(keyword_match),
      .groups = "drop"
    )

  remaining <- setNames(rep(capacity, length(frames)), frames)
  stratum_counts <- expand_grid(
    frame = frames,
    keyword_match = sort(unique(keyword_match), decreasing = TRUE)
  ) |>
    mutate(count = 0L)

  for (stratum in sort(unique(keyword_match), decreasing = TRUE)) {
    stratum_units <- units |>
      filter(keyword_match == stratum) |>
      arrange(digest)
    for (unit_row in seq_len(nrow(stratum_units))) {
      size <- stratum_units$size[[unit_row]]
      candidates <- frames[remaining[frames] >= size]
      stopifnot(length(candidates) > 0L)
      candidate_counts <- stratum_counts$count[
        match(
          paste(candidates, stratum),
          paste(stratum_counts$frame, stratum_counts$keyword_match)
        )
      ]
      frame <- candidates[order(candidate_counts, as.integer(str_extract(candidates, "\\d+")))[[1]]]
      rows <- stratum_units$rows[[unit_row]]
      assignment[rows] <- frame
      remaining[[frame]] <- remaining[[frame]] - size
      stratum_counts$count[
        stratum_counts$frame == frame & stratum_counts$keyword_match == stratum
      ] <- stratum_counts$count[
        stratum_counts$frame == frame & stratum_counts$keyword_match == stratum
      ] + size
    }
  }

  stopifnot(all(remaining == 0L), !anyNA(assignment))
  assignment
}

responsive_rows <- which(review_collection$reference_responsive)
nonresponsive_rows <- which(!review_collection$reference_responsive)

responsive_frames <- allocate_frames(
  row_count = length(responsive_rows),
  frames = record_frames$frame_id,
  capacity = 3L,
  paired_rows = list(c(33L, 35L), c(34L, 36L))
)

nonresponsive_frames <- allocate_frames(
  row_count = length(nonresponsive_rows),
  frames = record_frames$frame_id,
  capacity = 17L,
  paired_rows = list(c(17L, 21L), c(18L, 22L), c(19L, 23L), c(20L, 24L))
)

review_collection <- review_collection |>
  mutate(frame_id = NA_character_)

review_collection$frame_id[responsive_rows] <- responsive_frames
review_collection$frame_id[nonresponsive_rows] <- nonresponsive_frames

review_collection <- review_collection |>
  left_join(record_frames, by = join_by(frame_id)) |>
  mutate(text = str_replace(frame_template, fixed("{core}"), core_text)) |>
  select(-frame_template)

frame_balance <- review_collection |>
  count(frame_id, reference_responsive, name = "rows") |>
  pivot_wider(
    names_from = reference_responsive,
    values_from = rows,
    values_fill = 0
  )

stopifnot(
  all(frame_balance$`TRUE` == 3L),
  all(frame_balance$`FALSE` == 17L)
)

set.seed(7403)
review_collection <- review_collection |>
  slice_sample(n = nrow(review_collection)) |>
  mutate(raw_construction_order = row_number())

date_assignment <- NULL
date_pool <- seq.Date(as.Date("2026-03-01"), as.Date("2026-05-31"), by = "day")
for (candidate_seed in 7402:9000) {
  set.seed(candidate_seed)
  candidate_dates <- sample(date_pool, nrow(review_collection), replace = TRUE)
  candidate_cor <- abs(cor(
    as.numeric(candidate_dates),
    as.integer(review_collection$reference_responsive)
  ))
  if (candidate_cor < 0.08) {
    date_assignment <- candidate_dates
    break
  }
}
stopifnot(!is.null(date_assignment))

review_collection <- review_collection |>
  mutate(doc_date = date_assignment)
date_seed <- candidate_seed

label_numeric_for_id <- as.integer(review_collection$reference_responsive)
id_assignment <- NULL
for (candidate_seed in 7401:9000) {
  set.seed(candidate_seed)
  candidate_ids <- sample(seq_len(nrow(review_collection)))
  candidate_lowest <- sum(label_numeric_for_id[candidate_ids <= 36L])
  candidate_cor <- abs(cor(candidate_ids, label_numeric_for_id))
  if (candidate_lowest <= 8L && candidate_cor < 0.05) {
    id_assignment <- candidate_ids
    break
  }
}
stopifnot(!is.null(id_assignment))

review_collection <- review_collection |>
  mutate(
    doc_id_number = id_assignment,
    doc_id = sprintf("RYD-%04d", doc_id_number)
  )
id_seed <- candidate_seed

construction_to_doc <- review_collection |>
  select(construction_id, original_doc_id = doc_id)

review_collection <- review_collection |>
  left_join(
    construction_to_doc,
    by = join_by(near_duplicate_of == construction_id)
  ) |>
  mutate(near_duplicate_of = original_doc_id) |>
  select(-original_doc_id, -doc_id_number) |>
  arrange(doc_id) |>
  mutate(
    file_position = row_number(),
    construction_id = sprintf("RC-%04d", file_position)
  ) |>
  select(
    doc_id,
    record_type,
    doc_date,
    source_type,
    sender_role,
    subject,
    review_request,
    reference_responsive,
    reference_reason,
    construction_subtype,
    near_duplicate_of,
    text,
    core_text,
    frame_id,
    author_note,
    construction_id,
    file_position,
    raw_construction_order
  )

monitoring_text <- c(
  "Riverton Skills Centre posts a reminder about fall enrollment.",
  "Calder Yard contractor confirms a safety walkthrough next week.",
  "Syndicated brief: Calder Yard contractor confirms safety walkthrough next week.",
  "Riverton Tidewater hosts a harbour festival unrelated to the Calder city program.",
  "A vendor post says a delayed inspection log at Calder Yard is under review.",
  "Community calendar lists a classroom inspection drill at Riverton Skills Centre.",
  "Wire copy: delayed inspection log at Calder Yard is under review.",
  "City notice says bus passes remain available for workforce classes.",
  "A post mentions Riverton without enough context to pick the city or the town.",
  "Maintenance bulletin reports new guardrail signs at Calder Yard.",
  "Syndicated maintenance bulletin reports new guardrail signs at Calder Yard.",
  "Local brief says contract records will be audited after a missed check.",
  "Training newsletter asks volunteers to inspect donated laptops.",
  "Vendor post repeats that contract records will be audited after a missed check.",
  "Riverton Calder council posts a meeting agenda about yard procurement.",
  "Harbour blog writes about Riverton Tidewater seafood trucks.",
  "Safety clerk account says old route notes should not be shared.",
  "Civic notice announces a parking delay near the Calder library.",
  "Syndicated civic notice announces a parking delay near the Calder library.",
  "Workforce Lab posts a non-alert reminder about child care during evening classes.",
  "Calder Yard contractor denies deleting any inspection messages.",
  "Wire copy: Calder Yard contractor denies deleting any inspection messages.",
  "Riverton school board posts a classroom inspection checklist.",
  "A regional item says Riverton won a rowing race, with no contract context."
)

monitoring_stream <- tibble(
  construction_id = sprintf("STREAM-%04d", seq_along(monitoring_text)),
  record_type = "monitoring",
  arrival_order = seq_along(monitoring_text),
  doc_date = as.Date("2026-06-01") + c(
    0, 1, 1, 2, 3, 4, 4, 5, 6, 8, 9, 9,
    10, 11, 12, 12, 13, 14, 15, 16, 16, 17, 18, 19
  ),
  source_type = rep(c("news brief", "union bulletin", "vendor post", "civic calendar"), length.out = 24),
  text = monitoring_text,
  reference_alert = c(
    FALSE, TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, TRUE,
    FALSE, TRUE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, TRUE, TRUE, FALSE, FALSE
  ),
  reference_reason = if_else(
    reference_alert,
    "monitoring reference item concerns the review topic or Calder Yard records",
    "monitoring reference item is unrelated, duplicated, or ambiguous"
  ),
  near_duplicate_of = c(
    NA, NA, "STREAM-0002", NA, NA, NA, "STREAM-0005", NA, NA, NA, "STREAM-0010",
    NA, NA, "STREAM-0012", NA, NA, NA, NA, "STREAM-0018", NA, NA, "STREAM-0021",
    NA, NA
  ),
  author_note = author_note
)

stream_label_numeric <- as.integer(monitoring_stream$reference_alert)
stream_assignment <- NULL
for (candidate_seed in 8401:9000) {
  set.seed(candidate_seed)
  candidate_ids <- sample(seq_len(nrow(monitoring_stream)))
  candidate_cor <- abs(cor(candidate_ids, stream_label_numeric))
  if (candidate_cor < 0.12) {
    stream_assignment <- candidate_ids
    break
  }
}
stopifnot(!is.null(stream_assignment))

stream_construction_to_id <- monitoring_stream |>
  mutate(stream_id = sprintf("MON-%03d", stream_assignment)) |>
  select(construction_id, original_stream_id = stream_id)

monitoring_stream <- monitoring_stream |>
  mutate(stream_id = sprintf("MON-%03d", stream_assignment)) |>
  left_join(
    stream_construction_to_id,
    by = join_by(near_duplicate_of == construction_id)
  ) |>
  mutate(near_duplicate_of = original_stream_id) |>
  select(-original_stream_id) |>
  select(
    stream_id,
    record_type,
    arrival_order,
    doc_date,
    source_type,
    text,
    reference_alert,
    reference_reason,
    near_duplicate_of,
    author_note
  ) |>
  arrange(arrival_order)
stream_seed <- candidate_seed

collection_path <- file.path(out_dir, "riverton-review-collection.csv")
stream_path <- file.path(out_dir, "riverton-monitoring-stream.csv")

mask_base_text <- function(text) {
  text |>
    str_to_lower(locale = "en") |>
    str_replace_all(
      regex("\\b(january|february|march|april|may|june|july|august|september|october|november|december)\\b"),
      "<month>"
    ) |>
    str_replace_all("\\b\\d+\\b", "<num>") |>
    str_squish()
}

keyword_regex <- regex(keyword_regex_text, ignore_case = TRUE)
near_duplicate_subtypes <- c(
  "near duplicate responsive original",
  "near duplicate responsive copy",
  "near duplicate not responsive original",
  "near duplicate not responsive copy"
)

# N46-12: the reason and subtype fields follow the text under the whole-word
# keyword rule. Near-duplicate rows keep their pair subtype.
review_collection <- review_collection |>
  mutate(
    keyword_hit_for_subtype = str_detect(text, keyword_regex),
    construction_subtype = case_when(
      construction_subtype %in% near_duplicate_subtypes ~ construction_subtype,
      reference_responsive & keyword_hit_for_subtype ~ "keyword responsive",
      reference_responsive ~ "vocabulary mismatch responsive",
      keyword_hit_for_subtype ~ "keyword false hit",
      TRUE ~ "not responsive"
    ),
    reference_reason = case_when(
      reference_responsive & keyword_hit_for_subtype ~
        "contains at least one predeclared keyword and is responsive to the request",
      reference_responsive ~
        "uses indirect wording about hiding the requested inspection problem",
      TRUE ~
        "does not concern hiding inspection delays, changing logs, or deleting related messages"
    )
  ) |>
  select(-keyword_hit_for_subtype)

keyword_results <- review_collection |>
  mutate(keyword_hit = str_detect(text, keyword_regex))
keyword_counts <- keyword_results |>
  summarise(
    hits = sum(keyword_hit),
    responsive_hits = sum(keyword_hit & reference_responsive),
    responsive_total = sum(reference_responsive),
    precision = responsive_hits / hits,
    recall = responsive_hits / responsive_total
  )

# ---- Surface sweep on the finished collection ---------------------------------
# The committed CSV has the same rows, order, and columns, so
# `--sweep-only data/riverton/riverton-review-collection.csv` reproduces the
# record-level part of this sweep. Core and frame features exist only here.

review_collection_for_sweep <- review_collection |>
  mutate(
    core_first_word = coalesce(word(core_text, 1), "no word"),
    core_first_two_words = coalesce(str_squish(str_extract(core_text, "^\\S+\\s+\\S+")), "no frame"),
    core_sentence_frame = coalesce(str_extract(core_text, "^\\S+\\s+\\S+\\s+\\S+"), "no frame"),
    core_has_colon = str_detect(core_text, fixed(":"))
  )

# The check-only modes read frames from text; confirm that reading equals the
# builder's own frame assignment, so CK-D1 and CK-D2 see the same frames here.
frames_read_from_text <- split_frame(review_collection$text)
stopifnot(
  identical(frames_read_from_text$frame_id, review_collection$frame_id),
  identical(frames_read_from_text$core, review_collection$core_text)
)

review_sweep <- surface_sweep(
  review_collection_for_sweep,
  extra_features = c(
    "frame_id",
    "core_first_word",
    "core_first_two_words",
    "core_sentence_frame",
    "core_has_colon"
  )
)

frame_scores <- review_collection_for_sweep |>
  group_by(frame_id) |>
  summarise(frame_share = mean(reference_responsive), .groups = "drop")
frame_ranked <- review_collection_for_sweep |>
  left_join(frame_scores, by = join_by(frame_id)) |>
  arrange(desc(frame_share), doc_id)
frame_ranker_diagnostic <- metric_from_prediction(
  seq_len(nrow(frame_ranked)) <= sum(frame_ranked$reference_responsive),
  frame_ranked$reference_responsive
) |>
  mutate(
    check = "frame-only ranker",
    feature = "frame_only_ranker",
    feature_value = "top 36 by frame share",
    positive_when_feature_is = "top 36",
    auc = NA_real_,
    refuses = positive_f1 >= refusal_f1 | balanced_accuracy >= refusal_ba
  )

review_sweep <- bind_rows(review_sweep, frame_ranker_diagnostic)
print_sweep(review_sweep, "rebuilt collection (record, core, and frame features)")

frame_share_cap <- review_collection_for_sweep |>
  filter(!reference_responsive) |>
  count(frame_id) |>
  summarise(max_share = max(n) / sum(n)) |>
  pull(max_share)

core_first_two_share_cap <- review_collection_for_sweep |>
  filter(!reference_responsive) |>
  count(core_first_two_words) |>
  summarise(max_share = max(n) / sum(n)) |>
  pull(max_share)

# N46-A3: elements fixed from commit a3478085.
responsive_core_digest <- digest(
  paste(sort(review_collection$core_text[review_collection$reference_responsive]), collapse = "\n"),
  algo = "sha256",
  serialize = FALSE
)
lowercase_weekday_rows <- str_detect(
  review_collection$text,
  "\\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\\b"
)

normalized_hashes <- review_collection |>
  mutate(
    normalized = str_squish(str_to_lower(text, locale = "en")),
    normalized_hash = map_chr(
      normalized,
      \(value) digest(value, algo = "sha256", serialize = FALSE)
    )
  )

base_text_counts <- review_collection |>
  mutate(base_text = mask_base_text(text)) |>
  count(base_text, sort = TRUE)

id_numeric <- as.integer(str_extract(review_collection$doc_id, "\\d+"))
label_numeric <- as.integer(review_collection$reference_responsive)
id_label_correlation <- abs(cor(id_numeric, label_numeric))
position_label_correlation <- abs(cor(review_collection$file_position, label_numeric))
date_label_correlation <- abs(cor(as.numeric(review_collection$doc_date), label_numeric))
lowest_36_responsive <- review_collection |>
  filter(id_numeric <= 36L) |>
  summarise(responsive = sum(reference_responsive)) |>
  pull(responsive)

stream_id_numeric <- as.integer(str_extract(monitoring_stream$stream_id, "\\d+"))
stream_label_correlation <- abs(cor(stream_id_numeric, as.integer(monitoring_stream$reference_alert)))

stopifnot(
  identical(nrow(review_collection), 240L),
  identical(sum(review_collection$reference_responsive), 36L),
  n_distinct(review_collection$doc_id) == nrow(review_collection),
  n_distinct(normalized_hashes$normalized_hash) == nrow(review_collection),
  all(nzchar(review_collection$author_note)),
  n_distinct(base_text_counts$base_text) >= 150L,
  max(base_text_counts$n) <= 3L,
  sum(!is.na(review_collection$near_duplicate_of)) == 6L,
  sum(!is.na(monitoring_stream$near_duplicate_of)) == 6L,
  !str_detect(paste(review_collection$text, collapse = " "), "RYD-\\d{4}"),
  !str_detect(paste(monitoring_stream$text, collapse = " "), "MON-\\d{3}"),
  id_label_correlation < 0.05,
  position_label_correlation < 0.05,
  date_label_correlation < 0.10,
  lowest_36_responsive <= 8L,
  stream_label_correlation < 0.12,
  keyword_counts$hits >= 28L,
  keyword_counts$hits <= 60L,
  keyword_counts$responsive_hits >= 8L,
  keyword_counts$hits - keyword_counts$responsive_hits >= 8L,
  !any(review_sweep$refuses),
  frame_share_cap <= 0.15,
  core_first_two_share_cap <= 0.15,
  identical(review_request, paste(
    "Find records about hiding safety inspection delays, changing inspection",
    "logs, or deleting inspection-related messages for the Calder Yard contract."
  )),
  identical(
    digest(review_request, algo = "sha256", serialize = FALSE),
    "57420a975a6ef439d79efa7f316e6f4cc27ecbed6e78774284e3490943842427"
  ),
  identical(
    responsive_core_digest,
    "4eb3583b3255b91353ffa82625e7072c3067ce21bbc7021b6caeb78cd5f0f5e1"
  ),
  identical(keyword_counts$hits - keyword_counts$responsive_hits, 17L),
  !any(lowercase_weekday_rows),
  all(keyword_results$keyword_hit[keyword_results$construction_subtype == "keyword false hit"]),
  !any(keyword_results$keyword_hit[
    keyword_results$construction_subtype %in% c("not responsive", "vocabulary mismatch responsive")
  ]),
  all(!keyword_results$reference_responsive[
    keyword_results$construction_subtype %in% c("keyword false hit", "not responsive")
  ]),
  all(
    keyword_results$keyword_hit[
      keyword_results$construction_subtype == "keyword responsive"
    ]
  ),
  identical(nrow(monitoring_stream), 24L),
  identical(monitoring_stream$arrival_order, seq_len(nrow(monitoring_stream)))
)

review_collection_output <- review_collection |>
  select(
    doc_id,
    record_type,
    doc_date,
    source_type,
    sender_role,
    subject,
    review_request,
    reference_responsive,
    reference_reason,
    construction_subtype,
    near_duplicate_of,
    text,
    author_note,
    construction_id,
    file_position
  )

write_csv(review_collection_output, collection_path)
write_csv(monitoring_stream, stream_path)

hash_lines <- function(path) {
  digest(
    paste(read_lines(path), collapse = "\n"),
    algo = "sha256",
    serialize = FALSE
  )
}

# N46-A3: the monitoring stream is byte-for-byte the stream committed at a3478085.
stopifnot(identical(
  hash_lines(stream_path),
  "b20bf84c900673191e282f02f8b1ec69b38cb85527ceef1d43b9567ea57eac4a"
))

metadata <- tibble(
  artifact = c(
    "riverton-review-collection.csv",
    "riverton-monitoring-stream.csv"
  ),
  description = c(
    paste(
      "Constructed review collection for one fictional e-discovery request;",
      "36 of 240 rows are reference responsive"
    ),
    paste(
      "Constructed dated monitoring stream with arrival order, syndicated",
      "near-duplicates, and ambiguous Riverton mentions"
    )
  ),
  source = "Created for this project",
  license = "MIT, same as this repository",
  created_on = "2026-09-23",
  purpose = c(
    paste(
      "Teaching fixture for keyword search, ranked review, stopping,",
      "and elusion sampling; not an evaluation benchmark."
    ),
    paste(
      "Teaching fixture for arrival-order monitoring, duplicate suppression,",
      "and ambiguous names; not real media data."
    )
  ),
  rows = c(nrow(review_collection), nrow(monitoring_stream)),
  class_counts = c(
    paste(
      paste(
        c("responsive", "not responsive"),
        c(
          sum(review_collection$reference_responsive),
          sum(!review_collection$reference_responsive)
        ),
        sep = "="
      ),
      collapse = "; "
    ),
    paste(
      paste(
        c("reference alert", "not alert"),
        c(
          sum(monitoring_stream$reference_alert),
          sum(!monitoring_stream$reference_alert)
        ),
        sep = "="
      ),
      collapse = "; "
    )
  ),
  fingerprint = c(hash_lines(collection_path), hash_lines(stream_path)),
  rng_kind = paste(RNGkind(), collapse = "; "),
  seed = "7401",
  effective_seeds = paste(
    "base=7401",
    "row_shuffle=7403",
    paste0("date=", date_seed, " (first seed from 7402 with |cor(date, label)| < 0.08)"),
    paste0("doc_id=", id_seed, " (first seed from 7401 with at most 8 responsive in IDs 1-36 and |cor(ID, label)| < 0.05)"),
    paste0("stream_id=", stream_seed, " (first seed from 8401 with |cor(ID, alert)| < 0.12)"),
    "heldout_splits=7501-7520",
    "ranker_folds=7601,7602,7603",
    sep = "; "
  ),
  review_request = review_request,
  shortcut_sweep = paste(
    "Refuses to write if any check reaches positive F1 >= 0.60 or balanced",
    "accuracy >= 0.75, and stops on any NA diagnostic. Checks: single values",
    "and held-out value sets (20 split-halves) of record features (length,",
    "punctuation, pronouns, digits, month, weekday, ID digit, ID order, date",
    "rank, file position, construction ID order, first three tokens, first",
    "word, first two words, sentence count, colon, source type, sender role,",
    "subject) and of core and frame features; the 20 most frequent non-topic",
    "tokens; out-of-fold glmnet ridge and lasso rankers over snowball",
    "stop-word counts and over format cues (length, punctuation,",
    "capitalization, digits), stratified 5-fold under three fold seeds, top",
    "36; a frame-only ranker; a 15 percent cap on any frame or core opening",
    "among non-responsive records; CK-D1, label-free rarity rules (k = 1 to 4)",
    "and a held-out ranker over the pair of frame and core opening word; and",
    "CK-D2, frame rules and a held-out frame ranker within the keyword-match",
    "and no-match strata, thresholded on balanced accuracy."
  )
)

write_csv(metadata, file.path(out_dir, "riverton-review-collection-metadata.csv"))

cat("wrote:\n")
print(
  tibble(
    file = c(
      collection_path,
      stream_path,
      file.path(out_dir, "riverton-review-collection-metadata.csv")
    )
  ) |>
    mutate(bytes = file.size(file))
)

print(keyword_counts)
