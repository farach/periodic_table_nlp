# A shared permutation null for the signals-and-discovery lessons.
#
# Every method in tasks 53 to 57 returns a confident-looking answer for any
# input, including noise. Keyword lists, summaries, topics, trends and outlier
# rankings all come back populated whether or not there is anything there. The
# only way to know whether a number means something is to ask what the same
# number looks like when the structure is destroyed and everything else is held
# fixed.
#
# `permutation_null()` takes an observed statistic and a function that returns
# one statistic computed on shuffled data. It reports the observed value beside
# the middle of the null distribution and a permutation p-value, so a lesson can
# say "this is what noise produces" instead of asking the reader to take a
# number on trust.
#
# The p-value uses the (r + 1) / (n + 1) form, which never returns zero. A
# permutation test cannot prove that an effect is impossible under chance; it
# can only say that it did not appear in the replicates that were run.

suppressPackageStartupMessages({
  library(tibble)
  library(stats)
})

permutation_null <- function(observed,
                             replicate_fn,
                             replicates = 1000L,
                             seed = 42L,
                             alternative = c("greater", "less", "two_sided")) {
  alternative <- match.arg(alternative)
  stopifnot(
    is.numeric(observed),
    length(observed) == 1L,
    is.function(replicate_fn),
    replicates >= 100L
  )

  set.seed(seed)
  draws <- vapply(seq_len(replicates), function(i) replicate_fn(), numeric(1))
  stopifnot(!anyNA(draws))

  extreme <- switch(
    alternative,
    greater = sum(draws >= observed),
    less = sum(draws <= observed),
    two_sided = sum(abs(draws - mean(draws)) >= abs(observed - mean(draws)))
  )

  tibble(
    observed = observed,
    null_mean = mean(draws),
    null_low = unname(quantile(draws, 0.05, type = 7)),
    null_high = unname(quantile(draws, 0.95, type = 7)),
    p_value = (extreme + 1) / (replicates + 1),
    replicates = replicates,
    alternative = alternative
  )
}

# Render a null result as a sentence a non-technical reader can act on.
describe_null <- function(null_result, statistic_name, digits = 3) {
  sprintf(
    paste0(
      "%s was %s. Shuffling produced a middle value of %s, with 90%% of ",
      "shuffles between %s and %s. Permutation p-value %s across %d shuffles."
    ),
    statistic_name,
    format(round(null_result$observed, digits), nsmall = 0),
    format(round(null_result$null_mean, digits), nsmall = 0),
    format(round(null_result$null_low, digits), nsmall = 0),
    format(round(null_result$null_high, digits), nsmall = 0),
    format(round(null_result$p_value, 4), nsmall = 0),
    null_result$replicates
  )
}
