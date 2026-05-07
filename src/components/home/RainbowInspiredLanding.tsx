export default function RainbowInspiredLanding() {
  return (
    <main className='relative min-h-[78vh] overflow-hidden bg-[#07070b] px-6 py-20 text-white'>
      <div className='pointer-events-none absolute inset-0'>
        <div className='absolute -top-28 left-1/2 h-80 w-80 -translate-x-1/2 rounded-full bg-fuchsia-500/30 blur-3xl' />
        <div className='absolute bottom-0 left-10 h-72 w-72 rounded-full bg-cyan-400/20 blur-3xl' />
        <div className='absolute right-8 top-28 h-64 w-64 rounded-full bg-violet-500/25 blur-3xl' />
      </div>

      <section className='relative mx-auto w-full max-w-4xl rounded-3xl border border-white/15 bg-white/5 p-8 shadow-2xl backdrop-blur-xl md:p-12'>
        <p className='inline-flex rounded-full border border-white/20 bg-white/10 px-3 py-1 text-xs font-medium uppercase tracking-wider text-white/85'>
          Veralify
        </p>
        <p className='mt-4 text-sm font-semibold uppercase tracking-[0.18em] text-fuchsia-300'>
          Coming Soon
        </p>
        <h1 className='mt-5 text-4xl font-semibold tracking-tight md:text-6xl'>
          Verify ownership.
          <br />
          Buy with confidence.
        </h1>
        <p className='mt-4 max-w-2xl text-base text-white/70 md:text-lg'>
          Follow Veralify on X for launch updates and early announcements.
        </p>

        <a
          href='https://x.com/Veralify'
          target='_blank'
          rel='noopener noreferrer'
          className='mt-8 inline-flex rounded-xl bg-gradient-to-r from-fuchsia-500 via-purple-500 to-cyan-400 px-6 py-3 font-semibold text-black transition hover:brightness-110'
        >
          Follow on X
        </a>
      </section>
    </main>
  );
}
