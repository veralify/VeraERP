import { Reveal, StaggerGroup, StaggerItem } from '@components/generic/Motion';
import { Card, PageHeader } from '@components/member/DashboardPrimitives';
import { EmptyState } from '@components/member/EmptyState';
import { getDebtPlanInput, getMoneySnapshot } from '@lib/money/data';
import { computeDebtPlan } from '@lib/money/debtPlan';
import { formatMoney } from '@lib/money/format';
import { computeUpcomingEvents } from '@lib/money/upcoming';
import { fadeUp } from '@lib/motion/variants';
import { createSupabaseServerClient } from '@lib/supabase/server';
import {
  CalendarClock,
  ClipboardList,
  CreditCard,
  FileText,
  PiggyBank,
  Receipt,
  Repeat,
  TrendingDown,
  Wallet,
} from 'lucide-react';
import type { Metadata } from 'next';

export const metadata: Metadata = { title: 'Money' };

const EVENT_LABEL: Record<string, string> = {
  expense: 'Expense',
  debt: 'Debt minimum',
  'subscription-renewal': 'Subscription renews',
  'subscription-trial': 'Trial ends',
  task: 'Task due',
};

export default async function MoneyOverviewPage() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const snapshot = await getMoneySnapshot(supabase, user.id);
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

  const monthStart = new Date();
  monthStart.setDate(1);
  monthStart.setHours(0, 0, 0, 0);
  const monthStartStr = monthStart.toISOString().slice(0, 10);

  const [
    { data: subscriptionRows },
    { data: adminTaskRows },
    { count: transactionsThisMonth },
    { data: documentRows },
  ] = await Promise.all([
    supabase
      .from('money_subscriptions')
      .select('id, name, amount, cadence, next_charge_date, trial_ends_on, active')
      .eq('user_id', user.id),
    supabase.from('money_admin_tasks').select('id, title, due_date, status').eq('user_id', user.id),
    supabase
      .from('money_transactions')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .gte('transaction_date', monthStartStr),
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
    subscriptions,
    adminTasks,
    days: 7,
  });

  const stats = [
    {
      label: 'Monthly income',
      value: formatMoney(monthlyIncome),
      icon: Wallet,
      tone: 'text-vera-success',
    },
    {
      label: 'Monthly expenses',
      value: formatMoney(monthlyExpenses),
      icon: TrendingDown,
      tone: 'text-vera-danger',
    },
    {
      label: 'Net cash flow',
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
      label: 'Transactions',
      href: '/dashboard/money/transactions',
      icon: CalendarClock,
      metric: `${transactionsThisMonth ?? 0} this month`,
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

  return (
    <main className="px-4 py-8 lg:px-8">
      <PageHeader
        eyebrow="Money"
        title="Your money, at a glance"
        body="Income, expenses, debts, savings, subscriptions, and more — private to your account, never visible to coaches or other members."
      />

      <StaggerGroup className="mt-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {stats.map((stat) => (
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
