'use client';

import { ConfirmDialog } from '@components/generic/ConfirmDialog';
import { Trash2 } from 'lucide-react';
import { useState } from 'react';

/** Delete with a confirm step; the delete itself stays a server-action form post. */
export function TripDeleteButton({
  id,
  label,
  action,
}: {
  id: string;
  label: string;
  action: (formData: FormData) => void | Promise<void>;
}) {
  const [open, setOpen] = useState(false);
  return (
    <>
      <button
        type="button"
        aria-label={`Delete ${label}`}
        onClick={() => setOpen(true)}
        className="rounded-vera-md p-2 text-vera-fg-subtle transition-colors hover:bg-vera-surface-muted hover:text-vera-danger"
      >
        <Trash2 className="h-4 w-4" strokeWidth={1.75} />
      </button>
      <ConfirmDialog
        open={open}
        onClose={() => setOpen(false)}
        title="Delete this trip?"
        body="The trip and the mileage expense it created are both removed."
        action={action}
        hiddenFields={{ id }}
      />
    </>
  );
}
