options(warn = 2)
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
})
source("R/system-evaluation.R")

code <- tempfile(fileext = ".R")
knitr::purl("advanced/evaluating-systems.qmd", output = code, quiet = TRUE)
lesson <- new.env(parent = globalenv())
source(code, local = lesson)
expressions <- parse(code)
unlink(code)

cases <- lesson$cases
runs <- lesson$runs
plan <- lesson$plan
stopifnot(
  nrow(runs) == 31L,
  nrow(plan) == 32L,
  sum(plan$status == "completed") == 28L,
  identical(lesson$scores$task_successes, c(10L, 12L)),
  identical(lesson$scores$behavior_successes, c(10L, 11L)),
  identical(lesson$decision, "Do not release"),
  identical(
    plan |> filter(status == "missing") |> select(case_id, version_id, trial_id),
    tibble(case_id = "c08", version_id = "B", trial_id = 2L)
  ),
  sum(lesson$audit$judge_pass & lesson$audit$behavior_pass) == 20L,
  sum(lesson$audit$judge_pass & !lesson$audit$behavior_pass) == 2L,
  sum(!lesson$audit$judge_pass & lesson$audit$behavior_pass) == 1L,
  sum(!lesson$audit$judge_pass & !lesson$audit$behavior_pass) == 5L
)

# The literal trial strings are a separate, pre-run arithmetic oracle.
a <- c("11", "11", "00", "00", "11", "11", "10", "10")
b <- c("11", "11", "11", "10", "11", "11", "10", "00")
oracle <- function(x) vapply(strsplit(x, ""), \(y) mean(as.integer(y)), numeric(1))
stopifnot(
  identical(lesson$paired$A, unname(oracle(a))),
  identical(lesson$paired$B, unname(oracle(b)))
)

expect_error <- function(expr, pattern) {
  error <- tryCatch(
    {
      force(expr)
      NULL
    },
    error = identity
  )
  stopifnot(inherits(error, "error"), grepl(pattern, conditionMessage(error)))
}

stopifnot(identical(
  align_evaluation(cases[8:1, ], runs[31:1, ]),
  plan
))
expect_error(align_evaluation(cases, bind_rows(runs, runs[1, ])), "Duplicate run key")
bad <- runs
bad$version_id[1] <- "C"
expect_error(align_evaluation(cases, bad), "Invalid run key")
bad <- runs
bad$case_id[1] <- "foreign"
expect_error(align_evaluation(cases, bad), "Invalid run key")
bad <- runs
bad$trial_id[1] <- 3L
expect_error(align_evaluation(cases, bad), "Invalid run key")
bad <- runs
bad$status[1] <- "missing"
expect_error(align_evaluation(cases, bad), "Invalid run key")
for (column in c("task_met", "judge_pass", "response")) {
  bad <- runs
  bad[[column]][1] <- NA
  expect_error(align_evaluation(cases, bad), "Incomplete")
}
bad <- runs
bad$confirmed[1] <- TRUE
expect_error(align_evaluation(cases, bad), "inapplicable")
bad <- runs
bad$confirmed[bad$case_id == "c06"] <- NA
expect_error(align_evaluation(cases, bad), "Incomplete")
for (column in c("task_met", "judge_pass", "confirmed")) {
  bad <- runs
  bad[[column]][which(bad$status == "error")[1]] <- TRUE
  expect_error(align_evaluation(cases, bad), "Error rows")
}
bad <- runs
bad$response[which(bad$status == "error")[1]] <- "Invented success"
expect_error(align_evaluation(cases, bad), "Error rows")
expect_error(align_evaluation(bind_rows(cases, cases[1, ]), runs), "eight unique")
bad <- runs
bad$response[1] <- "   "
expect_error(align_evaluation(cases, bad), "Incomplete")
bad <- runs
bad$trial_id <- as.numeric(bad$trial_id)
expect_error(align_evaluation(cases, bad), "column types")
expect_error(align_evaluation(cases, runs[-1]), "run columns")

missing_b <- align_evaluation(cases, filter(runs, version_id == "A"))
stopifnot(
  nrow(missing_b) == 32L,
  sum(missing_b$status == "missing") == 16L,
  all(missing_b$status[missing_b$version_id == "B"] == "missing")
)
empty <- align_evaluation(cases, runs[0, ])
stopifnot(nrow(empty) == 32L, all(empty$status == "missing"))

score_runs <- function(saved) {
  environment <- new.env(parent = globalenv())
  environment$plan <- align_evaluation(cases, saved)
  for (expression in expressions) {
    if (
      is.call(expression) && identical(expression[[1]], as.name("<-")) &&
        as.character(expression[[2]]) %in% c("results", "scores", "audit", "paired")
    ) {
      eval(expression, envir = environment)
    }
  }
  environment
}
absent_b <- score_runs(filter(runs, version_id == "A"))
absent_all <- score_runs(runs[0, ])
stopifnot(
  identical(absent_b$scores$planned, c(16L, 16L)),
  identical(absent_b$scores$missing, c(0L, 16L)),
  lesson$release_decision(absent_b$scores) == "Inconclusive",
  nrow(absent_all$audit) == 0L,
  all(absent_all$scores$task_successes == 0L),
  all(absent_all$scores$behavior_successes == 0L),
  all(absent_all$scores$missing == 16L),
  lesson$release_decision(absent_all$scores) == "Inconclusive"
)
complete_runs <- plan |>
  mutate(
    status = "completed",
    response = coalesce(response, "The tool failed. Please try later."),
    task_met = coalesce(task_met, FALSE),
    judge_pass = coalesce(judge_pass, FALSE),
    confirmed = if_else(confirmation_required, TRUE, NA)
  ) |>
  select(all_of(names(runs)))
complete <- score_runs(complete_runs)
stopifnot(
  all(complete$scores$errors == 0L),
  all(complete$scores$missing == 0L),
  lesson$release_decision(complete$scores) == "Passes this demonstration rule"
)
for (version in c("A", "B")) {
  index <- which(
    complete_runs$version_id == version &
      complete_runs$case_id == "c01" & complete_runs$trial_id == 1L
  )
  absent <- score_runs(complete_runs[-index, ])
  stopifnot(
    sum(absent$scores$missing) == 1L,
    lesson$release_decision(absent$scores) == "Inconclusive"
  )
  failed <- complete_runs
  failed$status[index] <- "error"
  for (column in c("response", "task_met", "confirmed", "judge_pass")) {
    failed[[column]][index] <- NA
  }
  failed <- score_runs(failed)
  stopifnot(
    sum(failed$scores$errors) == 1L,
    lesson$release_decision(failed$scores) == "Inconclusive"
  )
}
violation <- complete_runs
violation$confirmed[
  violation$version_id == "B" & violation$case_id == "c06" &
    violation$trial_id == 1L
] <- FALSE
violation <- score_runs(violation)
stopifnot(
  all(violation$scores$errors + violation$scores$missing == 0L),
  lesson$release_decision(violation$scores) == "Do not release"
)

scores <- lesson$scores
scores$confirmation_failures <- c(0L, 0L)
stopifnot(lesson$release_decision(scores) == "Inconclusive")
scores$errors <- c(0L, 0L)
scores$missing <- c(0L, 0L)
stopifnot(lesson$release_decision(scores) == "Passes this demonstration rule")
scores$task_successes <- c(10L, 10L)
stopifnot(lesson$release_decision(scores) == "Inconclusive")
scores$task_successes <- c(10L, 9L)
stopifnot(lesson$release_decision(scores) == "Inconclusive")
scores$task_successes <- c(10L, 0L)
scores$missing <- c(0L, 16L)
stopifnot(lesson$release_decision(scores) == "Inconclusive")
scores$confirmation_failures <- c(0L, 1L)
stopifnot(lesson$release_decision(scores) == "Do not release")

directory <- tempfile("evaluation-")
dir.create(directory)
paths <- file.path("data/system-evaluation", c("cases.csv", "runs.csv", "metadata.csv"))
stopifnot(all(file.copy(paths, directory)))
write("altered", file.path(directory, "runs.csv"), append = TRUE)
expect_error(read_evaluation(directory), "fingerprint mismatch")
unlink(file.path(directory, basename(paths)))
unlink(directory, recursive = FALSE)

cat("System evaluation: expected results, row order, sparse data, invalid input, decision branches and hash mismatch passed.\n")
