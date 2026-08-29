# Build the fictional Riverton reference files used by tasks 30 and 32.
#
# Run by hand, not during a render. Everything here is invented for teaching.
# No real place, employer, or person is described.
#
# Usage:
#   Rscript data-raw/build-riverton-reference.R

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tibble)
  library(digest)
})

out_dir <- "data/riverton"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# A gazetteer is a list of place names with locations attached. Real ones carry
# millions of rows and their own licences. This one has nine invented places so
# a lesson can show the lookup and its failure modes without a download.
places <- tribble(
  ~place_name,            ~place_type,   ~latitude, ~longitude, ~parent,
  "Riverton",             "city",           41.8210,   -71.4120, "Marrow County",
  "Riverton Heights",     "neighbourhood",  41.8402,   -71.3988, "Riverton",
  "East Riverton",        "neighbourhood",  41.8117,   -71.3841, "Riverton",
  "Marrow County",        "county",         41.7995,   -71.4503, "Calder",
  "Calder",               "state",          41.6500,   -71.5000, NA,
  "Bellhaven",            "city",           41.9331,   -71.2760, "Marrow County",
  "Riverton Skills Centre", "building",     41.8256,   -71.4077, "Riverton",
  "Norwood",              "city",           41.7042,   -71.6188, "Calder",
  "Riverton",             "city",           38.4410,   -75.1002, "Tidewater"
)

write_csv(places, file.path(out_dir, "riverton-gazetteer.csv"), na = "")

# A knowledge base gives each entity a stable identifier, so two mentions of
# the same thing can be tied together. Aliases are what makes linking possible
# and ambiguity is what makes it hard.
entities <- tribble(
  ~entity_id,   ~canonical_name,            ~entity_type,  ~description,
  "ORG-0001",   "Riverton Workforce Lab",   "organisation", "Fictional research group that labels workforce text",
  "ORG-0002",   "Riverton Skills Centre",   "organisation", "Fictional training provider in Riverton",
  "ORG-0003",   "Marrow County Transit",    "organisation", "Fictional public transport operator",
  "LOC-0001",   "Riverton",                 "place",        "Fictional city in Marrow County, Calder",
  "LOC-0002",   "Riverton",                 "place",        "Fictional town in Tidewater, unrelated to LOC-0001",
  "LOC-0003",   "Bellhaven",                "place",        "Fictional city in Marrow County",
  "CRD-0001",   "Forklift Operator Licence", "credential",  "Fictional certificate named in the job board",
  "CRD-0002",   "Data Support Certificate", "credential",   "Fictional certificate named in the training flyer"
)

aliases <- tribble(
  ~entity_id, ~alias,
  "ORG-0001", "Riverton Workforce Lab",
  "ORG-0001", "the Lab",
  "ORG-0001", "Workforce Lab",
  "ORG-0002", "Riverton Skills Centre",
  "ORG-0002", "Skills Centre",
  "ORG-0002", "RSC",
  "ORG-0003", "Marrow County Transit",
  "ORG-0003", "MCT",
  "LOC-0001", "Riverton",
  "LOC-0001", "Riverton, Calder",
  "LOC-0002", "Riverton",
  "LOC-0002", "Riverton, Tidewater",
  "LOC-0003", "Bellhaven",
  "CRD-0001", "forklift certification",
  "CRD-0001", "Forklift Operator Licence",
  "CRD-0002", "Data Support Certificate",
  "CRD-0002", "DATA SUPPORT CERTIFICATE"
)

write_csv(entities, file.path(out_dir, "riverton-entities.csv"))
write_csv(aliases, file.path(out_dir, "riverton-aliases.csv"))

# Short author-written strings for the language-identification lesson. They are
# deliberately plain so the meaning is easy to check, and they are labelled with
# the language they were written in rather than with a detector's guess.
language_samples <- tribble(
  ~sample_id, ~written_in, ~text,
  "L01", "en", "Evening shifts require a valid forklift certification.",
  "L02", "en", "Apply by October 15.",
  "L03", "es", "Muy \u00fatil y f\u00e1cil de usar.",
  "L04", "fr", "Les cours du soir commencent en octobre.",
  "L05", "de", "Der Kurs beginnt im Oktober.",
  "L06", "nl", "De cursus begint in oktober.",
  "L07", "en", "Open house.",
  "L08", "es", "Casa abierta."
)

write_csv(
  language_samples,
  file.path(out_dir, "language-samples.csv")
)

hash_lines <- function(path) {
  digest(
    paste(read_lines(path), collapse = "\n"),
    algo = "sha256",
    serialize = FALSE
  )
}

files <- c(
  "riverton-gazetteer.csv",
  "riverton-entities.csv",
  "riverton-aliases.csv",
  "language-samples.csv"
)

metadata <- tibble(
  artifact = files,
  description = c(
    "Invented place names with coordinates, including one deliberate duplicate name",
    "Invented entities with stable identifiers",
    "Surface forms that map to those identifiers, including one ambiguous alias",
    "Short author-written strings labelled with the language they were written in"
  ),
  source = "Created for this project",
  license = "MIT, same as this repository",
  created_on = "2026-08-29",
  fingerprint = vapply(
    file.path(out_dir, files),
    hash_lines,
    character(1),
    USE.NAMES = FALSE
  )
)

write_csv(metadata, file.path(out_dir, "riverton-reference-metadata.csv"))

cat("wrote:\n")
print(
  tibble(file = list.files(out_dir, full.names = TRUE)) |>
    mutate(bytes = file.size(file))
)
