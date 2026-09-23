# Build the fictional Riverton Skills Centre handbook used by tasks 70-72.
#
# Run by hand, not during a render. Everything here is invented for teaching:
# the centre, its programs, the stipend, the schedule, the rooms, and the course
# codes. No real organisation, program, or person is described.
#
# One builder writes three files so the facts, the question-answering probes,
# and the search judgments are frozen together before any lesson retrieves or
# generates anything:
#
# - riverton-handbook.csv: short passages with durable passage IDs. Numbers are
#   written as digits. Gold passages are spread through the ID order so that
#   ties broken by ID do not favour them.
# - riverton-handbook-questions.csv: six question-answering probes for task 70,
#   each with an expected action (answer, abstain, or flag premise), the gold
#   passage that answers or contradicts it, and acceptable short answers.
# - riverton-search-judgments.csv: exhaustive relevance judgments for task 72,
#   one row for every query and every passage, written before any index exists.
#
# The same person wrote the passages, the questions, and the judgments. They are
# a disclosed teaching fixture, not an independent benchmark.
#
# Usage:
#   Rscript data-raw/build-riverton-handbook.R

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(tibble)
  library(digest)
})

out_dir <- "data/riverton"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

author_note <- paste(
  "Invented by the site author for teaching; not a real program, policy,",
  "or benchmark."
)

handbook <- tribble(
  ~passage_id, ~topic, ~text,
  "H01", "location",
  "Classes are held at the Riverton Skills Centre on Mill Street in Riverton.",
  "H02", "contact",
  paste(
    "The enrollment desk answers phone calls from 9 a.m. to 5 p.m., Monday to",
    "Friday. Messages left after hours are returned the next business day."
  ),
  "H03", "programs",
  paste(
    "The Riverton Skills Centre runs two programs this fall: the Data Support",
    "Certificate and the Forklift Operator Licence course."
  ),
  "H04", "forklift eligibility",
  paste(
    "Forklift Operator Licence applicants must be at least 18 years old and",
    "able to lift 50 pounds."
  ),
  "H05", "transit",
  paste(
    "Marrow County Transit bus passes are provided for the first month of",
    "either program. Riders pay the regular $2 fare after that."
  ),
  "H06", "data schedule",
  paste(
    "Data Support Certificate classes meet on Monday and Wednesday evenings",
    "from 6 p.m. to 9 p.m. The course lasts 12 weeks."
  ),
  "H07", "enrollment documents",
  "Bring a photo ID and proof of address to your enrollment appointment.",
  "H08", "stipend",
  paste(
    "Data Support Certificate students receive a training stipend of $150 per",
    "week. Students must attend at least 90 percent of classes to receive it."
  ),
  "H09", "course codes",
  paste(
    "In the enrollment system, the Data Support Certificate is listed as",
    "course DSC-104 and the forklift course is listed as FOL-210."
  ),
  "H10", "refresher workshop",
  paste(
    "An optional spreadsheet refresher workshop, listed as DSC-105, meets on",
    "two Saturday mornings in September. It does not count toward the",
    "certificate."
  ),
  "H11", "forklift schedule",
  paste(
    "Forklift Operator Licence classes meet on Tuesday and Thursday mornings",
    "from 8 a.m. to noon. There are no weekend forklift classes."
  ),
  "H12", "data eligibility",
  paste(
    "No prior data experience is required for the Data Support Certificate.",
    "Applicants need basic spreadsheet skills."
  ),
  "H13", "child care",
  paste(
    "Free child care is available in Room 104 during evening classes for",
    "children aged 3 to 10."
  ),
  "H14", "deadline",
  "Applications for both fall programs close on October 15.",
  "H15", "laptops",
  paste(
    "Laptops are provided in class for Data Support Certificate students and",
    "may not be taken home."
  )
) |>
  mutate(
    source = "Constructed Riverton Skills Centre fall handbook",
    author_note = author_note
  )

# Acceptable short answers are separated by a vertical bar. Abstain and
# premise probes have no short answer: their correct behaviour is an action.
questions <- tribble(
  ~question_id, ~question, ~probe_type, ~expected_action, ~gold_passage_id,
  ~acceptable_answers,
  "Q1", "How much is the weekly training stipend?",
  "direct number", "answer", "H08",
  "$150|$150 per week|$150 a week|150 dollars per week",
  "Q2", "When do applications close?",
  "direct date", "answer", "H14",
  "October 15|Oct. 15|October 15th",
  "Q3", "Where can my kid stay while I study at night?",
  "paraphrase with no shared content word", "answer", "H13",
  "Room 104|in Room 104|free child care in Room 104",
  "Q4", "Do I need data experience to join the Data Support Certificate?",
  "yes or no", "answer", "H12",
  "No|no prior data experience is required",
  "Q5", "How much does parking cost at the centre?",
  "unanswerable on topic, with dollar amounts nearby", "abstain", NA,
  NA,
  "Q6", "When does the Saturday forklift session start?",
  "false premise contradicted by a passage", "flag premise", "H11",
  NA
) |>
  mutate(author_note = author_note)

# Exhaustive binary judgments: every query against every passage. A passage is
# relevant when a reader looking for the query's information would want it.
queries <- tribble(
  ~query_id, ~query, ~probe_type,
  "S1", "somewhere for my kid during night class", "vocabulary mismatch",
  "S2", "DSC-104", "exact identifier with near misses",
  "S3", "money while I train", "vocabulary mismatch",
  "S4", "free ride to class", "vocabulary mismatch",
  "S5", "weekend forklift classes", "negated fact",
  "S6", "what should I bring to enroll", "paraphrase",
  "S7", "can I take the laptop home", "lexical overlap",
  "S8", "cafeteria lunch menu", "out of scope"
)

relevant_pairs <- tribble(
  ~query_id, ~passage_id,
  "S1", "H13",
  "S2", "H09",
  "S3", "H08",
  "S4", "H05",
  "S5", "H11",
  "S6", "H07",
  "S7", "H15"
)

judgments <- queries |>
  cross_join(handbook |> select(passage_id)) |>
  left_join(
    relevant_pairs |> mutate(relevant = 1L),
    by = c("query_id", "passage_id")
  ) |>
  mutate(
    relevant = coalesce(relevant, 0L),
    judged_by = "page author, before any index was built"
  ) |>
  arrange(query_id, passage_id)

stopifnot(
  !anyDuplicated(handbook$passage_id),
  all(nzchar(handbook$text)),
  !anyDuplicated(questions$question_id),
  all(
    questions$gold_passage_id[!is.na(questions$gold_passage_id)] %in%
      handbook$passage_id
  ),
  identical(
    questions$expected_action,
    c("answer", "answer", "answer", "answer", "abstain", "flag premise")
  ),
  identical(nrow(judgments), nrow(queries) * nrow(handbook)),
  identical(sum(judgments$relevant), 7L),
  identical(
    judgments |>
      filter(query_id == "S8") |>
      pull(relevant) |>
      sum(),
    0L
  )
)

handbook_path <- file.path(out_dir, "riverton-handbook.csv")
questions_path <- file.path(out_dir, "riverton-handbook-questions.csv")
judgments_path <- file.path(out_dir, "riverton-search-judgments.csv")

write_csv(handbook, handbook_path)
write_csv(questions, questions_path, na = "")
write_csv(judgments, judgments_path)

hash_lines <- function(path) {
  digest(
    paste(read_lines(path), collapse = "\n"),
    algo = "sha256",
    serialize = FALSE
  )
}

files <- c(
  "riverton-handbook.csv",
  "riverton-handbook-questions.csv",
  "riverton-search-judgments.csv"
)

metadata <- tibble(
  artifact = files,
  description = c(
    "Invented fall-program handbook passages shared by tasks 70, 71, and 72",
    paste(
      "Six question-answering probes with expected actions, gold passages,",
      "and acceptable short answers"
    ),
    paste(
      "Exhaustive query-by-passage relevance judgments written before any",
      "search index was built"
    )
  ),
  source = "Created for this project",
  license = "MIT, same as this repository",
  created_on = "2026-09-23",
  rows = c(nrow(handbook), nrow(questions), nrow(judgments)),
  fingerprint = vapply(
    file.path(out_dir, files),
    hash_lines,
    character(1),
    USE.NAMES = FALSE
  )
)

write_csv(metadata, file.path(out_dir, "riverton-handbook-metadata.csv"))

cat(
  "wrote", nrow(handbook), "passages,", nrow(questions), "questions, and",
  nrow(judgments), "judgments\n"
)
