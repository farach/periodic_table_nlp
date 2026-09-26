# Build the cached language-model labels used by the guide page
# "Using a language model in a reproducible analysis".
#
# Usage, from the project root:
#   Rscript data-raw/build-llm-review-labels.R            # label all 240 records
#   Rscript data-raw/build-llm-review-labels.R --time 5   # time 5 records, write nothing
#
# The builder reads the frozen review collection from lesson 74 and the prompt
# file, asks the pinned local Qwen2.5-1.5B-Instruct model one yes-or-no question
# per record with greedy decoding, and writes every raw output. The prompt was
# written before the first run and is not tuned on model output. The metadata
# records the model revision, prompt fingerprint, decoding settings, platform,
# and file fingerprints, so the guide page can refuse a cache that no longer
# matches its instrument.

suppressPackageStartupMessages({
  library(dplyr)
  library(jsonlite)
  library(purrr)
  library(readr)
  library(stringr)
  library(tibble)
})

source("R/use-nlg.R")

args <- commandArgs(trailingOnly = TRUE)
time_only <- length(args) >= 1L && identical(args[[1]], "--time")
time_n <- if (time_only && length(args) >= 2L) as.integer(args[[2]]) else 5L

hash_lines <- function(path) {
  digest::digest(
    paste(read_lines(path), collapse = "\n"),
    algo = "sha256",
    serialize = FALSE
  )
}

collection_path <- "data/riverton/riverton-review-collection.csv"
prompt_path <- "data/riverton/riverton-llm-review-prompt.json"
labels_path <- "data/riverton/riverton-llm-review-labels.csv"
metadata_path <- "data/riverton/riverton-llm-review-labels-metadata.csv"

records <- read_csv(
  collection_path,
  na = c("", "NA"),
  col_types = cols(.default = col_character())
) |>
  select(doc_id, review_request, text)

prompt <- read_json(prompt_path)
stopifnot(
  n_distinct(records$review_request) == 1L,
  str_detect(prompt$user_template, fixed("{request}")),
  str_detect(prompt$user_template, fixed("{record}"))
)

fill_prompt <- function(request, record) {
  prompt$user_template |>
    str_replace(fixed("{request}"), request) |>
    str_replace(fixed("{record}"), record)
}

parse_label <- function(raw_output) {
  first_word <- raw_output |>
    str_to_lower() |>
    str_extract("[a-z]+")
  case_when(
    first_word == "yes" ~ "responsive",
    first_word == "no" ~ "not responsive",
    TRUE ~ "unparsed"
  )
}

model <- load_nlg_pipeline("qwen_1_5b_instruct", "text-generation")
max_new_tokens <- 3L

label_record <- function(request, record) {
  chat_prompt <- nlg_chat_prompt(
    model$tokenizer,
    prompt$system,
    fill_prompt(request, record)
  )
  generation <- nlg_generate(model, chat_prompt, max_new_tokens = max_new_tokens)
  tibble(
    raw_output = generation$text,
    output_tokens = generation$output_tokens,
    ended_by_eos = generation$ended_by_eos
  )
}

to_label <- if (time_only) slice_head(records, n = time_n) else records

started <- Sys.time()
labels <- to_label |>
  mutate(result = map2(review_request, text, label_record)) |>
  select(doc_id, result) |>
  tidyr::unnest(result) |>
  mutate(llm_label = parse_label(raw_output), .after = raw_output)
elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))

cat(sprintf(
  "Labelled %d records in %.1f seconds (%.2f seconds per record).\n",
  nrow(labels), elapsed, elapsed / nrow(labels)
))
print(count(labels, llm_label))

if (time_only) {
  print(labels)
  quit(save = "no", status = 0L)
}

stopifnot(
  identical(labels$doc_id, records$doc_id),
  all(labels$llm_label %in% c("responsive", "not responsive", "unparsed"))
)

write_csv(labels, labels_path, na = "")

python_versions <- reticulate::py_run_string(
  paste(
    "import platform, torch, transformers",
    "_versions = {'python': platform.python_version(),",
    "             'torch': torch.__version__,",
    "             'transformers': transformers.__version__}",
    sep = "\n"
  ),
  convert = TRUE
)$`_versions`

metadata <- tibble(
  artifact = "riverton-llm-review-labels.csv",
  description = paste(
    "Raw yes-or-no answers from the pinned local language model for all 240",
    "records in the constructed review collection, with parsed labels"
  ),
  source = "Created for this project by data-raw/build-llm-review-labels.R",
  license = "MIT, same as this repository",
  created_on = format(Sys.Date()),
  rows = nrow(labels),
  model_key = model$metadata$model_key,
  model_id = model$metadata$model_id,
  revision = model$metadata$revision,
  prompt_id = prompt$prompt_id,
  prompt_sha256 = hash_lines(prompt_path),
  collection_sha256 = hash_lines(collection_path),
  decoding = sprintf(
    "greedy; do_sample = FALSE; num_beams = 1; max_new_tokens = %d; repetition_penalty = 1",
    max_new_tokens
  ),
  platform = sprintf(
    "%s; %s; Python %s; torch %s; transformers %s",
    R.version.string,
    utils::sessionInfo()$running,
    python_versions$python,
    python_versions$torch,
    python_versions$transformers
  ),
  seconds_per_record = round(elapsed / nrow(labels), 2),
  fingerprint = hash_lines(labels_path)
)

write_csv(metadata, metadata_path, na = "")
cat("Wrote", labels_path, "and", metadata_path, "\n")
