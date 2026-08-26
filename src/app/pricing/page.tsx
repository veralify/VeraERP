import { PricingContent } from '@components/billing/PricingContent';
import { getActiveBrand } from '@config/brands';
import type { Metadata } from 'next';

const brand = getActiveBrand();

export const metadata: Metadata = {
  title: 'Pricing',
  description: `Plans and pricing for ${brand.name}.`,
};

export default function PricingPage() {
  return <PricingContent />;
}
