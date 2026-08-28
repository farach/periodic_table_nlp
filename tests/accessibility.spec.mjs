import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";

const pages = [
  "/",
  "/accessibility.html",
  "/1_source_data_loading/01-bits-to-character-encoding.html",
  "/1_source_data_loading/02-manual-typewriting.html",
  "/1_source_data_loading/03-loading-structured-datafile.html",
  "/1_source_data_loading/04-generating-a-corpus.html",
  "/1_source_data_loading/05-loading-from-api.html",
  "/1_source_data_loading/06-text-and-file-scraping.html",
  "/1_source_data_loading/07-text-extraction-and-ocr.html",
  "/2_training_data_generation/08-manual-annotation.html",
  "/2_training_data_generation/09-annotation-with-active-learning.html",
  "/2_training_data_generation/10-training-data-providers.html",
  "/2_training_data_generation/11-crowdsourcing-annotation.html",
  "/2_training_data_generation/12-textual-data-augmentation.html",
  "/2_training_data_generation/13-rule-based-training-data.html"
];

for (const path of pages) {
  test(`WCAG 2.2 AA automated scan: ${path}`, async ({ page }) => {
    await page.goto(path);

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
    await page.goto(path);
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
    await page.goto(path);
    const tables = page.locator("main table");
    const tableCount = await tables.count();

    for (let index = 0; index < tableCount; index += 1) {
      const caption = tables.nth(index).locator("caption");
      await expect(
        caption,
        `${path} table ${index + 1} has no caption`
      ).toHaveCount(1);
      await expect(caption).not.toHaveText("");
    }
  }
});

test("periodic table supports keyboard navigation", async ({ page }) => {
  await page.goto("/");

  const availableTiles = page.locator(".nlp-element.is-available");
  const plannedTiles = page.locator(".nlp-element.is-planned");

  await expect(availableTiles).toHaveCount(13);
  await expect(plannedTiles).toHaveCount(68);
  await expect(plannedTiles.first()).not.toHaveAttribute("aria-disabled");
  await expect(plannedTiles.first()).not.toHaveAttribute("aria-label");

  const labels = await availableTiles.evaluateAll((tiles) =>
    tiles.map((tile) => tile.getAttribute("aria-label"))
  );
  expect(new Set(labels).size).toBe(13);

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

test("every available tile opens its lesson", async ({ page }) => {
  const lessons = [
    [1, "01-bits-to-character-encoding.html"],
    [2, "02-manual-typewriting.html"],
    [3, "03-loading-structured-datafile.html"],
    [4, "04-generating-a-corpus.html"],
    [5, "05-loading-from-api.html"],
    [6, "06-text-and-file-scraping.html"],
    [7, "07-text-extraction-and-ocr.html"],
    [8, "08-manual-annotation.html"],
    [9, "09-annotation-with-active-learning.html"],
    [10, "10-training-data-providers.html"],
    [11, "11-crowdsourcing-annotation.html"],
    [12, "12-textual-data-augmentation.html"],
    [13, "13-rule-based-training-data.html"]
  ];

  for (const [taskNumber, fileName] of lessons) {
    await page.goto("/");
    await page
      .locator(`[data-task-number="${taskNumber}"]`)
      .click();
    await expect(page).toHaveURL(new RegExp(`${fileName}$`));
  }
});

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

test("periodic table fits a wide desktop viewport", async ({ page }) => {
  await page.setViewportSize({ width: 1600, height: 1000 });
  await page.goto("/");

  const dimensions = await page
    .locator(".periodic-scroll")
    .evaluate((element) => ({
      content: element.scrollWidth,
      viewport: element.clientWidth
    }));

  expect(dimensions.content).toBeLessThanOrEqual(
    dimensions.viewport + 1
  );
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

  const available = page.locator(".nlp-element.is-available").first();
  const planned = page.locator(".nlp-element.is-planned").first();

  await expect(available.getByText("Read lesson")).toBeVisible();
  await expect(planned.locator(".element-status")).toHaveText("Planned");
  await expect(
    page.getByText("Lesson planned", { exact: true })
  ).toBeVisible();

  const styles = await page.evaluate(() => {
    const availableTile = document.querySelector(
      ".nlp-element.is-available"
    );
    const plannedTile = document.querySelector(
      ".nlp-element.is-planned"
    );
    const availableStyle = getComputedStyle(availableTile);
    const plannedStyle = getComputedStyle(plannedTile);

    return {
      availableBorder: availableStyle.borderTopStyle,
      plannedBorder: plannedStyle.borderTopStyle,
      transitionDuration: availableStyle.transitionDuration
    };
  });

  expect(styles.availableBorder).toBe("solid");
  expect(styles.plannedBorder).toBe("dashed");
  expect(Number.parseFloat(styles.transitionDuration)).toBeLessThanOrEqual(
    0.01
  );
});
