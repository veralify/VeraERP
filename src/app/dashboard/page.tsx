import { NewsletterControl } from '@components/dashboard/NewsletterControl';
import { getActiveBrand } from '@config/brands';
import type { Metadata } from 'next';

const brand = getActiveBrand();

export const metadata: Metadata = {
  title: `${brand.name} Dashboard`,
  description: `Admin dashboard for ${brand.name} email campaigns and operations.`,
};

export default function DashboardPage() {
  return (
    <main
      className="px-6 pb-40 pt-10"
      style={{ backgroundColor: 'var(--page-bg)', color: 'var(--text-main)' }}
    >
      <NewsletterControl />
    </main>
  );
}
