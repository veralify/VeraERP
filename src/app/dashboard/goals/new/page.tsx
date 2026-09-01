import { PageHeader } from '@components/member/DashboardPrimitives';
import { GoalForm } from '@components/member/GoalForm';
import type { Metadata } from 'next';

export const metadata: Metadata = { title: 'Set up your plan' };

export default function NewGoalPage() {
  return (
    <main className="px-4 py-8 lg:px-8">
      <PageHeader
        eyebrow="Onboarding"
        title="Set up your plan"
        body="A minimal web setup creates a real goal and daily calorie/macro targets. Full guided onboarding remains iOS-first."
      />
      <GoalForm setup />
    </main>
  );
}
