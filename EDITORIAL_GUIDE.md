# Editorial guide

The project has two obligations: tell the truth and help the reader understand
it. Technical detail matters only when it serves those obligations.

## Build a story without inventing one

Each lesson should follow a human-scale arc:

1. Introduce a person facing a recognizable language problem.
2. Make the uncertainty or consequence clear.
3. Let the reader investigate through a small example.
4. Show the limit, complication, or tempting mistake.
5. Resolve the immediate problem with evidence.
6. End with a brief rule that the reader can apply later.

The person may be fictional, but the page must say so when readers could mistake
the example for a real case. Do not invent quotes, statistics, studies, or
personal details. Avoid danger, urgency, or sentiment that the subject has not
earned.

Use a concrete example to explain an abstract concept. Keep the example's
objects and terms consistent. Do not replace a technical explanation with a
metaphor or an idiom.

## Keep the prose out of the way

- Prefer specific nouns and plain verbs.
- Define a new term beside the example that needs it.
- Vary sentence length within the limits: 20 words for instructions and 25
  words for descriptions. Do not manufacture drama with fragments.
- Use headings to answer reader questions.
- Explain an output instead of praising it.
- Cut introductory sentences that delay the point.
- Keep optional machinery in a clearly labeled note.

Sentence-case headings are required. Public lessons do not discuss drafting
history.

## Apply controlled-language rules in context

Use ASD-STE100 Issue 9 as the reference for this project's plain-language
checks. The official edition is dated 15 January 2025.
The project does not claim certification or complete compliance.

- Give one action per instruction, except actions that must occur together.
- Keep each paragraph on one topic, with no more than six sentences.
- Prefer active voice. A descriptive passive needs a reason, such as an unknown actor.
- Use simple tenses. Do not use a progressive or perfect tense for an ordinary action.
- Avoid semicolons, idioms, and figurative meanings in authored teaching prose.
- Give meanings for technical terms near their first occurrence. Use one term for each concept.
- Examine general words for their permitted meaning and part of speech.
  A matching spelling alone is not enough.
- Record technical nouns and verbs with their subject, meaning, and page context.
  A technical term does not justify an unrelated ordinary meaning.

Apply these rules to descriptions, instructions, captions, alt text,
navigation labels, and authored prose emitted by R. Preserve quoted evidence,
source titles, code identifiers, and raw example data.

Execute `npm run test:prose` for source checks.
Its report lists inline-R blocks whose sentence boundaries and lengths need rendered checks.
The source checks still flag unambiguous semicolons in those blocks.
The browser suite examines rendered paragraphs, captions, and alt text without that deferral.
Examine authored display strings and figure options directly in the source as well.
These tests do not find every imperative or prove correct grammar and permitted vocabulary meanings.

Their word counts are conservative approximations, not the standard's exact
counting procedure. Read flagged passages in context. Do not hide findings
with a page exemption or a broad vocabulary whitelist.

The per-page record in `reviews/plain-language-pages.csv` distinguishes
completed reading from pending vocabulary work. The term register is
`reviews/technical-terms.csv`. People must still examine the prose.

For a prose-only repair, preserve calculations, model settings, conditions,
identifiers, numerical claims, citations, and data. A display-only string may
change when its meaning and interpolated values stay the same.
Record those changes separately. If an assertion compares that authored
wording, retain the assertion and change only its expected wording.
Compare executable structure and data fingerprints, then execute the relevant
tests and render the affected pages.

Read the applied pages twice after the last material edit. Record two clean
reads only if neither read finds a necessary change. Finish with an
uninterrupted read of the rendered page. A scan result does not replace these manual checks.

## Review for signs of machine-written prose

No detector can establish authorship from prose alone. The project uses several
different reviews because each catches a different problem.

### Round 1: residue scan

Run `Rscript scripts/check-prose.R`. The first scan looks for citation tokens,
unfinished placeholders, chatbot phrases, and other material that should never
reach a reader.

### Round 2: pattern scan

The same script checks for a short list of repeated words and structures that
often make technical prose sound generic. The build blocks an unresolved
match, but the match is not evidence about who wrote the sentence.

### Round 3: spoken edit

Read the lesson aloud. Rewrite sentences that sound like a presentation,
advertisement, press release, or scripted assistant. Check whether nearby
paragraphs begin the same way or repeat the same rhythm.

### Round 4: independent edit

A second editor reads for voice, narrative, and reader effort. The editor should
identify the point where attention drops, the hardest unexplained term, and the
sentence that sounds least like a person speaking.

### Round 5: skeptical fact review

Review every factual claim against its source. Look for missing qualifications,
conflicting findings, outdated practice, weak comparisons, and claims that move
from correlation to cause.

### Round 6: record-boundary review

When a lesson processes several messages, documents, or rows, pick one match and
trace it back to the source record. Search the code for `collapse`, `list_c()`,
`unlist()`, and global summaries. Each use needs a reason. Keep row-level results
as the default and derive corpus-wide lists from them only when the lesson asks a
corpus-wide question.

Check names as well as values. A row position is not a source ID, and a column
called `date` should not contain only the first date when more could exist.

### Round 7: comparison and null review

For every side-by-side rate, verify that the unit, denominator, case policy,
tokenizer, and preprocessing match. Trace derived labels back through a keyed
join rather than trusting row order.

Put a same-split, deployable baseline beside each model score. Record whether a
rule was written before or after its evaluation rows were read. For repeated
splits, check paired wins, ties, and losses before writing `always` or `never`.
For a permutation null, preserve nuisance structure that could create the
statistic. A check run only after selecting one parameter value cannot justify
that selection.

## Sign off on the rendered page

The last read happens in the browser after code execution. Check the title,
opening, transitions, tables, code output, captions, sources, and closing
memory cue. Do not publish from the source view alone.

## Check the series as a series

Consistent headings can help readers move between lessons, but identical
openings, paragraph sequences, and conclusions can make distinct topics feel
interchangeable. The automated repetition check finds exact sentences and
four-word openings only. A human editor must also read a run of neighboring
lessons for repeated argument shape, pacing, and stock transitions.

This review concerns observable prose, not authorship. Do not optimize text for
an AI detector or describe a person or model as the author based on style.
