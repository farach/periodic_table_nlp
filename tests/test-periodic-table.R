task_map <- read.csv(
  "data/periodic_table.csv",
  colClasses = c(
    task_number = "integer",
    symbol = "character",
    title = "character",
    item_type = "character",
    group_id = "integer",
    group_name = "character",
    stage = "character",
    lesson_path = "character",
    status = "character",
    last_reviewed = "character"
  ),
  na.strings = "NA",
  check.names = FALSE
)

has_lesson <- task_map$status == "available"

expected_group_sizes <- c(
  7L, 6L, 5L, 5L, 5L,
  6L, 4L, 4L, 5L, 5L,
  5L, 5L, 6L, 6L, 7L
)

lesson_sources <- sub(
  "[.]html$",
  ".qmd",
  task_map$lesson_path[has_lesson]
)
review_manifest <- read.csv(
  "data/lesson_reviews.csv",
  colClasses = "character",
  na.strings = "",
  check.names = FALSE
)

stopifnot(
  identical(nrow(task_map), 81L),
  identical(task_map$task_number, 1:81),
  identical(length(unique(task_map$symbol)), 81L),
  identical(sort(unique(task_map$group_id)), 1:15),
  identical(
    as.integer(table(task_map$group_id)),
    expected_group_sizes
  ),
  identical(which(has_lesson), 1:42),
  identical(sum(has_lesson), 42L),
  all(task_map$status %in% c("available", "planned")),
  all(nzchar(task_map$item_type)),
  all(nzchar(task_map$lesson_path[has_lesson])),
  all(task_map$lesson_path[!has_lesson] == ""),
  all(grepl(
    "^[0-9]{4}-[0-9]{2}-[0-9]{2}$",
    task_map$last_reviewed[has_lesson]
  )),
  all(task_map$last_reviewed[!has_lesson] == ""),
  identical(
    task_map$title[2],
    "Manual examples and pattern matching"
  ),
  all(file.exists(lesson_sources)),
  identical(review_manifest$source_file, lesson_sources)
)

readme <- paste(
  readLines("README.md", encoding = "UTF-8", warn = FALSE),
  collapse = "\n"
)
readme_lesson_links <- regmatches(
  readme,
  gregexpr(
    "[1-8]_[a-z_]+/[0-9]{2}-[a-z0-9-]+[.]qmd",
    readme,
    perl = TRUE
  )
)[[1]]

stopifnot(
  identical(
    sort(unique(readme_lesson_links)),
    sort(lesson_sources)
  )
)

site_index <- "_site/index.html"
stopifnot(file.exists(site_index))

html <- paste(
  readLines(site_index, encoding = "UTF-8", warn = FALSE),
  collapse = "\n"
)

count_matches <- function(pattern, text) {
  locations <- gregexpr(pattern, text, perl = TRUE)[[1]]
  if (locations[1] == -1) 0L else length(locations)
}

task_tokens <- regmatches(
  html,
  gregexpr(
    'data-task-number="[0-9]+"',
    html,
    perl = TRUE
  )
)[[1]]
rendered_task_numbers <- as.integer(
  gsub("[^0-9]", "", task_tokens)
)

available_tags <- regmatches(
  html,
  gregexpr(
    '<a class="nlp-element is-available"[^>]+>',
    html,
    perl = TRUE
  )
)[[1]]
rendered_hrefs <- sub(
  '.*href="([^"]+)".*',
  "\\1",
  available_tags
)

stopifnot(
  identical(rendered_task_numbers, 1:81),
  identical(
    count_matches('data-status="available"', html),
    42L
  ),
  identical(
    count_matches('data-status="planned"', html),
    39L
  ),
  identical(
    count_matches('data-item-type="[^"]+"', html),
    81L
  ),
  identical(
    count_matches('aria-disabled="true"', html),
    0L
  ),
  identical(
    count_matches('<section class="element-group ', html),
    15L
  ),
  identical(
    count_matches(
      '<h3 class="element-group-title( anchored)?"',
      html
    ),
    15L
  ),
  identical(
    count_matches('<span class="element-stage">', html),
    15L
  ),
  identical(
    count_matches('<a class="nlp-element is-planned"', html),
    0L
  ),
  identical(
    count_matches(
      '(?s)<div class="nlp-element is-planned"[^>]*>.*?<span class="element-status">Planned</span>',
      html
    ),
    39L
  ),
  identical(
    rendered_hrefs,
    task_map$lesson_path[has_lesson]
  ),
  all(file.exists(file.path("_site", rendered_hrefs))),
  grepl(
    'tabindex="0" role="region"',
    html,
    fixed = TRUE
  ),
  grepl(
    'aria-label="Periodic table of NLP tasks"',
    html,
    fixed = TRUE
  ),
  !grepl(
    'aria-labelledby="periodic-table-heading"',
    html,
    fixed = TRUE
  ),
  grepl(
    "This is a teaching aid, not a scientific taxonomy",
    html,
    fixed = TRUE
  ),
  identical(
    count_matches('class="available-routes"', html),
    1L
  ),
  identical(
    count_matches(
      '(?s)<nav class="available-routes"[^>]*>.*?<a href="[^"]+">',
      html
    ),
    1L
  )
)

css <- paste(
  readLines(
    "periodic-table.css",
    encoding = "UTF-8",
    warn = FALSE
  ),
  collapse = "\n"
)

base_css <- paste(
  readLines(
    "styles.css",
    encoding = "UTF-8",
    warn = FALSE
  ),
  collapse = "\n"
)

stopifnot(
  grepl(":focus-visible", css, fixed = TRUE),
  grepl(
    "prefers-reduced-motion: reduce",
    css,
    fixed = TRUE
  ),
  grepl("overflow-x: auto", css, fixed = TRUE),
  grepl("scroll-snap-type", css, fixed = TRUE),
  grepl("max-width: 100%", css, fixed = TRUE),
  grepl(".element-stage", css, fixed = TRUE),
  grepl(".element-kind", css, fixed = TRUE),
  grepl(
    ".quarto-title-banner .title",
    base_css,
    fixed = TRUE
  ),
  grepl("color: #f7fbff", base_css, fixed = TRUE),
  grepl("main.content", base_css, fixed = TRUE)
)

cat(
  paste0(
    "Periodic table passed: 81 ordered tasks, 15 groups, ",
    "42 lesson links, 39 planned tiles, visible item types, ",
    "stage labels, and responsive structural checks.\n"
  )
)
