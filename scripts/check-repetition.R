# Find prose that repeats across lessons.
#
# Lessons written from one brief will share phrasing, and a reader who notices
# the template stops trusting the voice. This fails the build when repetition
# passes what a careful writer would allow.
#
# One sentence is meant to be identical everywhere: the notice that the
# Riverton material is invented. A standard disclosure should read the same on
# every page, so it is exempt.

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(purrr)
  library(stringr)
  library(tibble)
})

allowed_repeats <- c(
  paste(
    "The Riverton Workforce Lab, its job board, and its training flyer are",
    "fictional and were created for teaching."
  )
)

max_shared_sentence <- 3L
max_shared_opening <- 4L

lesson_files <- list.dirs(".", recursive = FALSE, full.names = FALSE) |>
  keep(\(d) str_detect(d, "^[0-9]+_")) |>
  sort() |>
  map(\(d) list.files(d, pattern = "[.]qmd$", full.names = TRUE)) |>
  list_c() |>
  sort()

stopifnot(length(lesson_files) > 0)

strip_code <- function(lines) {
  fence <- cumsum(str_detect(lines, "^\\s*```")) %% 2
  lines[fence == 0 & !str_detect(lines, "^\\s*```")]
}

prose <- map(lesson_files, \(f) {
  read_lines(f) |>
    strip_code() |>
    discard(\(l) str_detect(l, "^\\s*(#|:::|-|\\||[a-z_]+:)")) |>
    str_squish() |>
    discard(\(l) !nzchar(l))
})
names(prose) <- basename(lesson_files)

sentences <- imap(prose, \(lines, file) {
  tibble(
    file = file,
    sentence = paste(lines, collapse = " ") |>
      str_split_1("(?<=[.?!]) (?=[A-Z])") |>
      str_squish()
  )
}) |>
  list_rbind() |>
  filter(str_count(sentence, "\\S+") >= 6, !sentence %in% allowed_repeats)

repeated <- sentences |>
  distinct(file, sentence) |>
  count(sentence, name = "lessons") |>
  filter(lessons > max_shared_sentence) |>
  arrange(desc(lessons))

# The first sentence is what a reader meets cold. If most lessons start the
# same way, the openings are a template rather than a scene.
openings <- sentences |>
  group_by(file) |>
  slice(1) |>
  ungroup() |>
  mutate(opening = word(sentence, 1, 4)) |>
  count(opening, name = "lessons") |>
  filter(lessons > max_shared_opening) |>
  arrange(desc(lessons))

failures <- character()

if (nrow(repeated) > 0) {
  failures <- c(
    failures,
    sprintf(
      "Sentence appears in %d lessons (limit %d): %s",
      repeated$lessons,
      max_shared_sentence,
      str_trunc(repeated$sentence, 90)
    )
  )
}

if (nrow(openings) > 0) {
  failures <- c(
    failures,
    sprintf(
      "%d lessons open with the same four words (limit %d): \"%s ...\"",
      openings$lessons,
      max_shared_opening,
      openings$opening
    )
  )
}

if (length(failures) > 0) {
  cat(paste(failures, collapse = "\n"), "\n")
  quit(status = 1)
}

cat(
  sprintf(
    "Repetition scan passed for %d lessons.\n",
    length(lesson_files)
  )
)
