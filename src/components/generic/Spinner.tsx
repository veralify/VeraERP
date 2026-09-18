import { Loader2 } from 'lucide-react';

const sizes = {
  sm: 'h-4 w-4',
  md: 'h-5 w-5',
  lg: 'h-8 w-8',
} as const;

/**
 * Inline loading spinner (Lucide `Loader2`, CSS-spun — no client boundary
 * needed). Use inside disabled submit buttons and section loading states.
 */
export function Spinner({
  size = 'md',
  className = '',
  label = 'Loading',
}: {
  size?: keyof typeof sizes;
  className?: string;
  label?: string;
}) {
  return (
    <span role="status" className="inline-flex items-center">
      <Loader2
        className={`animate-spin text-current ${sizes[size]} ${className}`}
        aria-hidden="true"
      />
      <span className="sr-only">{label}</span>
    </span>
  );
}
