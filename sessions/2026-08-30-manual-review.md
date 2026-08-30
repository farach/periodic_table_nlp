# Manual review: record boundaries and prose habits

Lesson 2 exposed a problem that a correct result had hidden. Five messages were
joined into one string before three patterns ran. The matches were right, but
the output could no longer say which message supplied each match.

## Rules carried forward

1. Keep one row per source record through extraction. Carry the source ID and
   source text with every derived value.
2. Use a list-column when one record can produce zero, one, or several matches.
3. Name first-match columns `first_date`, `first_email`, and so on. A name such
   as `date` conceals that later matches were discarded.
4. A number from `seq_along()` is a display position, not a source ID.
5. Flatten only for a corpus-wide question. Keep the row-level object, derive
   the flat result from it, and name the operation so the loss is visible.
6. Do not narrate hidden assertions as though they appear in the lesson. Explain
   the displayed output instead.

The audit searched every numbered `.qmd` file for `collapse = " "`, `list_c()`,
and `unlist(use.names = FALSE)`, then read each match in context. It found no
second case of accidental record loss. Other uses rebuild one sentence or
phrase, compute a document-level score, make a hash, or create an explicitly
corpus-wide inventory. Those uses keep the grouping key or state why the
records are being combined.

## Prose watch list

The manual read also caught a set of words used repeatedly as vague qualifiers
or as substitutes for saying how a failure occurs. The exact forms live in
`scripts/check-prose.R`, where the build can enforce them. Two genuine
linguistic terms remain allowed: `silent h` and `silent e`.

The fixes replace vague adverbs with the observable behavior:

- “without an error”
- “without reporting the guess”
- “returns no match”
- “the rules abstained”

This is a wording rule and an evidence rule. A sentence should name what the
program did, not merely suggest that it happened out of sight.

## Where the project remembers

- `CONTRIBUTING.md` states the data-shape rules for new code.
- `EDITORIAL_GUIDE.md` adds a record-boundary pass to every lesson review.
- `.github/pull_request_template.md` requires the pass before publication.
- `scripts/check-prose.R` fails on the recurring prose habits.

The session log preserves the reason. The automated checks preserve the habit.
