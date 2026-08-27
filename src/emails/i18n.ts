import { defaultLocale, isLocale, type Locale, localeMeta } from '@i18n/config';

export type EmailStrings = {
  welcome: {
    subject: string;
    preview: string;
    heroTitleLine1: string;
    heroTitleLine2: string;
    greeting: string;
    onList: string;
    building: string;
    bullet1: string;
    bullet2: string;
    bullet3: string;
    redefining: string;
    positionLabel: string;
    moveUp: string;
    inviteLabel: string;
    closingLine: string;
    signoff: string;
    teamLine: string;
  };
  referral: {
    subject: string;
    preview: string;
    heroTitleLine1: string;
    heroTitleLine2: string;
    greeting: string;
    friendJoined: string;
    positionLabel: string;
    friendsCountOne: string;
    friendsCountMany: string;
    keepClimbing: string;
    inviteLabel: string;
    signoff: string;
    teamLine: string;
  };
  common: {
    logoAlt: string;
    company: string;
    receiving: string;
    unsubscribe: string;
  };
};

const baseEmailStrings: EmailStrings = {
  welcome: {
    subject: "Welcome to {brand} — you're on the list",
    preview: "You're #{position} on the {brand} waitlist — invite friends to move up.",
    heroTitleLine1: 'Track. Connect.',
    heroTitleLine2: 'Transform.',
    greeting: 'Hey 👋',
    onList: "You're officially on the {brand} waitlist — thank you for joining us early.",
    building:
      "We're building AI-powered fitness accountability: food and nutrition tracking, progress goals, communities, live rooms, messaging, coach discovery, and personal insights in one Pro experience.",
    bullet1: '🥗 AI-assisted food and nutrition tracking.',
    bullet2: '🤝 Communities and live rooms for accountability.',
    bullet3: '💪 Coach discovery and progress insights.',
    redefining:
      "We're making consistency easier by connecting daily tracking to people and guidance that help members keep going.",
    positionLabel: 'Your position on the waitlist',
    moveUp:
      '**Want to move up?** The higher you climb, the sooner you get in — and the **top 100** unlock an **exclusive launch discount code**. Every friend who joins with your link bumps you up the list.',
    inviteLabel: 'Your personal invite link:',
    closingLine: 'Start with tracking. Stay for accountability.',
    signoff: 'Talk soon,',
    teamLine: 'The {brand} team ·',
  },
  referral: {
    subject: '🎉 A friend just joined {brand} — you moved up',
    preview: "🎉 A friend just joined {brand} with your link — you're now #{position}.",
    heroTitleLine1: 'You just moved',
    heroTitleLine2: 'up the list. 🎉',
    greeting: 'Great news 🎉',
    friendJoined:
      "A friend just joined the {brand} waitlist using **your invite link** — thank you for spreading the word! You've moved up the list.",
    positionLabel: 'Your new position on the waitlist',
    friendsCountOne: '1 friend joined with your link',
    friendsCountMany: '{count} friends joined with your link',
    keepClimbing:
      '**Keep climbing.** The **top 100** unlock an **exclusive launch discount code** — every friend who joins with your link bumps you higher.',
    inviteLabel: 'Your personal invite link:',
    signoff: 'Talk soon,',
    teamLine: 'The {brand} team ·',
  },
  common: {
    logoAlt: '{brand} logo',
    company: 'VERALIFY LTD · Company Number 17332341 · Registered in England and Wales.',
    receiving: 'You are receiving this because you joined our waitlist.',
    unsubscribe: 'Unsubscribe',
  },
};

export const emailStrings: Record<Locale, EmailStrings> = {
  en: baseEmailStrings,
  es: baseEmailStrings,
  fr: baseEmailStrings,
  de: baseEmailStrings,
  it: baseEmailStrings,
  ar: baseEmailStrings,
};

export function getEmailStrings(locale?: string | null): EmailStrings {
  return emailStrings[isLocale(locale) ? locale : defaultLocale];
}

export function getEmailDir(locale?: string | null): 'ltr' | 'rtl' {
  return localeMeta[isLocale(locale) ? locale : defaultLocale].dir;
}

export function fmt(template: string, vars: Record<string, string | number>): string {
  return template.replace(/\{(\w+)\}/g, (_, key) => (key in vars ? String(vars[key]) : `{${key}}`));
}
