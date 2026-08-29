# Catch models that are scored on the data they were fitted to.
#
# Two lessons in the models-and-analysis batch shipped first drafts that fitted a
# model on one object and then called predict() on that same object. Both
# produced numbers that looked like results: slice accuracies up to 1.000 against
# a real held-out score of 0.8209, and recall of exactly 1.000 for every class.
# Neither was caught by the other gates, because the code ran, the assertions
# passed, and the prose read well.
#
# This scan is deliberately narrow. It reports a leak only when the same symbol
# is handed to a fit() call and to a predict() or augment() call in the same
# lesson. That is the shape of the mistake, and it is cheap to check.
#
# A lesson may declare a reviewed exception with a comment on the fit or predict
# line:
#   # resubstitution-ok: <reason>
# Use it only when the lesson is showing what resubstitution looks like and says
# so to the reader.

suppressWarnings(suppressMessages({
  library(stringr)
}))

lesson_dirs <- list.dirs(".", recursive = FALSE, full.names = FALSE)
lesson_dirs <- lesson_dirs[str_detect(lesson_dirs, "^[0-9]+_")]

lesson_files <- sort(unlist(lapply(
  lesson_dirs,
  function(d) list.files(d, pattern = "\\.qmd$", full.names = TRUE)
)))

if (length(lesson_files) == 0) {
  cat("No lesson files found.\n")
  quit(status = 1)
}

# fit(x, data = D) / fit(x, D) / fit_resamples are all training entry points.
fit_pattern <- "\\bfit\\s*\\(([^)]*)\\)"
predict_pattern <- "\\b(?:predict|augment)\\s*\\(([^)]*)\\)"

# Pull the symbol that carries the data. For fit() it is the `data =` argument
# when named, otherwise the last positional argument. For predict() it is the
# second argument, named `new_data` or positional.
data_symbol_from_fit <- function(args) {
  named <- str_match(args, "data\\s*=\\s*([A-Za-z._][A-Za-z0-9._]*)")[, 2]
  if (!is.na(named)) return(named)
  parts <- str_trim(str_split(args, ",")[[1]])
  parts <- parts[nzchar(parts)]
  if (length(parts) < 2) return(NA_character_)
  last <- parts[[length(parts)]]
  if (str_detect(last, "=")) return(NA_character_)
  if (!str_detect(last, "^[A-Za-z._][A-Za-z0-9._]*$")) return(NA_character_)
  last
}

data_symbol_from_predict <- function(args) {
  named <- str_match(args, "new_data\\s*=\\s*([A-Za-z._][A-Za-z0-9._]*)")[, 2]
  if (!is.na(named)) return(named)
  parts <- str_trim(str_split(args, ",")[[1]])
  parts <- parts[nzchar(parts)]
  if (length(parts) < 2) return(NA_character_)
  second <- parts[[2]]
  if (str_detect(second, "=")) return(NA_character_)
  if (!str_detect(second, "^[A-Za-z._][A-Za-z0-9._]*$")) return(NA_character_)
  second
}

collect <- function(lines, pattern, extractor) {
  hits <- character(0)
  for (i in seq_along(lines)) {
    if (str_detect(lines[[i]], "resubstitution-ok")) next
    matches <- str_match_all(lines[[i]], pattern)[[1]]
    if (nrow(matches) == 0) next
    for (r in seq_len(nrow(matches))) {
      sym <- extractor(matches[r, 2])
      if (!is.na(sym)) hits <- c(hits, sym)
    }
  }
  unique(hits)
}

failures <- character(0)

for (path in lesson_files) {
  lines <- readLines(path, warn = FALSE)
  fit_data <- collect(lines, fit_pattern, data_symbol_from_fit)
  scored_data <- collect(lines, predict_pattern, data_symbol_from_predict)
  leaked <- intersect(fit_data, scored_data)
  if (length(leaked) > 0) {
    failures <- c(
      failures,
      sprintf(
        "%s scores a model on the data it was fitted to: %s",
        path,
        paste(leaked, collapse = ", ")
      )
    )
  }
}

if (length(failures) > 0) {
  cat("Resubstitution scan failed.\n\n")
  cat(paste(failures, collapse = "\n"), "\n\n")
  cat(paste(
    "Fit and score must use different data. If a lesson shows resubstitution",
    "on purpose, mark the line with # resubstitution-ok: <reason> and say so",
    "in the prose.\n"
  ))
  quit(status = 1)
}

cat(sprintf(
  "Resubstitution scan passed for %d lessons.\n",
  length(lesson_files)
))
