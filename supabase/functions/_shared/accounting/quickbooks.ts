// QuickBooks Online adapter (Intuit OAuth 2.0 + Accounting API v3).
//
// An expense becomes a `Purchase` with AccountBasedExpenseLineDetail lines,
// paid from a Bank or Credit Card account; the receipt is uploaded as an
// `Attachable` linked to it. One OAuth grant is one company (the realmId
// arrives on the redirect), so connections never share tokens here.

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

export const QBO_AUTHORIZE_URL = 'https://appcenter.intuit.com/connect/oauth2';
export const QBO_TOKEN_URL = 'https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer';
export const QBO_REVOKE_URL = 'https://developer.api.intuit.com/v2/oauth2/tokens/revoke';
export const QBO_SCOPE = 'com.intuit.quickbooks.accounting';
export const QBO_BASE_URLS = {
  sandbox: 'https://sandbox-quickbooks.api.intuit.com',
  production: 'https://quickbooks.api.intuit.com',
} as const;
// VERIFY: Intuit raises the minor version regularly; 75 was current when this
// was written and every field used here exists in much older versions.
export const QBO_MINOR_VERSION = '75';

export interface QuickBooksConfig {
  clientId: string;
  clientSecret: string;
  environment: 'sandbox' | 'production';
  fetch?: FetchLike;
}

type Json = Record<string, unknown>;

interface QboFaultError {
  Message?: string;
  Detail?: string;
  code?: string;
}

function faultErrors(body: unknown): QboFaultError[] {
  const data = (body ?? {}) as Json;
  const fault = (data.Fault ?? data.fault) as Json | undefined;
  const errors = (fault?.Error ?? fault?.error) as QboFaultError[] | undefined;
  return Array.isArray(errors) ? errors : [];
}

const qboErrorMessage: ErrorMessageExtractor = (body) => {
  const errors = faultErrors(body);
  if (errors.length) {
    return errors.map((e) => [e.Message, e.Detail].filter(Boolean).join(': ')).join('; ');
  }
  const data = (body ?? {}) as Json;
  if (typeof data.error === 'string') {
    return [data.error, data.error_description].filter(Boolean).join(': ');
  }
  return null;
};

// VERIFY: fault codes from Intuit's error-code list — 610 "Object Not Found",
// 5010 "Stale Object Error" (SyncToken raced another edit), 3200/3202 auth.
function qboClassify(status: number, body: unknown): AccountingErrorKind | null {
  const codes = faultErrors(body).map((e) => String(e.code ?? ''));
  if (codes.includes('610')) return 'not_found';
  if (codes.includes('5010')) return 'transient';
  if (codes.includes('3200') || codes.includes('3202')) return 'auth';
  if (status === 403) return 'permanent';
  return null;
}

export class QuickBooksAdapter implements AccountingAdapter {
  readonly provider = 'quickbooks' as const;
  // VERIFY: Intuit documents PKCE only for public clients; this confidential
  // (client-secret) flow does not send a challenge.
  readonly supportsPkce = false;
  // A Purchase must name the Bank / Credit Card account it was paid from.
  readonly requiresPaymentAccount = true;
  readonly maxAttachments = 10;

  private readonly fetch: FetchLike;
  private readonly base: string;
  private readonly paymentTypes = new Map<string, string>();

  constructor(private readonly config: QuickBooksConfig) {
    this.fetch = config.fetch ?? fetch;
    this.base = QBO_BASE_URLS[config.environment];
  }

  authorizeUrl(params: AuthorizeParams): string {
    const url = new URL(QBO_AUTHORIZE_URL);
    url.searchParams.set('client_id', this.config.clientId);
    url.searchParams.set('response_type', 'code');
    url.searchParams.set('scope', QBO_SCOPE);
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
      throw new AccountingError('auth', 'quickbooks: no refresh token', {
        provider: this.provider,
      });
    }
    // Intuit may rotate the refresh token on any refresh; the new one is kept.
    return await this.tokenRequest(
      { grant_type: 'refresh_token', refresh_token: tokens.refresh_token },
      tokens,
    );
  }

  async revoke(ctx: ConnectionContext, _options: RevokeOptions): Promise<void> {
    await providerFetch({
      provider: this.provider,
      fetch: this.fetch,
      url: QBO_REVOKE_URL,
      method: 'POST',
      headers: {
        Authorization: basicAuth(this.config.clientId, this.config.clientSecret),
        Accept: 'application/json',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ token: ctx.tokens.refresh_token ?? ctx.tokens.access_token }),
      errorMessage: qboErrorMessage,
    });
  }

  async listCompanies(
    tokens: TokenBundle,
    callbackParams: URLSearchParams,
  ): Promise<ExternalCompany[]> {
    const realmId = callbackParams.get('realmId');
    if (!realmId) {
      throw new AccountingError('permanent', 'quickbooks: the redirect carried no realmId', {
        provider: this.provider,
      });
    }
    const ctx = { companyId: realmId, tokens };
    const info = await this.api<Json>(ctx, 'GET', `companyinfo/${encodeURIComponent(realmId)}`);
    const company = (info.CompanyInfo ?? {}) as Json;
    let currency: string | null = null;
    try {
      const prefs = await this.api<Json>(ctx, 'GET', 'preferences');
      const home = (((prefs.Preferences as Json)?.CurrencyPrefs as Json)?.HomeCurrency as Json)
        ?.value;
      currency = typeof home === 'string' ? home : null;
    } catch {
      // Preferences are a nicety for the UI; a company without them still connects.
    }
    return [{
      id: realmId,
      name: String(company.CompanyName ?? company.LegalName ?? 'QuickBooks company'),
      country: typeof company.Country === 'string' ? company.Country : null,
      currency,
    }];
  }

  async listExpenseAccounts(ctx: ConnectionContext): Promise<ExternalOption[]> {
    // VERIFY: Classification is filterable in the query language; it covers
    // Expense, Other Expense and Cost of Goods Sold account types.
    const rows = await this.query(
      ctx,
      "select * from Account where Active = true and Classification = 'Expense' maxresults 1000",
      'Account',
    );
    return rows.map(accountOption);
  }

  async listPaymentAccounts(ctx: ConnectionContext): Promise<ExternalOption[]> {
    const rows = await this.query(
      ctx,
      "select * from Account where Active = true and AccountType in ('Bank', 'Credit Card') maxresults 1000",
      'Account',
    );
    return rows.map(accountOption);
  }

  async listTaxCodes(ctx: ConnectionContext): Promise<ExternalTaxCode[]> {
    const [codes, rates] = await Promise.all([
      this.query(ctx, 'select * from TaxCode where Active = true maxresults 1000', 'TaxCode'),
      this.query(ctx, 'select * from TaxRate maxresults 1000', 'TaxRate'),
    ]);
    const rateById = new Map(rates.map((r) => [String(r.Id), Number(r.RateValue)]));
    const result: ExternalTaxCode[] = [];
    for (const code of codes) {
      // VERIFY: purchase-side rates live in PurchaseTaxRateList.TaxRateDetail[].TaxRateRef.
      const purchase = ((code.PurchaseTaxRateList as Json)?.TaxRateDetail ?? []) as Json[];
      const sales = ((code.SalesTaxRateList as Json)?.TaxRateDetail ?? []) as Json[];
      if (!purchase.length && sales.length) continue; // sales-only codes cannot go on an expense
      const rate = purchase.length
        ? purchase.reduce((sum, d) => {
          const ref = String((d.TaxRateRef as Json)?.value ?? '');
          return sum + (rateById.get(ref) ?? 0);
        }, 0)
        : null;
      result.push({ id: String(code.Id), name: String(code.Name ?? code.Id), rate });
    }
    return result;
  }

  async createExpense(ctx: ConnectionContext, draft: ExpenseDraft): Promise<ExternalRecord> {
    const body = await this.purchaseBody(ctx, draft);
    const res = await this.api<Json>(ctx, 'POST', 'purchase', body);
    return { externalId: String((res.Purchase as Json).Id), externalType: 'Purchase' };
  }

  async updateExpense(
    ctx: ConnectionContext,
    record: ExternalRecord,
    draft: ExpenseDraft,
  ): Promise<ExternalRecord> {
    // Full update: QuickBooks needs the current SyncToken (optimistic locking).
    const syncToken = await this.syncToken(ctx, record.externalId);
    const body = {
      ...(await this.purchaseBody(ctx, draft)),
      Id: record.externalId,
      SyncToken: syncToken,
      sparse: false,
    };
    const res = await this.api<Json>(ctx, 'POST', 'purchase', body);
    return { externalId: String((res.Purchase as Json).Id), externalType: 'Purchase' };
  }

  async deleteExpense(ctx: ConnectionContext, record: ExternalRecord): Promise<void> {
    const syncToken = await this.syncToken(ctx, record.externalId);
    await this.api(ctx, 'POST', 'purchase', { Id: record.externalId, SyncToken: syncToken }, {
      operation: 'delete',
    });
  }

  async attachReceipt(
    ctx: ConnectionContext,
    record: ExternalRecord,
    file: ReceiptFile,
  ): Promise<string> {
    const metadata = {
      AttachableRef: [{ EntityRef: { type: record.externalType, value: record.externalId } }],
      FileName: file.fileName,
      ContentType: file.contentType,
    };
    // Multipart: part names must pair up by suffix (_01 metadata with _01 content).
    const form = new FormData();
    form.append(
      'file_metadata_01',
      new Blob([JSON.stringify(metadata)], { type: 'application/json' }),
      'metadata.json',
    );
    form.append('file_content_01', toBlob(file.bytes, file.contentType), file.fileName);
    const res = await providerJson<Json>({
      provider: this.provider,
      fetch: this.fetch,
      url: this.url(ctx.companyId, 'upload'),
      method: 'POST',
      headers: { Authorization: `Bearer ${ctx.tokens.access_token}`, Accept: 'application/json' },
      body: form,
      errorMessage: qboErrorMessage,
      classify: qboClassify,
    });
    const first = ((res?.AttachableResponse ?? []) as Json[])[0] ?? {};
    const attachable = first.Attachable as Json | undefined;
    if (!attachable?.Id) {
      throw new AccountingError(
        'permanent',
        `quickbooks upload: ${qboErrorMessage(first, '') ?? 'no Attachable returned'}`,
        { provider: this.provider },
      );
    }
    return String(attachable.Id);
  }

  // -------------------------------------------------------------------------

  private url(realmId: string, path: string, query: Record<string, string> = {}): string {
    const url = new URL(`${this.base}/v3/company/${encodeURIComponent(realmId)}/${path}`);
    for (const [key, value] of Object.entries(query)) url.searchParams.set(key, value);
    url.searchParams.set('minorversion', QBO_MINOR_VERSION);
    return url.toString();
  }

  private async api<T = Json>(
    ctx: ConnectionContext,
    method: string,
    path: string,
    body?: unknown,
    query: Record<string, string> = {},
  ): Promise<T> {
    const headers: Record<string, string> = {
      Authorization: `Bearer ${ctx.tokens.access_token}`,
      Accept: 'application/json',
    };
    if (body !== undefined) headers['Content-Type'] = 'application/json';
    return await providerJson<T>({
      provider: this.provider,
      fetch: this.fetch,
      url: this.url(ctx.companyId, path, query),
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
      errorMessage: qboErrorMessage,
      classify: qboClassify,
    });
  }

  private async query(ctx: ConnectionContext, sql: string, entity: string): Promise<Json[]> {
    const res = await this.api<Json>(ctx, 'GET', 'query', undefined, { query: sql });
    const rows = (res.QueryResponse as Json | undefined)?.[entity];
    return Array.isArray(rows) ? rows as Json[] : [];
  }

  private async syncToken(ctx: ConnectionContext, id: string): Promise<string> {
    const res = await this.api<Json>(ctx, 'GET', `purchase/${encodeURIComponent(id)}`);
    return String((res.Purchase as Json).SyncToken ?? '0');
  }

  /** Purchase.PaymentType follows the paid-from account's type. */
  private async paymentType(ctx: ConnectionContext, accountId: string): Promise<string> {
    const key = `${ctx.companyId}:${accountId}`;
    const cached = this.paymentTypes.get(key);
    if (cached) return cached;
    const res = await this.api<Json>(ctx, 'GET', `account/${encodeURIComponent(accountId)}`);
    const type = String((res.Account as Json)?.AccountType ?? '');
    const paymentType = type === 'Credit Card' ? 'CreditCard' : 'Cash';
    this.paymentTypes.set(key, paymentType);
    return paymentType;
  }

  private async purchaseBody(ctx: ConnectionContext, draft: ExpenseDraft): Promise<Json> {
    if (!draft.paymentAccountId) {
      throw new AccountingError('config', 'quickbooks: a payment account mapping is required', {
        provider: this.provider,
      });
    }
    const taxed = draft.lines.some((line) => line.taxCodeId);
    const body: Json = {
      PaymentType: await this.paymentType(ctx, draft.paymentAccountId),
      AccountRef: { value: draft.paymentAccountId },
      TxnDate: draft.date,
      CurrencyRef: { value: draft.currency },
      DocNumber: draftReference(draft),
      PrivateNote: `${draft.description} · ${draftReference(draft)}`.slice(0, 4000),
      Line: draft.lines.map((line) => ({
        DetailType: 'AccountBasedExpenseLineDetail',
        // With TaxExcluded QuickBooks adds the tax from the code on top of a
        // net Amount; a line without a code carries its gross figure.
        Amount: Number(taxed && line.taxCodeId ? line.net : line.gross),
        Description: line.description.slice(0, 4000),
        AccountBasedExpenseLineDetail: {
          AccountRef: { value: line.accountId },
          ...(line.taxCodeId ? { TaxCodeRef: { value: line.taxCodeId } } : {}),
          BillableStatus: 'NotBillable',
        },
      })),
    };
    // VERIFY: GlobalTaxCalculation applies to non-US (VAT/GST) companies; US
    // companies reject tax codes on purchases, so it is only sent with codes.
    // QuickBooks recomputes tax from the code, so a receipt rounded
    // differently can differ by a cent.
    if (taxed) body.GlobalTaxCalculation = 'TaxExcluded';
    return body;
  }

  private async tokenRequest(
    values: Record<string, string>,
    previous: TokenBundle | null,
  ): Promise<TokenBundle> {
    const body = await providerJson({
      provider: this.provider,
      fetch: this.fetch,
      url: QBO_TOKEN_URL,
      method: 'POST',
      headers: {
        Authorization: basicAuth(this.config.clientId, this.config.clientSecret),
        Accept: 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: formBody(values),
      errorMessage: qboErrorMessage,
      statusKinds: TOKEN_ENDPOINT_KINDS,
    });
    return tokenBundleFromResponse(body, previous, new Date(), this.provider);
  }
}

function accountOption(row: Json): ExternalOption {
  return {
    id: String(row.Id),
    name: String(row.FullyQualifiedName ?? row.Name ?? row.Id),
    code: typeof row.AcctNum === 'string' ? row.AcctNum : null,
    type: typeof row.AccountType === 'string' ? row.AccountType : null,
  };
}
