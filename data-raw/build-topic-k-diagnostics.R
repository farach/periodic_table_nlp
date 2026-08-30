# Compare candidate topic counts without choosing by the most nameable output.
#
# The published lesson reads the committed diagnostics and still fits the
# selected model live. Fitting 18 candidate models and evaluating held-out
# perplexity belongs here rather than in every site render.
#
# Usage:
#   Rscript data-raw/build-topic-k-diagnostics.R

suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
  library(purrr)
  library(readr)
  library(rsample)
  library(quanteda)
  library(topicmodels)
  library(digest)
})

source("R/inaugural-corpus.R")

out_dir <- "data/inaugural"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

paragraphs <- inaugural_paragraphs()
candidate_k <- 3:8
candidate_seeds <- c(42L, 7L, 2024L)
top_n <- 10L

set.seed(5501)
topic_split <- group_initial_split(
  paragraphs,
  group = speech_id,
  prop = 0.75
)
topic_training <- training(topic_split)
topic_testing <- testing(topic_split)

make_tokens <- function(data) {
  tokens(
    data$paragraph,
    remove_punct = TRUE,
    remove_numbers = TRUE
  ) |>
    tokens_tolower() |>
    tokens_remove(stopwords("en"))
}

training_dfm <- dfm(make_tokens(topic_training)) |>
  dfm_trim(min_termfreq = 5)

testing_dfm <- dfm(make_tokens(topic_testing)) |>
  dfm_match(features = featnames(training_dfm))

testing_dfm <- testing_dfm[ntoken(testing_dfm) > 0, ]

training_dtm <- convert(training_dfm, to = "topicmodels")
testing_dtm <- convert(testing_dfm, to = "topicmodels")
training_binary <- as.matrix(training_dtm > 0)

semantic_coherence <- function(model, binary_dtm, top_n = 10L) {
  beta <- posterior(model)$terms

  topic_values <- seq_len(nrow(beta)) |>
    map_dbl(\(topic) {
      top_words <- order(
        beta[topic, ],
        decreasing = TRUE
      )[seq_len(top_n)]

      word_pairs <- combn(seq_along(top_words), 2)

      apply(
        word_pairs,
        2,
        \(pair) {
          earlier_word <- top_words[pair[1]]
          later_word <- top_words[pair[2]]
          co_documents <- sum(
            binary_dtm[, earlier_word] &
              binary_dtm[, later_word]
          )
          earlier_documents <- sum(binary_dtm[, earlier_word])

          log((co_documents + 1) / earlier_documents)
        }
      ) |>
        mean()
    })

  mean(topic_values)
}

adjusted_top_word_exclusivity <- function(model, top_n = 10L) {
  beta <- posterior(model)$terms
  topic_count <- nrow(beta)
  share_by_topic <- sweep(
    beta,
    2,
    colSums(beta),
    "/"
  )

  raw_exclusivity <- seq_len(topic_count) |>
    map_dbl(\(topic) {
      top_words <- order(
        beta[topic, ],
        decreasing = TRUE
      )[seq_len(top_n)]

      mean(share_by_topic[topic, top_words])
    }) |>
    mean()

  chance_share <- 1 / topic_count
  (raw_exclusivity - chance_share) / (1 - chance_share)
}

candidate_grid <- expand.grid(
  k = candidate_k,
  seed = candidate_seeds
) |>
  as_tibble()

diagnostic_runs <- map2(
  candidate_grid$k,
  candidate_grid$seed,
  \(k, seed) {
    set.seed(seed)
    model <- LDA(
      training_dtm,
      k = k,
      method = "VEM",
      control = list(seed = seed)
    )

    tibble(
      k = k,
      seed = seed,
      semantic_coherence = semantic_coherence(
        model,
        training_binary,
        top_n = top_n
      ),
      adjusted_exclusivity = adjusted_top_word_exclusivity(
        model,
        top_n = top_n
      ),
      heldout_perplexity = perplexity(
        model,
        newdata = testing_dtm
      )
    )
  }
) |>
  list_rbind()

diagnostic_summary <- diagnostic_runs |>
  summarise(
    seeds = n(),
    coherence_mean = mean(semantic_coherence),
    coherence_low = min(semantic_coherence),
    coherence_high = max(semantic_coherence),
    exclusivity_mean = mean(adjusted_exclusivity),
    exclusivity_low = min(adjusted_exclusivity),
    exclusivity_high = max(adjusted_exclusivity),
    perplexity_mean = mean(heldout_perplexity),
    perplexity_low = min(heldout_perplexity),
    perplexity_high = max(heldout_perplexity),
    .by = k
  ) |>
  mutate(
    coherence_rank = min_rank(desc(coherence_mean)),
    exclusivity_rank = min_rank(desc(exclusivity_mean)),
    perplexity_rank = min_rank(perplexity_mean),
    selected = k == 5L,
    selection_reason = if_else(
      selected,
      paste(
        "Highest mean semantic coherence under the stated diagnostic priority;",
        "more topical resolution than k=3"
      ),
      ""
    )
  ) |>
  arrange(k)

runs_path <- file.path(
  out_dir,
  "topic-k-diagnostic-runs.csv"
)
summary_path <- file.path(
  out_dir,
  "topic-k-diagnostics.csv"
)

write_csv(
  diagnostic_runs |>
    mutate(
      across(
        c(
          semantic_coherence,
          adjusted_exclusivity,
          heldout_perplexity
        ),
        \(value) round(value, 6)
      )
    ),
  runs_path,
  na = ""
)

write_csv(
  diagnostic_summary |>
    mutate(
      across(
        c(
          coherence_mean,
          coherence_low,
          coherence_high,
          exclusivity_mean,
          exclusivity_low,
          exclusivity_high,
          perplexity_mean,
          perplexity_low,
          perplexity_high
        ),
        \(value) round(value, 6)
      )
    ),
  summary_path,
  na = ""
)

hash_lines <- function(path) {
  digest(
    paste(read_lines(path), collapse = "\n"),
    algo = "sha256",
    serialize = FALSE
  )
}

metadata <- tibble(
  artifact = c(
    "topic-k-diagnostic-runs.csv",
    "topic-k-diagnostics.csv"
  ),
  description = c(
    paste(
      "VEM LDA diagnostics for k=3:8 across seeds",
      "42, 7, and 2024"
    ),
    paste(
      "Mean, range, rank, and documented selection across",
      "three seeds per candidate k"
    )
  ),
  settings = c(
    paste(
      "speech split seed 5501; 75% training;",
      "training vocabulary only; min term frequency 5;",
      "top 10 words; VEM"
    ),
    paste(
      "higher coherence and adjusted exclusivity are better;",
      "lower held-out perplexity is better; selected k=5"
    )
  ),
  source = paste(
    "quanteda data_corpus_inaugural,",
    "reshaped by R/inaugural-corpus.R"
  ),
  license = paste(
    "Speeches are US government works",
    "in the public domain"
  ),
  built_on = "2026-08-30",
  fingerprint = c(
    hash_lines(runs_path),
    hash_lines(summary_path)
  )
)

write_csv(
  metadata,
  file.path(
    out_dir,
    "topic-k-diagnostics-metadata.csv"
  ),
  na = ""
)

stopifnot(
  identical(nrow(topic_training), 1023L),
  identical(nrow(topic_testing), 354L),
  identical(n_distinct(topic_training$speech_id), 42L),
  identical(n_distinct(topic_testing$speech_id), 18L),
  identical(nfeat(training_dfm), 2022L),
  identical(nrow(diagnostic_runs), 18L),
  identical(nrow(diagnostic_summary), 6L),
  all(diagnostic_summary$seeds == 3L),
  identical(
    diagnostic_summary$k[
      diagnostic_summary$coherence_rank == 1L
    ],
    5L
  ),
  identical(
    diagnostic_summary$k[
      diagnostic_summary$exclusivity_rank == 1L
    ],
    3L
  ),
  identical(
    diagnostic_summary$k[
      diagnostic_summary$perplexity_rank == 1L
    ],
    3L
  ),
  identical(sum(diagnostic_summary$selected), 1L)
)

cat("\nTopic-count diagnostics:\n")
print(
  diagnostic_summary |>
    select(
      k,
      coherence_mean,
      coherence_rank,
      exclusivity_mean,
      exclusivity_rank,
      perplexity_mean,
      perplexity_rank,
      selected
    )
)

cat("\nWrote:\n")
print(
  tibble(
    file = c(
      runs_path,
      summary_path,
      file.path(
        out_dir,
        "topic-k-diagnostics-metadata.csv"
      )
    ),
    bytes = file.size(file)
  )
)
