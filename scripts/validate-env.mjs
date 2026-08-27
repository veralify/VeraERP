#!/usr/bin/env node

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const ALL_VARS = [
  'NEXT_PUBLIC_SUPABASE_URL',
  'NEXT_PUBLIC_SUPABASE_ANON_KEY',
  'SUPABASE_SERVICE_ROLE_KEY',
  'OPENROUTER_API_KEY',
  'AGORA_APP_ID',
  'AGORA_APP_CERTIFICATE',
  'STRIPE_SECRET_KEY',
  'STRIPE_WEBHOOK_SECRET',
  'APPLE_IAP_KEY_ID',
  'APPLE_IAP_ISSUER_ID',
  'APPLE_IAP_PRIVATE_KEY',
  'APPLE_BUNDLE_ID',
  'APNS_KEY_ID',
  'APNS_TEAM_ID',
  'APNS_PRIVATE_KEY',
  'NEXT_PUBLIC_POSTHOG_KEY',
  'SENTRY_DSN',
  'NEXT_PUBLIC_SENTRY_DSN',
  'FOOD_DATA_PROVIDER_KEY',
  'RESEND_API_KEY',
];

const TIERS = {
  'web-public': [
    'NEXT_PUBLIC_SUPABASE_URL',
    'NEXT_PUBLIC_SUPABASE_ANON_KEY',
    'NEXT_PUBLIC_POSTHOG_KEY',
    'NEXT_PUBLIC_SENTRY_DSN',
  ],
  'web-server': [
    'NEXT_PUBLIC_SUPABASE_URL',
    'NEXT_PUBLIC_SUPABASE_ANON_KEY',
    'SUPABASE_SERVICE_ROLE_KEY',
    'STRIPE_SECRET_KEY',
    'STRIPE_WEBHOOK_SECRET',
    'RESEND_API_KEY',
    'SENTRY_DSN',
  ],
  'edge-functions': [
    'SUPABASE_SERVICE_ROLE_KEY',
    'OPENROUTER_API_KEY',
    'AGORA_APP_ID',
    'AGORA_APP_CERTIFICATE',
    'APPLE_IAP_KEY_ID',
    'APPLE_IAP_ISSUER_ID',
    'APPLE_IAP_PRIVATE_KEY',
    'APPLE_BUNDLE_ID',
    'APNS_KEY_ID',
    'APNS_TEAM_ID',
    'APNS_PRIVATE_KEY',
    'STRIPE_SECRET_KEY',
    'STRIPE_WEBHOOK_SECRET',
    'RESEND_API_KEY',
    'FOOD_DATA_PROVIDER_KEY',
    'SENTRY_DSN',
  ],
};

function usage() {
  console.error(
    'Usage: node scripts/validate-env.mjs [dotenv-file] [--tier web-public|web-server|edge-functions] [--soft]',
  );
}

function parseDotenv(path) {
  const env = {};
  const contents = readFileSync(resolve(path), 'utf8');
  for (const rawLine of contents.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;
    const match = line.match(/^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/);
    if (!match) continue;
    let value = match[2].trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    env[match[1]] = value;
  }
  return env;
}

const args = process.argv.slice(2);
let tier = 'web-server';
let soft = false;
let dotenvPath;

for (let i = 0; i < args.length; i += 1) {
  const arg = args[i];
  if (arg === '--soft') {
    soft = true;
  } else if (arg === '--tier') {
    tier = args[i + 1];
    i += 1;
  } else if (arg.startsWith('--tier=')) {
    tier = arg.slice('--tier='.length);
  } else if (arg === '--help' || arg === '-h') {
    usage();
    process.exit(0);
  } else if (!arg.startsWith('--') && !dotenvPath) {
    dotenvPath = arg;
  } else {
    console.error(`Unknown argument: ${arg}`);
    usage();
    process.exit(2);
  }
}

if (!Object.hasOwn(TIERS, tier)) {
  console.error(`Unknown tier: ${tier}`);
  usage();
  process.exit(2);
}

const fileEnv = dotenvPath ? parseDotenv(dotenvPath) : {};
const mergedEnv = { ...process.env, ...fileEnv };
const required = new Set(TIERS[tier]);
const rows = ALL_VARS.map((name) => ({
  name,
  required: required.has(name),
  status: mergedEnv[name] ? 'SET' : 'MISSING',
}));

console.log(`Environment validation tier: ${tier}${soft ? ' (soft)' : ''}`);
if (dotenvPath) console.log(`Dotenv file: ${dotenvPath}`);
console.table(
  rows.map((row) => ({
    Name: row.name,
    Required: row.required ? 'yes' : 'no',
    Status: row.status,
  })),
);

const missingRequired = rows
  .filter((row) => row.required && row.status === 'MISSING')
  .map((row) => row.name);
if (missingRequired.length > 0) {
  console.error(`Missing required variables for ${tier}: ${missingRequired.join(', ')}`);
  process.exit(soft ? 0 : 1);
}

console.log(`All required variables for ${tier} are set.`);
