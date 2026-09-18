import { AlertTriangle, CheckCircle2, Info, type LucideIcon, XCircle } from 'lucide-react';

export type BannerVariant = 'success' | 'error' | 'warning' | 'info';

const variantStyles: Record<
  BannerVariant,
  { icon: LucideIcon; classes: string; role: 'status' | 'alert' }
> = {
  success: {
    icon: CheckCircle2,
    classes: 'border-vera-success/40 bg-vera-success/10 text-vera-success',
    role: 'status',
  },
  error: {
    icon: XCircle,
    classes: 'border-vera-danger/40 bg-vera-danger/10 text-vera-danger',
    role: 'alert',
  },
  warning: {
    icon: AlertTriangle,
    classes: 'border-vera-warning/40 bg-vera-warning/10 text-vera-warning',
    role: 'status',
  },
  info: {
    icon: Info,
    classes: 'border-vera-info/40 bg-vera-info/10 text-vera-info',
    role: 'status',
  },
};

/**
 * Inline success/error/warning/info banner — server-safe (no client
 * boundary), so it renders directly from server components/pages driven by
 * a `?saved=` or `?error=` search param. See
 * design-system/veralify/components/states.md for the empty/error/loading
 * state contract this complements.
 */
export function Banner({
  variant = 'info',
  message,
  className = '',
}: {
  variant?: BannerVariant;
  message?: string;
  className?: string;
}) {
  if (!message) return null;
  const { icon: Icon, classes, role } = variantStyles[variant];

  return (
    <div
      role={role}
      className={`flex items-start gap-3 rounded-vera-md border p-3 text-sm ${classes} ${className}`}
    >
      <Icon className="mt-0.5 h-4 w-4 flex-shrink-0" aria-hidden="true" strokeWidth={2} />
      <p>{message}</p>
    </div>
  );
}
