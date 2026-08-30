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
6. End with an image or rule the reader can recall later.

The person may be fictional, but the page must say so when readers could mistake
the example for a real case. Do not invent quotes, statistics, studies, or
personal details. Avoid danger, urgency, or sentiment that the subject has not
earned.

A recurring object can support memory. A badge with a damaged name, a labeled
folder of documents, or a librarian's reading list gives an abstract idea a
place to live. Use one image and let it go when its work is done.

## Keep the prose out of the way

- Prefer specific nouns and plain verbs.
- Define a new term beside the example that needs it.
- Vary sentence length, but do not manufacture drama with fragments.
- Use headings to answer reader questions.
- Explain an output instead of praising it.
- Cut introductory sentences that delay the point.
- Keep optional machinery in a clearly labeled note.

Sentence-case headings are required. Public lessons do not discuss drafting
history.

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
