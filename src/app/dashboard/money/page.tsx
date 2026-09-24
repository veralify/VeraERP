import { Banner } from '@components/generic/Banner';
import { Reveal, StaggerGroup, StaggerItem } from '@components/generic/Motion';
import { Card, PageHeader } from '@components/member/DashboardPrimitives';
import { EmptyState } from '@components/member/EmptyState';
import { BudgetMeter } from '@components/money/BudgetMeter';
import { CategoryBars } from '@components/money/CategoryBars';
import { MonthPicker } from '@components/money/MonthPicker';
import { ReceiptStatusBadge } from '@components/money/ReceiptStatusBadge';
import { StatTile } from '@components/money/StatTile';
import { TrendChart } from '@components/money/TrendChart';
import { getDebtPlanInput, getMoneySnapshot } from '@lib/money/data';
import { computeDebtPlan } from '@lib/money/debtPlan';
import { formatCurrency, formatCurrencyCompact, formatMoney } from '@lib/money/format';
import {
  fetchAllTransactions,
  getBudgets,
  getCustomCategoryNames,
  getHomeCurrency,
  getLinkedTransactions,
  RECEIPT_COLUMNS,
} from '@lib/money/queries';
import { receiptView } from '@lib/money/receipts';
import {
  budgetProgress,
  categoryLabel,
  currentMonth,
  monthBounds,
  monthLabel,
  monthlyTrend,
  monthOf,
  niceTicks,
  parseMonth,
  percentChange,
  shiftMonth,
  summarize,
} from '@lib/money/spending';
import { computeUpcomingEvents } from '@lib/money/upcoming';
import { fadeUp } from '@lib/motion/variants';
import { createSupabaseServerClient } from '@lib/supabase/server';
import {
  ArrowLeftRight,
  CalendarClock,
  ClipboardList,
  CreditCard,
  Download,
  FileText,
  PiggyBank,
  Receipt,
  ReceiptText,
  Repeat,
  Scale,
  Target,
  TrendingDown,
  TrendingUp,
  Wallet,
} from 'lucide-react';
import type { Metadata } from 'next';

export const metadata: Metadata = { title: 'Money' };

type SearchParams = Promise<{ month?: string }>;

const EVENT_LABEL: Record<string, string> = {
  expense: 'Expense',
  debt: 'Debt minimum',
  'subscription-renewal': 'Subscription renews',
  'subscription-trial': 'Trial ends',
  task: 'Task due',
};

export default async function MoneyOverviewPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const thisMonth = currentMonth();
  // Future months have nothing to show yet, so the selector stops at today.
  const requested = parseMonth(params.month, thisMonth);
  const month = requested > thisMonth ? thisMonth : requested;
  const previousMonth = shiftMonth(month, -1);
  const monthName = monthLabel(month);
  const previousName = monthLabel(previousMonth);
  const trendStart = shiftMonth(month, -11);

  const [snapshot, home, customNames, budgets, transactions, { data: receiptRows }] =
    await Promise.all([
      getMoneySnapshot(supabase, user.id),
      getHomeCurrency(supabase, user.id),
      getCustomCategoryNames(supabase, user.id),
      getBudgets(supabase, user.id),
      // One read covers the 12-month trend, this month and last month.
      fetchAllTransactions(supabase, user.id, {
        from: monthBounds(trendStart).start,
        to: monthBounds(month).end,
      }),
      supabase
        .from('money_receipts')
        .select(RECEIPT_COLUMNS)
        .eq('user_id', user.id)
        .is('deleted_at', null)
        .order('created_at', { ascending: false })
        .limit(5),
    ]);

  const monthRows = transactions.rows.filter((row) => monthOf(row.transaction_date) === month);
  const previousRows = transactions.rows.filter(
    (row) => monthOf(row.transaction_date) === previousMonth,
  );
  const summary = summarize(monthRows, home);
  const previous = summarize(previousRows, home);
  const trend = monthlyTrend(transactions.rows, home, month, 12);
  const progress = budgetProgress(budgets, monthRows, home);
  const previousByCategory = new Map(previous.byCategory.map((c) => [c.key, c.total]));

  const receipts = receiptRows ?? [];
  const linked = await getLinkedTransactions(supabase, user.id, receipts);

  const money = (value: number) => formatCurrency(value, home);
  const homeBudgets = progress.filter((p) => p.currency === home);
  const budgetLeft = homeBudgets.reduce((s, p) => s + Math.max(0, p.remaining), 0);
  const budgetTotal = homeBudgets.reduce((s, p) => s + p.limit, 0);

  // ---- the recurring plan (unchanged from the original overview) ----
  const {
    activeIncome,
    activeExpenses,
    activeSavings,
    debts,
    monthlyIncome,
    monthlyExpenses,
    totalDebt,
    netCashFlow,
  } = snapshot;

  const [{ data: subscriptionRows }, { data: adminTaskRows }, { data: documentRows }] =
    await Promise.all([
      supabase
        .from('money_subscriptions')
        .select('id, name, amount, cadence, next_charge_date, trial_ends_on, active')
        .eq('user_id', user.id),
      supabase
        .from('money_admin_tasks')
        .select('id, title, due_date, status')
        .eq('user_id', user.id),
      supabase.from('money_documents').select('id, expiry_date').eq('user_id', user.id),
    ]);

  const subscriptions = subscriptionRows ?? [];
  const adminTasks = adminTaskRows ?? [];
  const documents = documentRows ?? [];

  const activeSubscriptions = subscriptions.filter((s) => s.active);
  const monthlySubscriptionSpend = activeSubscriptions.reduce(
    (s, r) => s + (r.cadence === 'yearly' ? Number(r.amount) / 12 : Number(r.amount)),
    0,
  );
  const openTasks = adminTasks.filter((t) => t.status === 'open').length;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const expiringSoonDocs = documents.filter((d) => {
    if (!d.expiry_date) return false;
    const days = Math.round(
      (new Date(`${d.expiry_date}T00:00:00`).getTime() - today.getTime()) / 86400000,
    );
    return days <= 30;
  }).length;

  const plan = computeDebtPlan(getDebtPlanInput(snapshot));
  const upcoming = computeUpcomingEvents({
    expenses: activeExpenses,
    debts,
    subscriptions: activeSubscriptions,
    adminTasks,
    days: 7,
  });

  const planStats = [
    {
      label: 'Planned monthly income',
      value: formatMoney(monthlyIncome),
      icon: Wallet,
      tone: 'text-vera-success',
    },
    {
      label: 'Planned monthly expenses',
      value: formatMoney(monthlyExpenses),
      icon: TrendingDown,
      tone: 'text-vera-danger',
    },
    {
      label: 'Planned net cash flow',
      value: formatMoney(netCashFlow),
      icon: PiggyBank,
      tone: netCashFlow >= 0 ? 'text-vera-success' : 'text-vera-danger',
    },
    {
      label: 'Total debt',
      value: formatMoney(totalDebt),
      icon: CalendarClock,
      tone: 'text-vera-secondary',
    },
  ];

  const manageTiles = [
    {
      label: 'Transactions',
      href: '/dashboard/money/transactions',
      icon: ArrowLeftRight,
      metric: `${summary.count} in ${monthLabel(month, 'short')}`,
    },
    {
      label: 'Receipts',
      href: '/dashboard/money/receipts',
      icon: ReceiptText,
      metric: receipts.length ? `Latest ${receipts[0].created_at.slice(0, 10)}` : 'None yet',
    },
    {
      label: 'Budgets',
      href: '/dashboard/money/budgets',
      icon: Target,
      metric: budgets.length ? `${budgets.length} set` : 'None set',
    },
    {
      label: 'Income sources',
      href: '/dashboard/money/income',
      icon: Wallet,
      metric: `${activeIncome.length} active`,
    },
    {
      label: 'Expenses',
      href: '/dashboard/money/expenses',
      icon: Receipt,
      metric: `${activeExpenses.length} active`,
    },
    {
      label: 'Debts',
      href: '/dashboard/money/debts',
      icon: CreditCard,
      metric: debts.length ? formatMoney(totalDebt) : 'None',
    },
    {
      label: 'Savings goals',
      href: '/dashboard/money/savings',
      icon: PiggyBank,
      metric: `${activeSavings.length} active`,
    },
    {
      label: 'Subscriptions',
      href: '/dashboard/money/subscriptions',
      icon: Repeat,
      metric: activeSubscriptions.length
        ? `${formatMoney(monthlySubscriptionSpend)}/mo active`
        : 'None active',
    },
    {
      label: 'Admin tasks',
      href: '/dashboard/money/admin-tasks',
      icon: ClipboardList,
      metric: `${openTasks} open`,
    },
    {
      label: 'Documents',
      href: '/dashboard/money/documents',
      icon: FileText,
      metric: expiringSoonDocs
        ? `${expiringSoonDocs} expiring soon`
        : `${documents.length} on file`,
    },
  ];

  const unconvertedNote = summary.unconverted
    .flatMap((bucket) => [
      bucket.spending ? `${formatCurrency(bucket.spending, bucket.currency)} spent` : null,
      bucket.income ? `${formatCurrency(bucket.income, bucket.currency)} received` : null,
    ])
    .filter((part) => part !== null)
    .join(', ');

  return (
    <main className="px-4 py-8 lg:px-8">
      <PageHeader
        eyebrow="Money"
        title="Your money, at a glance"
        body={`What came in, what went out and where it went in ${monthName}, in ${home}. Private to your account — never visible to coaches or other members.`}
        action={
          <div className="flex flex-wrap items-center gap-2">
            <MonthPicker basePath="/dashboard/money" month={month} maxMonth={thisMonth} />
            <a
              className="btn-apple-secondary"
              href={`/dashboard/money/transactions/export?month=${month}`}
              download
            >
              <Download className="h-4 w-4" strokeWidth={1.75} aria-hidden="true" />
              Export CSV
            </a>
          </div>
        }
      />

      <div className="grid gap-3">
        <Banner
          variant="warning"
          message={
            transactions.error
              ? 'Some transactions couldn’t be loaded, so these figures may be incomplete. Refresh to try again.'
              : transactions.truncated
                ? 'You have more transactions in this period than the dashboard reads at once, so the figures are partial. Export to CSV for the full list.'
                : undefined
          }
        />
        <Banner
          variant="info"
          message={
            unconvertedNote
              ? `Not in the totals below: ${unconvertedNote} in ${monthName}. These are in other currencies and have no ${home} amount yet.`
              : undefined
          }
        />
      </div>

      <StaggerGroup className="mt-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatTile
          label={`Spent in ${monthLabel(month, 'short')}`}
          value={money(summary.spending)}
          icon={TrendingDown}
          delta={percentChange(summary.spending, previous.spending)}
          upIsGood={false}
          comparedTo={previousName}
        />
        <StatTile
          label={`Income in ${monthLabel(month, 'short')}`}
          value={money(summary.income)}
          icon={TrendingUp}
          delta={percentChange(summary.income, previous.income)}
          upIsGood
          comparedTo={previousName}
        />
        <StatTile
          label="Net position"
          value={money(summary.net)}
          icon={Scale}
          delta={percentChange(summary.net, previous.net)}
          upIsGood
          comparedTo={previousName}
          footnote={`${previousName}: ${money(previous.net)}`}
        />
        <StatTile
          label="Budget left"
          value={homeBudgets.length ? money(budgetLeft) : '—'}
          icon={Target}
          footnote={
            homeBudgets.length
              ? `of ${money(budgetTotal)} across ${homeBudgets.length} ${homeBudgets.length === 1 ? 'budget' : 'budgets'}`
              : 'Set a budget to track what’s left'
          }
        />
      </StaggerGroup>

      <div className="mt-6 grid gap-6 xl:grid-cols-[1fr_420px]">
        <div className="min-w-0 space-y-6">
          <Reveal variants={fadeUp}>
            <Card>
              <h2 className="text-xl font-bold">Where it went</h2>
              <p className="mt-1 text-sm text-vera-fg-muted">
                Spending by category in {monthName}, in {home}.
              </p>
              {summary.byCategory.length ? (
                <CategoryBars
                  data={summary.byCategory.map((c) => ({
                    key: c.key,
                    label: categoryLabel(c.key, customNames),
                    total: c.total,
                    previous: previousByCategory.get(c.key) ?? 0,
                  }))}
                  currency={home}
                  monthLabel={monthName}
                  previousLabel={previousName}
                />
              ) : (
                <EmptyState
                  icon={<TrendingDown className="h-6 w-6" strokeWidth={1.75} />}
                  title={`No spending in ${monthName}`}
                  body="Expenses you log here or scan on your phone show up by category."
                  ctaHref="/dashboard/money/transactions"
                  ctaLabel="Log a transaction"
                />
              )}
            </Card>
          </Reveal>

          <Reveal variants={fadeUp} delay={0.05}>
            <Card>
              <h2 className="text-xl font-bold">Last 12 months</h2>
              <p className="mt-1 text-sm text-vera-fg-muted">
                Spending and income per month, {monthLabel(trendStart)} – {monthName}, in {home}.
              </p>
              <TrendChart
                currency={home}
                ticks={niceTicks(Math.max(...trend.flatMap((p) => [p.spending, p.income]))).map(
                  (value) => ({ value, label: formatCurrencyCompact(value, home) }),
                )}
                data={trend.map((point) => ({
                  month: point.month,
                  short: monthLabel(point.month, 'short'),
                  long: monthLabel(point.month),
                  spending: point.spending,
                  income: point.income,
                  spendingText: money(point.spending),
                  incomeText: money(point.income),
                  netText: money(point.net),
                  spendingShort: formatCurrencyCompact(point.spending, home),
                  incomeShort: formatCurrencyCompact(point.income, home),
                }))}
              />
            </Card>
          </Reveal>
        </div>

        <div className="min-w-0 space-y-6">
          <Reveal variants={fadeUp}>
            <Card>
              <div className="flex items-center justify-between gap-3">
                <h2 className="text-xl font-bold">Budgets</h2>
                <a
                  className="text-sm font-semibold text-vera-primary hover:underline"
                  href={`/dashboard/money/budgets?month=${month}`}
                >
                  Manage
                </a>
              </div>
              {progress.length ? (
                <div className="mt-4 grid gap-5">
                  {progress.map((p) => (
                    <BudgetMeter
                      key={p.id}
                      label={categoryLabel(p.key, customNames)}
                      state={p.state}
                      ratio={p.ratio}
                      spentText={formatCurrency(p.spent, p.currency)}
                      limitText={formatCurrency(p.limit, p.currency)}
                      remainingText={
                        p.remaining >= 0
                          ? `${formatCurrency(p.remaining, p.currency)} left`
                          : `${formatCurrency(-p.remaining, p.currency)} over`
                      }
                    />
                  ))}
                </div>
              ) : (
                <EmptyState
                  icon={<Target className="h-6 w-6" strokeWidth={1.75} />}
                  title="No budgets yet"
                  body="Set a monthly limit per category and see how much is left. Budgets sync to your phone."
                  ctaHref="/dashboard/money/budgets"
                  ctaLabel="Set a budget"
                />
              )}
            </Card>
          </Reveal>

          <Reveal variants={fadeUp} delay={0.05}>
            <Card>
              <div className="flex items-center justify-between gap-3">
                <h2 className="text-xl font-bold">Recent receipts</h2>
                <a
                  className="text-sm font-semibold text-vera-primary hover:underline"
                  href="/dashboard/money/receipts"
                >
                  View all
                </a>
              </div>
              {receipts.length ? (
                <ul className="mt-3 divide-y divide-vera-border">
                  {receipts.map((receipt) => {
                    const tx = receipt.transaction_id ? linked.get(receipt.transaction_id) : null;
                    const view = receiptView(receipt, tx ?? null);
                    return (
                      <li key={receipt.id} className="flex items-center justify-between gap-3 py-3">
                        <div className="min-w-0">
                          <p className="truncate font-semibold">
                            {view.merchant ??
                              (receipt.status === 'failed' ? 'Unreadable receipt' : 'Not read yet')}
                          </p>
                          <p className="mt-0.5 flex flex-wrap items-center gap-2 text-sm text-vera-fg-muted">
                            {view.date}
                            <ReceiptStatusBadge status={receipt.status} />
                          </p>
                        </div>
                        {view.total !== null && view.currency ? (
                          <p className="flex-none font-semibold tabular-nums">
                            {formatCurrency(view.total, view.currency)}
                          </p>
                        ) : null}
                      </li>
                    );
                  })}
                </ul>
              ) : (
                <EmptyState
                  icon={<ReceiptText className="h-6 w-6" strokeWidth={1.75} />}
                  title="No receipts yet"
                  body="Scan a receipt with the Veralify app and it appears here once it syncs."
                />
              )}
            </Card>
          </Reveal>
        </div>
      </div>

      <h2 className="mt-12 text-2xl font-black tracking-tight">Your plan</h2>
      <p className="mt-1 text-sm text-vera-fg-muted">
        Recurring income, bills and debts you’ve set up — the budget behind the month.
      </p>

      <StaggerGroup className="mt-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {planStats.map((stat) => (
          <StaggerItem
            key={stat.label}
            as="article"
            className="rounded-vera-xl border border-vera-border bg-vera-surface p-5 shadow-[var(--vera-shadow-sm)]"
          >
            <stat.icon className={`h-5 w-5 ${stat.tone}`} strokeWidth={1.75} />
            <p className="mt-3 text-2xl font-black tracking-tight">{stat.value}</p>
            <p className="mt-1 text-sm text-vera-fg-muted">{stat.label}</p>
          </StaggerItem>
        ))}
      </StaggerGroup>

      <div className="mt-6 grid gap-6 xl:grid-cols-[1fr_420px]">
        <div className="space-y-6">
          <Reveal variants={fadeUp}>
            <Card>
              <h2 className="text-xl font-bold">Debt payoff plan</h2>
              <p className="mt-2 text-sm text-vera-fg-muted">
                Avalanche strategy — minimums first, then extra budget goes to the highest-APR debt.
              </p>
              {debts.length ? (
                <dl className="mt-5 grid grid-cols-2 gap-4 text-sm sm:grid-cols-4">
                  <div>
                    <dt className="text-vera-fg-muted">Status</dt>
                    <dd
                      className={`mt-1 font-semibold ${plan.feasible ? 'text-vera-success' : 'text-vera-danger'}`}
                    >
                      {plan.feasible ? 'Feasible' : 'Not feasible'}
                    </dd>
                  </div>
                  <div>
                    <dt className="text-vera-fg-muted">Required / month</dt>
                    <dd className="mt-1 font-semibold">{formatMoney(plan.requiredMonthly)}</dd>
                  </div>
                  <div>
                    <dt className="text-vera-fg-muted">Target</dt>
                    <dd className="mt-1 font-semibold">{snapshot.targetMonths} months</dd>
                  </div>
                  <div>
                    <dt className="text-vera-fg-muted">Available</dt>
                    <dd className="mt-1 font-semibold">{formatMoney(plan.available)}</dd>
                  </div>
                </dl>
              ) : (
                <EmptyState
                  title="No debts logged"
                  body="Add a debt to see an automatic Avalanche payoff plan."
                  ctaHref="/dashboard/money/debts"
                  ctaLabel="Add a debt"
                />
              )}
              <div className="mt-5">
                <a className="btn-apple-secondary" href="/dashboard/money/debts">
                  View full plan
                </a>
              </div>
            </Card>
          </Reveal>

          <Reveal variants={fadeUp} delay={0.05}>
            <Card>
              <h2 className="text-xl font-bold">Upcoming (7 days)</h2>
              {upcoming.events.length ? (
                <div className="mt-4 divide-y divide-vera-border">
                  {upcoming.events.map((event) => (
                    <div
                      key={`${event.type}-${event.id}`}
                      className="flex items-center justify-between py-3 text-sm"
                    >
                      <div>
                        <p className="font-semibold">{event.name}</p>
                        <p className="text-vera-fg-muted">
                          {EVENT_LABEL[event.type]} · due {event.dueDate}
                        </p>
                      </div>
                      {event.amount !== null ? (
                        <p className="font-semibold">{formatMoney(event.amount)}</p>
                      ) : null}
                    </div>
                  ))}
                </div>
              ) : (
                <EmptyState
                  title="Nothing due in the next 7 days"
                  body="Bills, debt minimums, subscription renewals, trial endings, and task due dates show up here."
                />
              )}
            </Card>
          </Reveal>
        </div>

        <div className="space-y-6">
          <Reveal variants={fadeUp}>
            <Card>
              <h2 className="text-xl font-bold">Manage</h2>
              <div className="mt-4 grid grid-cols-1 gap-2 sm:grid-cols-2">
                {manageTiles.map((tile) => (
                  <a
                    key={tile.href}
                    href={tile.href}
                    className="flex flex-col gap-2 rounded-vera-lg border border-vera-border px-4 py-3 transition-colors hover:border-vera-primary/40"
                  >
                    <tile.icon className="h-4 w-4 text-vera-primary" strokeWidth={1.75} />
                    <span className="text-sm font-semibold">{tile.label}</span>
                    <span className="text-xs text-vera-fg-muted">{tile.metric}</span>
                  </a>
                ))}
              </div>
            </Card>
          </Reveal>
        </div>
      </div>
    </main>
  );
}
