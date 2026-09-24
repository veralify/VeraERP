import { fetchAllTransactions, getCustomCategoryNames, getHomeCurrency } from '@lib/money/queries';
import {
  categoryLabel,
  monthBounds,
  normalizeCategoryKey,
  parseTransactionFilters,
  toCsv,
} from '@lib/money/spending';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { type NextRequest, NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';

const HEADER = [
  'date',
  'merchant',
  'type',
  'category_key',
  'category',
  'amount',
  'currency',
  'home_amount',
  'home_currency',
  'tax_amount',
  'scope',
  'account',
  'source',
  'notes',
  'receipt_id',
  'id',
];

/**
 * CSV of the signed-in user's transactions, with the same filters as the
 * transactions page (`month`, `category`, `scope`, `direction`). Owner-scoped
 * twice: the query filters on the session's user id, and RLS enforces it.
 * The route sits outside the dashboard layout's auth redirect, so it checks
 * the session itself.
 */
export async function GET(request: NextRequest) {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    return NextResponse.json({ error: 'UNAUTHENTICATED' }, { status: 401 });
  }

  const filters = parseTransactionFilters(Object.fromEntries(request.nextUrl.searchParams));
  const range = filters.month ? monthBounds(filters.month) : null;
  const [result, home, customNames] = await Promise.all([
    fetchAllTransactions(supabase, user.id, { from: range?.start, to: range?.end }, filters),
    getHomeCurrency(supabase, user.id),
    getCustomCategoryNames(supabase, user.id),
  ]);
  // A partial file that looks complete is worse than none: fail loudly.
  if (result.error || result.truncated) {
    return NextResponse.json(
      {
        error: result.error ? 'EXPORT_FAILED' : 'EXPORT_TOO_LARGE',
        message: result.error
          ? 'Could not read your transactions. Try again.'
          : 'Too many transactions for one file. Export one month at a time.',
      },
      { status: result.error ? 500 : 413 },
    );
  }

  const rows = result.rows.map((row) => {
    const key = normalizeCategoryKey(row.category);
    return [
      row.transaction_date,
      row.merchant,
      row.direction,
      key,
      categoryLabel(key, customNames),
      Number(row.amount),
      row.currency,
      row.home_amount === null ? null : Number(row.home_amount),
      row.home_amount === null ? null : home,
      row.tax_amount === null ? null : Number(row.tax_amount),
      row.scope,
      row.account,
      row.source,
      row.notes,
      row.receipt_id,
      row.id,
    ];
  });

  const name = [
    'veralify-transactions',
    filters.month,
    filters.category,
    filters.scope,
    filters.direction,
  ]
    .filter((part) => part)
    .join('-')
    .replace(/[^A-Za-z0-9_-]/g, '_');

  // The BOM makes Excel read the file as UTF-8 (accented merchant names, €).
  return new NextResponse(`﻿${toCsv([HEADER, ...rows])}`, {
    headers: {
      'Content-Type': 'text/csv; charset=utf-8',
      'Content-Disposition': `attachment; filename="${name}.csv"`,
      'Cache-Control': 'private, no-store',
      'X-Content-Type-Options': 'nosniff',
    },
  });
}
