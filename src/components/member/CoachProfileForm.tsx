import { UserCog } from 'lucide-react';
import { upsertCoachProfileAction } from '../../app/dashboard/coach/actions';
import { Field, inputClass, SubmitButton } from './DashboardPrimitives';

type Existing = {
  headline: string | null;
  bio: string | null;
  specialties: string[];
  years_experience: number | null;
  hourly_rate: number | null;
  currency: string;
  location: string | null;
  online_only: boolean;
} | null;

export function CoachProfileForm({ existing }: { existing: Existing }) {
  return (
    <form
      action={upsertCoachProfileAction}
      className="grid gap-4 rounded-vera-2xl border border-vera-border bg-vera-surface p-6 md:grid-cols-2"
    >
      <div className="md:col-span-2">
        <h2 className="flex items-center gap-2 text-xl font-bold">
          <UserCog className="h-5 w-5 text-vera-primary" aria-hidden="true" />
          {existing ? 'Edit coach profile' : 'Create coach profile'}
        </h2>
        <p className="mt-1 text-sm text-vera-fg-muted">
          A profile is required before Stripe Connect onboarding and public discovery.
        </p>
      </div>
      <Field label="Headline">
        <input
          className={inputClass}
          name="headline"
          required
          defaultValue={existing?.headline ?? ''}
          placeholder="Certified strength & nutrition coach"
        />
      </Field>
      <Field label="Location">
        <input
          className={inputClass}
          name="location"
          defaultValue={existing?.location ?? ''}
          placeholder="Remote / city"
        />
      </Field>
      <div className="md:col-span-2">
        <Field label="Bio">
          <textarea
            className={`${inputClass} min-h-24`}
            name="bio"
            defaultValue={existing?.bio ?? ''}
          />
        </Field>
      </div>
      <div className="md:col-span-2">
        <Field label="Specialties (comma separated)">
          <input
            className={inputClass}
            name="specialties"
            defaultValue={existing?.specialties.join(', ') ?? ''}
            placeholder="weight loss, strength training, nutrition"
          />
        </Field>
      </div>
      <Field label="Years of experience">
        <input
          className={inputClass}
          name="yearsExperience"
          type="number"
          min="0"
          max="60"
          defaultValue={existing?.years_experience ?? ''}
        />
      </Field>
      <Field label="Hourly rate">
        <input
          className={inputClass}
          name="hourlyRate"
          type="number"
          min="0"
          step="0.01"
          defaultValue={existing?.hourly_rate ?? ''}
        />
      </Field>
      <Field label="Currency">
        <input
          className={inputClass}
          name="currency"
          maxLength={3}
          defaultValue={existing?.currency ?? 'USD'}
        />
      </Field>
      <Field label="Online only">
        <label className="flex min-h-11 items-center gap-2 text-sm">
          <input type="checkbox" name="onlineOnly" defaultChecked={existing?.online_only ?? true} />
          Sessions are online-only
        </label>
      </Field>
      <div className="md:col-span-2">
        <SubmitButton pendingLabel="Saving…">
          {existing ? 'Save changes' : 'Create profile'}
        </SubmitButton>
      </div>
    </form>
  );
}
