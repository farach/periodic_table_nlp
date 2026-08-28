# Contributing

This project teaches natural language processing to people who may be new to R,
programming, or both. A lesson succeeds when a reader understands the idea and
knows when it is useful.

Read [EDITORIAL_GUIDE.md](EDITORIAL_GUIDE.md) before drafting and
[RESEARCH_STANDARDS.md](RESEARCH_STANDARDS.md) before making technical claims.
Use [MODERNIZATION_NOTES.md](MODERNIZATION_NOTES.md) to identify tasks that
need current transformer, retrieval, inference, or evaluation research.

## Write for the reader

- Begin with a problem the reader can recognize.
- Use everyday language before introducing a technical term.
- Define each technical term close to its first use.
- Keep examples small enough to check by eye.
- Explain what the code does and what its output means.
- Put optional implementation detail after the main explanation.
- End with a short list of ideas the reader should remember.
- Give the lesson a restrained narrative arc with a person, a need, a
  complication, and a useful resolution.

Public pages must stand on their own. Draft history belongs in Git, not in a
lesson. Do not refer to earlier drafts, previous versions, rewrites, or what a
chapter used to say.

## Review writing in multiple rounds

Automated classifiers cannot prove that a person or a machine wrote a passage.
This project checks for visible writing habits and residue instead.

1. Run `Rscript scripts/check-prose.R` for machine residue and common style
   patterns.
2. Read the lesson aloud and remove stiff phrasing, repeated structures, and
   unnecessary setup.
3. Ask an independent editor to challenge the voice, narrative, and clarity.
4. Run a separate skeptical review of every factual claim and source.
5. Proofread the final rendered page without editing while reading.

Record all five rounds in the pull request checklist. A tool passing is not a
substitute for editorial judgment.

## Run every example

Every published code chunk must have output produced by a real execution.

1. Keep code evaluation enabled and caching disabled.
2. Use deterministic inputs. Set a seed before any random operation.
3. Add an assertion for each important expected result.
4. Render the entire site after changing code or package versions.
5. Treat errors, unexpected output, and unexplained warnings as publishing
   blockers.
6. Run command-line snippets exactly as written before publishing them.

## Write code in the tidyverse style

Lesson code uses the tidyverse: `readr` to read files, `tibble` to build
tables, `dplyr` to reshape them, `tidyr` to pivot, `purrr` to iterate, and
`stringr` for strings. Use the native pipe `|>`.

- Load packages by name in a visible chunk near the top of the lesson and
  assert that they attached. Do not use `library(tidyverse)`; naming each
  package shows the reader which one does which job.
- Give `readr::read_csv()` an explicit `col_types = cols(...)` and a deliberate
  `na =`. Column types are a teaching point, so never rely on type guessing.
- Keep base R where it is the subject of the lesson or has no tidyverse
  equivalent, such as `charToRaw()`, `Encoding()`, `iconv()`, and matrix work
  handed to another package.
- `stringr` uses the ICU regular expression engine. Base R uses TRE, or PCRE2
  with `perl = TRUE`. When a lesson explains how a pattern behaves, say which
  engine produced that behaviour and confirm it by running the code.
- While editing, run one lesson at a time with
  `Rscript scripts/run-lesson.R <path>`. It executes every chunk in order and
  fails on any warning. The full render remains the gate before publishing.

The project-level Quarto settings execute every R chunk and stop on errors. The
GitHub Actions workflow restores the locked R environment and renders every
page on each pull request.

## Make the page accessible

- Use headings in a logical order.
- Give informative images meaningful alt text.
- Introduce tables in the surrounding text and use clear column names.
- Do not rely on color alone to communicate meaning.
- Use descriptive link text instead of "click here."
- Check keyboard navigation, focus visibility, and the page at 200% zoom.
- Run `npm run test:a11y` after rendering the site.
- Test with a real screen reader before public release; an automated scan does
  not reproduce a person's experience.

## Check factual claims

Use the evidence hierarchy and claim labels in
[RESEARCH_STANDARDS.md](RESEARCH_STANDARDS.md). Link to primary research or
official documentation in a final "Sources" section, but explain the fact in
the lesson rather than expecting readers to interpret the source themselves.

For fast-moving topics, record when the research was checked. Separate
established knowledge, current practice, emerging methods, and speculation.
Search for evidence that contradicts the lesson before publishing it.

## Review before publishing

- [ ] A first-time reader can explain why the lesson matters.
- [ ] The narrative helps memory without inventing drama or evidence.
- [ ] Technical terms are defined in plain language.
- [ ] Every code chunk has been executed.
- [ ] Important outputs have explicit assertions.
- [ ] The full site renders without an error.
- [ ] Links, headings, tables, and image descriptions have been checked.
- [ ] The page contains no drafting history or references to prior versions.
- [ ] All writing-review and research-review rounds are recorded.
