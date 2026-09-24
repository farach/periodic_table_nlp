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
# 0a5a5af9 and a3478085 and on a quarantined intermediate collection, and exits
# 0 only if all three are refused.

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

  result <- bind_rows(single_value, heldout, frequent_tokens, function_words, format_cues) |>
    mutate(refuses = positive_f1 >= refusal_f1 | balanced_accuracy >= refusal_ba) |>
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
# 0a5a5af9 and a3478085 and the quarantined intermediate collection whose path
# is given, and the function-word ranker must be among the checks that refuse
# the intermediate collection. Writes nothing; exits 0 only if all hold.
if (length(args) == 2L && identical(args[[1]], "--negative-controls")) {
  controls <- list(
    "committed at 0a5a5af9" = read_committed_collection("0a5a5af9"),
    "committed at a3478085" = read_committed_collection("a3478085"),
    "intermediate collection" = read_csv(args[[2]], show_col_types = FALSE, na = c("", "NA"))
  )
  control_results <- imap(controls, \(data, label) print_sweep(surface_sweep(data), label))
  refused <- map_lgl(control_results, \(result) any(result$refuses))
  function_word_refuses <- any(
    control_results[["intermediate collection"]]$refuses &
      control_results[["intermediate collection"]]$check == "held-out function-word ranker"
  )
  cat("\nRefused:", paste(names(refused), refused, sep = " = ", collapse = "; "), "\n")
  cat("Function-word ranker refuses the intermediate collection:", function_word_refuses, "\n")
  quit(status = if (all(refused) && function_word_refuses) 0L else 1L)
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

work_areas <- tribble(
  ~area, ~items, ~actions, ~details,
  "facilities",
  list(c("badge printer", "east gate light", "break room fan", "loading dock sign")),
  list(c("opened a repair ticket for", "checked the status of", "asked maintenance to look at")),
  list(c("after the morning shift", "before visitor hours", "near the training entrance")),
  "scheduling",
  list(c("orientation calendar", "room booking", "callback list", "evening roster")),
  list(c("moved", "confirmed", "updated")),
  list(c("for next Tuesday", "before the afternoon intake", "after a supervisor request")),
  "payroll",
  list(c("timesheet export", "stipend batch", "overtime form", "direct deposit list")),
  list(c("checked", "sent", "corrected")),
  list(c("for the finance desk", "before noon", "after a duplicate row appeared")),
  "training",
  list(c("forklift refresher sheet", "spreadsheet practice file", "classroom key list", "attendance binder")),
  list(c("moved", "printed", "filed")),
  list(c("for the instructor", "before the evening class", "with the updated cover page")),
  "transit",
  list(c("bus pass envelope", "shuttle roster", "fare voucher form", "route notice")),
  list(c("counted", "reordered", "corrected")),
  list(c("for Monday pickup", "after two names changed", "with the new stop name")),
  "supplies",
  list(c("glove order", "paper shipment", "laptop cart labels", "visitor pens")),
  list(c("received", "recounted", "requested")),
  list(c("from the front desk", "for the skills lab", "after the delivery arrived")),
  "visitors",
  list(c("sign-in sheet", "guest badge list", "tour schedule", "parking note")),
  list(c("prepared", "updated", "checked")),
  list(c("for the contractor tour", "before the noon walkthrough", "after the room changed")),
  "IT",
  list(c("portal ticket", "password reset queue", "scanner cable", "shared drive folder")),
  list(c("closed", "reopened", "renamed")),
  list(c("after the help desk call", "for the records assistant", "before the export")),
  "safety",
  list(c("classroom drill note", "visitor vest list", "spill kit checklist", "inspection newsletter")),
  list(c("posted", "updated", "filed")),
  list(c("for training only", "near the supply shelf", "with the outreach materials"))
)

everyday_texts <- pmap_dfr(
  work_areas,
  \(area, items, actions, details) {
    expand_grid(
      item = unlist(items),
      action = unlist(actions),
      detail = unlist(details)
    ) |>
      mutate(
        variant = row_number(),
        text = case_when(
          variant %% 9L == 1L ~ str_c(
            "The ", item, " note says the ", area, " desk ", action, " it ", detail, "."
          ),
          variant %% 9L == 2L ~ str_c(
            "Please review the ", item, " ", detail, "."
          ),
          variant %% 9L == 3L ~ str_c(
            "Keep the ", item, " with the ", area, " materials ", detail, "."
          ),
          variant %% 9L == 4L ~ str_c(
            "Move the ", item, " to the ", area, " folder ", detail, "."
          ),
          variant %% 9L == 5L ~ str_c(
            "Use the ", item, " for the ", area, " follow-up ", detail, "."
          ),
          variant %% 9L == 6L ~ str_c(
            "Tell the front desk the ", item, " was handled ", detail, "."
          ),
          variant %% 9L == 7L ~ str_c(
            "Do not move the ", item, " from the ", area, " shelf ", detail, "."
          ),
          variant %% 9L == 8L ~ str_c(
            "After the update, the ", area, " desk checked the ", item, " ", detail, "."
          ),
          TRUE ~ str_c(
            "If anyone asks, the ", item, " is with ", area, " ", detail, "."
          )
        )
      ) |>
      select(text)
  }
) |>
  distinct() |>
  pull(text)

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
nonresponsive_everyday_texts <- everyday_texts[seq_len(nonresponsive_needed)]

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
  remaining <- setNames(rep(capacity, length(frames)), frames)

  for (pair_index in seq_along(paired_rows)) {
    rows <- paired_rows[[pair_index]]
    frame <- frames[[pair_index]]
    assignment[rows] <- frame
    remaining[[frame]] <- remaining[[frame]] - length(rows)
  }

  for (row in which(is.na(assignment))) {
    frame <- names(remaining)[remaining > 0][[1]]
    assignment[[row]] <- frame
    remaining[[frame]] <- remaining[[frame]] - 1L
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
    "36; a frame-only ranker; and a 15 percent cap on any frame or core",
    "opening among non-responsive records."
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
