// Fatture in Cloud adapter (OAuth 2.0 + API v2).
//
// An expense becomes a received document of type "expense" (spesa). With
// every line mapped to an IVA rate (vat type id) it is sent "detailed", one
// item per rate; otherwise as totals only (amount_net + amount_vat). A
// mapped paid-from account adds a paid payment line. The receipt is uploaded
// first to get an attachment token, which is then set on the document.
//
// One token covers every company the user can access, so connections from
// one consent share one Vault secret.

import {
  type ErrorMessageExtractor,
  providerFetch,
  providerJson,
  toBlob,
  TOKEN_ENDPOINT_KINDS,
  tokenBundleFromResponse,
} from './http.ts';
import { centsToString, draftReference, toCents } from './draft.ts';
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

export const FIC_API_BASE = 'https://api-v2.fattureincloud.it';
// VERIFY: scope names as listed in the FiC developer console.
export const FIC_SCOPES = [
  'received_documents:a',
  'entity.suppliers:r',
  'settings:r',
].join(' ');

export interface FattureInCloudConfig {
  clientId: string;
  clientSecret: string;
  fetch?: FetchLike;
}

type Json = Record<string, unknown>;

const ficErrorMessage: ErrorMessageExtractor = (body) => {
  const data = (body ?? {}) as Json;
  const error = data.error as Json | string | undefined;
  if (typeof error === 'string') {
    return [error, data.error_description].filter(Boolean).join(': ');
  }
  if (error && typeof error === 'object') {
    const parts = [typeof error.message === 'string' ? error.message : null];
    const validation = error.validation_result as Record<string, unknown> | undefined;
    if (validation && typeof validation === 'object') {
      for (const [field, messages] of Object.entries(validation)) {
        parts.push(`${field}: ${Array.isArray(messages) ? messages.join(', ') : String(messages)}`);
      }
    }
    const text = parts.filter(Boolean).join('; ');
    if (text) return text;
  }
  return null;
};

// 403 from FiC is a missing permission or plan feature on that company, not
// an expired token: a new consent would not change it.
function ficClassify(status: number, _body: unknown): AccountingErrorKind | null {
  return status === 403 ? 'permanent' : null;
}

export class FattureInCloudAdapter implements AccountingAdapter {
  readonly provider = 'fatture_in_cloud' as const;
  // VERIFY: FiC documents the plain authorization-code flow for server apps.
  readonly supportsPkce = false;
  readonly requiresPaymentAccount = false;
  // A received document holds one attachment.
  readonly maxAttachments = 1;

  private readonly fetch: FetchLike;

  constructor(private readonly config: FattureInCloudConfig) {
    this.fetch = config.fetch ?? fetch;
  }

  authorizeUrl(params: AuthorizeParams): string {
    const url = new URL(`${FIC_API_BASE}/oauth/authorize`);
    url.searchParams.set('response_type', 'code');
    url.searchParams.set('client_id', this.config.clientId);
    url.searchParams.set('redirect_uri', params.redirectUri);
    url.searchParams.set('scope', FIC_SCOPES);
    url.searchParams.set('state', params.state);
    return url.toString();
  }

  async exchangeCode(params: ExchangeParams): Promise<TokenBundle> {
    return await this.tokenRequest({
      grant_type: 'authorization_code',
      client_id: this.config.clientId,
      client_secret: this.config.clientSecret,
      redirect_uri: params.redirectUri,
      code: params.code,
    }, null);
  }

  async refresh(tokens: TokenBundle): Promise<TokenBundle> {
    if (!tokens.refresh_token) {
      throw new AccountingError('auth', 'fatture_in_cloud: no refresh token', {
        provider: this.provider,
      });
    }
    return await this.tokenRequest({
      grant_type: 'refresh_token',
      client_id: this.config.clientId,
      client_secret: this.config.clientSecret,
      refresh_token: tokens.refresh_token,
    }, tokens);
  }

  // VERIFY: no public revocation endpoint is documented; the user removes the
  // app from their FiC account settings. Deleting the stored token is what
  // disconnects it on our side.
  async revoke(_ctx: ConnectionContext, _options: RevokeOptions): Promise<void> {}

  async listCompanies(
    tokens: TokenBundle,
    _callbackParams: URLSearchParams,
  ): Promise<ExternalCompany[]> {
    const res = await this.api<Json>(tokens, 'GET', '/user/companies');
    // VERIFY: companies sit under data.companies; an accountant's client
    // companies are listed there as well (as controlled companies).
    const data = (res.data ?? {}) as Json;
    const companies: Json[] = [];
    for (const company of (data.companies ?? []) as Json[]) {
      companies.push(company);
      for (const controlled of (company.controlled_companies ?? []) as Json[]) {
        companies.push(controlled);
      }
    }
    const seen = new Set<string>();
    return companies
      .filter((c) => c.id !== undefined && !seen.has(String(c.id)) && seen.add(String(c.id)))
      .map((c) => ({
        id: String(c.id),
        name: String(c.name ?? 'Fatture in Cloud'),
        // Fatture in Cloud is for Italian businesses; its ledgers are in euro.
        country: 'IT',
        currency: 'EUR',
      }));
  }

  async listExpenseAccounts(ctx: ConnectionContext): Promise<ExternalOption[]> {
    // FiC has no chart of accounts on received documents, only free-text
    // categories; the company's existing categories are what can be mapped.
    const res = await this.api<Json>(
      ctx.tokens,
      'GET',
      `/c/${encodeURIComponent(ctx.companyId)}/info/received_document_categories`,
    );
    return ((res.data ?? []) as unknown[])
      .filter((c): c is string => typeof c === 'string' && c.length > 0)
      .map((name) => ({ id: name, name }));
  }

  async listTaxCodes(ctx: ConnectionContext): Promise<ExternalTaxCode[]> {
    const res = await this.api<Json>(
      ctx.tokens,
      'GET',
      `/c/${encodeURIComponent(ctx.companyId)}/info/vat_types`,
    );
    return ((res.data ?? []) as Json[])
      .filter((v) => v.is_disabled !== true)
      .map((v) => ({
        id: String(v.id),
        name: String(v.description ?? `IVA ${v.value}%`),
        rate: Number.isFinite(Number(v.value)) ? Number(v.value) : null,
      }));
  }

  async listPaymentAccounts(ctx: ConnectionContext): Promise<ExternalOption[]> {
    const res = await this.api<Json>(
      ctx.tokens,
      'GET',
      `/c/${encodeURIComponent(ctx.companyId)}/info/payment_accounts`,
    );
    return ((res.data ?? []) as Json[]).map((a) => ({
      id: String(a.id),
      name: String(a.name ?? a.id),
      type: typeof a.type === 'string' ? a.type : null,
    }));
  }

  async createExpense(ctx: ConnectionContext, draft: ExpenseDraft): Promise<ExternalRecord> {
    const res = await this.api<Json>(
      ctx.tokens,
      'POST',
      `/c/${encodeURIComponent(ctx.companyId)}/received_documents`,
      { data: this.document(draft) },
    );
    const id = (res.data as Json | undefined)?.id;
    if (id === undefined || id === null) {
      throw new AccountingError('transient', 'fatture_in_cloud: document created without an id', {
        provider: this.provider,
      });
    }
    return { externalId: String(id), externalType: 'received_document' };
  }

  async updateExpense(
    ctx: ConnectionContext,
    record: ExternalRecord,
    draft: ExpenseDraft,
  ): Promise<ExternalRecord> {
    await this.api(ctx.tokens, 'PUT', this.documentPath(ctx, record), {
      data: this.document(draft),
    });
    return record;
  }

  async deleteExpense(ctx: ConnectionContext, record: ExternalRecord): Promise<void> {
    await this.api(ctx.tokens, 'DELETE', this.documentPath(ctx, record));
  }

  async attachReceipt(
    ctx: ConnectionContext,
    record: ExternalRecord,
    file: ReceiptFile,
  ): Promise<string> {
    // VERIFY: multipart fields `filename` + `attachment`, answered with
    // data.attachment_token.
    const form = new FormData();
    form.append('filename', file.fileName);
    form.append('attachment', toBlob(file.bytes, file.contentType), file.fileName);
    const upload = await providerJson<Json>({
      provider: this.provider,
      fetch: this.fetch,
      url: `${FIC_API_BASE}/c/${encodeURIComponent(ctx.companyId)}/received_documents/attachment`,
      method: 'POST',
      headers: { Authorization: `Bearer ${ctx.tokens.access_token}`, Accept: 'application/json' },
      body: form,
      errorMessage: ficErrorMessage,
      classify: ficClassify,
    });
    const token = (upload?.data as Json | undefined)?.attachment_token;
    if (typeof token !== 'string' || !token) {
      throw new AccountingError('transient', 'fatture_in_cloud: upload returned no token', {
        provider: this.provider,
      });
    }
    await this.api(ctx.tokens, 'PUT', this.documentPath(ctx, record), {
      data: { attachment_token: token },
    });
    return token;
  }

  // -------------------------------------------------------------------------

  private documentPath(ctx: ConnectionContext, record: ExternalRecord): string {
    return `/c/${encodeURIComponent(ctx.companyId)}/received_documents/${
      encodeURIComponent(record.externalId)
    }`;
  }

  // VERIFY: field names of the received-document model (type, entity, date,
  // category, description, amount_net, amount_vat, is_detailed, items_list,
  // payments_list) as in the v2 OpenAPI spec.
  private document(draft: ExpenseDraft): Json {
    const detailed = draft.lines.every((l) => l.taxCodeId);
    const netCents = draft.lines.reduce((sum, l) => sum + (toCents(l.net) ?? 0), 0);
    const doc: Json = {
      type: 'expense',
      entity: { name: draft.merchant.slice(0, 255) },
      date: draft.date,
      category: draft.lines[0]?.accountId ?? '',
      description: draft.description.slice(0, 255),
      invoice_number: draftReference(draft),
      currency: { id: draft.currency },
      amount_net: Number(centsToString(netCents)),
      amount_vat: Number(draft.taxTotal),
      is_detailed: detailed,
    };
    if (detailed) {
      doc.items_list = draft.lines.map((line) => ({
        name: line.description.slice(0, 255),
        qty: 1,
        net_price: Number(line.net),
        category: line.accountId,
        vat: { id: Number(line.taxCodeId) },
      }));
    }
    if (draft.paymentAccountId) {
      doc.payments_list = [{
        amount: Number(draft.total),
        due_date: draft.date,
        paid_date: draft.date,
        status: 'paid',
        payment_account: { id: Number(draft.paymentAccountId) },
      }];
    }
    return doc;
  }

  private async api<T = Json>(
    tokens: TokenBundle,
    method: string,
    path: string,
    body?: unknown,
  ): Promise<T> {
    const headers: Record<string, string> = {
      Authorization: `Bearer ${tokens.access_token}`,
      Accept: 'application/json',
    };
    if (body !== undefined) headers['Content-Type'] = 'application/json';
    if (method === 'DELETE') {
      await providerFetch({
        provider: this.provider,
        fetch: this.fetch,
        url: `${FIC_API_BASE}${path}`,
        method,
        headers,
        errorMessage: ficErrorMessage,
        classify: ficClassify,
      });
      return null as T;
    }
    return await providerJson<T>({
      provider: this.provider,
      fetch: this.fetch,
      url: `${FIC_API_BASE}${path}`,
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
      errorMessage: ficErrorMessage,
      classify: ficClassify,
    });
  }

  private async tokenRequest(
    values: Record<string, string>,
    previous: TokenBundle | null,
  ): Promise<TokenBundle> {
    // VERIFY: the token endpoint accepts a JSON body with the client
    // credentials inside it.
    const body = await providerJson({
      provider: this.provider,
      fetch: this.fetch,
      url: `${FIC_API_BASE}/oauth/token`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify(values),
      errorMessage: ficErrorMessage,
      statusKinds: TOKEN_ENDPOINT_KINDS,
    });
    return tokenBundleFromResponse(body, previous, new Date(), this.provider);
  }
}
