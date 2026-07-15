import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Page Not Found',
  description: 'Page not found',
};

export default function NotFound() {
  return (
    <main className="bg-blue-theme px-6 py-24">
      <section className="flex flex-col gap-8 justify-between">
        <p className="text-9xl font-bold dm-serif">404</p>
        <h2 className="text-4xl outfit">Page Not Found</h2>
        <p className="text-xl sm:text-3xl sanchez">
          Sorry, we couldn&apos;t find the page you were looking for.
        </p>
        <a
          href="/"
          title="Go back home"
          className="w-48 border-2 border-black px-4 py-2 text-center transition-colors duration-150 ease-in-out hover:bg-red-300 poppins"
        >
          &larr; Go Home
        </a>
      </section>
    </main>
  );
}
