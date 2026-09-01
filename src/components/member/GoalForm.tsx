import { createGoalAction } from '../../app/dashboard/goals/actions';
import { Field, inputClass, SubmitButton } from './DashboardPrimitives';

export function GoalForm({ setup = false }: { setup?: boolean }) {
  return (
    <form
      action={createGoalAction}
      className="grid gap-4 rounded-vera-2xl border border-vera-border bg-vera-surface p-6 md:grid-cols-2"
    >
      <div className="md:col-span-2">
        <h2 className="text-xl font-bold">{setup ? 'Set up your plan' : 'Create goal'}</h2>
        <p className="mt-1 text-sm text-vera-fg-muted">
          Targets use deterministic Mifflin-St Jeor math and daily macro splits.
        </p>
      </div>
      <Field label="Goal title">
        <input
          className={inputClass}
          name="title"
          required
          defaultValue={setup ? 'My Veralify plan' : ''}
        />
      </Field>
      <Field label="Goal direction">
        <select className={inputClass} name="direction" defaultValue="lose">
          <option value="lose">Lose weight</option>
          <option value="maintain">Maintain</option>
          <option value="gain">Gain weight</option>
        </select>
      </Field>
      <Field label="Sex for BMR">
        <select className={inputClass} name="sex" defaultValue="female">
          <option value="female">Female</option>
          <option value="male">Male</option>
        </select>
      </Field>
      <Field label="Activity level">
        <select className={inputClass} name="activityLevel" defaultValue="moderate">
          <option value="sedentary">Sedentary</option>
          <option value="light">Light</option>
          <option value="moderate">Moderate</option>
          <option value="active">Active</option>
          <option value="very_active">Very active</option>
        </select>
      </Field>
      <Field label="Age">
        <input className={inputClass} name="ageYears" type="number" min="13" max="100" required />
      </Field>
      <Field label="Height (cm)">
        <input className={inputClass} name="heightCm" type="number" min="100" max="250" required />
      </Field>
      <Field label="Current weight (kg)">
        <input
          className={inputClass}
          name="currentWeightKg"
          type="number"
          step="0.1"
          min="30"
          max="300"
          required
        />
      </Field>
      <Field label="Target weight (kg)">
        <input
          className={inputClass}
          name="targetWeightKg"
          type="number"
          step="0.1"
          min="30"
          max="300"
          required
        />
      </Field>
      <Field label="Target date">
        <input className={inputClass} name="targetDate" type="date" />
      </Field>
      <div className="flex items-end">
        <SubmitButton>{setup ? 'Create my plan' : 'Create goal'}</SubmitButton>
      </div>
    </form>
  );
}
