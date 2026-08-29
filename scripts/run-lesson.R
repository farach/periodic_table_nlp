# Run every R chunk in one lesson from the project root.
#
# Usage: Rscript scripts/run-lesson.R <path/to/lesson.qmd>
#
# This is a fast check used while editing. It extracts the R code from a
# lesson and runs it in order, exactly as the rendered page would. It does
# not replace `quarto render`, which is still the published gate.

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 1L) {
  stop("Supply exactly one lesson path.", call. = FALSE)
}

lesson_file <- args[[1]]

if (!file.exists(lesson_file)) {
  stop(sprintf("Lesson not found: %s", lesson_file), call. = FALSE)
}

code_file <- tempfile(fileext = ".R")
on.exit(unlink(code_file), add = TRUE)

invisible(
  knitr::purl(
    lesson_file,
    output = code_file,
    documentation = 0L,
    quiet = TRUE
  )
)

code_lines <- readLines(code_file, encoding = "UTF-8", warn = FALSE)

if (!any(nzchar(trimws(code_lines)))) {
  stop(sprintf("No R code found in %s", lesson_file), call. = FALSE)
}

lesson_env <- new.env(parent = globalenv())

# Plot objects only emit their warnings when they are printed, and ggplot does a
# lot of its work at print time: dropped rows, missing values, and out-of-range
# scale limits all surface there. Sourcing with `print.eval = TRUE` against a
# null device makes this fast check see the same warnings `quarto render` would,
# without writing any files. Lesson 44 once passed this script and then failed
# the render because a scale limit silently dropped two points.
grDevices::pdf(NULL)
on.exit(grDevices::dev.off(), add = TRUE)

result <- withCallingHandlers(
  tryCatch(
    {
      source(
        code_file,
        local = lesson_env,
        echo = FALSE,
        print.eval = TRUE,
        encoding = "UTF-8"
      )
      "ok"
    },
    error = function(condition) {
      cat(
        sprintf(
          "FAILED %s\n%s\n",
          lesson_file,
          conditionMessage(condition)
        )
      )
      quit(status = 1)
    }
  ),
  warning = function(condition) {
    cat(
      sprintf(
        "WARNING in %s\n%s\n",
        lesson_file,
        conditionMessage(condition)
      )
    )
    quit(status = 1)
  }
)

stopifnot(identical(result, "ok"))

cat(
  sprintf(
    "Ran %s (%d lines of R).\n",
    lesson_file,
    sum(nzchar(trimws(code_lines)))
  )
)
