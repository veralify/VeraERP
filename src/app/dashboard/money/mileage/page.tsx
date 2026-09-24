import { Banner } from '@components/generic/Banner';
import { Reveal, StaggerGroup, StaggerItem } from '@components/generic/Motion';
import {
  Card,
  ErrorMessage,
  Field,
  inputClass,
  PageHeader,
  SubmitButton,
} from '@components/member/DashboardPrimitives';
import { EmptyState } from '@components/member/EmptyState';
import { fadeUp } from '@lib/motion/variants';
import { createSupabaseServerClient } from '@lib/supabase/server';
import type { SupabaseClient } from '@supabase/supabase-js';
import { Car, Gauge, MapPin, Route } from 'lucide-react';
import type { Metadata } from 'next';
import { formatAmount, formatDate, isoDate } from '../reports/_lib/report';
import {
  type DistanceUnit,
  MILEAGE_PRESETS,
  presetById,
  toMiles,
  ukTaxYearStart,
} from './_lib/mileage';
import { deleteTripAction, logTripAction } from './actions';
import { TripDeleteButton } from './TripDeleteButton';

export const metadata: Metadata = { title: 'Mileage · Money' };

type SearchParams = Promise<{ preset?: string; error?: string; saved?: string }>;

interface TripRow {
  id: string;
  trip_date: string;
  origin: string;
  destination: string;
  distance: number | string;
  unit: DistanceUnit;
  rate_per_unit: number | string;
  currency: string;
  purpose: string;
  scope: 'business' | 'personal';
  transaction: { amount: number | string } | null;
}

const LIST_LIMIT = 100;
const numberFormat = new Intl.NumberFormat('en-IE', { maximumFractionDigits: 1 });

function tripAmount(trip: TripRow): number {
  if (trip.transaction) return Number(trip.transaction.amount);
  return Math.round(Number(trip.distance) * Number(trip.rate_per_unit) * 100) / 100;
}

export default async function MileagePage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;
  const client = supabase as unknown as SupabaseClient;

  const today = isoDate(new Date());
  const yearStart = `${today.slice(0, 4)}-01-01`;
  const taxYearStart = ukTaxYearStart(today);
  const since = taxYearStart < yearStart ? taxYearStart : yearStart;

  const select =
    'id, trip_date, origin, destination, distance, unit, rate_per_unit, currency, purpose, scope, transaction:money_transactions(amount)';
  const [{ data: recentRows, error: listError }, { data: periodRows }] = await Promise.all([
    client
      .from('money_mileage_trips')
      .select(select)
      .eq('user_id', user.id)
      .is('deleted_at', null)
      .order('trip_date', { ascending: false })
      .order('created_at', { ascending: false })
      .limit(LIST_LIMIT),
    client
      .from('money_mileage_trips')
      .select(select)
      .eq('user_id', user.id)
      .is('deleted_at', null)
      .gte('trip_date', since)
      .limit(5000),
  ]);
  const trips = (recentRows ?? []) as unknown as TripRow[];
  const period = (periodRows ?? []) as unknown as TripRow[];

  // This calendar year: distance per unit and the amount claimed per currency.
  const thisYear = period.filter((trip) => trip.trip_date >= yearStart);
  const distanceByUnit = { km: 0, mi: 0 };
  const claimed = new Map<string, number>();
  for (const trip of thisYear) {
    distanceByUnit[trip.unit] += Number(trip.distance);
    claimed.set(trip.currency, (claimed.get(trip.currency) ?? 0) + tripAmount(trip));
  }
  const businessMilesThisTaxYear = period
    .filter((trip) => trip.scope === 'business' && trip.trip_date >= taxYearStart)
    .reduce((sum, trip) => sum + toMiles(Number(trip.distance), trip.unit), 0);

  // The form starts from the chosen preset; with none chosen, from what the
  // last trip used, so a regular rate only has to be typed once.
  const last = trips[0];
  const preset = presetById(
    params.preset ??
      (last && !(last.currency === 'GBP' && last.unit === 'mi') ? 'custom' : 'uk_car'),
  );
  const rememberedRate =
    preset.rate === null && last && (preset.id === 'custom' || last.currency === preset.currency)
      ? String(Number(last.rate_per_unit))
      : '';
  const formCurrency = preset.id === 'custom' && last ? last.currency : preset.currency;
  const formUnit = preset.id === 'custom' && last ? last.unit : preset.unit;

  const stats = [
    { label: 'Trips this year', value: String(thisYear.length), icon: Route },
    {
      label: 'Distance this year',
      value:
        [
          distanceByUnit.km ? `${numberFormat.format(distanceByUnit.km)} km` : '',
          distanceByUnit.mi ? `${numberFormat.format(distanceByUnit.mi)} mi` : '',
        ]
          .filter(Boolean)
          .join(' · ') || '0 km',
      icon: Gauge,
    },
    {
      label: 'Claimed this year',
      value:
        [...claimed.entries()]
          .map(([currency, total]) => formatAmount(total, currency))
          .join(' · ') || formatAmount(0, formCurrency),
      icon: Car,
    },
    {
      label: 'UK business miles this tax year',
      value: `${numberFormat.format(businessMilesThisTaxYear)} / 10,000`,
      icon: MapPin,
    },
  ];

  return (
    <main className="px-4 py-8 lg:px-8">
      <PageHeader
        eyebrow="Money"
        title="Mileage"
        body="Log business journeys in your own vehicle. Each trip is added to your expenses at the rate you choose, ready for your reports."
      />
      <ErrorMessage
        message={
          params.error === 'save'
            ? 'We couldn’t save that trip. Please try again.'
            : params.error
              ? 'Enter a date, a distance above zero, a rate and a three-letter currency.'
              : undefined
        }
      />
      <Banner
        variant="success"
        message={params.saved ? 'Trip saved and added to your expenses.' : undefined}
      />

      <StaggerGroup className="mt-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {stats.map((stat) => (
          <StaggerItem
            key={stat.label}
            as="article"
            className="rounded-vera-xl border border-vera-border bg-vera-surface p-5 shadow-[var(--vera-shadow-sm)]"
          >
            <stat.icon className="h-5 w-5 text-vera-primary" strokeWidth={1.75} />
            <p className="mt-3 text-2xl font-black tracking-tight">{stat.value}</p>
            <p className="mt-1 text-sm text-vera-fg-muted">{stat.label}</p>
          </StaggerItem>
        ))}
      </StaggerGroup>

      <div className="mt-6 grid gap-6 xl:grid-cols-[1fr_420px]">
        <Reveal variants={fadeUp}>
          <Card>
            <h2 className="text-xl font-bold">Your trips</h2>
            <Banner
              variant="error"
              className="mt-4"
              message={listError ? 'We couldn’t load your trips. Please try again.' : undefined}
            />
            {trips.length ? (
              <StaggerGroup className="mt-4 divide-y divide-vera-border">
                {trips.map((trip) => {
                  const route =
                    trip.origin && trip.destination
                      ? `${trip.origin} → ${trip.destination}`
                      : trip.purpose || 'Trip';
                  return (
                    <StaggerItem
                      key={trip.id}
                      as="div"
                      className="flex items-center justify-between gap-3 py-4"
                    >
                      <div className="min-w-0">
                        <p className="truncate font-semibold">{route}</p>
                        <p className="text-sm text-vera-fg-muted">
                          {formatDate(trip.trip_date)} ·{' '}
                          {numberFormat.format(Number(trip.distance))} {trip.unit} ·{' '}
                          {trip.scope === 'business' ? 'Business' : 'Personal'}
                          {trip.purpose && trip.origin ? ` · ${trip.purpose}` : ''}
                        </p>
                      </div>
                      <div className="flex items-center gap-3">
                        <p className="text-lg font-bold tabular-nums">
                          {formatAmount(tripAmount(trip), trip.currency)}
                        </p>
                        <TripDeleteButton id={trip.id} label={route} action={deleteTripAction} />
                      </div>
                    </StaggerItem>
                  );
                })}
              </StaggerGroup>
            ) : (
              <EmptyState
                icon={<Car className="h-6 w-6" strokeWidth={1.75} />}
                title="No trips logged"
                body="Log a business journey and it appears here and in your expenses, at the rate you set."
              />
            )}
            {trips.length === LIST_LIMIT ? (
              <p className="mt-4 text-sm text-vera-fg-muted">
                Showing your latest {LIST_LIMIT} trips. Every trip is in your expense reports.
              </p>
            ) : null}
          </Card>
        </Reveal>

        <Reveal variants={fadeUp} delay={0.05}>
          <form
            action={logTripAction}
            className="grid gap-4 rounded-vera-2xl border border-vera-border bg-vera-surface p-6"
          >
            <h2 className="text-xl font-bold">Log a trip</h2>
            <nav className="flex flex-wrap gap-2" aria-label="Rate presets">
              {MILEAGE_PRESETS.map((option) => (
                <a
                  key={option.id}
                  href={`/dashboard/money/mileage?preset=${option.id}`}
                  aria-current={option.id === preset.id ? 'true' : undefined}
                  className={`rounded-full border px-3 py-1.5 text-xs font-semibold transition-colors ${
                    option.id === preset.id
                      ? 'border-vera-primary bg-vera-primary/10 text-vera-primary'
                      : 'border-vera-border text-vera-fg-muted hover:border-vera-primary/40'
                  }`}
                >
                  {option.label}
                </a>
              ))}
            </nav>
            <p className="text-sm text-vera-fg-muted">{preset.description}</p>
            <input type="hidden" name="preset" value={preset.id} />

            <Field label="Date">
              <input
                className={inputClass}
                name="trip_date"
                type="date"
                required
                defaultValue={today}
              />
            </Field>
            <div className="grid gap-4 sm:grid-cols-2">
              <Field label="From">
                <input className={inputClass} name="origin" placeholder="Office" maxLength={200} />
              </Field>
              <Field label="To">
                <input
                  className={inputClass}
                  name="destination"
                  placeholder="Client site"
                  maxLength={200}
                />
              </Field>
            </div>
            <div className="grid gap-4 sm:grid-cols-[1fr_120px]">
              <Field label="Distance">
                <input
                  className={inputClass}
                  name="distance"
                  type="number"
                  min="0.1"
                  step="0.1"
                  required
                  inputMode="decimal"
                />
              </Field>
              <Field label="Unit">
                <select className={inputClass} name="unit" defaultValue={formUnit}>
                  <option value="km">km</option>
                  <option value="mi">miles</option>
                </select>
              </Field>
            </div>
            <div className="grid gap-4 sm:grid-cols-[1fr_120px]">
              <Field label={preset.band ? 'Rate per mile (first 10,000)' : 'Rate per unit'}>
                <input
                  className={inputClass}
                  name="rate"
                  type="number"
                  min="0"
                  step="0.0001"
                  required
                  inputMode="decimal"
                  defaultValue={preset.rate ?? rememberedRate}
                  placeholder={preset.id === 'it_aci' ? 'e.g. 0.4521' : undefined}
                />
              </Field>
              <Field label="Currency">
                <input
                  className={`${inputClass} uppercase`}
                  name="currency"
                  required
                  maxLength={3}
                  pattern="[A-Za-z]{3}"
                  defaultValue={formCurrency}
                />
              </Field>
            </div>
            {preset.band ? (
              <Field label="Rate per mile after 10,000 business miles">
                <input
                  className={inputClass}
                  name="rate_after"
                  type="number"
                  min="0"
                  step="0.0001"
                  required
                  inputMode="decimal"
                  defaultValue={preset.band.rateAfter}
                />
              </Field>
            ) : null}
            <Field label="Purpose">
              <input
                className={inputClass}
                name="purpose"
                placeholder="Client meeting"
                maxLength={500}
              />
            </Field>
            <Field label="Scope">
              <select className={inputClass} name="scope" defaultValue="business">
                <option value="business">Business</option>
                <option value="personal">Personal</option>
              </select>
            </Field>
            {preset.band ? (
              <p className="text-xs text-vera-fg-muted">
                The higher rate covers the first 10,000 business miles from 6 April. Trips already
                logged this tax year are counted automatically; a trip that crosses the line is
                split between the two rates.
              </p>
            ) : null}
            <SubmitButton>Log trip</SubmitButton>
          </form>
        </Reveal>
      </div>
    </main>
  );
}
