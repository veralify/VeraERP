const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1400, height: 900 } });
  await page.goto('http://localhost:3000/', { waitUntil: 'networkidle' });
  const pages = ['income','transactions','debts','plan'];
  for (const p of pages) {
    await page.click(`button[data-page="${p}"]`);
    await page.waitForTimeout(700);
    await page.screenshot({ path: `/tmp/w-${p}.png`, fullPage: true });
  }
  await browser.close();
})();
