'use client';

import { useLanguage } from '@i18n/LanguageProvider';

export function NotFoundContent() {
  const { t } = useLanguage();

  return (
    <main className="bg-blue-theme px-6 py-24">
      <section className="flex flex-col gap-8 justify-between">
        <p className="text-9xl font-bold dm-serif">404</p>
        <h2 className="text-4xl outfit">{t.notFound.heading}</h2>
        <p className="text-xl sm:text-3xl sanchez">{t.notFound.message}</p>
        <a
          href="/"
          title={t.notFound.goHome}
          className="w-48 border-2 border-black px-4 py-2 text-center transition-colors duration-150 ease-in-out hover:bg-red-300 poppins"
        >
          &larr; {t.notFound.goHome}
        </a>
      </section>
    </main>
  );
}
