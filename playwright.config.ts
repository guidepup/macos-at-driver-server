import { devices } from "@playwright/test";
import { withGuidepup } from "@guidepup/playwright";

export default withGuidepup({
  testDir: "./test/voiceover",
  timeout: 5 * 60 * 1000,
  retries: 0,
  reporter: [["html", { open: "never" }], ["line"]],
  projects: [
    {
      name: "webkit",
      use: { ...devices["Desktop Safari"] },
    },
  ],
});
