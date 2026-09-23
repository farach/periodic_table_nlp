# Build the fictional Riverton review collection used by task 74.
#
# Run by hand, not during a render. Everything here is invented for teaching.
# No real legal matter, company, person, source, or news item is described.
#
# Usage:
#   Rscript data-raw/build-riverton-review-collection.R

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tibble)
  library(tidyr)
  library(purrr)
  library(stringr)
  library(digest)
})

set.seed(7401)
RNGkind(kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")

out_dir <- "data/riverton"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

author_note <- paste(
  "Constructed teaching record: this row is fictional and does not describe",
  "a real person, organisation, case, or media item."
)

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

make_review_rows <- function(texts,
                             responsive,
                             subtype,
                             start_index,
                             near_duplicate_of = NA_character_) {
  row_count <- length(texts)
  reference_reason <- if (responsive && str_detect(subtype, "keyword")) {
    "mentions inspection records, delay, deletion, or logs tied to the request"
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
    text = texts,
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
        text = str_to_sentence(str_c(
          "the ", area, " team ", action, " the ", item, " ", detail, "."
        ))
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
  mutate(file_position = row_number()) |>
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

collection_path <- file.path(out_dir, "riverton-review-collection.csv")
stream_path <- file.path(out_dir, "riverton-monitoring-stream.csv")

score_binary_feature <- function(data, feature_name) {
  values <- data[[feature_name]]
  feature_values <- sort(unique(values))

  map_dfr(feature_values, \(feature_value) {
    positive_when_equal <- values == feature_value
    orientations <- tibble(
      positive_when_feature_is = c("present", "absent"),
      predicted = list(positive_when_equal, !positive_when_equal)
    ) |>
      mutate(
        true_positive = map_int(predicted, \(x) sum(x & data$reference_responsive)),
        false_positive = map_int(predicted, \(x) sum(x & !data$reference_responsive)),
        false_negative = map_int(predicted, \(x) sum(!x & data$reference_responsive)),
        true_negative = map_int(predicted, \(x) sum(!x & !data$reference_responsive)),
        positive_precision = if_else(
          true_positive + false_positive == 0L,
          0,
          true_positive / (true_positive + false_positive)
        ),
        positive_recall = true_positive / (true_positive + false_negative),
        positive_f1 = if_else(
          positive_precision + positive_recall == 0,
          0,
          2 * positive_precision * positive_recall /
            (positive_precision + positive_recall)
        ),
        responsive_recall = true_positive / (true_positive + false_negative),
        not_responsive_recall = true_negative / (true_negative + false_positive),
        balanced_accuracy = (responsive_recall + not_responsive_recall) / 2
      ) |>
      arrange(desc(positive_f1), desc(balanced_accuracy)) |>
      slice(1)

    tibble(
      feature = feature_name,
      feature_value = as.character(feature_value),
      positive_when_feature_is = orientations$positive_when_feature_is,
      positive_f1 = orientations$positive_f1,
      balanced_accuracy = orientations$balanced_accuracy
    )
  }) |>
    arrange(desc(positive_f1), desc(balanced_accuracy)) |>
    slice(1)
}

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

review_features <- review_collection |>
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
    month = format(doc_date, "%m"),
    weekday = weekdays(doc_date),
    id_last_digit = str_sub(doc_id, -1),
    id_number_band = ntile(doc_id_number, 5),
    date_rank_band = ntile(as.numeric(doc_date), 5),
    file_position_band = ntile(file_position, 5),
    construction_template = paste0(
      "template-",
      as.integer(str_extract(construction_id, "\\d+")) %% 12L
    ),
    source_type = source_type,
    sender_role = sender_role,
    subject = subject
  )

shortcut_features <- c(
  "length_band",
  "punctuation_band",
  "first_person_pronoun",
  "has_digit",
  "month",
  "weekday",
  "id_last_digit",
  "id_number_band",
  "date_rank_band",
  "file_position_band",
  "construction_template",
  "source_type",
  "sender_role",
  "subject"
)

shortcut_diagnostics <- map_dfr(
  shortcut_features,
  \(feature) score_binary_feature(review_features, feature)
)

print(
  shortcut_diagnostics |>
    mutate(
      positive_f1 = round(positive_f1, 4),
      balanced_accuracy = round(balanced_accuracy, 4)
    ),
  n = Inf,
  width = Inf
)

keyword_regex <- regex(paste(keyword_terms, collapse = "|"), ignore_case = TRUE)
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
  max(shortcut_diagnostics$positive_f1) < 0.60,
  max(shortcut_diagnostics$balanced_accuracy) < 0.75,
  identical(nrow(monitoring_stream), 24L),
  identical(monitoring_stream$arrival_order, seq_len(nrow(monitoring_stream)))
)

write_csv(review_collection, collection_path)
write_csv(monitoring_stream, stream_path)

hash_lines <- function(path) {
  digest(
    paste(read_lines(path), collapse = "\n"),
    algo = "sha256",
    serialize = FALSE
  )
}

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
  review_request = review_request,
  shortcut_sweep = paste(
    "Refuses to write if any audited superficial feature reaches positive",
    "F1 >= 0.60 or balanced accuracy >= 0.75."
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
