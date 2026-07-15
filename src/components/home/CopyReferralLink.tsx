'use client';

import { useLanguage } from '@i18n/LanguageProvider';
import { useState } from 'react';

type Props = {
  referralUrl: string;
  primaryColor: string;
};

export function CopyReferralLink({ referralUrl, primaryColor }: Props) {
  const { t } = useLanguage();
  const [copied, setCopied] = useState(false);

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(referralUrl);
    } catch {
      /* ignore */
    }
    setCopied(true);
    setTimeout(() => setCopied(false), 1800);
  };

  return (
    <div
      className="mt-6 flex items-center gap-2 rounded-full border p-1.5"
      style={{ borderColor: 'var(--surface-border)', backgroundColor: 'var(--page-bg)' }}
    >
      <input
        type="text"
        readOnly
        value={referralUrl}
        className="h-9 w-full bg-transparent px-3 text-sm outline-none"
        style={{ color: 'var(--text-main)' }}
      />
      <button
        type="button"
        onClick={copy}
        className="matrix-text inline-flex h-9 shrink-0 items-center justify-center rounded-full px-4 text-xs font-semibold text-white transition hover:brightness-110"
        style={{ backgroundColor: primaryColor }}
      >
        {copied ? t.welcome.copied : t.welcome.copy}
      </button>
    </div>
  );
}
