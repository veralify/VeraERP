import { nextOccurrence } from './debtPlan';

/**
 * Superset of `computeUpcomingBills` (debtPlan.ts) that also merges
 * subscription renewals/trial-endings and open admin-task due dates into
 * one "upcoming in N days" feed for the Overview page. `computeUpcomingBills`
 * itself is left untouched — this is a separate, additive function.
 */
export type UpcomingEvent = {
  type: 'expense' | 'debt' | 'subscription-renewal' | 'subscription-trial' | 'task';
  id: string;
  name: string;
  amount: number | null;
  dueDate: string;
  daysUntil: number;
};

function toLocalDateStr(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function parseLocalDate(dateStr: string): Date {
  return new Date(`${dateStr}T00:00:00`);
}

export function computeUpcomingEvents(input: {
  expenses: { id: string; name: string; amount: number; due_day: number | null }[];
  debts: { id: string; name: string; minimum_payment: number; due_day: number | null }[];
  subscriptions: {
    id: string;
    name: string;
    amount: number;
    next_charge_date: string | null;
    trial_ends_on: string | null;
  }[];
  adminTasks: { id: string; title: string; due_date: string | null; status: string }[];
  days: number;
}): { days: number; count: number; events: UpcomingEvent[] } {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const horizon = new Date(today);
  horizon.setDate(horizon.getDate() + input.days);
  const daysUntil = (d: Date) => Math.round((d.getTime() - today.getTime()) / 86400000);
  const events: UpcomingEvent[] = [];

  for (const r of input.expenses) {
    const d = nextOccurrence(r.due_day, today);
    if (d && d <= horizon) {
      events.push({
        type: 'expense',
        id: r.id,
        name: r.name,
        amount: Number(r.amount) || 0,
        dueDate: toLocalDateStr(d),
        daysUntil: daysUntil(d),
      });
    }
  }

  for (const r of input.debts) {
    const d = nextOccurrence(r.due_day, today);
    if (d && d <= horizon && Number(r.minimum_payment) > 0) {
      events.push({
        type: 'debt',
        id: r.id,
        name: r.name,
        amount: Number(r.minimum_payment) || 0,
        dueDate: toLocalDateStr(d),
        daysUntil: daysUntil(d),
      });
    }
  }

  for (const r of input.subscriptions) {
    if (r.next_charge_date) {
      const d = parseLocalDate(r.next_charge_date);
      if (d >= today && d <= horizon) {
        events.push({
          type: 'subscription-renewal',
          id: r.id,
          name: r.name,
          amount: Number(r.amount) || 0,
          dueDate: r.next_charge_date,
          daysUntil: daysUntil(d),
        });
      }
    }
    if (r.trial_ends_on) {
      const d = parseLocalDate(r.trial_ends_on);
      if (d >= today && d <= horizon) {
        events.push({
          type: 'subscription-trial',
          id: r.id,
          name: r.name,
          amount: null,
          dueDate: r.trial_ends_on,
          daysUntil: daysUntil(d),
        });
      }
    }
  }

  for (const r of input.adminTasks) {
    if (r.due_date && r.status === 'open') {
      const d = parseLocalDate(r.due_date);
      if (d <= horizon) {
        events.push({
          type: 'task',
          id: r.id,
          name: r.title,
          amount: null,
          dueDate: r.due_date,
          daysUntil: daysUntil(d),
        });
      }
    }
  }

  events.sort((a, b) => a.daysUntil - b.daysUntil);
  return { days: input.days, count: events.length, events };
}
