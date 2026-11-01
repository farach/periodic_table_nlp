import { readdirSync } from "node:fs";
import { join, posix } from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";
import { inspectText } from "../scripts/check-plain-language.mjs";

const siteDir = "_site";

// Collect the published pages from the built site so a new lesson is covered
// as soon as it renders, without anyone remembering to edit this list.
function lessonPages() {
  const found = [];

  for (const entry of readdirSync(siteDir, { withFileTypes: true })) {
    if (!entry.isDirectory() || !/^[0-9]+_/.test(entry.name)) {
      continue;
    }

    for (const file of readdirSync(join(siteDir, entry.name))) {
      if (file.endsWith(".html")) {
        found.push(posix.join("/", entry.name, file));
      }
    }
  }

  return found.sort();
}

const lessonPagePaths = lessonPages();
const pages = [
  "/",
  "/accessibility.html",
  "/using-language-models.html",
  "/advanced/index.html",
  "/advanced/evaluating-systems.html",
  ...lessonPagePaths
];
const totalTasks = 81;

test("Map and Beyond are available in desktop and mobile navigation", async ({ page }) => {
  for (const width of [1280, 375]) {
    await page.setViewportSize({ width, height: 900 });
    await page.goto("/");
    const header = page.locator("#quarto-header");
    if (width < 992) await header.getByRole("button", { name: "Toggle navigation" }).click();
    await header.getByRole("link", { name: "Beyond the periodic table", exact: true }).click();
    await expect(page.locator("h1")).toHaveText("Beyond the periodic table");
    if (width < 992) await header.getByRole("button", { name: "Toggle navigation" }).click();
    await header.getByRole("link", { name: "Map", exact: true }).click();
    await expect(page.locator("#nlp-task-map")).toBeVisible();
  }
});

test("six sidebar stages retain every lesson in task order", async ({ page }) => {
  await page.goto("/advanced/index.html");
  const stages = [
    ["1. Source and training data", 1, 13],
    ["2. Language structure", 14, 42],
    ["3. Models and analysis", 43, 62],
    ["4. Language generation", 63, 68],
    ["5. Language systems", 69, 74],
    ["6. Visualization", 75, 81]
  ];
  for (const [name, first, last] of stages) {
    const group = page.locator("#quarto-sidebar li.sidebar-item-section").filter({
      has: page.getByText(name, { exact: true })
    });
    await expect(group).toHaveCount(1);
    const numbers = await group.locator("a[href]").evaluateAll((links) => links
      .map((link) => link.getAttribute("href").match(/\/(\d{2})-[^/]+\.html$/)?.[1])
      .filter(Boolean).map(Number));
    expect(numbers).toEqual(Array.from({ length: last - first + 1 }, (_, index) => first + index));
    const lessonLinks = group.locator('a[href$=".html"]');
    if (!(await lessonLinks.first().isVisible())) {
      await group.getByText(name, { exact: true }).click();
    }
    await expect(lessonLinks.first()).toBeVisible();
    await expect(lessonLinks.last()).toBeVisible();
    const visibleNumbers = await lessonLinks.evaluateAll((links) => links.map((link) =>
      Number(link.innerText.trim().match(/^(\d+)\.\s+/)?.[1])));
    expect(visibleNumbers).toEqual(numbers);
  }
});

for (const path of pages) {
  test(`Rendered authored-prose limits: ${path}`, async ({ page }) => {
    const response = await page.goto(path);
    expect(response.status()).toBe(200);
    const parts = await page.locator("main p, main li, main figcaption, main caption, main h1, main h2, main h3, main h4, main h5, main h6").evaluateAll((elements) => elements.flatMap((element) => {
      if (element.closest("pre") || (element.closest("table") && element.tagName !== "CAPTION")) return [];
      const copy = element.cloneNode(true);
      for (const nested of copy.querySelectorAll("ul, ol, p, pre, table, .anchorjs-link")) nested.remove();
      for (const unit of copy.querySelectorAll("code, .math")) unit.replaceWith(" CODE ");
      if (element.closest("#sources")) {
        for (const title of copy.querySelectorAll("a")) title.replaceWith(" TITLE ");
      }
      return [{ kind: /^H[1-6]$/.test(element.tagName) ? "label" : "paragraph", text: copy.textContent.trim() }];
    }));
    for (const text of await page.locator("main img[alt]").evaluateAll((images) => images.map((image) => image.alt))) {
      parts.push({ kind: "paragraph", text });
    }
    const findings = parts.flatMap(({ text, kind }) => inspectText(text, kind).map((finding) => `${path}: ${finding}`));
    expect(findings, findings.join("\n")).toEqual([]);
  });
}

test("malformed byte comparison is visible with all three results", async ({ page }) => {
  await page.goto("/1_source_data_loading/01-bits-to-character-encoding.html");
  const table = page.locator("table").filter({
    has: page.locator("caption", { hasText: "One malformed byte sequence read three ways" })
  });
  await expect(table).toBeVisible();
  const rows = table.locator("tbody tr");
  await expect(rows).toHaveCount(4);
  await expect(rows.nth(1).locator("td").nth(1)).toHaveText("4");
  await expect(rows.nth(2).locator("td").nth(1)).toHaveText("NA");
  await expect(rows.nth(3).locator("td").nth(1)).toHaveText("Hi \uFFFD(");
});

test("geocoding service limits render as four list items", async ({ page }) => {
  await page.goto("/6_entity_enrichment/30-geocoding.html");
  await expect(page.locator("#geocoding-in-production ul > li")).toHaveCount(4);
});

test("whitespace comparison retains both rows and original line breaks", async ({ page }) => {
  await page.goto("/8_documents/40-raw-text-cleaning.html");
  const table = page.locator("table").filter({
    has: page.locator("caption", { hasText: "Whitespace squishing removes the flyer line layout" })
  });
  const rows = table.locator("tbody tr");
  await expect(rows).toHaveCount(2);
  const before = rows.nth(0).locator("td").nth(1);
  const after = rows.nth(1).locator("td").nth(1);
  expect((await before.textContent()).match(/\n/g)).toHaveLength(5);
  expect(await after.textContent()).not.toContain("\n");
  await expect(before).toHaveCSS("white-space", "pre-line");
});

const captionedTable = (page, caption) =>
  page.locator("table").filter({ has: page.locator("caption", { hasText: caption }) });

const columnCells = (table, column) => table.locator(`tbody tr td:nth-child(${column})`);

test("HTML-cleaning comparison keeps undecoded entity text", async ({ page }) => {
  await page.goto("/8_documents/40-raw-text-cleaning.html");
  const table = captionedTable(page, "Entity handling after two HTML-cleaning approaches");
  await expect(columnCells(table, 2)).toHaveText([
    "Training &amp; tools&nbsp;provided.",
    "Training & tools provided."
  ]);
});

test("whitespace-sensitive tables retain padding and top captions", async ({ page }) => {
  const tables = [
    ["/4_word_processing/21-normalization.html", "Lowercasing and spacing changes"],
    ["/7_sentences_and_paragraphs/35-sentence-segmentation.html", "Where each splitter puts the boundaries"],
    ["/8_documents/39-deduplication.html", "Six documents prepared for duplicate comparison"],
    ["/8_documents/39-deduplication.html", "Exact hashes before normalization"],
    ["/8_documents/40-raw-text-cleaning.html", "Whitespace squishing removes the flyer line layout"]
  ];
  for (const width of [1280, 375]) {
    await page.setViewportSize({ width, height: 900 });
    for (const [path, caption] of tables) {
      await page.goto(path);
      const table = captionedTable(page, caption);
      await expect(table.locator("caption")).toHaveCSS("caption-side", "top");
      const padding = await table.locator("tbody td").first().evaluate((cell) =>
        parseFloat(getComputedStyle(cell).paddingInlineStart));
      expect(padding, `${path}: cells need space between columns`).toBeGreaterThanOrEqual(4);
    }
  }
});

test("tokenizer tables show special tokens and decoded unknown text", async ({ page }) => {
  await page.goto("/3_word_parsing/14-tokenization.html");
  const vocabulary = captionedTable(page, "The first rows of the BPE vocabulary");
  await expect(columnCells(vocabulary, 2).first()).toHaveText("<PAD>");
  await expect(columnCells(vocabulary, 2).nth(1)).toHaveText("<UNK>");
  await expect(columnCells(vocabulary, 2).nth(2)).toHaveText("<BOS>");
  await expect(columnCells(vocabulary, 2).nth(3)).toHaveText("<EOS>");
  const decoded = columnCells(captionedTable(page, "Round-trip results for the four texts"), 4);
  await expect(decoded).toHaveCount(4);
  await expect(decoded).toHaveText(Array(4).fill(/\S/));
});

test("padded spacing example keeps its internal spaces", async ({ page }) => {
  await page.goto("/4_word_processing/21-normalization.html");
  const raw = captionedTable(page, "Lowercasing and spacing changes").locator("tbody tr").nth(1).locator("td").nth(1);
  expect(await raw.textContent()).toContain("No   prior   data");
  await expect(raw).toHaveCSS("white-space", "pre-wrap");
});

test("stored counts print as whole numbers", async ({ page }) => {
  await page.goto("/3_word_parsing/18-dependency-parsing.html");
  await expect(columnCells(captionedTable(page, "Held-out parser scores bundled with the lesson"), 2))
    .toHaveText(["4007", "2899", "0.7235", "2629", "0.6561"]);
  await page.goto("/9_model_development/47-monitoring-models.html");
  await expect(columnCells(captionedTable(page, "Model and corpus size for the monitoring replay"), 2))
    .toHaveText(["1377", "335", "0.8209"]);
});

test("sentence boundary table keeps one row for each piece", async ({ page }) => {
  await page.goto("/7_sentences_and_paragraphs/35-sentence-segmentation.html");
  const found = await columnCells(
    captionedTable(page, "Splitter counts compared with the five expected sentences"),
    2
  ).allTextContents();
  const pieceCount = found.reduce((total, value) => total + Number(value), 0);
  expect(pieceCount).toBeGreaterThan(0);
  const boundaries = captionedTable(page, "Where each splitter puts the boundaries");
  await expect(boundaries.locator("tbody tr")).toHaveCount(pieceCount);
  await expect(columnCells(boundaries, 4)).toHaveText(Array(pieceCount).fill(/^\s*(yes|no)\s*$/));
  const pieces = await columnCells(boundaries, 2).allTextContents();
  expect(pieces.some((piece) => piece.includes("\n"))).toBe(true);
  await expect(columnCells(boundaries, 2).first()).toHaveCSS("white-space", "pre-line");
});

test("duplicate tables keep the internal spaces of D03", async ({ page }) => {
  await page.goto("/8_documents/39-deduplication.html");
  for (const caption of ["Six documents prepared for duplicate comparison", "Exact hashes before normalization"]) {
    const table = captionedTable(page, caption);
    const row = table.locator("tbody tr").nth(2);
    await expect(row.locator("td").first()).toHaveText("D03");
    const textColumn = caption.startsWith("Six") ? 3 : 2;
    const text = row.locator(`td:nth-child(${textColumn})`);
    expect(await text.textContent()).toContain("THE employer   pays for certification   TRAINING.");
    await expect(text).toHaveCSS("white-space", "pre-wrap");
  }
});

test("generation tables show angle-bracket tokens and marker patterns", async ({ page }) => {
  await page.goto("/13_natural_language_generation/63-next-token-prediction.html");
  const tokens = columnCells(
    captionedTable(page, "Highest-probability next tokens from the selected trigram"),
    2
  );
  const tokenCount = await tokens.count();
  expect(tokenCount).toBeGreaterThan(0);
  await expect(tokens).toHaveText(Array(tokenCount).fill(/\S/));
  await expect(tokens.filter({ hasText: /^<unk>$/ }).first()).toBeVisible();
  await page.goto("/13_natural_language_generation/67-paraphrasing.html");
  const invariants = captionedTable(page, "Constructed paraphrase probes and predeclared invariants");
  await expect(invariants).toContainText("\\b(may|can|allowed|permitted)\\b");
  await expect(invariants).toContainText("\\b(must|required|obliged|has to)\\b");
});

test("timeline figure retains its caption and accessible description", async ({ page }) => {
  await page.goto("/15_information_visualization/79-events-on-a-timeline.html");
  const figure = page.locator("#fig-event-timeline");
  await expect(figure).toHaveCount(1);
  await expect(figure.locator("figcaption")).toContainText("Timeline of eight events");
  await expect(figure.locator("img")).toHaveAttribute("alt", /Hollow points and dashed bars show planned events/);
  await expect(figure.locator("img")).toHaveAttribute("alt", /start date is unknown/);
  await expect(page.locator("main")).not.toContainText("{#fig-event-timeline");
});

test("advanced lesson keeps its expected results and routes", async ({ page }) => {
  await page.goto("/");
  await page.locator("main a[href$='advanced/index.html']").first().click();
  await expect(page.locator("h1")).toHaveText("Beyond the periodic table");
  for (const name of ["LangChain", "LangGraph", "LangSmith", "vitals"]) {
    await expect(page.locator("main")).toContainText(name);
  }
  await page.locator("main a[href$='evaluating-systems.html']").first().click();
  await expect(page.locator("h1")).toHaveText("Compare two system versions in R");
  await expect(page.locator("main")).toContainText("Do not release B.");
  const scores = page.locator("table").filter({
    has: page.locator("caption", { hasText: "Task success improves" })
  });
  await expect(scores.locator("tbody tr")).toHaveCount(2);
  const cells = await scores.locator("tbody tr").evaluateAll((rows) =>
    rows.map((row) => [...row.querySelectorAll("td")].map((cell) => cell.textContent.trim()))
  );
  expect(cells).toEqual([
    ["A", "16", "10", "10", "0", "1", "0", "62.5"],
    ["B", "16", "12", "11", "1", "2", "1", "75.0"]
  ]);
  expect(await page.locator("main pre.sourceCode").allTextContents())
    .not.toEqual(expect.arrayContaining([expect.stringContaining("knitr::kable")]));
});

test("advanced score table scrolls with the keyboard on a small screen", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 800 });
  const response = await page.goto("/advanced/evaluating-systems.html");
  expect(response.status()).toBe(200);
  const output = page.locator(".cell-output-display").filter({
    has: page.locator("caption", { hasText: "Task success improves" })
  });
  await expect(output).toHaveAttribute("tabindex", "0");
  await expect(output).toHaveAttribute("role", "region");
  await output.focus();
  await output.press("ArrowRight");
  await expect.poll(() => output.evaluate((element) => element.scrollLeft))
    .toBeGreaterThan(0);
});

for (const path of ["/advanced/index.html", "/advanced/evaluating-systems.html"]) {
  test(`advanced mobile WCAG scan: ${path}`, async ({ page }) => {
    await page.setViewportSize({ width: 320, height: 800 });
    const response = await page.goto(path);
    expect(response.status()).toBe(200);
    const results = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag21aa", "wcag22aa"])
      .analyze();
    expect(results.violations, JSON.stringify(results.violations, null, 2))
      .toEqual([]);
  });
}

if (pages.length < 3) {
  throw new Error(
    `Expected rendered lessons under ${siteDir}. Run "quarto render" first.`
  );
}

for (const path of pages) {
  test(`WCAG 2.2 AA automated scan: ${path}`, async ({ page }) => {
    const response = await page.goto(path);
    expect(response.status(), `${path} did not load`).toBe(200);

    const results = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag21aa", "wcag22aa"])
      .analyze();

    expect(
      results.violations,
      JSON.stringify(results.violations, null, 2)
    ).toEqual([]);
  });
}

test("every page reflows to a 320-pixel viewport", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 800 });

  for (const path of pages) {
    const response = await page.goto(path);
    expect(response.status(), `${path} did not load`).toBe(200);
    const widths = await page.evaluate(() => ({
      document: document.documentElement.scrollWidth,
      viewport: document.documentElement.clientWidth
    }));

    expect(
      widths.document,
      `${path} widens the document at 320 pixels`
    ).toBeLessThanOrEqual(widths.viewport);
  }
});

test("every rendered table has a caption", async ({ page }) => {
  for (const path of pages) {
    const response = await page.goto(path);
    expect(response.status(), `${path} did not load`).toBe(200);
    const captions = await page.locator("main table").evaluateAll((tables) =>
      tables.map((table) =>
        [...table.querySelectorAll("caption")].map((caption) =>
          caption.textContent.trim()
        )
      )
    );

    for (const [index, texts] of captions.entries()) {
      const message = `${path} table ${index + 1} must have one nonempty caption`;
      expect(texts, message).toHaveLength(1);
      expect(texts[0], message).not.toBe("");
    }
  }
});

test("periodic table supports keyboard navigation", async ({ page }) => {
  await page.goto("/");

  const availableTiles = page.locator(".nlp-element.is-available");
  const plannedTiles = page.locator(".nlp-element.is-planned");
  const plannedCount = totalTasks - lessonPagePaths.length;

  await expect(availableTiles).toHaveCount(lessonPagePaths.length);
  await expect(plannedTiles).toHaveCount(plannedCount);

  if (plannedCount > 0) {
    await expect(plannedTiles.first()).not.toHaveAttribute("aria-disabled");
    await expect(plannedTiles.first()).not.toHaveAttribute("aria-label");
    await expect(
      plannedTiles.first().locator(".element-status")
    ).toBeVisible();
    await expect(
      plannedTiles.first().locator(".element-status")
    ).toHaveText("Planned");
  }

  const labels = await availableTiles.evaluateAll((tiles) =>
    tiles.map((tile) => tile.getAttribute("aria-label"))
  );
  expect(new Set(labels).size).toBe(lessonPagePaths.length);

  const firstTile = availableTiles.first();
  await firstTile.focus();
  await expect(firstTile).toBeFocused();

  const focusStyle = await firstTile.evaluate((element) => {
    const style = window.getComputedStyle(element);
    return {
      outlineStyle: style.outlineStyle,
      outlineWidth: style.outlineWidth
    };
  });
  expect(focusStyle.outlineStyle).not.toBe("none");
  expect(Number.parseFloat(focusStyle.outlineWidth)).toBeGreaterThanOrEqual(2);

  await firstTile.press("Enter");
  await expect(page).toHaveURL(
    /01-bits-to-character-encoding[.]html$/
  );
});

for (const path of lessonPagePaths) {
  const fileName = path.split("/").pop();
  const taskNumber = Number.parseInt(fileName, 10);

  if (!Number.isInteger(taskNumber)) {
    throw new Error(`Lesson file does not start with a task number: ${path}`);
  }

  test(`available tile opens its lesson: ${fileName}`, async ({ page }) => {
    await page.goto("/");
    await page
      .locator(`[data-task-number="${taskNumber}"]`)
      .click();
    await expect(page).toHaveURL(new RegExp(`${fileName}$`));
  });
}

test("periodic table scrolls without widening the page", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 800 });
  await page.goto("/");

  const measurements = await page.evaluate(() => {
    const scroller = document.querySelector(".periodic-scroll");
    return {
      documentWidth: document.documentElement.scrollWidth,
      viewportWidth: document.documentElement.clientWidth,
      scrollerWidth: scroller.scrollWidth,
      scrollerViewport: scroller.clientWidth
    };
  });

  expect(measurements.documentWidth).toBeLessThanOrEqual(
    measurements.viewportWidth
  );
  expect(measurements.scrollerWidth).toBeGreaterThan(
    measurements.scrollerViewport
  );

  const scroller = page.locator(".periodic-scroll");
  await scroller.focus();
  await scroller.press("ArrowRight");

  await expect
    .poll(() => scroller.evaluate((element) => element.scrollLeft))
    .toBeGreaterThan(0);
});

const measureMap = (page) =>
  page.evaluate(() => {
    const scroller = document.querySelector(".periodic-scroll");
    const tile = document.querySelector(".nlp-element");
    const rootSize = Number.parseFloat(
      getComputedStyle(document.documentElement).fontSize
    );

    return {
      documentWidth: document.documentElement.scrollWidth,
      viewportWidth: document.documentElement.clientWidth,
      scrollerWidth: scroller.scrollWidth,
      scrollerViewport: scroller.clientWidth,
      tileRem: tile.getBoundingClientRect().width / rootSize,
      nameSize: getComputedStyle(
        document.querySelector(".element-name")
      ).fontSize
    };
  });

// The site's content column is narrower than the fifteen full-size columns,
// so on a desktop the map keeps readable tiles and scrolls sideways instead
// of shrinking them to fit.
test("periodic table keeps full-size tiles on a desktop", async ({ page }) => {
  await page.setViewportSize({ width: 1600, height: 1000 });
  await page.goto("/");

  const map = await measureMap(page);

  expect(map.documentWidth).toBeLessThanOrEqual(map.viewportWidth);
  expect(map.tileRem).toBeGreaterThanOrEqual(7.5);
  expect(map.scrollerWidth).toBeGreaterThan(map.scrollerViewport);

  const later = page.getByRole("button", { name: "Later groups" });
  await expect(later).toBeVisible();
  await expect(later).toBeEnabled();
});

// A page that embeds the map in a column at least 118rem wide gets the whole
// map without scrolling. The width set here leaves room for the scroller's
// padding and scrollbar gutter, because the container query measures the
// content box.
test("periodic table fits a container wide enough for it", async ({ page }) => {
  await page.setViewportSize({ width: 2400, height: 1000 });
  await page.goto("/");

  const scrolling = await measureMap(page);

  await page.addStyleTag({
    content: ".periodic-scroll { width: 124rem; max-width: none; }"
  });
  await page.evaluate(() => window.dispatchEvent(new Event("resize")));

  const fitted = await measureMap(page);

  expect(fitted.scrollerWidth).toBeLessThanOrEqual(
    fitted.scrollerViewport + 1
  );
  expect(fitted.tileRem).toBeGreaterThanOrEqual(7.5);
  expect(fitted.nameSize).toBe(scrolling.nameSize);
  await expect(page.locator(".task-map-scroll-controls")).toBeHidden();
});

test("map controls scroll narrow viewports", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 800 });
  await page.goto("/");

  const earlier = page.getByRole("button", {
    name: "Earlier groups"
  });
  const later = page.getByRole("button", {
    name: "Later groups"
  });
  const scroller = page.locator("#nlp-task-map");

  await expect(earlier).toBeDisabled();
  await expect(later).toBeEnabled();
  await later.click();

  await expect
    .poll(() => scroller.evaluate((element) => element.scrollLeft))
    .toBeGreaterThan(0);
  await expect(earlier).toBeEnabled();
});

test("navigation controls keep native button semantics", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");

  const menuButton = page.locator(".navbar-toggler");
  await expect(menuButton).not.toHaveAttribute("role");
  await expect(menuButton).toHaveAttribute("type", "button");

  await menuButton.focus();
  const focusStyle = await menuButton.evaluate((element) => {
    const style = window.getComputedStyle(element);
    return {
      outlineStyle: style.outlineStyle,
      outlineWidth: style.outlineWidth
    };
  });
  expect(focusStyle.outlineStyle).not.toBe("none");
  expect(Number.parseFloat(focusStyle.outlineWidth)).toBeGreaterThanOrEqual(2);
});

test("search returns focus to its trigger", async ({ page }) => {
  await page.goto("/");

  const searchButton = page.locator("#quarto-search button");
  await searchButton.click();
  await page.keyboard.press("Escape");

  await expect(searchButton).toBeFocused();
});

test("the skip link reaches the main content", async ({ page }) => {
  await page.goto("/");
  await page.keyboard.press("Tab");

  const skipLink = page.locator(".skip-link");
  await expect(skipLink).toBeFocused();
  await skipLink.press("Enter");
  await expect(page.locator("#quarto-document-content")).toBeFocused();
});

test("tile status survives forced colors and reduced motion", async ({
  page
}) => {
  await page.emulateMedia({
    forcedColors: "active",
    reducedMotion: "reduce"
  });
  await page.goto("/");

  const plannedCount = totalTasks - lessonPagePaths.length;
  const available = page.locator(".nlp-element.is-available").first();
  const planned = page.locator(".nlp-element.is-planned").first();

  await expect(available.getByText("Read lesson")).toBeVisible();

  if (plannedCount > 0) {
    await expect(planned.locator(".element-status")).toHaveText("Planned");
    await expect(
      page.getByText("Lesson planned", { exact: true })
    ).toBeVisible();
  } else {
    // A finished map has nothing planned, so it must not offer a key or
    // instructions for a tile state that no longer appears.
    await expect(
      page.getByText("Lesson planned", { exact: true })
    ).toHaveCount(0);
    await expect(page.locator("#task-map-instructions")).not.toContainText(
      "Dashed tiles"
    );
  }

  const styles = await page.evaluate(() => {
    const availableTile = document.querySelector(
      ".nlp-element.is-available"
    );
    const plannedTile = document.querySelector(
      ".nlp-element.is-planned"
    );
    const availableStyle = getComputedStyle(availableTile);

    return {
      availableBorder: availableStyle.borderTopStyle,
      plannedBorder: plannedTile
        ? getComputedStyle(plannedTile).borderTopStyle
        : null,
      transitionDuration: availableStyle.transitionDuration
    };
  });

  expect(styles.availableBorder).toBe("solid");
  if (plannedCount > 0) {
    expect(styles.plannedBorder).toBe("dashed");
  } else {
    expect(styles.plannedBorder).toBeNull();
  }
  expect(Number.parseFloat(styles.transitionDuration)).toBeLessThanOrEqual(
    0.01
  );
});

test("accessibility page records pending manual review", async ({ page }) => {
  await page.goto("/accessibility.html");
  const status = page.locator("#checks-that-still-need-people p").first();
  await expect(status).toBeVisible();
  await expect(status).toContainText(/Manual tests with current NVDA, JAWS, VoiceOver/);
  await expect(status).toContainText("pending");
});
