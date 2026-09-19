'use client';

import { RouteErrorState } from '@components/generic/RouteErrorState';
import { useEffect } from 'react';

export default function MoneyError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error(error);
  }, [error]);

  return (
    <main className="px-4 py-16 lg:px-8">
      <RouteErrorState
        title="We couldn't load your money data"
        body="Something went wrong loading this page. Your data is safe — try again."
        onRetry={reset}
      />
    </main>
  );
}
