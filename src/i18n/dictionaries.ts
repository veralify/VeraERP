import type { Locale } from './config';
import { ar } from './locales/ar';
import { de } from './locales/de';
import { type Dictionary, en } from './locales/en';
import { es } from './locales/es';
import { fr } from './locales/fr';
import { it } from './locales/it';

/** Single source of truth for locale → dictionary, shared by the client LanguageProvider and server pages. */
export const dictionaries: Record<Locale, Dictionary> = { en, es, fr, de, it, ar };
export type { Dictionary };
