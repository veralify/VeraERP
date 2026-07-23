'use client';

/**
 * Morning-sky background for day mode: a soft blue-to-warm gradient with a
 * glowing sun and slowly drifting clouds. Purely decorative (aria-hidden) and
 * pointer-events-none so it never blocks the hero content. Animations pause
 * under prefers-reduced-motion (handled in globals.css).
 */
export function DaySky({ showSun = true }: { showSun?: boolean }) {
  return (
    <div
      className="day-sky pointer-events-none absolute inset-0 overflow-hidden"
      aria-hidden="true"
    >
      {showSun && <div className="day-sun" />}
      <div className="day-cloud day-cloud-1" />
      <div className="day-cloud day-cloud-2" />
      <div className="day-cloud day-cloud-3" />
      <div className="day-cloud day-cloud-4" />
    </div>
  );
}
