nlg_project_root <- function() {
  root <- normalizePath(".", winslash = "/", mustWork = TRUE)
  manifest <- file.path(root, "data", "nlg-models.csv")

  if (!file.exists(manifest)) {
    stop(
      "Run NLG lessons from the project root so data/nlg-models.csv is available.",
      call. = FALSE
    )
  }

  root
}

nlg_model_manifest <- function() {
  read.csv(
    file.path(nlg_project_root(), "data", "nlg-models.csv"),
    colClasses = "character",
    check.names = FALSE
  )
}

nlg_model_file_manifest <- function() {
  read.csv(
    file.path(nlg_project_root(), "data", "nlg-model-files.csv"),
    colClasses = c(
      model_key = "character",
      model_id = "character",
      revision = "character",
      local_directory = "character",
      file_path = "character",
      sha256 = "character",
      bytes = "numeric"
    ),
    check.names = FALSE
  )
}

nlg_python_path <- function() {
  root <- nlg_project_root()
  candidates <- if (.Platform$OS.type == "windows") {
    file.path(root, ".venv-nlg", "Scripts", "python.exe")
  } else {
    file.path(root, ".venv-nlg", "bin", "python")
  }

  if (!file.exists(candidates)) {
    stop(
      paste(
        "The pinned NLG Python environment is missing.",
        "Create .venv-nlg, install requirements-nlg.txt, and run",
        "scripts/setup-nlg-models.py before rendering."
      ),
      call. = FALSE
    )
  }

  normalizePath(candidates, winslash = "/", mustWork = TRUE)
}

use_project_nlg <- function() {
  python <- nlg_python_path()

  if (reticulate::py_available(initialize = FALSE)) {
    active_python <- normalizePath(
      reticulate::py_config()$python,
      winslash = "/",
      mustWork = TRUE
    )

    if (!identical(tolower(active_python), tolower(python))) {
      stop(
        paste0(
          "reticulate is already using ", active_python, ". ",
          "NLG lessons require ", python, ". ",
          "Render spaCy and NLG lessons in separate R sessions."
        ),
        call. = FALSE
      )
    }
  } else {
    reticulate::use_python(python, required = TRUE)
  }

  Sys.setenv(
    HF_HUB_OFFLINE = "1",
    TRANSFORMERS_OFFLINE = "1",
    HF_HUB_DISABLE_TELEMETRY = "1"
  )

  invisible(python)
}

nlg_model_path <- function(model_key) {
  manifest <- nlg_model_manifest()
  selected <- manifest[manifest$model_key == model_key, , drop = FALSE]

  if (nrow(selected) != 1L) {
    stop(
      sprintf("Expected one NLG model named '%s'.", model_key),
      call. = FALSE
    )
  }

  model_path <- file.path(
    nlg_project_root(),
    "data-raw",
    ".cache",
    "nlg-models",
    selected$local_directory
  )
  nlg_verify_model_snapshot(selected, model_path)

  normalizePath(model_path, winslash = "/", mustWork = TRUE)
}

nlg_verify_model_snapshot <- function(model_record,
                                      model_path,
                                      file_manifest = nlg_model_file_manifest()) {
  files <- file_manifest[
    file_manifest$model_key == model_record$model_key,
    ,
    drop = FALSE
  ]

  if (nrow(files) == 0L) {
    stop(
      sprintf(
        "No runtime files are recorded for NLG model '%s'.",
        model_record$model_key
      ),
      call. = FALSE
    )
  }

  bound_fields <- c("model_id", "revision", "local_directory")
  for (field in bound_fields) {
    if (!all(files[[field]] == model_record[[field]])) {
      stop(
        sprintf(
          "data/nlg-model-files.csv has a mismatched %s for '%s'.",
          field,
          model_record$model_key
        ),
        call. = FALSE
      )
    }
  }

  for (row_index in seq_len(nrow(files))) {
    file_record <- files[row_index, , drop = FALSE]
    path <- file.path(model_path, file_record$file_path)
    expected_bytes <- file_record$bytes
    expected_hash <- file_record$sha256

    if (!file.exists(path)) {
      stop(
        sprintf(
          "%s: missing; expected %.0f bytes and SHA-256 %s. Run %s.",
          path,
          expected_bytes,
          expected_hash,
          "scripts/setup-nlg-models.py in a clean snapshot directory"
        ),
        call. = FALSE
      )
    }

    actual_bytes <- file.info(path)$size
    if (!identical(as.numeric(actual_bytes), as.numeric(expected_bytes))) {
      stop(
        sprintf(
          "%s: found %.0f bytes; expected %.0f.",
          path,
          actual_bytes,
          expected_bytes
        ),
        call. = FALSE
      )
    }

    actual_hash <- digest::digest(file = path, algo = "sha256")
    if (!identical(actual_hash, expected_hash)) {
      stop(
        sprintf(
          "%s: found SHA-256 %s; expected %s.",
          path,
          actual_hash,
          expected_hash
        ),
        call. = FALSE
      )
    }
  }

  invisible(files)
}

load_nlg_pipeline <- function(model_key, task) {
  use_project_nlg()
  manifest <- nlg_model_manifest()
  metadata <- manifest[manifest$model_key == model_key, , drop = FALSE]
  model_path <- nlg_model_path(model_key)
  tokenizer <- huggingfaceR::hf_load_tokenizer(
    model_path,
    local_files_only = TRUE
  )
  pipeline <- huggingfaceR::hf_load_pipeline(
    model_path,
    tokenizer = tokenizer,
    task = task,
    device = -1L
  )
  pipeline$model$generation_config$temperature <- NULL
  pipeline$model$generation_config$top_p <- NULL
  pipeline$model$generation_config$top_k <- NULL

  list(
    pipeline = pipeline,
    tokenizer = tokenizer,
    metadata = metadata
  )
}

nlg_chat_prompt <- function(tokenizer, system, user) {
  messages <- list(
    reticulate::dict(role = "system", content = system),
    reticulate::dict(role = "user", content = user)
  )

  tokenizer$apply_chat_template(
    messages,
    tokenize = FALSE,
    add_generation_prompt = TRUE
  )
}

nlg_as_r <- function(value) {
  if (inherits(value, "python.builtin.object")) {
    reticulate::py_to_r(value)
  } else {
    value
  }
}

nlg_token_count <- function(tokenizer, text, add_special_tokens = TRUE) {
  token_ids <- tokenizer$encode(
    text,
    add_special_tokens = add_special_tokens
  )

  as.integer(length(unlist(nlg_as_r(token_ids), use.names = FALSE)))
}

nlg_assert_input_budget <- function(input_tokens, max_input_tokens, item_ids) {
  over_budget <- input_tokens > max_input_tokens
  if (any(over_budget)) {
    stop(
      sprintf(
        "Input budget exceeded before generation for %s: %s tokens; limit %s.",
        paste(item_ids[over_budget], collapse = ", "),
        paste(input_tokens[over_budget], collapse = ", "),
        max_input_tokens
      ),
      call. = FALSE
    )
  }

  invisible(TRUE)
}

nlg_output_diagnostics <- function(sequence_ids,
                                   is_encoder_decoder,
                                   input_tokens,
                                   max_new_tokens,
                                   eos_ids,
                                   decoder_seed_tokens = 1L) {
  sequence_ids <- as.integer(sequence_ids)
  prompt_tokens <- if (is_encoder_decoder) {
    as.integer(decoder_seed_tokens)
  } else {
    as.integer(input_tokens)
  }
  output_ids <- if (length(sequence_ids) > prompt_tokens) {
    sequence_ids[seq.int(prompt_tokens + 1L, length(sequence_ids))]
  } else {
    integer()
  }
  ended_by_eos <- length(output_ids) > 0L &&
    tail(output_ids, 1L) %in% eos_ids

  list(
    output_ids = output_ids,
    output_tokens = length(output_ids),
    ended_by_eos = ended_by_eos,
    hit_token_cap = length(output_ids) >= max_new_tokens,
    last_token_id = if (length(output_ids) > 0L) {
      tail(output_ids, 1L)
    } else {
      NA_integer_
    }
  )
}

nlg_required_fact_action <- function(required, text_flag) {
  if (length(required) != length(text_flag) || anyNA(required)) {
    stop("Required-fact flags must have matching lengths.", call. = FALSE)
  }

  missing_required <- required & !text_flag
  list(
    missing_required = sum(missing_required),
    revision_needed = any(missing_required)
  )
}

nlg_screen_label <- function(result) {
  ifelse(
    is.na(result),
    "not applicable",
    ifelse(
      result,
      "not flagged by screen",
      "held for human review"
    )
  )
}

nlg_generate <- function(model_bundle,
                         prompt,
                         max_new_tokens,
                         repetition_penalty = 1) {
  encoded <- model_bundle$tokenizer(
    prompt,
    return_tensors = "pt",
    truncation = FALSE
  )
  input_ids <- encoded[["input_ids"]]
  attention_mask <- encoded[["attention_mask"]]
  input_tokens <- nlg_token_count(
    model_bundle$tokenizer,
    prompt
  )

  generated <- model_bundle$pipeline$model$generate(
    input_ids = input_ids,
    attention_mask = attention_mask,
    max_new_tokens = as.integer(max_new_tokens),
    do_sample = FALSE,
    num_beams = 1L,
    repetition_penalty = repetition_penalty
  )
  sequence_list <- nlg_as_r(
    generated$detach()$cpu()$tolist()
  )
  sequence_ids <- as.integer(unlist(sequence_list[[1]], use.names = FALSE))
  is_encoder_decoder <- isTRUE(
    nlg_as_r(
      model_bundle$pipeline$model$config$is_encoder_decoder
    )
  )
  eos_ids <- as.integer(
    unlist(
      nlg_as_r(
        model_bundle$pipeline$model$generation_config$eos_token_id
      ),
      use.names = FALSE
    )
  )
  diagnostics <- nlg_output_diagnostics(
    sequence_ids = sequence_ids,
    is_encoder_decoder = is_encoder_decoder,
    input_tokens = input_tokens,
    max_new_tokens = max_new_tokens,
    eos_ids = eos_ids
  )
  output_ids <- diagnostics$output_ids

  list(
    text = trimws(
      model_bundle$tokenizer$decode(
        output_ids,
        skip_special_tokens = TRUE,
        clean_up_tokenization_spaces = TRUE
      )
    ),
    input_tokens = input_tokens,
    output_tokens = diagnostics$output_tokens,
    ended_by_eos = diagnostics$ended_by_eos,
    hit_token_cap = diagnostics$hit_token_cap,
    last_token_id = diagnostics$last_token_id
  )
}
