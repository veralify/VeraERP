/**
 * Mileage allowances: what a business trip in your own vehicle can be
 * claimed at. Mirrors VeralifyCore `Mileage` on iOS — keep the two in step.
 *
 * Presets are defaults for the form, never locked: the user can change any
 * rate before saving, and the rate used is stored on each trip.
 */

export type DistanceUnit = 'km' | 'mi';

export const KM_PER_MILE = 1.609344;

export interface MileagePreset {
  id: string;
  label: string;
  description: string;
  currency: string;
  unit: DistanceUnit;
  /** Per `unit`; null when the user has to supply it. */
  rate: number | null;
  /**
   * A second rate after a yearly allowance of business miles (the UK car
   * band). Counted per UK tax year, business trips only.
   */
  band?: { limitMiles: number; rateAfter: number };
}

// VERIFY: HMRC approved mileage allowance payments — cars and vans 45p per
// mile for the first 10,000 business miles in the tax year, 25p after;
// motorcycles 24p; bicycles 20p. Unchanged since 2011–12; check gov.uk
// ("Travel — mileage and fuel rates and allowances") before each tax year.
export const MILEAGE_PRESETS: MileagePreset[] = [
  {
    id: 'uk_car',
    label: 'UK car or van (HMRC)',
    description: '45p a mile for the first 10,000 business miles this tax year, then 25p.',
    currency: 'GBP',
    unit: 'mi',
    rate: 0.45,
    band: { limitMiles: 10_000, rateAfter: 0.25 },
  },
  {
    id: 'uk_motorcycle',
    label: 'UK motorcycle (HMRC)',
    description: '24p a mile.',
    currency: 'GBP',
    unit: 'mi',
    rate: 0.24,
  },
  {
    id: 'uk_bicycle',
    label: 'UK bicycle (HMRC)',
    description: '20p a mile.',
    currency: 'GBP',
    unit: 'mi',
    rate: 0.2,
  },
  {
    // VERIFY: Italy has no single statutory rate. The ACI publishes cost-per-km
    // tables by vehicle make, model and fuel each year, so the user looks up
    // their own vehicle's figure and enters it.
    id: 'it_aci',
    label: 'Italy (ACI tables)',
    description:
      'Enter the rate per km for your vehicle from the ACI tables — it depends on make, model and fuel.',
    currency: 'EUR',
    unit: 'km',
    rate: null,
  },
  {
    id: 'custom',
    label: 'Custom rate',
    description: 'Any rate per km or per mile, in any currency.',
    currency: 'EUR',
    unit: 'km',
    rate: null,
  },
];

export function presetById(id: string | undefined | null): MileagePreset {
  return MILEAGE_PRESETS.find((preset) => preset.id === id) ?? MILEAGE_PRESETS[0];
}

export function toMiles(distance: number, unit: DistanceUnit): number {
  return unit === 'mi' ? distance : distance / KM_PER_MILE;
}

const round2 = (value: number) => Math.round((value + Number.EPSILON) * 100) / 100;

/** First day (YYYY-MM-DD) of the UK tax year containing `date`: 6 April. */
export function ukTaxYearStart(date: string): string {
  const [year, month, day] = date.split('-').map(Number);
  const startYear = month > 4 || (month === 4 && day >= 6) ? year : year - 1;
  return `${startYear}-04-06`;
}

export interface MileageInput {
  distance: number;
  unit: DistanceUnit;
  /** Per unit of distance. */
  rate: number;
  /** When set, `rate` applies up to the band's limit of business miles, then `rateAfter`. */
  band?: { limitMiles: number; rateAfter: number } | null;
  /** Business miles already claimed this tax year before this trip. */
  priorBusinessMiles?: number;
  /** The band counts business miles only; a personal trip is charged at `rate`. */
  business?: boolean;
}

export interface MileageAmount {
  amount: number;
  /** The single per-unit rate that gives `amount` for this trip; stored on the trip. */
  effectiveRate: number;
  /** Miles of this trip charged at the rate after the band. */
  milesAfterBand: number;
}

/**
 * The claim for one trip. With a band (UK cars), the band rates are per mile
 * whatever unit the trip was logged in; a trip that crosses the 10,000-mile
 * line is split, the part before it at 45p and the rest at 25p.
 */
export function mileageAmount(input: MileageInput): MileageAmount {
  const { distance, unit, rate } = input;
  if (!(distance > 0) || !(rate >= 0)) return { amount: 0, effectiveRate: 0, milesAfterBand: 0 };

  if (!input.band || input.business === false) {
    const amount = round2(distance * rate);
    return { amount, effectiveRate: rate, milesAfterBand: 0 };
  }

  const miles = toMiles(distance, unit);
  const prior = Math.max(0, input.priorBusinessMiles ?? 0);
  const inBand = Math.max(0, Math.min(miles, input.band.limitMiles - prior));
  const after = miles - inBand;
  const amount = round2(inBand * rate + after * input.band.rateAfter);
  return {
    amount,
    effectiveRate: Math.round((amount / distance) * 10_000) / 10_000,
    milesAfterBand: after,
  };
}
