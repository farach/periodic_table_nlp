# Reading the review records

These files record what reviewers read and what remains uncertain. They do
not establish complete ASD-STE100 compliance or accessibility certification.
Source reads and rendered-page reads have separate records.

## Source records

`plain-language-pages.csv` has one record for each of the 86 public pages.
Each source hash identifies the exact file bytes read by the reviewers.
An unchanged page can retain an earlier snapshot date.

| Field | Meaning |
|---|---|
| `source_file` | Repository-relative QMD path. |
| `source_sha256` | SHA-256 of the source file bytes. |
| `source_snapshot_at` | Time when the source snapshot was recorded. |
| `reviewer` | Original editor. Later readers appear in the scope or limitations. |
| `edits` | Changes and their reasons. |
| `technical_terms` | Terms relevant to this page, including candidates. |
| `dictionary_review` | Vocabulary work performed and its limits. |
| `post_apply_clean_reads` | Declared clean-pass count. Read the scope before interpreting the count. |
| `clean_passes_at_current_hash` | Recorded passes 1 and 2 at the stated source hash. |
| `first_clean_read_at` | Write time of the pass 1 record. |
| `second_clean_read_at` | Write time of the pass 2 record. |
| `uninterrupted_read_at_current_hash` | Whether a pass 3 record exists at that source hash. |
| `uninterrupted_read_at` | Write time of the pass 3 record. |
| `read_scope` | Scope recorded for the applied reads. |
| `limitations` | Unresolved matters and distinctions between review stages. |
| `final_read_scope` | Scope of source pass 3, not proof of a later rendered-page read. |
| `final_read_findings` | Findings from source pass 3. |

Pass timestamps are record-write times. Several pages can share a timestamp.
The times do not measure reading duration.

Some pass 2 reads covered only authored display strings.
The per-page `read_scope` field states each pass's actual coverage.
Do not treat every numbered pass as a complete-page read.

A statement such as "final CI pending" describes the stage at which that
source record was written. Use the rendered records for the later result.

## Rendered records

`rendered-pages.csv` records the final rendered-text read separately.
Its `source_commit` and `artifact_id` identify the build.
The source and HTML hashes identify the reviewed files.
The `scope` and `limitations` fields state what the reader examined.
A record can carry an earlier read forward only when the page's HTML is
identical to an earlier reviewed build. Its `scope` field says so.
Some `scope` fields name temporary audit files that are not in this
repository. The hashes and the artifact ID are the checkable evidence.

A rendered-text read can include tables, captions, alt text and generated
prose without inspecting raster image pixels. Automated browser tests and
selected image inspections provide separate evidence. They do not establish
complete visual or screen-reader coverage.

## Vocabulary records

`technical-terms.csv` retains the 242-record baseline used for the source
repair. Candidate entries are not approvals. Dictionary meaning and
part-of-speech coverage remains incomplete.

The source-page lists for the candidate entries `dependency head`, `leakage`
and `regularization` are inaccurate or unverified. Do not use those lists as
an inventory of terms present on the pages. The term list for lesson 04 in
the source records also retains the candidate `leakage`.

Later review produced 26 additional decisions and an amendment for
`negation scope`. `supplemental-term-decisions.csv` records those decisions
without changing the baseline CSV. Some older decision labels say
"technical name". Issue 9 uses "technical noun". Retaining a term for a
specific NLP meaning does not approve every ordinary use of that word.
