// The normalised merchant name that rules, duplicate checks and reports key on.
//
// Defined in money-manager-ios/docs/RECEIPTS_CONTRACTS.md §4 and implemented
// twice: here, and in Swift as `MerchantKey` in VeralifyCore. Both are tested
// against tests/fixtures/merchant_keys.json, and a test here fails if the
// Swift copy of that table drifts, so a rule learned on the phone matches the
// receipt the gateway reads.

/** Legal-form suffixes dropped from the end, as token sequences. */
const LEGAL_SUFFIXES: readonly (readonly string[])[] = [
  ['srl'],
  ['s', 'r', 'l'],
  ['spa'],
  ['s', 'p', 'a'],
  ['snc'],
  ['sas'],
  ['ltd'],
  ['limited'],
  ['plc'],
  ['llp'],
  ['inc'],
  ['llc'],
  ['gmbh'],
];

/**
 * `"ESSELUNGA S.p.A."` → `"esselunga"`, `"Marks & Spencer PLC"` → `"marks and spencer"`.
 *
 * "Alphanumeric" means any Unicode letter or number, not just ASCII: the app
 * is used in Arabic too, and an ASCII-only key would collapse every Arabic
 * merchant name to the empty string — and so to the same merchant.
 */
export function merchantKey(name: string): string {
  const folded = name
    .toLowerCase()
    .normalize('NFKD')
    .replace(/\p{M}/gu, '')
    .replaceAll('&', ' and ');
  const tokens = folded.split(/[^\p{L}\p{N}]+/u).filter((t) => t.length > 0);

  // Repeated, because a name can carry two ("Foo Ltd Inc"), but never down to
  // nothing: a business literally called "SPA" keeps its name.
  let stripped = true;
  while (stripped) {
    stripped = false;
    for (const suffix of LEGAL_SUFFIXES) {
      if (tokens.length > suffix.length && endsWith(tokens, suffix)) {
        tokens.splice(tokens.length - suffix.length, suffix.length);
        stripped = true;
        break;
      }
    }
  }
  return tokens.join(' ');
}

function endsWith(tokens: string[], suffix: readonly string[]): boolean {
  const offset = tokens.length - suffix.length;
  return suffix.every((part, i) => tokens[offset + i] === part);
}
