import { expect } from "@playwright/test";
import { voiceOverTest as test } from "@guidepup/playwright";

test.describe("VoiceOver speech extension", () => {
  test("announces the Hello Guidepup heading", async ({ page, voiceOver }) => {
    await page.goto("about:blank", { waitUntil: "load" });
    await page.setContent(`
      <!doctype html>
      <html lang="en">
        <head>
          <meta charset="utf-8" />
          <title>Hello Guidepup</title>
        </head>
        <body>
          <main>
            <h1>Hello Guidepup</h1>
          </main>
        </body>
      </html>
    `);

    await expect(
      page.getByRole("heading", { name: "Hello Guidepup" }),
    ).toBeVisible();

    await voiceOver.navigateToWebContent();
    await voiceOver.navigateNextHeadingUntil(/Hello Guidepup/);

    const spokenPhraseLog = await voiceOver.spokenPhraseLog();

    console.log(spokenPhraseLog);

    expect(spokenPhraseLog.join("\n")).toContain("Hello Guidepup");
  });
});
