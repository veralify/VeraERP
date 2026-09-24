// FreeAgent adapter (OAuth 2.0 + API v2).
//
// FreeAgent records out-of-pocket spending as an Expense claimed by a user,
// with one category, a gross value and an optional inline (base64)
// attachment. There is no paid-from account on an expense, so the payment
// account mapping is not used; one token is one company.

import {
  basicAuth,
  bytesToBase64,
  type ErrorMessageExtractor,
  formBody,
  providerFetch,
  providerJson,
  TOKEN_ENDPOINT_KINDS,
  tokenBundleFromResponse,
} from './http.ts';
import { centsToString, toCents } from './draft.ts';
import {
  type AccountingAdapter,
  AccountingError,
  type AuthorizeParams,
  type ConnectionContext,
  type ExchangeParams,
  type ExpenseDraft,
  type ExternalCompany,
  type ExternalOption,
  type ExternalRecord,
  type ExternalTaxCode,
  type FetchLike,
  type ReceiptFile,
  type RevokeOptions,
  type TokenBundle,
} from './types.ts';

export const FREEAGENT_BASE_URLS = {
  sandbox: 'https://api.sandbox.freeagent.com/v2',
  production: 'https://api.freeagent.com/v2',
} as const;

/**
 * FreeAgent takes a VAT *rate* on an expense rather than a tax-code id, so
 * the "tax codes" offered for mapping are the UK rates themselves.
 * VERIFY: companies outside the UK VAT scheme (e.g. flat-rate) may expect
 * different values; FreeAgent's categories also carry an auto_sales_tax_rate.
 */
export const FREEAGENT_TAX_RATES: ExternalTaxCode[] = [
  { id: '20', name: 'Standard rate (20%)', rate: 20 },
  { id: '5', name: 'Reduced rate (5%)', rate: 5 },
  { id: '0', name: 'Zero rate (0%)', rate: 0 },
];

// VERIFY: FreeAgent's documented attachment types; HEIC is not among them,
// so the worker only sends the JPEG pages the app produces.
const FREEAGENT_ATTACHMENT_TYPES = new Set([
  'image/png',
  'image/x-png',
  'image/jpeg',
  'image/jpg',
  'image/gif',
  'application/x-pdf',
  'application/pdf',
]);

export interface FreeAgentConfig {
  clientId: string;
  clientSecret: string;
  environment: 'sandbox' | 'production';
  fetch?: FetchLike;
}

type Json = Record<string, unknown>;

const freeAgentErrorMessage: ErrorMessageExtractor = (body) => {
  const data = (body ?? {}) as Json;
  const errors = data.errors;
  if (Array.isArray(errors)) {
    const messages = errors.map((e) => (e as Json)?.message).filter((m) => typeof m === 'string');
    if (messages.length) return messages.join('; ');
  } else if (errors && typeof errors === 'object') {
    const error = (errors as Json).error as Json | undefined;
    if (typeof error?.message === 'string') return error.message;
  }
  if (typeof data.error === 'string') {
    return [data.error, data.error_description].filter(Boolean).join(': ');
  }
  return null;
};

const COUNTRY_CODES: Record<string, string> = {
  'united kingdom': 'GB',
  uk: 'GB',
  'great britain': 'GB',
  'united states': 'US',
  usa: 'US',
};

export class FreeAgentAdapter implements AccountingAdapter {
  readonly provider = 'freeagent' as const;
  // VERIFY: FreeAgent's OAuth documentation does not mention PKCE.
  readonly supportsPkce = false;
  readonly requiresPaymentAccount = false;
  // An expense holds a single attachment.
  readonly maxAttachments = 1;

  private readonly fetch: FetchLike;
  private readonly base: string;
  private readonly userUrls = new Map<string, string>();

  constructor(private readonly config: FreeAgentConfig) {
    this.fetch = config.fetch ?? fetch;
    this.base = FREEAGENT_BASE_URLS[config.environment];
  }

  authorizeUrl(params: AuthorizeParams): string {
    const url = new URL(`${this.base}/approve_app`);
    url.searchParams.set('client_id', this.config.clientId);
    url.searchParams.set('response_type', 'code');
    url.searchParams.set('redirect_uri', params.redirectUri);
    url.searchParams.set('state', params.state);
    return url.toString();
  }

  async exchangeCode(params: ExchangeParams): Promise<TokenBundle> {
    return await this.tokenRequest(
      { grant_type: 'authorization_code', code: params.code, redirect_uri: params.redirectUri },
      null,
    );
  }

  async refresh(tokens: TokenBundle): Promise<TokenBundle> {
    if (!tokens.refresh_token) {
      throw new AccountingError('auth', 'freeagent: no refresh token', { provider: this.provider });
    }
    return await this.tokenRequest(
      { grant_type: 'refresh_token', refresh_token: tokens.refresh_token },
      tokens,
    );
  }

  // VERIFY: FreeAgent has no public token-revocation endpoint; the user
  // removes the app under Settings → Connected apps. Deleting our copy of the
  // token (done by accounting-disconnect) is what disconnects it here.
  async revoke(_ctx: ConnectionContext, _options: RevokeOptions): Promise<void> {}

  async listCompanies(
    tokens: TokenBundle,
    _callbackParams: URLSearchParams,
  ): Promise<ExternalCompany[]> {
    const res = await this.api<Json>(tokens, 'GET', `${this.base}/company`);
    const company = (res.company ?? {}) as Json;
    // VERIFY: the company resource's `country` is a display name.
    const country = typeof company.country === 'string'
      ? COUNTRY_CODES[company.country.toLowerCase()] ?? null
      : null;
    return [{
      id: String(company.url ?? `${this.base}/company`),
      name: String(company.name ?? 'FreeAgent company'),
      country: country ?? 'GB',
      currency: typeof company.currency === 'string' ? company.currency : null,
    }];
  }

  async listExpenseAccounts(ctx: ConnectionContext): Promise<ExternalOption[]> {
    const res = await this.api<Json>(ctx.tokens, 'GET', `${this.base}/categories`);
    // Admin expenses and cost of sales are the categories an expense can use.
    const groups = ['admin_expenses_categories', 'cost_of_sales_categories'];
    const options: ExternalOption[] = [];
    for (const group of groups) {
      for (const c of (res[group] ?? []) as Json[]) {
        const code = typeof c.nominal_code === 'string' ? c.nominal_code : null;
        options.push({
          id: String(c.url),
          name: code ? `${code} ${String(c.description ?? '')}`.trim() : String(c.description),
          code,
          type: group === 'admin_expenses_categories' ? 'admin_expenses' : 'cost_of_sales',
        });
      }
    }
    return options;
  }

  listTaxCodes(_ctx: ConnectionContext): Promise<ExternalTaxCode[]> {
    return Promise.resolve(FREEAGENT_TAX_RATES.map((rate) => ({ ...rate })));
  }

  listPaymentAccounts(_ctx: ConnectionContext): Promise<ExternalOption[]> {
    return Promise.resolve([]);
  }

  async createExpense(ctx: ConnectionContext, draft: ExpenseDraft): Promise<ExternalRecord> {
    const expense = await this.expenseBody(ctx, draft);
    const res = await this.api<Json>(ctx.tokens, 'POST', `${this.base}/expenses`, { expense });
    const created = (res.expense ?? {}) as Json;
    if (typeof created.url !== 'string') {
      throw new AccountingError('transient', 'freeagent: expense created without a url', {
        provider: this.provider,
      });
    }
    return { externalId: created.url, externalType: 'expense' };
  }

  async updateExpense(
    ctx: ConnectionContext,
    record: ExternalRecord,
    draft: ExpenseDraft,
  ): Promise<ExternalRecord> {
    const expense = await this.expenseBody(ctx, draft);
    await this.api(ctx.tokens, 'PUT', this.recordUrl(record), { expense });
    return record;
  }

  async deleteExpense(ctx: ConnectionContext, record: ExternalRecord): Promise<void> {
    await this.api(ctx.tokens, 'DELETE', this.recordUrl(record));
  }

  async attachReceipt(
    ctx: ConnectionContext,
    record: ExternalRecord,
    file: ReceiptFile,
  ): Promise<string> {
    if (!FREEAGENT_ATTACHMENT_TYPES.has(file.contentType)) {
      throw new AccountingError(
        'permanent',
        `freeagent: ${file.contentType} attachments are not accepted`,
        { provider: this.provider },
      );
    }
    const res = await this.api<Json>(ctx.tokens, 'PUT', this.recordUrl(record), {
      expense: {
        attachment: {
          data: bytesToBase64(file.bytes),
          file_name: file.fileName,
          content_type: file.contentType,
          description: 'Receipt',
        },
      },
    });
    const attachment = ((res?.expense as Json | undefined)?.attachment ?? {}) as Json;
    return String(attachment.url ?? file.fileName);
  }

  // -------------------------------------------------------------------------

  /** Records are identified by their full API url; refuse anything off our base. */
  private recordUrl(record: ExternalRecord): string {
    if (!record.externalId.startsWith(`${this.base}/`)) {
      throw new AccountingError('permanent', 'freeagent: unexpected record url', {
        provider: this.provider,
      });
    }
    return record.externalId;
  }

  private async userUrl(tokens: TokenBundle, companyId: string): Promise<string> {
    const cached = this.userUrls.get(companyId);
    if (cached) return cached;
    const res = await this.api<Json>(tokens, 'GET', `${this.base}/users/me`);
    const url = String((res.user as Json)?.url ?? '');
    if (!url) {
      throw new AccountingError('transient', 'freeagent: could not resolve the current user', {
        provider: this.provider,
      });
    }
    this.userUrls.set(companyId, url);
    return url;
  }

  private async expenseBody(ctx: ConnectionContext, draft: ExpenseDraft): Promise<Json> {
    // One category per expense: the first line's account. Lines differ only by
    // VAT rate (see draft.ts), so the total and the summed VAT describe it fully.
    const [first] = draft.lines;
    const rates = new Set(draft.lines.map((l) => l.taxCodeId ?? l.vatRate));
    const gross = toCents(draft.total) ?? 0;
    const body: Json = {
      user: await this.userUrl(ctx.tokens, ctx.companyId),
      category: first.accountId,
      dated_on: draft.date,
      // VERIFY: FreeAgent records money spent as a negative gross_value.
      gross_value: centsToString(-gross),
      currency: draft.currency,
      description: draft.description.slice(0, 255),
      receipt_reference: draft.transactionId,
    };
    if (draft.taxKnown) {
      // VERIFY: manual_sales_tax_amount overrides the category's automatic VAT.
      body.manual_sales_tax_amount = draft.taxTotal;
      const [rate] = [...rates];
      if (rates.size === 1 && rate !== null && rate !== undefined) body.sales_tax_rate = rate;
    }
    return body;
  }

  private async api<T = Json>(
    tokens: TokenBundle,
    method: string,
    url: string,
    body?: unknown,
  ): Promise<T> {
    const headers: Record<string, string> = {
      Authorization: `Bearer ${tokens.access_token}`,
      Accept: 'application/json',
      // FreeAgent asks API clients to identify themselves.
      'User-Agent': 'Veralify',
    };
    if (body !== undefined) headers['Content-Type'] = 'application/json';
    if (method === 'DELETE') {
      await providerFetch({
        provider: this.provider,
        fetch: this.fetch,
        url,
        method,
        headers,
        errorMessage: freeAgentErrorMessage,
      });
      return null as T;
    }
    return await providerJson<T>({
      provider: this.provider,
      fetch: this.fetch,
      url,
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
      errorMessage: freeAgentErrorMessage,
    });
  }

  private async tokenRequest(
    values: Record<string, string>,
    previous: TokenBundle | null,
  ): Promise<TokenBundle> {
    const body = await providerJson({
      provider: this.provider,
      fetch: this.fetch,
      url: `${this.base}/token_endpoint`,
      method: 'POST',
      headers: {
        Authorization: basicAuth(this.config.clientId, this.config.clientSecret),
        'Content-Type': 'application/x-www-form-urlencoded',
        Accept: 'application/json',
      },
      body: formBody(values),
      errorMessage: freeAgentErrorMessage,
      statusKinds: TOKEN_ENDPOINT_KINDS,
    });
    return tokenBundleFromResponse(body, previous, new Date(), this.provider);
  }
}
