import { useEffect, useRef } from 'react';

const CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789@#$%&!><';
const REVEAL_MS = 130;
const TICK_MS = 48;

type Props = {
  text: string;
  delay?: number;
  /** Change this value to re-trigger the animation (e.g. pass `open` from parent) */
  trigger?: unknown;
  className?: string;
  style?: React.CSSProperties;
};

export function ScrambleText({ text, delay = 0, trigger, className, style }: Props) {
  const elRef = useRef<HTMLSpanElement>(null);

  useEffect(() => {
    const el = elRef.current;
    if (!el) return;

    let nonSpaceIdx = 0;
    const lockAt = [...text].map((c) => (c === ' ' ? -1 : nonSpaceIdx++ * REVEAL_MS));
    const duration = nonSpaceIdx * REVEAL_MS;

    let id: ReturnType<typeof setInterval>;

    const timeoutId = setTimeout(() => {
      const t0 = performance.now();

      id = setInterval(() => {
        const elapsed = performance.now() - t0;
        let html = '';

        for (let i = 0; i < text.length; i++) {
          const ch = text[i];
          if (ch === ' ') { html += ' '; continue; }
          if (elapsed >= lockAt[i]) {
            html += ch;
          } else {
            const progress = elapsed / lockAt[i];
            const opacity = (0.35 + 0.55 * progress).toFixed(2);
            const rand = CHARS[Math.floor(Math.random() * CHARS.length)];
            html += `<span style="color:#3b82f6;opacity:${opacity}">${rand}</span>`;
          }
        }

        el.innerHTML = html;

        if (elapsed >= duration) {
          el.textContent = text;
          clearInterval(id);
        }
      }, TICK_MS);
    }, delay);

    return () => {
      clearTimeout(timeoutId);
      clearInterval(id);
      el.textContent = text;
    };
  // Re-run whenever `trigger` changes (e.g. overlay opens)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [trigger]);

  return (
    <span ref={elRef} className={className} style={style}>
      {text}
    </span>
  );
}
