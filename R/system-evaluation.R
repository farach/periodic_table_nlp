align_evaluation <- function(cases, runs) {
  case_columns <- c(
    "case_id", "slice", "input", "target", "confirmation_required"
  )
  run_columns <- c(
    "case_id", "version_id", "trial_id", "status", "response",
    "task_met", "confirmed", "judge_pass"
  )
  check <- function(condition, message) {
    if (!isTRUE(condition)) stop(message, call. = FALSE)
  }
  check(identical(names(cases), case_columns), "Invalid case columns.")
  check(identical(names(runs), run_columns), "Invalid run columns.")
  check(
    all(vapply(cases[1:4], is.character, logical(1))) &&
      is.logical(cases$confirmation_required) &&
      all(vapply(runs[c(1, 2, 4, 5)], is.character, logical(1))) &&
      is.integer(runs$trial_id) &&
      all(vapply(runs[6:8], is.logical, logical(1))),
    "Invalid evaluation column types."
  )
  check(
    !anyNA(cases) &&
      all(vapply(cases[1:4], \(x) all(nzchar(trimws(x))), logical(1))) &&
      !anyDuplicated(cases$case_id) &&
      setequal(cases$case_id, sprintf("c%02d", 1:8)),
    "Expected eight unique, fully specified cases."
  )
  check(
    !anyNA(runs[c("case_id", "version_id", "trial_id", "status")]) &&
      all(runs$case_id %in% cases$case_id) &&
      all(runs$version_id %in% c("A", "B")) &&
      all(runs$trial_id %in% 1:2) &&
      all(runs$status %in% c("completed", "error")),
    "Invalid run key or status."
  )
  check(
    !anyDuplicated(runs[c("case_id", "version_id", "trial_id")]),
    "Duplicate run key."
  )
  completed <- runs$status == "completed"
  required <- cases$confirmation_required[match(runs$case_id, cases$case_id)]
  check(
    all(!is.na(runs$response[completed])) &&
      all(nzchar(trimws(runs$response[completed]))) &&
      !anyNA(runs$task_met[completed]) &&
      !anyNA(runs$judge_pass[completed]) &&
      !anyNA(runs$confirmed[completed & required]) &&
      all(is.na(runs$confirmed[completed & !required])),
    "Incomplete or inapplicable completed-run annotation."
  )
  check(
    all(vapply(
      runs[!completed, c("response", "task_met", "confirmed", "judge_pass")],
      \(x) all(is.na(x)),
      logical(1)
    )),
    "Error rows must not contain response or grading annotations."
  )

  tidyr::expand_grid(
    case_id = sort(cases$case_id),
    version_id = c("A", "B"),
    trial_id = 1:2
  ) |>
    dplyr::left_join(cases, by = "case_id", relationship = "many-to-one") |>
    dplyr::left_join(runs, by = c("case_id", "version_id", "trial_id")) |>
    dplyr::mutate(status = dplyr::coalesce(status, "missing"))
}

read_evaluation <- function(directory = "data/system-evaluation") {
  metadata <- readr::read_csv(
    file.path(directory, "metadata.csv"),
    col_types = readr::cols(.default = readr::col_character()),
    na = character(),
    show_col_types = FALSE
  )
  stopifnot(
    identical(names(metadata), c("artifact", "fingerprint")),
    identical(metadata$artifact, c("cases.csv", "runs.csv")),
    !anyNA(metadata),
    all(grepl("^[a-f0-9]{64}$", metadata$fingerprint))
  )
  observed <- vapply(metadata$artifact, \(name) {
    digest::digest(
      paste(readr::read_lines(file.path(directory, name)), collapse = "\n"),
      algo = "sha256", serialize = FALSE
    )
  }, character(1))
  if (!identical(unname(observed), metadata$fingerprint)) {
    stop("Evaluation data fingerprint mismatch.", call. = FALSE)
  }
  cases <- readr::read_csv(
    file.path(directory, "cases.csv"),
    col_types = readr::cols(
      .default = readr::col_character(),
      confirmation_required = readr::col_logical()
    ),
    na = "", show_col_types = FALSE
  )
  runs <- readr::read_csv(
    file.path(directory, "runs.csv"),
    col_types = readr::cols(
      .default = readr::col_character(),
      trial_id = readr::col_integer(),
      task_met = readr::col_logical(),
      confirmed = readr::col_logical(),
      judge_pass = readr::col_logical()
    ),
    na = "", show_col_types = FALSE
  )
  if (nrow(readr::problems(cases)) + nrow(readr::problems(runs)) > 0L) {
    stop("Evaluation CSV parsing failed.", call. = FALSE)
  }
  align_evaluation(cases, runs)
  list(cases = cases, runs = runs)
}
