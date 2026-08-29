# Build a small, offline extract of Open English WordNet for lesson 58.
#
# Source:  Open English WordNet 2024, https://en-word.net/
# Licence: Creative Commons Attribution 4.0 International (CC BY 4.0)
#          https://creativecommons.org/licenses/by/4.0/
# Format:  WN-LMF 1.3 XML (161,705 lexical entries, 120,630 synsets, 103 MB)
#
# WordNet is far too large to ship with this site, and downloading it at render
# time would break the promise that every page builds offline. This script runs
# by hand, keeps a curated slice, and commits the result. Re-run it only when the
# lesson needs a different set of words.
#
# Usage (from the repository root):
#   Rscript data-raw/build-wordnet-extract.R

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(purrr)
  library(stringr)
  library(xml2)
  library(digest)
})

out_dir <- "data/wordnet"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Kept outside the repository index so a 103 MB intermediate never gets committed.
cache_dir <- "data-raw/.cache"
dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)

source_url <- "https://en-word.net/static/english-wordnet-2024.xml.gz"
gz_path <- file.path(cache_dir, "english-wordnet-2024.xml.gz")
xml_path <- file.path(cache_dir, "english-wordnet-2024.xml")

if (!file.exists(gz_path)) {
  message("Downloading ", source_url)
  download.file(source_url, gz_path, mode = "wb", quiet = FALSE)
}

if (!file.exists(xml_path)) {
  message("Decompressing")
  con_in <- gzfile(gz_path, open = "rb")
  con_out <- file(xml_path, open = "wb")
  repeat {
    chunk <- readBin(con_in, what = "raw", n = 8L * 1024L * 1024L)
    if (length(chunk) == 0L) break
    writeBin(chunk, con_out)
  }
  close(con_in)
  close(con_out)
}

message("Parsing ", xml_path, " (", round(file.info(xml_path)$size / 1e6), " MB)")
doc <- read_xml(xml_path)
xml_ns_strip(doc)
lexicon <- xml_find_first(doc, "./Lexicon")
stopifnot(!is.na(xml_attr(lexicon, "version")))

lexicon_label <- xml_attr(lexicon, "label")
lexicon_version <- xml_attr(lexicon, "version")
lexicon_licence <- xml_attr(lexicon, "license")

# WN-LMF gives every lexical entry exactly one Lemma, so the two node sets line
# up position for position. Everything below leans on that, so check it.
entries <- xml_find_all(lexicon, "./LexicalEntry")
lemma_nodes <- xml_find_all(lexicon, "./LexicalEntry/Lemma")
stopifnot(length(entries) == length(lemma_nodes))
message("Lexical entries in source: ", length(entries))

entry_lemma <- tolower(xml_attr(lemma_nodes, "writtenForm"))
entry_pos <- xml_attr(lemma_nodes, "partOfSpeech")

pos_label <- c(
  n = "noun", v = "verb", a = "adjective",
  r = "adverb", s = "adjective satellite"
)

# The words the lesson works with. "bank", "run", "light", "spring", "table",
# "plant" and "match" carry the polysemy argument; the rest are ordinary words
# whose hypernym chains read cleanly.
target_lemmas <- c(
  "bank", "run", "light", "spring", "table", "plant", "match", "letter",
  "dog", "cat", "bird", "oak", "rose", "hammer", "chair", "river",
  "city", "teacher", "doctor", "engineer", "language", "word", "sentence",
  "meaning", "computer", "machine", "model", "train", "school", "job",
  "work", "skill", "wage", "worker", "market", "office", "report", "record"
)

keep <- which(entry_lemma %in% target_lemmas)
message("Matching entries: ", length(keep))
stopifnot(length(keep) > 0L)

senses <- map_dfr(keep, function(i) {
  sense_nodes <- xml_find_all(entries[[i]], "./Sense")
  if (length(sense_nodes) == 0L) return(NULL)
  tibble(
    lemma = entry_lemma[[i]],
    part_of_speech = unname(pos_label[entry_pos[[i]]]),
    sense_id = xml_attr(sense_nodes, "id"),
    synset_id = xml_attr(sense_nodes, "synset"),
    sense_order = seq_along(sense_nodes)
  )
})

wanted_synsets <- unique(senses$synset_id)
message("Synsets referenced: ", length(wanted_synsets))

# Pull every synset id in one vectorised call, then index rather than search.
all_synsets <- xml_find_all(lexicon, "./Synset")
all_synset_ids <- xml_attr(all_synsets, "id")
message("Synsets in source: ", length(all_synsets))

synset_definition <- function(node) {
  d <- xml_text(xml_find_first(node, "./Definition"))
  if (is.na(d)) NA_character_ else str_squish(d)
}
synset_example <- function(node) {
  e <- xml_text(xml_find_first(node, "./Example"))
  if (is.na(e)) NA_character_ else str_squish(e)
}

wanted_index <- match(wanted_synsets, all_synset_ids)
stopifnot(!anyNA(wanted_index))

synset_rows <- tibble(
  synset_id = wanted_synsets,
  part_of_speech = unname(pos_label[xml_attr(all_synsets[wanted_index], "partOfSpeech")]),
  definition = map_chr(wanted_index, ~ synset_definition(all_synsets[[.x]])),
  example = map_chr(wanted_index, ~ synset_example(all_synsets[[.x]]))
)

# Hypernym and hyponym links, one step in each direction.
relations <- map_dfr(seq_along(wanted_synsets), function(k) {
  rel <- xml_find_all(all_synsets[[wanted_index[[k]]]], "./SynsetRelation")
  if (length(rel) == 0L) return(NULL)
  tibble(
    synset_id = wanted_synsets[[k]],
    relation = xml_attr(rel, "relType"),
    target_synset_id = xml_attr(rel, "target")
  )
}) |>
  filter(relation %in% c("hypernym", "hyponym"))

# A synset is a set of synonyms, so the lesson needs every lemma in each one.
# Scanning all senses is the only way to get that, so do it in one vectorised
# pass and subset before touching the tree again.
all_sense_nodes <- xml_find_all(lexicon, "./LexicalEntry/Sense")
all_sense_synset <- xml_attr(all_sense_nodes, "synset")
message("Senses in source: ", length(all_sense_nodes))

needed_synsets <- unique(c(wanted_synsets, relations$target_synset_id))
hit <- which(all_sense_synset %in% needed_synsets)
message("Senses touching the extract: ", length(hit))

hit_lemma <- xml_attr(
  xml_find_first(all_sense_nodes[hit], "../Lemma"),
  "writtenForm"
)
stopifnot(length(hit_lemma) == length(hit), !anyNA(hit_lemma))

membership_all <- tibble(
  synset_id = all_sense_synset[hit],
  lemma = tolower(hit_lemma)
) |>
  distinct() |>
  arrange(synset_id, lemma)

membership <- membership_all |> filter(synset_id %in% wanted_synsets)

target_index <- match(relations$target_synset_id, all_synset_ids)
relations <- relations |>
  mutate(
    target_definition = map_chr(target_index, function(j) {
      if (is.na(j)) NA_character_ else synset_definition(all_synsets[[j]])
    })
  ) |>
  left_join(
    membership_all |>
      group_by(synset_id) |>
      summarise(target_members = paste(lemma, collapse = ", "), .groups = "drop") |>
      rename(target_synset_id = synset_id),
    by = "target_synset_id"
  ) |>
  arrange(synset_id, relation, target_synset_id)

senses <- senses |> arrange(lemma, part_of_speech, sense_order)
synset_rows <- synset_rows |> arrange(synset_id)

write_csv(senses, file.path(out_dir, "wordnet-senses.csv"), na = "")
write_csv(synset_rows, file.path(out_dir, "wordnet-synsets.csv"), na = "")
write_csv(membership, file.path(out_dir, "wordnet-members.csv"), na = "")
write_csv(relations, file.path(out_dir, "wordnet-relations.csv"), na = "")

metadata <- tibble(
  field = c(
    "source_name", "source_url", "source_version", "source_licence",
    "licence_url", "attribution", "generated_on", "generator",
    "target_lemmas", "n_lemmas_requested", "n_lemmas_found",
    "n_senses", "n_synsets", "n_membership_rows", "n_relation_rows",
    "sha256_senses", "sha256_synsets", "sha256_members", "sha256_relations"
  ),
  value = c(
    "Open English WordNet",
    source_url,
    paste(lexicon_label, lexicon_version),
    lexicon_licence,
    "https://creativecommons.org/licenses/by/4.0/",
    "Open English WordNet, used under CC BY 4.0. Sense content is unchanged; this file is a subset.",
    format(Sys.Date()),
    "data-raw/build-wordnet-extract.R",
    paste(sort(target_lemmas), collapse = " "),
    as.character(length(target_lemmas)),
    as.character(n_distinct(senses$lemma)),
    as.character(nrow(senses)),
    as.character(nrow(synset_rows)),
    as.character(nrow(membership)),
    as.character(nrow(relations)),
    digest(file = file.path(out_dir, "wordnet-senses.csv"), algo = "sha256"),
    digest(file = file.path(out_dir, "wordnet-synsets.csv"), algo = "sha256"),
    digest(file = file.path(out_dir, "wordnet-members.csv"), algo = "sha256"),
    digest(file = file.path(out_dir, "wordnet-relations.csv"), algo = "sha256")
  )
)

write_csv(metadata, file.path(out_dir, "wordnet-metadata.csv"), na = "")

message("\nWrote:")
print(as.data.frame(metadata), right = FALSE)
