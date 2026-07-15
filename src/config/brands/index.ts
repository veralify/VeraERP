import type { BrandConfig, BrandId } from './types';
import { veralifyBrand } from './veralify';

const brands: Record<BrandId, BrandConfig> = {
  veralify: veralifyBrand,
};

const envBrand = (process.env.NEXT_PUBLIC_BRAND || 'veralify').toLowerCase();

export const activeBrand = brands[(envBrand as BrandId) || 'veralify'] || veralifyBrand;
export const getActiveBrand = () => activeBrand;
export const getBrandById = (brandId: BrandId) => brands[brandId];
