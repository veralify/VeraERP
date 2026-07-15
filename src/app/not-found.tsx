import { NotFoundContent } from '@components/legal/NotFoundContent';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Page Not Found',
  description: 'Page not found',
};

export default function NotFound() {
  return <NotFoundContent />;
}
