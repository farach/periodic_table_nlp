source("R/use-nlg.R")

file_manifest <- nlg_model_file_manifest()
stopifnot(
  nrow(file_manifest) == 23L,
  all(nchar(file_manifest$sha256) == 64L),
  all(file_manifest$bytes > 0)
)

models <- nlg_model_manifest()
invisible(lapply(models$model_key, nlg_model_path))

fixture_model <- models[models$model_key == "opus_en_fr", , drop = FALSE]
fixture_manifest <- file_manifest[
  file_manifest$model_key == "opus_en_fr" &
    file_manifest$file_path == "config.json",
  ,
  drop = FALSE
]
fixture_dir <- tempfile("nlg-integrity-")
dir.create(fixture_dir)
fixture_path <- file.path(fixture_dir, "config.json")
real_path <- file.path(
  nlg_model_path("opus_en_fr"),
  "config.json"
)
stopifnot(file.copy(real_path, fixture_path))
nlg_verify_model_snapshot(
  fixture_model,
  fixture_dir,
  file_manifest = fixture_manifest
)

fixture_bytes <- readBin(
  fixture_path,
  what = "raw",
  n = file.info(fixture_path)$size
)
fixture_bytes[[1]] <- as.raw(bitwXor(as.integer(fixture_bytes[[1]]), 1L))
writeBin(fixture_bytes, fixture_path)
model_load_calls <- 0L
tamper_error <- tryCatch(
  {
    nlg_verify_model_snapshot(
      fixture_model,
      fixture_dir,
      file_manifest = fixture_manifest
    )
    model_load_calls <- model_load_calls + 1L
    NULL
  },
  error = identity
)
stopifnot(
  inherits(tamper_error, "error"),
  model_load_calls == 0L,
  grepl(fixture_path, conditionMessage(tamper_error), fixed = TRUE),
  grepl("SHA-256", conditionMessage(tamper_error), fixed = TRUE)
)

unlink(fixture_path)
missing_error <- tryCatch(
  nlg_verify_model_snapshot(
    fixture_model,
    fixture_dir,
    file_manifest = fixture_manifest
  ),
  error = identity
)
stopifnot(
  inherits(missing_error, "error"),
  grepl(fixture_path, conditionMessage(missing_error), fixed = TRUE),
  grepl("missing", conditionMessage(missing_error), fixed = TRUE)
)
unlink(fixture_dir, recursive = TRUE)

immediate_eos <- nlg_output_diagnostics(
  sequence_ids = c(59513L, 0L),
  is_encoder_decoder = TRUE,
  input_tokens = 4L,
  max_new_tokens = 5L,
  eos_ids = 0L
)
capped <- nlg_output_diagnostics(
  sequence_ids = c(59513L, 42L),
  is_encoder_decoder = TRUE,
  input_tokens = 4L,
  max_new_tokens = 1L,
  eos_ids = 0L
)
forced_eos_at_cap <- nlg_output_diagnostics(
  sequence_ids = c(59513L, 0L),
  is_encoder_decoder = TRUE,
  input_tokens = 4L,
  max_new_tokens = 1L,
  eos_ids = 0L
)
decoder_only <- nlg_output_diagnostics(
  sequence_ids = c(10L, 11L, 0L),
  is_encoder_decoder = FALSE,
  input_tokens = 2L,
  max_new_tokens = 1L,
  eos_ids = 0L
)

stopifnot(
  immediate_eos$output_tokens == 1L,
  immediate_eos$ended_by_eos,
  !immediate_eos$hit_token_cap,
  capped$output_tokens == 1L,
  !capped$ended_by_eos,
  capped$hit_token_cap,
  forced_eos_at_cap$output_tokens == 1L,
  forced_eos_at_cap$ended_by_eos,
  forced_eos_at_cap$hit_token_cap,
  identical(decoder_only$output_ids, 0L),
  decoder_only$ended_by_eos,
  decoder_only$hit_token_cap
)

generation_calls <- 0L
budget_error <- tryCatch(
  {
    nlg_assert_input_budget(193L, 192L, "oversized")
    generation_calls <- generation_calls + 1L
    NULL
  },
  error = identity
)
stopifnot(
  inherits(budget_error, "error"),
  generation_calls == 0L,
  grepl("before generation", conditionMessage(budget_error), fixed = TRUE)
)

optional_missing <- nlg_required_fact_action(
  required = c(TRUE, FALSE),
  text_flag = c(TRUE, FALSE)
)
required_missing <- nlg_required_fact_action(
  required = c(TRUE, FALSE),
  text_flag = c(FALSE, TRUE)
)
stopifnot(
  !optional_missing$revision_needed,
  optional_missing$missing_required == 0L,
  required_missing$revision_needed,
  required_missing$missing_required == 1L,
  identical(
    nlg_screen_label(c(TRUE, FALSE, NA)),
    c(
      "not flagged by screen",
      "held for human review",
      "not applicable"
    )
  )
)

number_screen_false_negative <- identical(
  regmatches("24", gregexpr("\\b\\d+\\b", "24", perl = TRUE))[[1]],
  regmatches(
    "twenty-four",
    gregexpr("\\b\\d+\\b", "twenty-four", perl = TRUE)
  )[[1]]
)
modal_screen_false_negative <- grepl(
  "\\b(must|required|obliged|has to)\\b",
  "Visitors have to sign.",
  ignore.case = TRUE,
  perl = TRUE
)
stopifnot(
  !number_screen_false_negative,
  !modal_screen_false_negative,
  identical(nlg_screen_label(FALSE), "held for human review"),
  !grepl("verified", nlg_screen_label(FALSE), fixed = TRUE)
)

suppressPackageStartupMessages(library(dplyr))

all_not_applicable <- tibble(
  item_id = "all-na",
  numbers_preserved = NA,
  name_present = NA,
  negation_visible = NA,
  modal_visible = NA
) |>
  rowwise() |>
  mutate(
    applicable_screens = sum(!is.na(c_across(c(
      numbers_preserved,
      name_present,
      negation_visible,
      modal_visible
    )))),
    flagged_screens = sum(c_across(c(
      numbers_preserved,
      name_present,
      negation_visible,
      modal_visible
    )) %in% FALSE)
  ) |>
  ungroup()

stopifnot(
  identical(all_not_applicable$applicable_screens, 0L),
  identical(all_not_applicable$flagged_screens, 0L)
)

suppressPackageStartupMessages({
  library(huggingfaceR)
  library(reticulate)
})

use_project_nlg()
nlg_config <- reticulate::py_config()
stopifnot(
  nlg_same_path(nlg_config$virtualenv, nlg_venv_path())
)

transformers_module <- nlg_import_python_module("transformers")
transformers_path <- normalizePath(
  nlg_as_r(transformers_module$`__file__`),
  winslash = "/",
  mustWork = TRUE
)
stopifnot(startsWith(
  tolower(transformers_path),
  paste0(tolower(nlg_venv_path()), "/")
))

missing_module_error <- tryCatch(
  nlg_import_python_module("_periodic_table_nlg_missing_module"),
  error = identity
)
stopifnot(
  inherits(missing_module_error, "error"),
  grepl(
    "Underlying Python error:",
    conditionMessage(missing_module_error),
    fixed = TRUE
  ),
  grepl(
    "_periodic_table_nlg_missing_module",
    conditionMessage(missing_module_error),
    fixed = TRUE
  )
)

translation_model <- load_nlg_pipeline("opus_en_fr", "translation")
forced_probe <- nlg_generate(
  translation_model,
  "The library is open.",
  max_new_tokens = 1L
)
translation_probe <- nlg_generate(
  translation_model,
  "The library is open on Tuesday.",
  max_new_tokens = 24L
)
stopifnot(
  forced_probe$output_tokens == 1L,
  forced_probe$ended_by_eos,
  forced_probe$hit_token_cap,
  nzchar(translation_probe$text)
)
rm(translation_model)
gc()

embedding_model <- load_nlg_pipeline("minilm_l6_v2", "feature-extraction")
embedding_texts <- c(
  "Free child care is available during evening classes.",
  "Can I bring my kid to class at night?"
)
embedding_rows <- lapply(embedding_texts, function(text) {
  token_vectors <- embedding_model$pipeline(text)[[1]]
  pooled <- colMeans(do.call(rbind, lapply(token_vectors, unlist)))
  pooled / sqrt(sum(pooled^2))
})
embedding_matrix <- do.call(rbind, embedding_rows)
stopifnot(
  is.null(embedding_model$pipeline$model$generation_config),
  identical(dim(embedding_matrix), c(2L, 384L)),
  all(abs(rowSums(embedding_matrix^2) - 1) < 1e-6),
  sum(embedding_matrix[1, ] * embedding_matrix[2, ]) > 0
)
rm(embedding_model)
gc()

generation_model <- load_nlg_pipeline(
  "qwen_1_5b_instruct",
  "text-generation"
)
generation_prompt <- nlg_chat_prompt(
  generation_model$tokenizer,
  "Follow the instruction and return only the requested word.",
  "Return READY."
)
generation_probe <- nlg_generate(
  generation_model,
  generation_prompt,
  max_new_tokens = 12L
)
stopifnot(nzchar(generation_probe$text))

cat("NLG runtime integrity, accounting, and offline generation tests passed\n")
