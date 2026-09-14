const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1400, height: 1300 } });
  await page.goto('http://localhost:3000/cashflow-sankey.html', { waitUntil: 'networkidle' });
  await page.screenshot({ path: '/tmp/sankey-standalone.png', fullPage: true });
  await browser.close();
})();
