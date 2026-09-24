import { RECEIPT_STATUS_LABELS, type ReceiptStatus } from '@lib/money/receipts';
import { AlertTriangle, CheckCircle2, Clock, Eye, Upload } from 'lucide-react';

const STYLE = {
  uploaded: { icon: Upload, classes: 'border-vera-border text-vera-fg-muted' },
  processing: { icon: Clock, classes: 'border-vera-info/40 text-vera-info' },
  extracted: { icon: Eye, classes: 'border-vera-warning/40 text-vera-warning' },
  confirmed: { icon: CheckCircle2, classes: 'border-vera-success/40 text-vera-success' },
  failed: { icon: AlertTriangle, classes: 'border-vera-danger/40 text-vera-danger' },
} as const;

/** Receipt status as icon + word (never colour alone). */
export function ReceiptStatusBadge({ status }: { status: ReceiptStatus }) {
  const { icon: Icon, classes } = STYLE[status];
  return (
    <span
      className={`inline-flex items-center gap-1 rounded-full border px-2 py-0.5 text-xs font-medium ${classes}`}
    >
      <Icon className="h-3 w-3" strokeWidth={2} aria-hidden="true" />
      {RECEIPT_STATUS_LABELS[status]}
    </span>
  );
}
