import { useState, useEffect, useRef } from 'react';
import { ItemSearch } from '@components/search/ItemSearch';
import { ScrambleText } from '@components/search/ScrambleText';

export function NavSearch() {
  const [open, setOpen] = useState(false);
  const overlayRef = useRef<HTMLDivElement>(null);

  // Close on Escape
  useEffect(() => {
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false);
    };
    document.addEventListener('keydown', handleKey);
    return () => document.removeEventListener('keydown', handleKey);
  }, []);

  // Lock body scroll when overlay is open
  useEffect(() => {
    document.body.style.overflow = open ? 'hidden' : '';
    return () => { document.body.style.overflow = ''; };
  }, [open]);

  return (
    <>
      {/* Trigger button */}
      <button
        type="button"
        onClick={() => setOpen(true)}
        aria-label="Search lost and stolen items"
        className="matrix-text inline-flex items-center gap-2 rounded-xl border px-3 py-2 text-xs font-semibold transition hover:brightness-125"
        style={{
          borderColor: 'var(--surface-border)',
          color: 'var(--text-muted)',
          backgroundColor: 'transparent',
        }}
      >
        <svg viewBox="0 0 24 24" className="h-4 w-4 shrink-0" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
          <circle cx="11" cy="11" r="8" />
          <path d="m21 21-4.35-4.35" />
        </svg>
        <span className="hidden sm:inline">Search</span>
      </button>

      {/* Full-screen overlay */}
      {open && (
        <div
          ref={overlayRef}
          className="fixed inset-0 z-50 flex flex-col overflow-y-auto"
          style={{ backgroundColor: 'var(--page-bg)' }}
          onClick={(e) => { if (e.target === overlayRef.current) setOpen(false); }}
        >
          {/* Glow decoration */}
          <div className="pointer-events-none absolute inset-0 overflow-hidden">
            <div
              className="absolute left-1/2 top-0 h-72 w-72 -translate-x-1/2 rounded-full blur-3xl"
              style={{ backgroundColor: 'rgba(232,65,37,0.18)' }}
            />
          </div>

          {/* Header bar */}
          <div
            className="sticky top-0 z-10 flex items-center justify-between border-b px-6 py-4"
            style={{
              borderColor: 'var(--surface-border)',
              backgroundColor: 'var(--page-bg)',
            }}
          >
            <div className="flex items-center gap-2">
              <svg viewBox="0 0 24 24" className="h-5 w-5 shrink-0" fill="none" stroke="currentColor" strokeWidth="2" style={{ color: '#3b82f6' }} aria-hidden="true">
                <circle cx="11" cy="11" r="8" />
                <path d="m21 21-4.35-4.35" />
              </svg>
              <span className="matrix-heading text-sm font-semibold" style={{ color: 'var(--text-main)' }}>
                Search
              </span>
            </div>
            <button
              type="button"
              onClick={() => setOpen(false)}
              aria-label="Close search"
              className="matrix-text inline-flex h-8 w-8 items-center justify-center rounded-full border text-xs transition hover:brightness-125"
              style={{
                borderColor: 'var(--surface-border)',
                color: 'var(--text-muted)',
              }}
            >
              ✕
            </button>
          </div>

          {/* Content */}
          <div className="relative mx-auto w-full max-w-6xl flex-1 px-6 py-10">
            <div className="mb-8 text-center">
              <p className="matrix-heading text-3xl font-semibold md:text-4xl" style={{ color: 'var(--text-main)' }}>
                <ScrambleText text="Search Lost & Stolen Items" trigger={open} />
              </p>
              <p
                className="matrix-text mx-auto mt-3 max-w-xl text-xs md:text-sm"
                style={{ color: 'var(--text-muted)' }}
              >
                Search across Veralify and trusted public databases like BikeIndex to find reported stolen items.
              </p>
            </div>
            <ItemSearch />
          </div>
        </div>
      )}
    </>
  );
}
