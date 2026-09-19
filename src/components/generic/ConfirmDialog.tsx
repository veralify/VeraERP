'use client';

import { Modal } from './Modal';
import { SubmitButton } from './SubmitButton';

/**
 * Destructive-action confirm built on `Modal`. The actual delete stays a
 * real `<form action={action}>` post (server action), not a client fetch.
 */
export function ConfirmDialog({
  open,
  onClose,
  title,
  body,
  confirmLabel = 'Delete',
  action,
  hiddenFields,
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  body: string;
  confirmLabel?: string;
  action: (formData: FormData) => void | Promise<void>;
  hiddenFields?: Record<string, string>;
}) {
  return (
    <Modal open={open} onClose={onClose} title={title}>
      <p className="text-sm text-vera-fg-muted">{body}</p>
      <form action={action} className="mt-6 flex justify-end gap-3">
        {hiddenFields
          ? Object.entries(hiddenFields).map(([key, value]) => (
              <input key={key} type="hidden" name={key} value={value} />
            ))
          : null}
        <button type="button" onClick={onClose} className="btn-apple-secondary">
          Cancel
        </button>
        <SubmitButton pendingLabel="Deleting…" className="btn-apple-danger">
          {confirmLabel}
        </SubmitButton>
      </form>
    </Modal>
  );
}
