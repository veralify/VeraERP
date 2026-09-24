// Run: node --experimental-strip-types --test src/lib/money/spending.test.mjs
// (Node 22+; no test framework dependency — node:test and node:assert only.)
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { receiptView, sortImagePaths } from './receipts.ts';
import {
  budgetProgress,
  categoryAliases,
  categoryLabel,
  categoryOptions,
  csvCell,
  monthBounds,
  monthLabel,
  monthlyTrend,
  monthsEnding,
  niceTicks,
  normalizeCategoryKey,
  parseMonth,
  parseTransactionFilters,
  percentChange,
  resolveAmount,
  shiftMonth,
  summarize,
  toCsv,
} from './spending.ts';

const tx = (overrides) => ({
  transaction_date: '2026-09-10',
  amount: 10,
  direction: 'expense',
  category: 'groceries',
  currency: 'EUR',
  home_amount: null,
  ...overrides,
});

test('months shift across year boundaries and bound a month', () => {
  assert.equal(shiftMonth('2026-01', -1), '2025-12');
  assert.equal(shiftMonth('2026-12', 1), '2027-01');
  assert.equal(shiftMonth('2026-03', -14), '2025-01');
  assert.deepEqual(monthBounds('2026-12'), { start: '2026-12-01', end: '2027-01-01' });
  assert.deepEqual(monthsEnding('2026-02', 3), ['2025-12', '2026-01', '2026-02']);
  assert.equal(parseMonth('2026-13', '2026-09'), '2026-09');
  assert.equal(parseMonth('2026-02', '2026-09'), '2026-02');
  assert.equal(monthLabel('2026-09'), 'September 2026');
  assert.equal(monthLabel('2026-09', 'short'), 'Sep');
});

test('categories: keys pass, legacy names map, unknown text is kept', () => {
  assert.equal(normalizeCategoryKey('eating_out'), 'eating_out');
  assert.equal(normalizeCategoryKey('Food'), 'groceries');
  assert.equal(normalizeCategoryKey('Uncategorized'), 'other');
  assert.equal(normalizeCategoryKey(''), 'other');
  assert.equal(normalizeCategoryKey('Coffee beans'), 'Coffee beans');
  assert.equal(categoryLabel('gifts_donations'), 'Gifts & donations');
  assert.equal(categoryLabel('pet_care'), 'Pet care');
  assert.equal(categoryLabel('pet_care', { pet_care: 'Dog stuff' }), 'Dog stuff');
  assert.deepEqual(categoryAliases('groceries').sort(), ['Food', 'food', 'groceries']);
  const options = categoryOptions({ pet_care: 'Dog stuff', groceries: 'Ignored' });
  assert.equal(options.length, 19);
  assert.deepEqual(options.at(-1), { key: 'pet_care', label: 'Dog stuff' });
});

test('amounts prefer home_amount, else stay in their own currency', () => {
  assert.deepEqual(resolveAmount(tx({ currency: 'USD', home_amount: 9.2 }), 'EUR'), {
    currency: 'EUR',
    value: 9.2,
    inHome: true,
  });
  assert.deepEqual(resolveAmount(tx({ currency: 'USD' }), 'EUR'), {
    currency: 'USD',
    value: 10,
    inHome: false,
  });
});

test('summarize keeps unconverted currencies out of home totals', () => {
  const summary = summarize(
    [
      tx({ amount: 0.1 }),
      tx({ amount: 0.2 }),
      tx({ amount: 5, category: 'Food' }),
      tx({ amount: 30, category: 'transport' }),
      tx({ amount: 1000, direction: 'income', category: 'other' }),
      tx({ amount: 20, currency: 'USD' }),
      tx({ amount: 50, currency: 'GBP', home_amount: 58.5, category: 'travel' }),
    ],
    'EUR',
  );
  assert.equal(summary.spending, 93.8);
  assert.equal(summary.income, 1000);
  assert.equal(summary.net, 906.2);
  assert.deepEqual(
    summary.byCategory.map((c) => [c.key, c.total, c.count]),
    [
      ['travel', 58.5, 1],
      ['transport', 30, 1],
      ['groceries', 5.3, 3],
    ],
  );
  assert.deepEqual(summary.unconverted, [{ currency: 'USD', income: 0, spending: 20 }]);
});

test('trend covers every month, empty ones as zero', () => {
  const trend = monthlyTrend(
    [
      tx({ transaction_date: '2026-09-01', amount: 40 }),
      tx({ transaction_date: '2026-07-31', amount: 15, direction: 'income' }),
      tx({ transaction_date: '2025-01-01', amount: 999 }),
    ],
    'EUR',
    '2026-09',
    3,
  );
  assert.deepEqual(trend, [
    { month: '2026-07', income: 15, spending: 0, net: 15 },
    { month: '2026-08', income: 0, spending: 0, net: 0 },
    { month: '2026-09', income: 0, spending: 40, net: -40 },
  ]);
});

test('budget progress matches category and currency, flags near and over', () => {
  const progress = budgetProgress(
    [
      { id: 'a', category_key: 'groceries', monthly_limit: 100, currency: 'EUR' },
      { id: 'b', category_key: 'transport', monthly_limit: '50', currency: 'EUR' },
      { id: 'c', category_key: 'travel', monthly_limit: 200, currency: 'USD' },
      { id: 'd', category_key: 'health', monthly_limit: 10, currency: 'EUR' },
    ],
    [
      tx({ amount: 85, category: 'Food' }),
      tx({ amount: 60, category: 'transport' }),
      tx({ amount: 20, category: 'transport', direction: 'income' }),
      tx({ amount: 40, currency: 'USD', category: 'travel' }),
      tx({ amount: 99, currency: 'USD', home_amount: 90, category: 'travel' }),
    ],
    'EUR',
  );
  const byId = Object.fromEntries(progress.map((p) => [p.id, p]));
  assert.equal(byId.a.state, 'near');
  assert.equal(byId.a.spent, 85);
  assert.equal(byId.b.state, 'over');
  assert.equal(byId.b.remaining, -10);
  assert.equal(byId.c.spent, 40);
  assert.equal(byId.c.state, 'ok');
  assert.equal(byId.d.spent, 0);
  assert.deepEqual(
    progress.map((p) => p.id),
    ['b', 'a', 'c', 'd'],
  );
});

test('axis ticks are round numbers covering the maximum', () => {
  assert.deepEqual(niceTicks(2950), [0, 1000, 2000, 3000]);
  assert.deepEqual(niceTicks(1000), [0, 250, 500, 750, 1000]);
  assert.deepEqual(niceTicks(0), [0, 1]);
  assert.deepEqual(niceTicks(7.3), [0, 2, 4, 6, 8]);
});

test('percent change has no base at zero', () => {
  assert.equal(percentChange(150, 100), 50);
  assert.equal(percentChange(50, -100), 150);
  assert.equal(percentChange(10, 0), null);
});

test('filters accept only known values', () => {
  assert.deepEqual(
    parseTransactionFilters({
      month: '2026-09',
      category: ['groceries', 'x'],
      scope: 'business',
      direction: 'sideways',
    }),
    { month: '2026-09', category: 'groceries', scope: 'business', direction: null },
  );
});

test('csv escapes quotes and defuses spreadsheet formulas', () => {
  assert.equal(csvCell('Marks & Spencer'), 'Marks & Spencer');
  assert.equal(csvCell('Say "hi", ok'), '"Say ""hi"", ok"');
  assert.equal(csvCell('=HYPERLINK("x")'), '"\'=HYPERLINK(""x"")"');
  assert.equal(csvCell('-5'), "'-5");
  assert.equal(csvCell(-5), '-5');
  assert.equal(csvCell(null), '');
  assert.equal(
    toCsv([
      ['a', 1],
      ['b\nc', null],
    ]),
    'a,1\r\n"b\nc",\r\n',
  );
});

test('receipt view prefers the confirmed transaction, then the extraction', () => {
  const receipt = {
    id: 'r1',
    status: 'extracted',
    extraction: {
      merchant: { name: { value: 'ESSELUNGA S.p.A.', confidence: 0.9 } },
      category: { key: 'groceries', confidence: 0.9, source: 'model' },
      scope_suggestion: 'business',
    },
    merchant_key: 'esselunga',
    receipt_date: null,
    total: '12.50',
    currency: 'EUR',
    created_at: '2026-09-20T10:00:00Z',
    transaction_id: null,
  };
  assert.deepEqual(receiptView(receipt, null), {
    merchant: 'ESSELUNGA S.p.A.',
    date: '2026-09-20',
    dateIsUpload: true,
    total: 12.5,
    currency: 'EUR',
    category: 'groceries',
    scope: 'business',
  });
  const linked = receiptView(
    { ...receipt, extraction: 'not an object', receipt_date: '2026-09-19' },
    {
      id: 't1',
      merchant: 'Esselunga',
      amount: 12.5,
      currency: 'EUR',
      category: 'eating_out',
      scope: 'personal',
      transaction_date: '2026-09-19',
    },
  );
  assert.equal(linked.merchant, 'Esselunga');
  assert.equal(linked.category, 'eating_out');
  assert.equal(linked.scope, 'personal');
  assert.equal(linked.dateIsUpload, false);
  assert.deepEqual(sortImagePaths(['u/r/10.jpg', 'u/r/2.jpg', 'u/r/1.jpg']), [
    'u/r/1.jpg',
    'u/r/2.jpg',
    'u/r/10.jpg',
  ]);
});
