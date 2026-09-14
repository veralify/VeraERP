const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1400, height: 1300 } });
  await page.goto('http://localhost:3000/cashflow-sankey.html', { waitUntil: 'networkidle' });
  const svg = await page.$eval('#sankeySvg, svg', el => el.outerHTML);
  require('fs').writeFileSync('/tmp/svg.html', svg);
  await browser.close();
})();
