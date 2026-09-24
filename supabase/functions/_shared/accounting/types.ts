// Shared vocabulary for the accounting integrations (contract §6).
//
// Every provider (QuickBooks Online, Xero, FreeAgent, Fatture in Cloud) is an
// adapter behind `AccountingAdapter`. The edge functions and the sync worker
// only ever talk to this interface, so provider quirks — realm ids, tenant
// headers, SyncTokens, base64 attachments — stay inside the adapter files.

export type AccountingProvider = 'quickbooks' | 'xero' | 'freeagent' | 'fatture_in_cloud';

export const ACCOUNTING_PROVIDERS: readonly AccountingProvider[] = [
  'quickbooks',
  'xero',
  'freeagent',
  'fatture_in_cloud',
];

export function isAccountingProvider(value: unknown): value is AccountingProvider {
  return typeof value === 'string' && (ACCOUNTING_PROVIDERS as readonly string[]).includes(value);
}

/**
 * The OAuth token bundle. Serialised as JSON into one Supabase Vault secret;
 * it never touches a plain column and never leaves the server.
 */
export interface TokenBundle {
  access_token: string;
  refresh_token: string | null;
  /** ISO instant the access token stops working. */
  expires_at: string;
  /** ISO instant the refresh token stops working, when the provider says. */
  refresh_expires_at?: string | null;
  token_type?: string | null;
  scope?: string | null;
}

/** A company / organisation / tenant the token can act on. */
export interface ExternalCompany {
  /** QuickBooks realmId, Xero tenantId, FreeAgent company url, FiC company id. */
  id: string;
  name: string;
  country: string | null;
  currency: string | null;
}

/** An option for the mapping screen: an expense account, a payment account. */
export interface ExternalOption {
  id: string;
  name: string;
  /** Account code / nominal code where the provider has one. */
  code?: string | null;
  /** Provider-specific kind, e.g. QuickBooks "Credit Card", Xero "BANK". */
  type?: string | null;
}

export interface ExternalTaxCode extends ExternalOption {
  /** Percentage, e.g. 22 or 20; null when the provider does not say. */
  rate: number | null;
}

/** One expense line, amounts as decimal strings with two places. */
export interface ExpenseLine {
  description: string;
  /** Expense account / category id, from accounting_mappings (kind category). */
  accountId: string;
  /** Tax code from accounting_mappings (kind tax_rate); null = let the provider decide / no tax. */
  taxCodeId: string | null;
  /** VAT rate the line was booked at, "22" / "20" / "0"; null when unknown. */
  vatRate: string | null;
  net: string;
  tax: string;
  gross: string;
}

/**
 * A money_transactions row, already mapped to the connection's accounts.
 * Built by `buildExpenseDraft` (draft.ts); adapters only translate it.
 */
export interface ExpenseDraft {
  /** money_transactions.id — used as the provider-side reference for traceability. */
  transactionId: string;
  /** YYYY-MM-DD. */
  date: string;
  merchant: string;
  description: string;
  currency: string;
  /** Gross total, decimal string. */
  total: string;
  /** Sum of line tax, decimal string. */
  taxTotal: string;
  /** True when the tax figures are known (a receipt or a user-entered tax amount). */
  taxKnown: boolean;
  lines: ExpenseLine[];
  /** Paid-from account from accounting_mappings (kind payment_account, key "default"). */
  paymentAccountId: string | null;
}

/** What a provider record is called in accounting_links. */
export interface ExternalRecord {
  externalId: string;
  /** e.g. "Purchase", "SPEND", "ACCPAY", "expense", "received_document". */
  externalType: string;
}

export interface ReceiptFile {
  fileName: string;
  contentType: string;
  bytes: Uint8Array;
}

/** Everything an adapter needs to act on one company. */
export interface ConnectionContext {
  companyId: string;
  tokens: TokenBundle;
}

export interface AuthorizeParams {
  state: string;
  redirectUri: string;
  /** S256 PKCE challenge; only passed when the adapter `supportsPkce`. */
  codeChallenge?: string;
}

export interface ExchangeParams {
  code: string;
  redirectUri: string;
  codeVerifier?: string | null;
}

export interface RevokeOptions {
  /**
   * Another connection still uses the same token bundle (Xero and Fatture in
   * Cloud grant one token for several companies). The adapter must then only
   * detach this company, not revoke the whole grant.
   */
  tokenShared: boolean;
}

export interface AccountingAdapter {
  readonly provider: AccountingProvider;
  readonly supportsPkce: boolean;
  /** A paid-from account is mandatory to create an expense (QuickBooks Purchase). */
  readonly requiresPaymentAccount: boolean;
  /** How many receipt pages the provider can hold per record. */
  readonly maxAttachments: number;

  authorizeUrl(params: AuthorizeParams): string;
  exchangeCode(params: ExchangeParams): Promise<TokenBundle>;
  refresh(tokens: TokenBundle): Promise<TokenBundle>;
  /** Best effort; providers without a revocation endpoint resolve immediately. */
  revoke(ctx: ConnectionContext, options: RevokeOptions): Promise<void>;

  /**
   * Companies the fresh token can act on. `callbackParams` carries extras the
   * provider put on the redirect (QuickBooks sends `realmId` there).
   */
  listCompanies(tokens: TokenBundle, callbackParams: URLSearchParams): Promise<ExternalCompany[]>;
  listExpenseAccounts(ctx: ConnectionContext): Promise<ExternalOption[]>;
  listTaxCodes(ctx: ConnectionContext): Promise<ExternalTaxCode[]>;
  listPaymentAccounts(ctx: ConnectionContext): Promise<ExternalOption[]>;

  createExpense(ctx: ConnectionContext, draft: ExpenseDraft): Promise<ExternalRecord>;
  updateExpense(
    ctx: ConnectionContext,
    record: ExternalRecord,
    draft: ExpenseDraft,
  ): Promise<ExternalRecord>;
  deleteExpense(ctx: ConnectionContext, record: ExternalRecord): Promise<void>;
  /** Returns the provider's id for the attachment (or upload token). */
  attachReceipt(ctx: ConnectionContext, record: ExternalRecord, file: ReceiptFile): Promise<string>;
}

export type FetchLike = (input: string | URL | Request, init?: RequestInit) => Promise<Response>;

/**
 * How a failure should be handled:
 * - `auth`: the access token (or, from a token endpoint, the grant) is bad —
 *   refresh, and if that fails the connection needs re-authorisation.
 * - `rate_limited` / `transient`: try again later with backoff.
 * - `not_found`: the provider record is gone (update → create, delete → done).
 * - `config`: something the user must fix here (a missing mapping). Retried
 *   on the normal schedule so a fix within the backoff window still lands.
 * - `permanent`: the provider rejected the data; retrying the same payload
 *   cannot succeed, so the job goes straight to `dead`.
 */
export type AccountingErrorKind =
  | 'auth'
  | 'rate_limited'
  | 'transient'
  | 'not_found'
  | 'config'
  | 'permanent';

export class AccountingError extends Error {
  readonly kind: AccountingErrorKind;
  readonly status: number | null;
  readonly retryAfterSeconds: number | null;
  readonly provider: AccountingProvider | null;

  constructor(
    kind: AccountingErrorKind,
    message: string,
    options: {
      status?: number | null;
      retryAfterSeconds?: number | null;
      provider?: AccountingProvider | null;
    } = {},
  ) {
    super(message);
    this.name = 'AccountingError';
    this.kind = kind;
    this.status = options.status ?? null;
    this.retryAfterSeconds = options.retryAfterSeconds ?? null;
    this.provider = options.provider ?? null;
  }

  get retryable(): boolean {
    return this.kind === 'rate_limited' || this.kind === 'transient' || this.kind === 'config';
  }
}
