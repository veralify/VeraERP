'use client';

import { X } from 'lucide-react';
import { type ReactNode, useEffect, useState } from 'react';
import { createPortal } from 'react-dom';

/**
 * Token-styled portal dialog — the app's only prior modal (`AuthModal`) is
 * styled off the legacy `--surface`/`--brand-primary` CSS vars, not the
 * `vera-*` token system, so it isn't reusable as-is. This one is generic:
 * pass `title` + `children`.
 */
export function Modal({
  open,
  onClose,
  title,
  children,
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
}) {
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, onClose]);

  if (!open || !mounted) return null;

  return createPortal(
    <div className="fixed inset-0 z-[100] flex items-center justify-center overflow-y-auto p-4">
      <button
        type="button"
        aria-label="Close dialog"
        onClick={onClose}
        className="absolute inset-0 h-full w-full cursor-default bg-black/60 backdrop-blur-sm"
      />
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="vera-modal-title"
        className="relative w-full max-w-[480px] rounded-vera-2xl border border-vera-border bg-vera-surface p-6 shadow-[var(--vera-shadow-md)]"
      >
        <div className="flex items-start justify-between gap-4">
          <h2 id="vera-modal-title" className="text-xl font-bold">
            {title}
          </h2>
          <button
            type="button"
            onClick={onClose}
            aria-label="Close"
            className="rounded-vera-md p-1.5 text-vera-fg-subtle transition-colors hover:bg-vera-surface-muted hover:text-vera-fg"
          >
            <X className="h-5 w-5" strokeWidth={1.75} />
          </button>
        </div>
        <div className="mt-5">{children}</div>
      </div>
    </div>,
    document.body,
  );
}
