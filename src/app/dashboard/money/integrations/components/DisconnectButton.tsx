'use client';

import { ConfirmDialog } from '@components/generic/ConfirmDialog';
import { useState } from 'react';
import { disconnectAction } from '../actions';

/** Disconnect behind a confirmation: it revokes access at the provider. */
export function DisconnectButton({ id, name }: { id: string; name: string }) {
  const [open, setOpen] = useState(false);
  return (
    <>
      <button type="button" className="btn-apple-secondary" onClick={() => setOpen(true)}>
        Disconnect
      </button>
      <ConfirmDialog
        open={open}
        onClose={() => setOpen(false)}
        title={`Disconnect ${name}?`}
        body="Expenses will stop syncing and Veralify’s access is revoked. Records already sent stay in your accounting software, and your account mapping is kept if you reconnect."
        confirmLabel="Disconnect"
        action={disconnectAction}
        hiddenFields={{ id }}
      />
    </>
  );
}
