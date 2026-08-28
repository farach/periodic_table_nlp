markdown_files <- list.files(
  ".",
  pattern = "[.](md|qmd)$",
  all.files = TRUE,
  recursive = TRUE,
  full.names = TRUE,
  include.dirs = FALSE,
  no.. = TRUE
)

relative_paths <- gsub("\\\\", "/", markdown_files)
excluded <- grepl(
  "(^|/)(_site|renv|[.]git|node_modules)/",
  relative_paths
)
markdown_files <- markdown_files[!excluded]
relative_paths <- relative_paths[!excluded]

strip_code_fences <- function(lines) {
  inside_fence <- FALSE
  keep <- logical(length(lines))

  for (line_number in seq_along(lines)) {
    if (grepl("^\\s*```", lines[line_number])) {
      inside_fence <- !inside_fence
      next
    }

    keep[line_number] <- !inside_fence
  }

  lines[keep]
}

scan_patterns <- function(patterns, round_name) {
  findings <- character()

  for (file_number in seq_along(markdown_files)) {
    lines <- readLines(
      markdown_files[file_number],
      encoding = "UTF-8",
      warn = FALSE
    )
    prose <- strip_code_fences(lines)

    for (pattern_name in names(patterns)) {
      matching_lines <- grep(
        patterns[[pattern_name]],
        prose,
        ignore.case = TRUE,
        perl = TRUE
      )

      if (length(matching_lines) > 0) {
        for (line_number in matching_lines) {
          findings <- c(
            findings,
            sprintf(
              "%s: %s (%s): %s",
              round_name,
              relative_paths[file_number],
              pattern_name,
              trimws(prose[line_number])
            )
          )
        }
      }
    }
  }

  findings
}

residue_patterns <- c(
  "citation residue" = paste0(
    "\\b(contentReference|oaicite|oai_citation|",
    "turn[0-9]+(search|view)[0-9]+|attached_file)\\b"
  ),
  "unfinished placeholder" = paste0(
    "\\[(insert|your name|company|date|link)",
    "[^]]*\\]"
  ),
  "chatbot sign-off" = paste0(
    "i hope this helps|let me know if you need|",
    "is there anything else you would like"
  ),
  "assistant introduction" = paste0(
    "as an ai (assistant|language model)|",
    "^(certainly|of course)[,!]"
  ),
  "knowledge-cutoff disclaimer" = paste0(
    "as of my (last )?(knowledge|update)|",
    "based on information available up to"
  )
)

style_patterns <- c(
  "stock vocabulary" = paste0(
    "\\b(delve|tapestry|synergy|seamless|",
    "game[- ]changer|",
    "cutting[- ]edge)\\b"
  ),
  "corporate verb" = "\\b(utilize|leverage|empower)\\b",
  "throat-clearing phrase" = paste0(
    "it('s| is) important to note|",
    "it('s| is) worth (noting|mentioning)|",
    "without further ado|in today('s|s)|",
    "let('s| us) (dive|delve|unpack)|",
    "it goes without saying"
  ),
  "empty transition" = paste0(
    "^\\s*(moreover|furthermore|additionally|",
    "importantly|interestingly|notably),"
  ),
  "dramatic reveal" = paste0(
    "here('s| is) (the thing|the kicker|",
    "where it gets interesting)"
  ),
  "staged contrast" = paste0(
    "(is not|isn't|was not|wasn't|are not|aren't) ",
    "(just|only) .{0,100}\\b(but|it is|it's|they are|they're)\\b"
  )
)

round_one <- scan_patterns(
  residue_patterns,
  "Round 1 residue scan"
)
round_two <- scan_patterns(
  style_patterns,
  "Round 2 pattern scan"
)

dash_findings <- character()
em_dash <- intToUtf8(0x2014)

for (file_number in seq_along(markdown_files)) {
  lines <- readLines(
    markdown_files[file_number],
    encoding = "UTF-8",
    warn = FALSE
  )
  prose <- paste(strip_code_fences(lines), collapse = "\n")
  locations <- gregexpr(em_dash, prose, fixed = TRUE)[[1]]
  dash_count <- if (locations[1] == -1) 0L else length(locations)

  if (dash_count > 3L) {
    dash_findings <- c(
      dash_findings,
      sprintf(
        "Round 2 pattern scan: %s (em dash count): %d",
        relative_paths[file_number],
        dash_count
      )
    )
  }
}

findings <- c(round_one, round_two, dash_findings)

if (length(findings) > 0) {
  cat(paste(findings, collapse = "\n"), "\n")
  quit(status = 1)
}

cat(
  sprintf(
    "Round 1 residue scan passed for %d files.\n",
    length(markdown_files)
  )
)
cat("Round 2 pattern scan passed.\n")
