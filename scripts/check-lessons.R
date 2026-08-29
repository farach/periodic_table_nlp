lesson_directories <- sort(
  list.dirs(".", recursive = FALSE, full.names = FALSE)[
    grepl("^[0-9]+_", list.dirs(".", recursive = FALSE, full.names = FALSE))
  ]
)

stopifnot(length(lesson_directories) > 0)

lesson_files <- sort(
  unlist(
    lapply(
      lesson_directories,
      function(directory) {
        list.files(
          directory,
          pattern = "[.]qmd$",
          full.names = TRUE
        )
      }
    ),
    use.names = FALSE
  )
)

failures <- character()
source_chunk_total <- 0L
visible_source_chunk_total <- 0L
rendered_chunk_total <- 0L

review_manifest <- read.csv(
  "data/lesson_reviews.csv",
  colClasses = "character",
  check.names = FALSE
)

normalized_lesson_files <- gsub("\\\\", "/", lesson_files)

if (
  !identical(
    names(review_manifest),
    c(
      "task_number",
      "source_file",
      "editorial_status",
      "last_researched",
      "last_code_run",
      "project_narrative_review",
      "project_prose_scan",
      "project_adversarial_review",
      "adversarial_rounds",
      "project_automated_accessibility",
      "manual_accessibility",
      "human_approval",
      "open_limitations"
    )
  ) ||
  !identical(nrow(review_manifest), length(lesson_files)) ||
  !identical(
    review_manifest$source_file,
    normalized_lesson_files
  ) ||
  !identical(
    as.integer(review_manifest$task_number),
    seq_along(lesson_files)
  ) ||
  !all(
    review_manifest$editorial_status ==
      "review-ready"
  ) ||
  !all(grepl(
    "^[0-9]{4}-[0-9]{2}-[0-9]{2}$",
    review_manifest$last_researched
  )) ||
  !all(grepl(
    "^[0-9]{4}-[0-9]{2}-[0-9]{2}$",
    review_manifest$last_code_run
  )) ||
  !all(review_manifest$project_prose_scan == "passed") ||
  !all(review_manifest$project_narrative_review == "passed") ||
  !all(review_manifest$project_adversarial_review == "passed") ||
  !all(
    as.integer(review_manifest$adversarial_rounds) >= 1L
  ) ||
  !all(
    review_manifest$project_automated_accessibility ==
      "passed"
  ) ||
  !all(
    review_manifest$manual_accessibility %in%
      c("pending", "passed")
  ) ||
  !all(
    review_manifest$human_approval %in% c("pending", "approved")
  ) ||
  !all(nzchar(review_manifest$open_limitations))
) {
  failures <- c(
    failures,
    "data/lesson_reviews.csv is incomplete or out of sync"
  )
}

count_matches <- function(pattern, text) {
  locations <- gregexpr(pattern, text, perl = TRUE)[[1]]
  if (locations[1] == -1) 0L else length(locations)
}

for (lesson_file in lesson_files) {
  lines <- readLines(
    lesson_file,
    encoding = "UTF-8",
    warn = FALSE
  )
  text <- paste(lines, collapse = "\n")

  required_sections <- c(
    "## What you will learn",
    "## What to remember",
    "## Sources"
  )

  for (section in required_sections) {
    if (!grepl(section, text, fixed = TRUE)) {
      failures <- c(
        failures,
        sprintf("%s is missing %s", lesson_file, section)
      )
    }
  }

  if (!grepl('description: "', text, fixed = TRUE)) {
    failures <- c(
      failures,
      sprintf("%s is missing a description", lesson_file)
    )
  }

  if (!grepl("options(warn = 2)", text, fixed = TRUE)) {
    failures <- c(
      failures,
      sprintf(
        "%s does not turn warnings into errors",
        lesson_file
      )
    )
  }

  first_code <- regexpr("```\\{r", text, perl = TRUE)[1]
  learning_section <- regexpr(
    "## What you will learn",
    text,
    fixed = TRUE
  )[1]

  if (
    first_code == -1 ||
    learning_section == -1 ||
    learning_section > first_code
  ) {
    failures <- c(
      failures,
      sprintf(
        "%s must state learning goals before its first R chunk",
        lesson_file
      )
    )
  }

  chunks <- regmatches(
    text,
    gregexpr(
      "(?s)```\\{r[^}]*\\}\\s*\\n.*?\\n```",
      text,
      perl = TRUE
    )
  )[[1]]

  if (identical(chunks, character(0))) {
    failures <- c(
      failures,
      sprintf("%s has no executable R chunks", lesson_file)
    )
  } else {
    source_chunk_total <- source_chunk_total + length(chunks)
    visible_source_chunk_total <- visible_source_chunk_total +
      sum(!grepl(
        "#\\|\\s*include:\\s*false",
        chunks,
        ignore.case = TRUE,
        perl = TRUE
      ))

    for (chunk_number in seq_along(chunks)) {
      if (!grepl("stopifnot(", chunks[chunk_number], fixed = TRUE)) {
        failures <- c(
          failures,
          sprintf(
            "%s chunk %d has no expected-result assertion",
            lesson_file,
            chunk_number
          )
        )
      }
    }
  }

  blocked_options <- c(
    "eval:\\s*false",
    "cache:\\s*true",
    "error:\\s*true"
  )

  for (option in blocked_options) {
    if (grepl(option, text, ignore.case = TRUE, perl = TRUE)) {
      failures <- c(
        failures,
        sprintf(
          "%s contains a blocked execution option: %s",
          lesson_file,
          option
        )
      )
    }
  }

  history_pattern <- paste0(
    "original (chapter|version)|",
    "previous (chapter|version|draft)|",
    "earlier (chapter|version|draft)|",
    "used to say"
  )

  if (grepl(history_pattern, text, ignore.case = TRUE, perl = TRUE)) {
    failures <- c(
      failures,
      sprintf("%s contains drafting history", lesson_file)
    )
  }

  sources_start <- regexpr("## Sources", text, fixed = TRUE)[1]
  sources_text <- if (sources_start == -1) "" else {
    substring(text, sources_start)
  }
  source_count <- count_matches("https://", sources_text)

  if (source_count < 2L) {
    failures <- c(
      failures,
      sprintf("%s needs at least two linked sources", lesson_file)
    )
  }

  output_file <- file.path(
    "_site",
    sub("[.]qmd$", ".html", lesson_file)
  )

  if (dir.exists("_site")) {
    if (!file.exists(output_file)) {
      failures <- c(
        failures,
        sprintf("Rendered lesson is missing: %s", output_file)
      )
    } else {
      output <- paste(
        readLines(output_file, encoding = "UTF-8", warn = FALSE),
        collapse = "\n"
      )
      rendered_chunk_total <- rendered_chunk_total +
        count_matches('<div class="cell">', output)
    }
  }
}

if (length(failures) > 0) {
  cat(paste(failures, collapse = "\n"), "\n")
  quit(status = 1)
}

if (
  dir.exists("_site") &&
  rendered_chunk_total != visible_source_chunk_total
) {
  stop(
    sprintf(
      "Expected %d visible chunks but found %d rendered chunks.",
      visible_source_chunk_total,
      rendered_chunk_total
    ),
    call. = FALSE
  )
}

cat(
  sprintf(
    paste0(
      "Checked %d lessons, %d executed R chunks, ",
      "and the review manifest.\n"
    ),
    length(lesson_files),
    source_chunk_total
  )
)
