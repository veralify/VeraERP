import { RainbowInspiredLanding } from '@components/home/RainbowInspiredLanding';
import { getActiveBrand } from '@config/brands';
import type { Metadata } from 'next';

const brand = getActiveBrand();

export const metadata: Metadata = {
  title: `${brand.name} | Coming Soon`,
  description: `Sign up to get upcoming ${brand.name} updates.`,
};

export default function HomePage() {
  return <RainbowInspiredLanding />;
}
