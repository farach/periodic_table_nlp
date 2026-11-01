import assert from "node:assert/strict";
import test from "node:test";
import { auditSource, inspectSourceBlock, inspectText, plainText, publicPages, sourceBlocks } from "../scripts/check-plain-language.mjs";

test("description and recognized instruction limits differ", () => {
  assert.deepEqual(inspectText(`${"word ".repeat(25)}.`), []);
  assert.match(inspectText(`${"word ".repeat(26)}.`)[0], /limit 25/);
  assert.deepEqual(inspectText(`Read ${"word ".repeat(19)}.`), []);
  assert.match(inspectText(`Read ${"word ".repeat(20)}.`)[0], /limit 20/);
  assert.match(inspectText(`Do not remove ${"word ".repeat(18)}.`)[0], /limit 20/);
});

test("paragraph limit and semicolons are not silently exempted", () => {
  assert.deepEqual(inspectText("A result. ".repeat(6)), []);
  assert.match(inspectText("A result. ".repeat(7))[0], /limit 6/);
  assert.match(inspectText("Read the result; record the value.")[0], /semicolon/);
  assert.deepEqual(inspectText('The quoted value is "a; b".'), []);
  assert.deepEqual(inspectText("Use `x; y`."), []);
});

test("possessives and contractions cannot hide intervening prose", () => {
  assert.equal(plainText("The model's result differs from the person's result."), "The model's result differs from the person's result.");
  assert.equal(plainText("Don't remove the model's label."), "Don't remove the model's label.");
  assert.match(inspectText(`The model's ${"word ".repeat(26)} person's result.`)[0], /limit 25/);
});

test("quoted terminal punctuation preserves genuine sentence boundaries", () => {
  const text = 'The text ends with "a quotation." The next sentence starts here.';
  assert.equal(plainText(text), "The text ends with QUOTATION. The next sentence starts here.");
  assert.deepEqual(inspectText(text), []);
  assert.deepEqual(inspectText(`${"word ".repeat(14)}"done." The ${"word ".repeat(14)}.`), []);
  assert.match(inspectText('The text ends with "a quotation." '.repeat(7))[0], /limit 6/);
  assert.equal(plainText("The text ends with 'a quotation.' The next sentence starts here."), "The text ends with QUOTATION. The next sentence starts here.");
  assert.equal(plainText("The text ends with \u201Ca quotation.\u201D The next sentence starts here."), "The text ends with QUOTATION. The next sentence starts here.");
});

test("embedded quoted questions cannot hide long surrounding prose", () => {
  const text = `${"word ".repeat(14)}"Done?" and ${"word ".repeat(13)}.`;
  assert.match(inspectText(text)[0], /limit 25/);
  assert.match(inspectText(`The result is "done." The ${"word ".repeat(26)}.`)[0], /limit 25/);
});

test("ordinary link wording is retained and citation titles are explicit units", () => {
  assert.equal(plainText("Read [the named guide](guide.qmd)."), "Read the named guide.");
  assert.equal(plainText("Read [the named guide](guide.qmd).", true), "Read TITLE .");
  assert.equal(plainText('The label is "many words in a label".'), "The label is QUOTATION .");
  assert.equal(plainText("Use `str_count(x, ';')`."), "Use CODE .");
  assert.deepEqual(inspectText("Use the finite-population correction."), []);
  assert.match(inspectText(`Read [${"word ".repeat(26)}](guide.qmd).`)[0], /limit 20/);
});

test("lowercase package names start separate sentences", () => {
  const text = "The lesson reads that file. It does not write examples while the page renders. readr opens the saved file.";
  assert.deepEqual(inspectText(text), []);
  assert.match(inspectText("readr opens a file. ".repeat(7))[0], /limit 6/);
  assert.deepEqual(inspectText("Use e.g. a local file. readr opens it."), []);
});

test("continued initialisms do not create extra sentences", () => {
  const paragraph = "A U.S. map shows the states. " + "A result. ".repeat(5);
  assert.deepEqual(inspectText(paragraph), []);
  assert.match(inspectText(paragraph + "One more sentence.")[0], /limit 6/);
  assert.match(inspectText("The map covers the U.S. " + "A result. ".repeat(6))[0], /limit 6/);
});

test("only source-section citation labels receive title treatment", () => {
  const source = `Read [${"word ".repeat(26)}](guide.qmd).\n\n## Sources\n\n- [${"word ".repeat(26)}](https://example.test/) describes the method.\n\n## Next\n\nRead [${"word ".repeat(26)}](guide.qmd).`;
  const blocks = sourceBlocks(source).blocks;
  assert.equal(blocks.filter((block) => block.kind === "citation").length, 1);
  assert.equal(blocks.flatMap((block) => inspectText(block.text, block.kind)).length, 2);
});

test("front matter and prose are scanned but fences remain explicitly excluded", () => {
  const source = ["---", 'title: "A lesson"', 'description: "Read the results."', "---", "", "## Heading", "", "A paragraph.", "", "```{r}", 'cat("Do not edit raw output;")', "```", "", "A second paragraph."].join("\n");
  const result = sourceBlocks(source);
  assert.equal(result.excludedFences, 1);
  assert.equal(result.blocks.length, 5);
  assert.equal(result.blocks.at(-1).line, 14);
  assert.ok(result.blocks.every((block) => !block.text.includes("cat(")));
});

test("lists form separate blocks and longer fences close correctly", () => {
  const result = sourceBlocks("- Read a result.\n  Record its value.\n- Read another.\n\n````text\n```\nraw output\n````\n");
  assert.equal(result.blocks.length, 2);
  assert.equal(result.blocks[0].text, "Read a result.   Record its value.");
  assert.equal(result.excludedFences, 1);
  assert.throws(() => sourceBlocks("```{r}\nx <- 1"), /Unclosed/);
});

test("wrapped numeric sentence endings are not removed as list markers", () => {
  const prose = sourceBlocks("Rows were scaled to length\n1. The next sentence starts here.").blocks;
  assert.equal(prose.length, 1);
  assert.equal(prose[0].text, "Rows were scaled to length 1. The next sentence starts here.");
  assert.deepEqual(inspectText(prose[0].text), []);
  const list = sourceBlocks("Steps:\n\n1. Read the file.\n2. Save the result.").blocks;
  assert.deepEqual(list.map((block) => block.text), ["Steps:", "Read the file.", "Save the result."]);
});

test("inline R defers only uncertain source length and paragraph verdicts", () => {
  const dynamic = inspectSourceBlock({ text: `The result is \`r result\`. ${"word ".repeat(26)}.` });
  assert.equal(dynamic.requiresRenderedCheck, true);
  assert.deepEqual(dynamic.findings, []);
  assert.match(inspectSourceBlock({ text: "The result is `r result`; examine it." }).findings[0], /semicolon/);
  assert.match(inspectSourceBlock({ text: `${"word ".repeat(26)}.` }).findings[0], /limit 25/);
  assert.equal(inspectSourceBlock({ text: "Use `nrow(data)`." }).requiresRenderedCheck, false);
  assert.match(inspectText(`The result is known. ${"word ".repeat(26)}.`)[0], /limit 25/);
  assert.match(inspectText("An actual rendered sentence. ".repeat(7))[0], /limit 6/);
});

test("source coverage reports every deferred inline-R block", () => {
  const report = auditSource();
  assert.ok(report.deferred.length > 0);
  assert.equal(report.deferred.length, report.coverage.reduce((sum, page) => sum + page.deferredBlocks, 0));
  assert.ok(report.deferred.every((block) => block.path.endsWith(".qmd") && block.line > 0 && block.reason.includes("rendered")));
});

test("public-page discovery follows the render manifest", () => {
  const pages = publicPages();
  assert.equal(pages.length, 86);
  assert.ok(pages.includes("index.qmd"));
  assert.ok(pages.includes("accessibility.qmd"));
  assert.ok(pages.includes("advanced/evaluating-systems.qmd"));
  assert.ok(pages.includes("15_information_visualization/81-knowledge-graph-visualization.qmd"));
  assert.equal(new Set(pages).size, pages.length);
});
