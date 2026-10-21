options(warn = 2, cli.progress_show_after = Inf)

lesson_file <- "3_word_parsing/15-vocabulary-building.qmd"
fixture <- "tests/fixtures/vocabulary-69.bpe"
sentences <- readr::read_csv(
  "data/workforce/workforce_sentences.csv",
  col_types = readr::cols(.default = readr::col_character()),
  na = character()
)

# An actual tokenizers.bpe 0.1.6 fit of the lesson's unchanged training rows:
# Windows R 4.6.1, coverage = 1, vocab_size = 200L, threads = 1L.
# Fit 907 of 2,000 produced 69 pieces; the other 1,999 produced 68.
# Only line endings were normalized in this saved regression fixture.
variant <- tokenizers.bpe::bpe_load_model(fixture, threads = 1L)
flyer_text <- tolower(sentences$text[sentences$document_id == "F001"])
variant_ids <- tokenizers.bpe::bpe_encode(variant, flyer_text, type = "ids")
stopifnot(
  nrow(variant$vocabulary) == 200L,
  identical(lengths(variant_ids), c(16L, 10L, 7L, 10L, 12L, 14L)),
  !any(unlist(variant_ids) == 1L),
  identical(unlist(tokenizers.bpe::bpe_decode(variant, variant_ids)), flyer_text)
)

render_lesson <- function(model = NULL, alter = NULL) {
  lesson <- new.env(parent = globalenv())
  if (!is.null(model)) {
    lesson$bpe <- function(x, model_path, vocab_size, coverage, threads) {
      stopifnot(
        identical(
          readLines(x, encoding = "UTF-8"),
          tolower(sentences$text[sentences$document_id != "F001"])
        ),
        identical(vocab_size, 200L),
        identical(coverage, 1),
        identical(threads, 1L)
      )
      model
    }
  }
  if (!is.null(alter)) {
    lesson$bpe_encode <- function(model, x, type) {
      alter(tokenizers.bpe::bpe_encode(model, x, type = type), type)
    }
  }
  output <- tempfile(fileext = ".md")
  on.exit(unlink(output), add = TRUE)
  knitr::opts_knit$set(root.dir = getwd())
  knitr::opts_chunk$set(error = FALSE)
  knitr::knit(lesson_file, output = output, envir = lesson, quiet = TRUE)
  pieces <- sum(lengths(lesson$flyer_ids))
  prose <- paste(readLines(output, encoding = "UTF-8"), collapse = " ")
  stopifnot(
    identical(length(lesson$flat_flyer_subwords), pieces),
    identical(length(lesson$flat_flyer_ids), pieces),
    identical(
      lesson$flyer_unknown_by_line$sentence_id,
      sentences$sentence_id[sentences$document_id == "F001"]
    ),
    identical(
      lesson$subword_test_summary$value[
        lesson$subword_test_summary$measure == "flyer subword pieces"
      ],
      as.character(pieces)
    ),
    grepl(sprintf("none of the %d BPE pieces is unknown", pieces), prose),
    grepl(sprintf("Comparing 10 word tokens with %d pieces", pieces), prose)
  )
  cat(sprintf("Vocabulary lesson passed with %d BPE pieces.\n", pieces))
}

render_lesson(variant)
render_lesson()

expect_rejected <- function(alter) {
  error <- tryCatch(
    {
      render_lesson(variant, alter)
      NULL
    },
    error = identity
  )
  stopifnot(
    inherits(error, "error"),
    grepl("is not TRUE|are not all TRUE|not identical", conditionMessage(error))
  )
}

for (bad_id in c(1L, -1L, 5L)) {
  expect_rejected(function(result, type) {
    if (type == "ids") {
      result[[1]][1] <- bad_id
    }
    result
  })
}
expect_rejected(function(result, type) {
  if (type == "subwords") {
    result[[1]] <- result[[1]][-1]
  }
  result
})
expect_rejected(function(result, type) rev(result))
cat("Rejected unknown, invalid, mismatched, missing, and reordered pieces.\n")
