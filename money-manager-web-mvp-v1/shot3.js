const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1400, height: 900 } });
  await page.goto('http://localhost:3000/', { waitUntil: 'networkidle' });
  const pages = ['income','expenses','transactions','subscriptions','debts','savings','plan','admin-tasks','documents'];
  for (const p of pages) {
    await page.click(`button[data-page="${p}"]`);
    await page.waitForTimeout(400);
    await page.screenshot({ path: `/tmp/page-${p}.png`, fullPage: true });
  }
  await browser.close();
})();
