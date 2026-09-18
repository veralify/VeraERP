import { CalendarPlus } from 'lucide-react';
import { createCoachSessionAction } from '../../app/dashboard/coach/actions';
import { Field, inputClass, SubmitButton } from './DashboardPrimitives';

export function CoachSessionForm() {
  return (
    <form
      action={createCoachSessionAction}
      className="grid gap-4 rounded-vera-2xl border border-vera-border bg-vera-surface p-6 md:grid-cols-2"
    >
      <div className="md:col-span-2">
        <h2 className="flex items-center gap-2 text-xl font-bold">
          <CalendarPlus className="h-5 w-5 text-vera-primary" aria-hidden="true" />
          Open a session slot
        </h2>
        <p className="mt-1 text-sm text-vera-fg-muted">
          Published as "available" so clients can find and book it from coach discovery.
        </p>
      </div>
      <div className="md:col-span-2">
        <Field label="Title">
          <input className={inputClass} name="title" required placeholder="1:1 kickoff call" />
        </Field>
      </div>
      <div className="md:col-span-2">
        <Field label="Description">
          <textarea className={`${inputClass} min-h-20`} name="description" />
        </Field>
      </div>
      <Field label="Format">
        <select className={inputClass} name="sessionType" defaultValue="video">
          <option value="video">Video</option>
          <option value="audio">Audio</option>
          <option value="in_person">In person</option>
        </select>
      </Field>
      <Field label="Duration (minutes)">
        <input
          className={inputClass}
          name="durationMinutes"
          type="number"
          min="15"
          step="15"
          defaultValue={30}
          required
        />
      </Field>
      <div className="md:col-span-2">
        <Field label="Scheduled at">
          <input className={inputClass} name="scheduledAt" type="datetime-local" required />
        </Field>
      </div>
      <div className="md:col-span-2">
        <SubmitButton pendingLabel="Publishing…">Publish session</SubmitButton>
      </div>
    </form>
  );
}
