import { TermsContent } from '@components/legal/TermsContent';
import { getActiveBrand } from '@config/brands';
import type { Metadata } from 'next';

const brand = getActiveBrand();

export const metadata: Metadata = {
  title: 'Terms of Service',
  description: `The terms governing your use of ${brand.name}.`,
};

export default function TermsPage() {
  return <TermsContent />;
}
