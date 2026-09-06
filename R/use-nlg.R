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
  required_files <- strsplit(
    selected$required_files,
    ";",
    fixed = TRUE
  )[[1]]
  missing <- required_files[
    !file.exists(file.path(model_path, required_files))
  ]

  if (length(missing) > 0L) {
    stop(
      paste0(
        "The pinned model ", selected$model_id, " is incomplete. ",
        "Run .venv-nlg's Python with scripts/setup-nlg-models.py. ",
        "Missing: ", paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  normalizePath(model_path, winslash = "/", mustWork = TRUE)
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
  output_ids <- if (is_encoder_decoder) {
    sequence_ids
  } else if (length(sequence_ids) > input_tokens) {
    sequence_ids[seq.int(input_tokens + 1L, length(sequence_ids))]
  } else {
    integer()
  }
  eos_ids <- as.integer(
    unlist(
      nlg_as_r(
        model_bundle$pipeline$model$generation_config$eos_token_id
      ),
      use.names = FALSE
    )
  )
  ended_by_eos <- length(output_ids) > 0L &&
    tail(output_ids, 1L) %in% eos_ids

  list(
    text = trimws(
      model_bundle$tokenizer$decode(
        output_ids,
        skip_special_tokens = TRUE,
        clean_up_tokenization_spaces = TRUE
      )
    ),
    input_tokens = input_tokens,
    output_tokens = length(output_ids),
    ended_by_eos = ended_by_eos,
    hit_token_cap = length(output_ids) >= max_new_tokens &&
      !ended_by_eos,
    last_token_id = if (length(output_ids) > 0L) {
      tail(output_ids, 1L)
    } else {
      NA_integer_
    }
  )
}
