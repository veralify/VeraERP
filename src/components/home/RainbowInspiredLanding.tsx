'use client';

import { getActiveBrand } from '@config/brands';
import { useEffect, useRef, useState } from 'react';

export function RainbowInspiredLanding() {
  const brand = getActiveBrand();
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const formRef = useRef<HTMLFormElement>(null);
  const [status, setStatus] = useState('');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    let width = 0;
    let height = 0;
    let dpr = 1;
    let stars: {
      x: number;
      y: number;
      r: number;
      depth: number;
      base: number;
      tw: number;
      tws: number;
    }[] = [];

    let mx = 0;
    let my = 0;
    let tx = 0;
    let ty = 0;
    let scrollY = 0;
    let raf = 0;

    const makeStars = () => {
      const count = Math.min(220, Math.round((width * height) / (dpr * dpr) / 6500));
      stars = [];
      for (let i = 0; i < count; i++) {
        const depth = Math.random();
        stars.push({
          x: Math.random() * width,
          y: Math.random() * height,
          r: (depth * 1.5 + 0.35) * dpr,
          depth: depth * 0.9 + 0.1,
          base: 0.35 + depth * 0.6,
          tw: Math.random() * Math.PI * 2,
          tws: 0.4 + Math.random() * 1.6,
        });
      }
    };

    const resize = () => {
      const prevWidth = width;
      const prevHeight = height;
      const prevDpr = dpr;
      dpr = Math.min(window.devicePixelRatio || 1, 2);
      width = canvas.width = Math.floor(window.innerWidth * dpr);
      height = canvas.height = Math.floor(window.innerHeight * dpr);
      canvas.style.width = `${window.innerWidth}px`;
      canvas.style.height = `${window.innerHeight}px`;

      if (stars.length && prevWidth > 0 && prevHeight > 0) {
        // Rescale existing stars proportionally so they stay put on resize
        // instead of being randomly regenerated (which looks like a fast jump).
        const sx = width / prevWidth;
        const sy = height / prevHeight;
        const sr = dpr / prevDpr;
        for (const s of stars) {
          s.x *= sx;
          s.y *= sy;
          s.r *= sr;
        }
      } else {
        makeStars();
      }
    };

    const onMove = (e: MouseEvent) => {
      tx = e.clientX / window.innerWidth - 0.5;
      ty = e.clientY / window.innerHeight - 0.5;
    };
    const onTouch = (e: TouchEvent) => {
      const t = e.touches[0];
      if (!t) return;
      tx = t.clientX / window.innerWidth - 0.5;
      ty = t.clientY / window.innerHeight - 0.5;
    };
    const onScroll = () => {
      scrollY = window.scrollY || window.pageYOffset || 0;
    };

    let t = 0;
    const wrap = (v: number, max: number) => ((v % max) + max) % max;

    const draw = () => {
      t += 0.016;
      mx += (tx - mx) * 0.05;
      my += (ty - my) * 0.05;
      ctx.clearRect(0, 0, width, height);

      const shiftX = mx * 90 * dpr;
      const shiftY = my * 90 * dpr;

      for (const s of stars) {
        const px = wrap(s.x - shiftX * s.depth, width);
        const py = wrap(s.y - shiftY * s.depth - scrollY * dpr * s.depth * 0.35, height);
        const twinkle = 0.65 + 0.35 * Math.sin(t * s.tws + s.tw);
        ctx.globalAlpha = Math.min(1, s.base * twinkle);
        ctx.beginPath();
        ctx.arc(px, py, s.r, 0, Math.PI * 2);
        ctx.fillStyle = '#ffffff';
        ctx.fill();
      }
      ctx.globalAlpha = 1;
      raf = requestAnimationFrame(draw);
    };

    resize();
    onScroll();
    window.addEventListener('resize', resize);
    window.addEventListener('mousemove', onMove);
    window.addEventListener('touchmove', onTouch, { passive: true });
    window.addEventListener('scroll', onScroll, { passive: true });
    raf = requestAnimationFrame(draw);

    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener('resize', resize);
      window.removeEventListener('mousemove', onMove);
      window.removeEventListener('touchmove', onTouch);
      window.removeEventListener('scroll', onScroll);
    };
  }, []);

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const form = event.currentTarget;
    const emailInput = form.elements.namedItem('email') as HTMLInputElement | null;
    const consentInput = form.elements.namedItem('consent') as HTMLInputElement | null;
    const email = emailInput?.value.trim() ?? '';

    if (!email) {
      emailInput?.classList.add('shake');
      setTimeout(() => emailInput?.classList.remove('shake'), 400);
      return;
    }

    const consent = consentInput?.checked ?? false;
    if (!consent) {
      setStatus('Please tick the consent box to join the waitlist.');
      return;
    }

    setLoading(true);
    setStatus('');

    try {
      const res = await fetch('/api/waitlist', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email,
          brand: brand.id,
          consent,
          source: 'waitlist',
          ref: new URLSearchParams(window.location.search).get('ref'),
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Something went wrong.');

      form.reset();
      const params = new URLSearchParams();
      if (data.position) params.set('pos', String(data.position));
      if (data.referralCode) params.set('ref', data.referralCode);
      if (data.alreadySubscribed) params.set('welcome', 'back');
      window.location.href = `/welcome?${params.toString()}`;
    } catch (error) {
      setStatus(error instanceof Error ? error.message : 'Something went wrong.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <main
      className="relative w-full overflow-hidden"
      style={{ backgroundColor: '#05070f', color: 'var(--text-main)' }}
    >
      <section className="relative z-10 flex min-h-screen w-full flex-col items-center justify-center overflow-hidden px-6 text-center">
        <canvas
          ref={canvasRef}
          className="pointer-events-none absolute inset-0 h-full w-full"
          style={{ zIndex: 0 }}
        />

        <div className="relative z-10 flex flex-col items-center">
          <h1 className="text-5xl font-semibold leading-[1.05] tracking-tight md:text-7xl">
            Good things come
            <br />
            <span className="hero-serif italic">to those who wait.</span>
          </h1>
        </div>

        <a
          href="#waitlist"
          aria-label="Scroll down"
          className="scroll-cue absolute bottom-10 left-1/2 -translate-x-1/2 text-white/60 transition hover:text-white"
        >
          <svg className="h-7 w-7" viewBox="0 0 24 24" fill="none" aria-hidden="true">
            <path
              d="M6 9l6 6 6-6"
              stroke="currentColor"
              strokeWidth={2}
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </a>
      </section>

      <section
        id="waitlist"
        className="relative z-10 flex min-h-screen w-full flex-col items-center justify-center px-6 py-16 text-center"
        style={{ backgroundColor: '#05070f' }}
      >
        <div className="pointer-events-none absolute inset-0 overflow-hidden">
          <div className="horizon-glow" />
          <div className="horizon-arc" />
        </div>

        <div className="relative z-10 mx-auto flex w-full max-w-2xl flex-col items-center justify-center text-center">
          <p className="hero-badge inline-flex items-center gap-2 rounded-full border px-4 py-1.5 text-sm font-medium">
            {brand.copy.heroBadge}
          </p>

          <h1 className="mt-8 text-5xl font-semibold leading-[1.05] tracking-tight md:text-7xl">
            {brand.copy.heroTitleLine1}
            <br />
            <span className="hero-serif italic">{brand.copy.heroTitleLine2}</span>
          </h1>

          <p
            className="mx-auto mt-6 max-w-md text-base md:text-lg"
            style={{ color: 'var(--text-muted)' }}
          >
            {brand.copy.heroDescription}
          </p>

          <form
            ref={formRef}
            onSubmit={handleSubmit}
            className="mx-auto mt-10 flex w-full max-w-md items-center gap-2 rounded-xl border p-2"
            style={{
              borderColor: 'rgba(255,255,255,0.12)',
              backgroundColor: 'rgba(255,255,255,0.04)',
            }}
          >
            <input
              type="email"
              id="waitlist-email"
              name="email"
              placeholder="Your Email Address"
              autoComplete="email"
              className="newsletter-input h-11 w-full bg-transparent px-3 text-sm outline-none"
              style={{ color: 'var(--text-main)' }}
              required
            />
            <button
              type="submit"
              disabled={loading}
              className="inline-flex h-11 shrink-0 items-center justify-center gap-2 rounded-lg bg-white px-5 text-sm font-semibold text-black transition hover:bg-white/90"
            >
              {loading && (
                <svg className="h-4 w-4 animate-spin" viewBox="0 0 24 24" aria-hidden="true">
                  <circle
                    cx="12"
                    cy="12"
                    r="9"
                    stroke="currentColor"
                    strokeWidth={3}
                    fill="none"
                    opacity="0.3"
                  />
                  <path
                    d="M21 12a9 9 0 0 0-9-9"
                    stroke="currentColor"
                    strokeWidth={3}
                    fill="none"
                  />
                </svg>
              )}
              <span>{loading ? 'Joining' : 'Get Notified'}</span>
            </button>
          </form>
          <label
            htmlFor="waitlist-consent"
            className="matrix-text mx-auto mt-3 flex max-w-md cursor-pointer items-start gap-2 text-left text-xs"
            style={{ color: 'var(--text-muted)' }}
          >
            <input
              type="checkbox"
              id="waitlist-consent"
              name="consent"
              className="mt-0.5 h-3.5 w-3.5 shrink-0"
              style={{ accentColor: brand.theme.primary }}
            />
            <span>
              I agree to receive product and launch updates from Veralify Ltd and accept the{' '}
              <a
                href="/privacy"
                target="_blank"
                rel="noopener noreferrer"
                className="underline hover:opacity-80"
              >
                Privacy Policy
              </a>
              .
            </span>
          </label>
          <p className="mt-3 text-xs" style={{ color: 'var(--text-muted)' }}>
            {status}
          </p>
        </div>
      </section>
    </main>
  );
}
