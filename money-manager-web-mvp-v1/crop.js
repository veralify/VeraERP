const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1400, height: 1300 } });
  await page.goto('http://localhost:3000/cashflow-sankey.html', { waitUntil: 'networkidle' });
  await page.screenshot({ path: '/tmp/crop1.png', clip: { x: 650, y: 180, width: 300, height: 120 } });
  await browser.close();
})();
