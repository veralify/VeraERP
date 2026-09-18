'use client';

import type { ReactNode } from 'react';
import { useFormStatus } from 'react-dom';
import { Spinner } from './Spinner';

/**
 * Form submit button with a real pending state via `useFormStatus` — shows
 * the shared `Spinner` and disables re-submission while a server action is
 * in flight. Drop-in replacement for a static `<button type="submit">`;
 * must render inside the `<form action={...}>` it reports on.
 */
export function SubmitButton({
  children,
  pendingLabel,
  className = '',
}: {
  children: ReactNode;
  pendingLabel?: ReactNode;
  className?: string;
}) {
  const { pending } = useFormStatus();

  return (
    <button type="submit" className={`btn-apple min-h-11 ${className}`} disabled={pending}>
      {pending ? (
        <>
          <Spinner size="sm" label="Submitting" />
          {pendingLabel ?? children}
        </>
      ) : (
        children
      )}
    </button>
  );
}
