import { useState } from 'react';

type Bike = {
  id: number;
  title: string;
  serial: string;
  status: string;
  stolen: boolean;
  stolen_location: string | null;
  large_img: string | null;
  thumb: string | null;
  url: string;
  manufacturer_name: string;
  frame_model: string | null;
  year: number | null;
  frame_colors: string[];
  date_stolen: number | null;
};

function formatDate(unix: number | null): string {
  if (!unix) return 'Unknown date';
  return new Date(unix * 1000).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
}

function BikeCard({ bike }: { bike: Bike }) {
  const statusColor =
    bike.status === 'stolen'
      ? { bg: 'rgba(239,68,68,0.15)', border: 'rgba(239,68,68,0.4)', text: '#fca5a5' }
      : bike.status === 'found'
        ? { bg: 'rgba(34,197,94,0.15)', border: 'rgba(34,197,94,0.4)', text: '#86efac' }
        : { bg: 'rgba(232,65,37,0.1)', border: 'rgba(232,65,37,0.3)', text: '#ffb5a8' };

  return (
    <a
      href={bike.url}
      target="_blank"
      rel="noopener noreferrer"
      className="group flex flex-col overflow-hidden rounded-2xl border transition-all duration-200 hover:brightness-110"
      style={{
        borderColor: 'var(--surface-border)',
        backgroundColor: 'var(--surface-elevated)',
        textDecoration: 'none',
      }}
    >
      {/* Image */}
      <div
        className="relative flex h-44 w-full items-center justify-center overflow-hidden"
        style={{ backgroundColor: 'var(--item-bg)' }}
      >
        {bike.thumb || bike.large_img ? (
          <img
            src={bike.thumb || bike.large_img!}
            alt={bike.title}
            className="h-full w-full object-cover transition-transform duration-300 group-hover:scale-105"
          />
        ) : (
          <svg
            viewBox="0 0 64 64"
            className="h-16 w-16 opacity-20"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
          >
            <circle cx="16" cy="44" r="12" />
            <circle cx="48" cy="44" r="12" />
            <path d="M16 44 L32 16 L48 44" />
            <path d="M24 28 L40 28" />
            <circle cx="32" cy="16" r="4" />
          </svg>
        )}

        {/* Status badge */}
        <span
          className="matrix-text absolute left-3 top-3 rounded-full px-2 py-0.5 text-[10px] font-semibold uppercase"
          style={{
            backgroundColor: statusColor.bg,
            border: `1px solid ${statusColor.border}`,
            color: statusColor.text,
          }}
        >
          {bike.status}
        </span>
      </div>

      {/* Content */}
      <div className="flex flex-1 flex-col gap-2 p-4">
        <p className="matrix-heading text-sm font-semibold leading-tight" style={{ color: 'var(--text-main)' }}>
          {bike.title}
        </p>

        <div className="matrix-text space-y-1 text-xs" style={{ color: 'var(--text-muted)' }}>
          {bike.stolen_location && (
            <p className="flex items-center gap-1.5">
              <span style={{ color: '#3b82f6' }}>📍</span>
              {bike.stolen_location}
            </p>
          )}
          {bike.serial && bike.serial !== 'Hidden' && (
            <p className="flex items-center gap-1.5">
              <span style={{ color: '#3b82f6' }}>#</span>
              {bike.serial}
            </p>
          )}
          {bike.date_stolen && bike.stolen && (
            <p className="flex items-center gap-1.5">
              <span style={{ color: '#3b82f6' }}>📅</span>
              Stolen {formatDate(bike.date_stolen)}
            </p>
          )}
          {bike.frame_colors?.length > 0 && (
            <p className="flex items-center gap-1.5">
              <span style={{ color: '#3b82f6' }}>🎨</span>
              {bike.frame_colors.join(', ')}
            </p>
          )}
        </div>

        {/* Footer: source badge */}
        <div className="mt-auto flex items-center justify-between pt-3">
          <span
            className="matrix-text inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-[10px] font-semibold"
            style={{
              borderColor: 'rgba(232,65,37,0.35)',
              backgroundColor: 'rgba(232,65,37,0.08)',
              color: '#ffb5a8',
            }}
          >
            <svg viewBox="0 0 16 16" className="h-3 w-3 fill-current" aria-hidden="true">
              <circle cx="8" cy="8" r="7" stroke="currentColor" strokeWidth="1.5" fill="none" />
              <path d="M5 8a3 3 0 1 0 6 0 3 3 0 0 0-6 0z" />
            </svg>
            BikeIndex
          </span>
          <span
            className="matrix-text text-[10px] opacity-50 transition-opacity group-hover:opacity-100"
            style={{ color: 'var(--text-muted)' }}
          >
            View →
          </span>
        </div>
      </div>
    </a>
  );
}

export function ItemSearch() {
  const [query, setQuery] = useState('');
  const [bikes, setBikes] = useState<Bike[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [searched, setSearched] = useState(false);
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(false);

  const runSearch = async (searchQuery: string, searchPage: number) => {
    setLoading(true);
    setError(null);

    try {
      const res = await fetch(
        `/api/search/bikes?q=${encodeURIComponent(searchQuery)}&page=${searchPage}`,
      );
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Search failed');

      const results: Bike[] = data.bikes || [];
      if (searchPage === 1) {
        setBikes(results);
      } else {
        setBikes((prev) => [...prev, ...results]);
      }
      setHasMore(results.length === 12);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Search failed');
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!query.trim()) return;
    setSearched(true);
    setPage(1);
    await runSearch(query.trim(), 1);
  };

  const handleLoadMore = async () => {
    const nextPage = page + 1;
    setPage(nextPage);
    await runSearch(query.trim(), nextPage);
  };

  return (
    <div className="w-full">
      {/* Search bar */}
      <form
        onSubmit={handleSearch}
        className="mx-auto flex w-full max-w-2xl items-center gap-2 rounded-full border p-1.5"
        style={{
          borderColor: 'var(--surface-border)',
          backgroundColor: 'var(--page-bg)',
        }}
      >
        <svg
          viewBox="0 0 24 24"
          className="ml-3 h-4 w-4 shrink-0 opacity-40"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          aria-hidden="true"
        >
          <circle cx="11" cy="11" r="8" />
          <path d="m21 21-4.35-4.35" />
        </svg>
        <input
          type="text"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search for a lost or stolen bike..."
          className="search-input h-10 w-full bg-transparent px-2 text-sm outline-none"
          style={{ color: 'var(--text-main)' }}
        />
        <button
          type="submit"
          disabled={loading || !query.trim()}
          className="matrix-text inline-flex h-10 shrink-0 items-center justify-center gap-2 rounded-full px-5 text-xs font-semibold text-white transition hover:brightness-110 disabled:opacity-50"
          style={{ backgroundColor: '#3b82f6' }}
        >
          {loading && page === 1 ? (
            <>
              <svg className="h-3.5 w-3.5 animate-spin" viewBox="0 0 24 24" aria-hidden="true">
                <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="3" fill="none" opacity="0.3" />
                <path d="M21 12a9 9 0 0 0-9-9" stroke="currentColor" strokeWidth="3" fill="none" />
              </svg>
              Searching
            </>
          ) : (
            'Search'
          )}
        </button>
      </form>

      {/* Error */}
      {error && (
        <p className="matrix-text mt-4 text-center text-xs" style={{ color: '#fca5a5' }}>
          {error}
        </p>
      )}

      {/* Empty state */}
      {searched && !loading && !error && bikes.length === 0 && (
        <p className="matrix-text mt-8 text-center text-sm" style={{ color: 'var(--text-muted)' }}>
          No results found for &ldquo;{query}&rdquo;
        </p>
      )}

      {/* Results grid */}
      {bikes.length > 0 && (
        <div className="mt-8">
          <p className="matrix-text mb-4 text-center text-xs" style={{ color: 'var(--text-muted)' }}>
            {bikes.length} result{bikes.length !== 1 ? 's' : ''} — click any card to view on source
          </p>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {bikes.map((bike) => (
              <BikeCard key={bike.id} bike={bike} />
            ))}
          </div>

          {/* Load more */}
          {hasMore && (
            <div className="mt-8 text-center">
              <button
                type="button"
                onClick={handleLoadMore}
                disabled={loading}
                className="matrix-text inline-flex h-10 items-center gap-2 rounded-full border px-6 text-xs font-semibold transition hover:brightness-110 disabled:opacity-50"
                style={{
                  borderColor: 'var(--surface-border)',
                  color: 'var(--text-muted)',
                }}
              >
                {loading ? (
                  <>
                    <svg className="h-3.5 w-3.5 animate-spin" viewBox="0 0 24 24" aria-hidden="true">
                      <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="3" fill="none" opacity="0.3" />
                      <path d="M21 12a9 9 0 0 0-9-9" stroke="currentColor" strokeWidth="3" fill="none" />
                    </svg>
                    Loading
                  </>
                ) : (
                  'Load more'
                )}
              </button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
