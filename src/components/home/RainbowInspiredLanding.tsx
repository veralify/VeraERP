export default function RainbowInspiredLanding() {
  return (
    <main className='relative overflow-hidden bg-[#05070f] px-6 pb-20 pt-14 text-white md:pt-20'>
      <div className='pointer-events-none absolute inset-0'>
        <div className='absolute left-1/2 top-0 h-[24rem] w-[24rem] -translate-x-1/2 rounded-full bg-[#E84125]/25 blur-3xl' />
        <div className='absolute -left-20 top-40 h-72 w-72 rounded-full bg-[#E84125]/20 blur-3xl' />
        <div className='absolute -right-20 bottom-0 h-80 w-80 rounded-full bg-[#E84125]/20 blur-3xl' />
      </div>

      <section className='relative mx-auto grid w-full max-w-6xl gap-10 rounded-3xl border border-white/10 bg-white/[0.03] p-8 shadow-[0_0_120px_rgba(232,65,37,0.22)] backdrop-blur-xl md:grid-cols-2 md:p-12'>
        <div>
          <p className='matrix-text inline-flex items-center rounded-full border border-[#E84125]/40 bg-[#E84125]/15 px-3 py-1 text-xs font-medium tracking-wide text-[#ffb5a8]'>
            Coming Soon
          </p>
          <h1 className='matrix-heading mt-5 text-4xl font-semibold leading-tight tracking-tight md:text-6xl'>
            The trust layer
            <br />
            for physical assets.
          </h1>
          <p className='matrix-text mt-5 max-w-xl text-base text-slate-300 md:text-lg'>
            Veralify helps users verify ownership and risk signals before buying,
            selling, or transferring high-value items.
          </p>

          <div className='mt-8 flex flex-wrap gap-3'>
            <a
              href='https://x.com/Veralify'
              target='_blank'
              rel='noopener noreferrer'
              className='matrix-text inline-flex rounded-xl bg-[#E84125] px-6 py-3 font-semibold text-black transition hover:brightness-110'
            >
              Follow on X
            </a>
          </div>
        </div>

        <div className='rounded-2xl border border-[#E84125]/35 bg-[#120806] p-6'>
          <div className='flex items-center gap-3'>
            <img
              src='/logo.png'
              alt='Veralify logo'
              className='h-12 w-12 rounded-xl object-cover ring-1 ring-white/20'
            />
            <div>
              <p className='matrix-text text-sm text-slate-400'>Veralify Network</p>
              <p className='matrix-heading text-lg font-semibold'>Ownership Verification API</p>
            </div>
          </div>

          <div className='matrix-text mt-6 space-y-3 text-sm text-slate-300'>
            <div className='rounded-lg border border-[#E84125]/30 bg-[#E84125]/10 p-3'>Real-time risk checks</div>
            <div className='rounded-lg border border-[#E84125]/30 bg-[#E84125]/10 p-3'>Stolen item intelligence</div>
            <div className='rounded-lg border border-[#E84125]/30 bg-[#E84125]/10 p-3'>Transfer-ready provenance</div>
          </div>
        </div>
      </section>
    </main>
  );
}
