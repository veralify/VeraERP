import { PrivacyContent } from '@components/legal/PrivacyContent';
import { getActiveBrand } from '@config/brands';
import type { Metadata } from 'next';

const brand = getActiveBrand();

export const metadata: Metadata = {
  title: 'Privacy Policy',
  description: `How ${brand.name} collects, uses, and protects your personal data.`,
};

export default function PrivacyPage() {
  return <PrivacyContent />;
}
