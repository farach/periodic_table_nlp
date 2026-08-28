import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";

const pages = [
  "/",
  "/accessibility.html",
  "/1_source_data_loading/01-bits-to-character-encoding.html",
  "/1_source_data_loading/02-manual-typewriting.html",
  "/1_source_data_loading/03-loading-structured-datafile.html",
  "/1_source_data_loading/04-generating-a-corpus.html",
  "/1_source_data_loading/05-loading-from-api.html"
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

test("periodic table supports keyboard navigation", async ({ page }) => {
  await page.goto("/");

  const availableTiles = page.locator(".nlp-element.is-available");
  const plannedTiles = page.locator(".nlp-element.is-planned");

  await expect(availableTiles).toHaveCount(5);
  await expect(plannedTiles).toHaveCount(76);
  await expect(plannedTiles.first()).not.toHaveAttribute("aria-disabled");
  await expect(plannedTiles.first()).not.toHaveAttribute("aria-label");

  const labels = await availableTiles.evaluateAll((tiles) =>
    tiles.map((tile) => tile.getAttribute("aria-label"))
  );
  expect(new Set(labels).size).toBe(5);

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
    [5, "05-loading-from-api.html"]
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
  await expect(planned.getByText("Planned")).toBeVisible();

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
