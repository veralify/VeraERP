'use client';

import { useTheme } from './ThemeProvider';

export function ThemeToggle() {
  const { theme, toggle, ready } = useTheme();
  const isNight = theme === 'night';

  return (
    <button
      type="button"
      onClick={toggle}
      aria-label={isNight ? 'Switch to day mode' : 'Switch to night mode'}
      title={isNight ? 'Switch to day mode' : 'Switch to night mode'}
      className="inline-flex h-9 w-9 items-center justify-center rounded-full border transition-colors hover:bg-white/10"
      style={{
        borderColor: 'var(--surface-border)',
        backgroundColor: 'var(--surface)',
        color: 'var(--text-main)',
        // Avoid a wrong-icon flash before the client reconciles the stored mode.
        opacity: ready ? 1 : 0,
      }}
    >
      {isNight ? (
        // Moon
        <svg className="h-[18px] w-[18px]" viewBox="0 0 24 24" fill="none" aria-hidden="true">
          <path
            d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8Z"
            stroke="currentColor"
            strokeWidth={1.8}
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      ) : (
        // Sun
        <svg className="h-[18px] w-[18px]" viewBox="0 0 24 24" fill="none" aria-hidden="true">
          <circle cx="12" cy="12" r="4.2" stroke="currentColor" strokeWidth={1.8} />
          <path
            d="M12 2.5v2.2M12 19.3v2.2M4.6 4.6l1.6 1.6M17.8 17.8l1.6 1.6M2.5 12h2.2M19.3 12h2.2M4.6 19.4l1.6-1.6M17.8 6.2l1.6-1.6"
            stroke="currentColor"
            strokeWidth={1.8}
            strokeLinecap="round"
          />
        </svg>
      )}
    </button>
  );
}
