'use client';

import { Pencil, Trash2 } from 'lucide-react';
import type { ReactNode } from 'react';
import { useState } from 'react';
import { ConfirmDialog } from './ConfirmDialog';
import { Modal } from './Modal';
import { SubmitButton } from './SubmitButton';

/**
 * Gives a list row an edit-pencil (opens a `Modal` with a prefilled form)
 * and a delete-trash (opens a `ConfirmDialog`) without wiring modal state
 * separately on every one of the 9 money list pages. Each page authors its
 * own edit-field markup server-side (same `Field`/`inputClass` primitives
 * used for the "Add" form, just prefilled via `defaultValue`) and passes it
 * as `children` — a Server Component can pass server-rendered JSX as
 * children into a Client Component, so this works across domains with very
 * different field counts.
 */
export function RowActions({
  id,
  itemLabel,
  editTitle,
  updateAction,
  deleteAction,
  children,
}: {
  id: string;
  itemLabel: string;
  editTitle: string;
  updateAction: (formData: FormData) => void | Promise<void>;
  deleteAction: (formData: FormData) => void | Promise<void>;
  children: ReactNode;
}) {
  const [editOpen, setEditOpen] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);

  // Server actions redirect back to this same page, which is a soft navigation that
  // keeps this component mounted, so the modal would otherwise stay open after saving.
  // The redirect surfaces as a rejected promise; `finally` closes and rethrows it.
  const submitUpdate = async (formData: FormData) => {
    try {
      await updateAction(formData);
    } finally {
      setEditOpen(false);
    }
  };

  return (
    <div className="flex items-center gap-1">
      <button
        type="button"
        aria-label={`Edit ${itemLabel}`}
        onClick={() => setEditOpen(true)}
        className="rounded-vera-md p-2 text-vera-fg-subtle transition-colors hover:bg-vera-surface-muted hover:text-vera-fg"
      >
        <Pencil className="h-4 w-4" strokeWidth={1.75} />
      </button>
      <button
        type="button"
        aria-label={`Delete ${itemLabel}`}
        onClick={() => setDeleteOpen(true)}
        className="rounded-vera-md p-2 text-vera-fg-subtle transition-colors hover:bg-vera-danger/10 hover:text-vera-danger"
      >
        <Trash2 className="h-4 w-4" strokeWidth={1.75} />
      </button>

      <Modal open={editOpen} onClose={() => setEditOpen(false)} title={editTitle}>
        <form action={submitUpdate} className="grid gap-4">
          <input type="hidden" name="id" value={id} />
          {children}
          <SubmitButton>Save changes</SubmitButton>
        </form>
      </Modal>

      <ConfirmDialog
        open={deleteOpen}
        onClose={() => setDeleteOpen(false)}
        title={`Delete "${itemLabel}"?`}
        body="This can't be undone."
        confirmLabel="Delete"
        action={deleteAction}
        hiddenFields={{ id }}
      />
    </div>
  );
}
