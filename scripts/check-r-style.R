# Check the R code in every lesson against the tidyverse style guide.
#
# `dry = "fail"` asks styler to compute the formatted result without writing
# anything. It exits with an error when a file would change, so the same rule
# applies in RStudio, locally, and on CI.
#
# Usage:
#   Rscript scripts/check-r-style.R
#
# To fix one lesson:
#   styler::style_file("1_source_data_loading/01-bits-to-character-encoding.qmd")

suppressPackageStartupMessages({
  library(styler)
})

lesson_directories <- list.dirs(
  ".",
  recursive = FALSE,
  full.names = FALSE
)

lesson_directories <- lesson_directories[
  grepl("^[0-9]+_", lesson_directories)
]

lesson_files <- unlist(
  lapply(
    lesson_directories,
    list.files,
    pattern = "[.]qmd$",
    full.names = TRUE
  ),
  use.names = FALSE
)

stopifnot(
  length(lesson_files) > 0L,
  all(file.exists(lesson_files))
)

tryCatch(
  {
    style_file(
      lesson_files,
      strict = TRUE,
      dry = "fail"
    )
  },
  error = function(condition) {
    cat(
      "Tidyverse style check failed.\n",
      conditionMessage(condition),
      "\n\nRun styler::style_file() on the listed lesson files.\n",
      sep = ""
    )
    quit(status = 1L)
  }
)

cat(
  sprintf(
    "Tidyverse style check passed for %d lessons.\n",
    length(lesson_files)
  )
)
