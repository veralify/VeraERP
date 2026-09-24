// Xero adapter (Xero Identity OAuth 2.0 + Accounting API 2.0).
//
// A paid expense becomes a SPEND BankTransaction on the mapped bank / card
// account. With no paid-from account mapped it becomes a draft ACCPAY bill
// instead, for the bookkeeper to approve and pay. Receipts go to the
// record's Attachments endpoint.
//
// One Xero consent can cover several organisations (tenants) with a single
// token, so connections from the same consent share one Vault secret; see
// the migration's accounting_replace_token for how a refresh reaches all of
// them.

import { draftReference } from './draft.ts';
import {
  basicAuth,
  type ErrorMessageExtractor,
  formBody,
  providerFetch,
  providerJson,
  toBlob,
  TOKEN_ENDPOINT_KINDS,
  tokenBundleFromResponse,
} from './http.ts';
import {
  type AccountingAdapter,
  AccountingError,
  type AccountingErrorKind,
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

export const XERO_AUTHORIZE_URL = 'https://login.xero.com/identity/connect/authorize';
export const XERO_TOKEN_URL = 'https://identity.xero.com/connect/token';
export const XERO_REVOKE_URL = 'https://identity.xero.com/connect/revocation';
export const XERO_CONNECTIONS_URL = 'https://api.xero.com/connections';
export const XERO_API_BASE = 'https://api.xero.com/api.xro/2.0';
// VERIFY: Xero is moving apps to granular scopes (e.g. accounting.banktransactions,
// accounting.invoices) in place of accounting.transactions; newly registered
// apps may need those names instead.
export const XERO_SCOPES = [
  'openid',
  'profile',
  'email',
  'offline_access',
  'accounting.transactions',
  'accounting.settings.read',
  'accounting.contacts',
  'accounting.attachments',
].join(' ');

/**
 * UK tax types a Xero organisation typically offers on purchases (the real
 * list always comes from /TaxRates; this is documentation for the mapping
 * screen's defaults and the tests).
 */
export const XERO_UK_PURCHASE_TAX_TYPES = {
  '20': 'INPUT2', // 20% (VAT on Expenses)
  '5': 'RRINPUT', // 5% (VAT on Expenses)
  '0': 'ZERORATEDINPUT', // Zero Rated Expenses
  exempt: 'EXEMPTINPUT', // Exempt Expenses
  none: 'NONE', // No VAT
} as const;

export interface XeroConfig {
  clientId: string;
  clientSecret: string;
  fetch?: FetchLike;
}

type Json = Record<string, unknown>;

const xeroErrorMessage: ErrorMessageExtractor = (body) => {
  const data = (body ?? {}) as Json;
  const messages: string[] = [];
  for (const element of (data.Elements ?? []) as Json[]) {
    for (const v of (element.ValidationErrors ?? []) as Json[]) {
      if (typeof v.Message === 'string') messages.push(v.Message);
    }
  }
  if (messages.length) return messages.join('; ');
  if (typeof data.Detail === 'string') return data.Detail;
  if (typeof data.Message === 'string') return data.Message;
  if (typeof data.error === 'string') {
    return [data.error, data.error_description].filter(Boolean).join(': ');
  }
  return null;
};

// 403 from the API means the tenant is no longer connected to this app
// ("AuthenticationUnsuccessful" / "AuthorizationUnsuccessful") — only a new
// consent helps, so it is treated like an expired grant.
function xeroClassify(status: number, _body: unknown): AccountingErrorKind | null {
  return status === 403 ? 'auth' : null;
}

export class XeroAdapter implements AccountingAdapter {
  readonly provider = 'xero' as const;
  // VERIFY: Xero accepts a PKCE challenge alongside the client secret for
  // web apps (it is mandatory for its "PKCE" app type).
  readonly supportsPkce = true;
  readonly requiresPaymentAccount = false;
  readonly maxAttachments = 10;

  private readonly fetch: FetchLike;

  constructor(private readonly config: XeroConfig) {
    this.fetch = config.fetch ?? fetch;
  }

  authorizeUrl(params: AuthorizeParams): string {
    const url = new URL(XERO_AUTHORIZE_URL);
    url.searchParams.set('response_type', 'code');
    url.searchParams.set('client_id', this.config.clientId);
    url.searchParams.set('redirect_uri', params.redirectUri);
    url.searchParams.set('scope', XERO_SCOPES);
    url.searchParams.set('state', params.state);
    if (params.codeChallenge) {
      url.searchParams.set('code_challenge', params.codeChallenge);
      url.searchParams.set('code_challenge_method', 'S256');
    }
    return url.toString();
  }

  async exchangeCode(params: ExchangeParams): Promise<TokenBundle> {
    return await this.tokenRequest({
      grant_type: 'authorization_code',
      code: params.code,
      redirect_uri: params.redirectUri,
      code_verifier: params.codeVerifier ?? null,
    }, null);
  }

  async refresh(tokens: TokenBundle): Promise<TokenBundle> {
    if (!tokens.refresh_token) {
      throw new AccountingError('auth', 'xero: no refresh token', { provider: this.provider });
    }
    // Xero rotates the refresh token on every use; the old one stops working
    // (after a short grace period), so the new bundle must be stored at once.
    return await this.tokenRequest(
      { grant_type: 'refresh_token', refresh_token: tokens.refresh_token },
      tokens,
    );
  }

  async revoke(ctx: ConnectionContext, options: RevokeOptions): Promise<void> {
    if (options.tokenShared) {
      // Other organisations still use this grant: detach only this tenant.
      const connections = await this.connections(ctx.tokens);
      const match = connections.find((c) => c.tenantId === ctx.companyId);
      if (!match) return;
      await providerFetch({
        provider: this.provider,
        fetch: this.fetch,
        url: `${XERO_CONNECTIONS_URL}/${encodeURIComponent(String(match.id))}`,
        method: 'DELETE',
        headers: { Authorization: `Bearer ${ctx.tokens.access_token}` },
        errorMessage: xeroErrorMessage,
      });
      return;
    }
    await providerFetch({
      provider: this.provider,
      fetch: this.fetch,
      url: XERO_REVOKE_URL,
      method: 'POST',
      headers: {
        Authorization: basicAuth(this.config.clientId, this.config.clientSecret),
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: formBody({ token: ctx.tokens.refresh_token ?? ctx.tokens.access_token }),
      errorMessage: xeroErrorMessage,
    });
  }

  async listCompanies(
    tokens: TokenBundle,
    _callbackParams: URLSearchParams,
  ): Promise<ExternalCompany[]> {
    const connections = (await this.connections(tokens)).filter(
      (c) => (c.tenantType ?? 'ORGANISATION') === 'ORGANISATION',
    );
    const companies: ExternalCompany[] = [];
    for (const connection of connections) {
      const tenantId = String(connection.tenantId);
      let country: string | null = null;
      let currency: string | null = null;
      try {
        const res = await this.api<Json>({ companyId: tenantId, tokens }, 'GET', 'Organisation');
        const org = ((res.Organisations ?? []) as Json[])[0] ?? {};
        country = typeof org.CountryCode === 'string' ? org.CountryCode : null;
        currency = typeof org.BaseCurrency === 'string' ? org.BaseCurrency : null;
      } catch {
        // Country and currency only label the connection; keep going without them.
      }
      companies.push({
        id: tenantId,
        name: String(connection.tenantName ?? 'Xero organisation'),
        country,
        currency,
      });
    }
    return companies;
  }

  async listExpenseAccounts(ctx: ConnectionContext): Promise<ExternalOption[]> {
    const res = await this.api<Json>(ctx, 'GET', 'Accounts', undefined, {
      where: 'Class=="EXPENSE"&&Status=="ACTIVE"',
    });
    return ((res.Accounts ?? []) as Json[]).map((a) => ({
      // Line items reference accounts by code; an account without a code
      // falls back to its id (see lineItem()).
      id: String(a.Code ?? a.AccountID),
      name: String(a.Name ?? a.Code),
      code: typeof a.Code === 'string' ? a.Code : null,
      type: typeof a.Type === 'string' ? a.Type : null,
    }));
  }

  async listPaymentAccounts(ctx: ConnectionContext): Promise<ExternalOption[]> {
    const res = await this.api<Json>(ctx, 'GET', 'Accounts', undefined, {
      where: 'Type=="BANK"&&Status=="ACTIVE"',
    });
    return ((res.Accounts ?? []) as Json[]).map((a) => ({
      id: String(a.AccountID),
      name: String(a.Name ?? a.Code ?? a.AccountID),
      code: typeof a.Code === 'string' ? a.Code : null,
      // BANK, CREDITCARD, PAYPAL
      type: typeof a.BankAccountType === 'string' ? a.BankAccountType : 'BANK',
    }));
  }

  async listTaxCodes(ctx: ConnectionContext): Promise<ExternalTaxCode[]> {
    const res = await this.api<Json>(ctx, 'GET', 'TaxRates');
    return ((res.TaxRates ?? []) as Json[])
      .filter((t) => (t.Status ?? 'ACTIVE') === 'ACTIVE' && t.CanApplyToExpenses !== false)
      .map((t) => ({
        id: String(t.TaxType),
        name: String(t.Name ?? t.TaxType),
        rate: Number.isFinite(Number(t.EffectiveRate)) ? Number(t.EffectiveRate) : null,
        type: String(t.TaxType),
      }));
  }

  async createExpense(ctx: ConnectionContext, draft: ExpenseDraft): Promise<ExternalRecord> {
    if (draft.paymentAccountId) {
      const res = await this.api<Json>(ctx, 'PUT', 'BankTransactions', {
        BankTransactions: [this.bankTransaction(draft)],
      });
      const created = ((res.BankTransactions ?? []) as Json[])[0] ?? {};
      return { externalId: String(created.BankTransactionID), externalType: 'SPEND' };
    }
    const res = await this.api<Json>(ctx, 'PUT', 'Invoices', { Invoices: [this.bill(draft)] });
    const created = ((res.Invoices ?? []) as Json[])[0] ?? {};
    return { externalId: String(created.InvoiceID), externalType: 'ACCPAY' };
  }

  async updateExpense(
    ctx: ConnectionContext,
    record: ExternalRecord,
    draft: ExpenseDraft,
  ): Promise<ExternalRecord> {
    // The record keeps the type it was created as; switching SPEND ↔ ACCPAY
    // would orphan whatever the bookkeeper already reconciled against it.
    if (record.externalType === 'ACCPAY') {
      await this.api(ctx, 'POST', `Invoices/${encodeURIComponent(record.externalId)}`, {
        Invoices: [{ ...this.bill(draft), InvoiceID: record.externalId }],
      });
      return record;
    }
    if (!draft.paymentAccountId) {
      throw new AccountingError(
        'config',
        'xero: this expense was synced as a bank payment; map a payment account to update it',
        { provider: this.provider },
      );
    }
    await this.api(ctx, 'POST', `BankTransactions/${encodeURIComponent(record.externalId)}`, {
      BankTransactions: [{ ...this.bankTransaction(draft), BankTransactionID: record.externalId }],
    });
    return record;
  }

  async deleteExpense(ctx: ConnectionContext, record: ExternalRecord): Promise<void> {
    // Xero has no hard delete: a bank transaction or a draft bill is set to DELETED.
    // VERIFY: an AUTHORISED bill would need VOIDED; bills are created as DRAFT here.
    if (record.externalType === 'ACCPAY') {
      await this.api(ctx, 'POST', `Invoices/${encodeURIComponent(record.externalId)}`, {
        Invoices: [{ InvoiceID: record.externalId, Status: 'DELETED' }],
      });
      return;
    }
    await this.api(ctx, 'POST', `BankTransactions/${encodeURIComponent(record.externalId)}`, {
      BankTransactions: [{ BankTransactionID: record.externalId, Status: 'DELETED' }],
    });
  }

  async attachReceipt(
    ctx: ConnectionContext,
    record: ExternalRecord,
    file: ReceiptFile,
  ): Promise<string> {
    const collection = record.externalType === 'ACCPAY' ? 'Invoices' : 'BankTransactions';
    // VERIFY: PUT creates a new attachment (POST would overwrite one with the
    // same file name); the body is the raw file, not multipart.
    const res = await providerJson<Json>({
      provider: this.provider,
      fetch: this.fetch,
      url: `${XERO_API_BASE}/${collection}/${encodeURIComponent(record.externalId)}/Attachments/${
        encodeURIComponent(file.fileName)
      }`,
      method: 'PUT',
      headers: {
        ...this.headers(ctx),
        'Content-Type': file.contentType,
      },
      body: toBlob(file.bytes, file.contentType),
      errorMessage: xeroErrorMessage,
      classify: xeroClassify,
    });
    const attachment = ((res?.Attachments ?? []) as Json[])[0] ?? {};
    return String(attachment.AttachmentID ?? file.fileName);
  }

  // -------------------------------------------------------------------------

  private headers(ctx: ConnectionContext): Record<string, string> {
    return {
      Authorization: `Bearer ${ctx.tokens.access_token}`,
      'xero-tenant-id': ctx.companyId,
      Accept: 'application/json',
    };
  }

  private async api<T = Json>(
    ctx: ConnectionContext,
    method: string,
    path: string,
    body?: unknown,
    query: Record<string, string> = {},
  ): Promise<T> {
    const url = new URL(`${XERO_API_BASE}/${path}`);
    for (const [key, value] of Object.entries(query)) url.searchParams.set(key, value);
    const headers = this.headers(ctx);
    if (body !== undefined) headers['Content-Type'] = 'application/json';
    return await providerJson<T>({
      provider: this.provider,
      fetch: this.fetch,
      url: url.toString(),
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
      errorMessage: xeroErrorMessage,
      classify: xeroClassify,
    });
  }

  private async connections(tokens: TokenBundle): Promise<Json[]> {
    const res = await providerJson<Json[]>({
      provider: this.provider,
      fetch: this.fetch,
      url: XERO_CONNECTIONS_URL,
      headers: { Authorization: `Bearer ${tokens.access_token}`, Accept: 'application/json' },
      errorMessage: xeroErrorMessage,
    });
    return Array.isArray(res) ? res : [];
  }

  private lineAmountTypes(draft: ExpenseDraft): 'Inclusive' | 'NoTax' {
    // Gross line amounts with Xero working the VAT out of them ("Inclusive"),
    // or no VAT at all when nothing is known about it.
    return draft.taxKnown || draft.lines.some((l) => l.taxCodeId) ? 'Inclusive' : 'NoTax';
  }

  private lineItems(draft: ExpenseDraft): Json[] {
    const inclusive = this.lineAmountTypes(draft) === 'Inclusive';
    return draft.lines.map((line) => {
      const item: Json = {
        Description: line.description.slice(0, 4000),
        Quantity: 1,
        UnitAmount: Number(line.gross),
      };
      // VERIFY: LineItems accept AccountID as an alternative to AccountCode.
      if (/^[0-9a-f]{8}-[0-9a-f]{4}-/i.test(line.accountId)) item.AccountID = line.accountId;
      else item.AccountCode = line.accountId;
      if (line.taxCodeId) item.TaxType = line.taxCodeId;
      // Our tax figure comes from the receipt; pin it so Xero's own rounding
      // does not change the booked VAT.
      if (inclusive && line.taxCodeId && draft.taxKnown) item.TaxAmount = Number(line.tax);
      return item;
    });
  }

  private bankTransaction(draft: ExpenseDraft): Json {
    return {
      Type: 'SPEND',
      // VERIFY: a Contact given only by Name is matched or created by Xero.
      Contact: { Name: draft.merchant.slice(0, 255) },
      Date: draft.date,
      Reference: draftReference(draft),
      CurrencyCode: draft.currency,
      BankAccount: { AccountID: draft.paymentAccountId },
      LineAmountTypes: this.lineAmountTypes(draft),
      LineItems: this.lineItems(draft),
    };
  }

  private bill(draft: ExpenseDraft): Json {
    return {
      Type: 'ACCPAY',
      Contact: { Name: draft.merchant.slice(0, 255) },
      Date: draft.date,
      DueDate: draft.date,
      InvoiceNumber: draftReference(draft),
      CurrencyCode: draft.currency,
      // Draft: an unpaid bill created by an app should be approved by a person.
      Status: 'DRAFT',
      LineAmountTypes: this.lineAmountTypes(draft),
      LineItems: this.lineItems(draft),
    };
  }

  private async tokenRequest(
    values: Record<string, string | null>,
    previous: TokenBundle | null,
  ): Promise<TokenBundle> {
    const body = await providerJson({
      provider: this.provider,
      fetch: this.fetch,
      url: XERO_TOKEN_URL,
      method: 'POST',
      headers: {
        Authorization: basicAuth(this.config.clientId, this.config.clientSecret),
        'Content-Type': 'application/x-www-form-urlencoded',
        Accept: 'application/json',
      },
      body: formBody(values),
      errorMessage: xeroErrorMessage,
      statusKinds: TOKEN_ENDPOINT_KINDS,
    });
    return tokenBundleFromResponse(body, previous, new Date(), this.provider);
  }
}
