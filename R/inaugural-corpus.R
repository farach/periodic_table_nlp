# Shared corpus for the models-and-analysis lessons.
#
# The Riverton material is 28 sentences, which is too small to train or
# evaluate anything. These lessons use the inaugural addresses bundled with
# quanteda instead: 60 speeches from 1789 to 2025, with the year, the
# president, and the party recorded for each one.
#
# The speeches are works of the United States government and are in the public
# domain. quanteda packages them; DATA_SOURCES.md records both facts.
#
# Every lesson builds the corpus through this file so they all agree on what a
# paragraph is and which rows exist.
#
# `president` is the full name, built from quanteda's FirstName and President
# docvars. The President docvar alone is a surname, and four surnames cover two
# people each: Adams, Harrison, Roosevelt, and Bush. Grouping on the surname
# would silently merge John Adams with John Quincy Adams and Theodore Roosevelt
# with Franklin Roosevelt. There are 60 speeches by 40 people, not 36.
# `surname` is kept so a lesson can show that collision.

suppressPackageStartupMessages({
  library(quanteda)
  library(dplyr)
  library(tibble)
  library(tidyr)
  library(stringr)
})

# A paragraph here is a block of text separated by blank lines and holding at
# least 25 words. Short blocks are salutations and headings, which carry the
# speech's style without carrying its argument.
inaugural_paragraphs <- function(min_words = 25L) {
  speeches <- tibble(
    speech_id = names(quanteda::data_corpus_inaugural),
    year = as.integer(quanteda::data_corpus_inaugural$Year),
    surname = as.character(quanteda::data_corpus_inaugural$President),
    first_name = as.character(quanteda::data_corpus_inaugural$FirstName),
    party = as.character(quanteda::data_corpus_inaugural$Party),
    text = as.character(quanteda::data_corpus_inaugural)
  ) |>
    mutate(president = str_squish(paste(first_name, surname)))

  speeches |>
    mutate(paragraph = str_split(text, "\n+")) |>
    select(-text) |>
    unnest(paragraph) |>
    mutate(paragraph = str_squish(paragraph)) |>
    filter(str_count(paragraph, "\\S+") >= min_words) |>
    group_by(speech_id) |>
    mutate(
      paragraph_id = sprintf("%s-p%02d", speech_id, row_number())
    ) |>
    ungroup() |>
    mutate(
      era = factor(
        if_else(year < 1900, "before 1900", "1900 or later"),
        levels = c("before 1900", "1900 or later")
      ),
      paragraph_words = str_count(paragraph, "\\S+")
    ) |>
    select(
      paragraph_id,
      speech_id,
      year,
      president,
      surname,
      party,
      era,
      paragraph_words,
      paragraph
    )
}
