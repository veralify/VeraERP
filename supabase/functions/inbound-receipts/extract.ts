// Asks ai-gateway to read an e-mailed receipt, acting for its owner.
//
// There is no user token on an inbound e-mail, so this uses the
// server-to-server form of receipts-extract (contract §5): the service role
// key as the bearer and `user_id` in the body. The gateway applies the same
// ownership check, scan limit and response as for the phone.

export interface ExtractRequest {
  supabaseUrl: string;
  serviceRoleKey: string;
  userId: string;
  receiptId: string;
  homeCurrency: string;
  fetchImpl?: typeof fetch;
  timeoutMs?: number;
}

export interface ExtractOutcome {
  receipt_id: string;
  ok: boolean;
  status: number;
  /** The gateway's error code (SCAN_LIMIT_REACHED, UNREADABLE, …) or a local one. */
  error?: string;
}

// VERIFY: the e-mail carries no hint of the user's locale. en-GB reads
// day-first dates, which matches both markets the app targets (UK and Italy);
// switch to a stored locale if one is ever added to money_settings.
export const DEFAULT_EXTRACT_LOCALE = 'en-GB';

export function extractUrl(supabaseUrl: string): string {
  return `${supabaseUrl.replace(/\/+$/, '')}/functions/v1/ai-gateway/receipts-extract`;
}

export async function requestExtraction(request: ExtractRequest): Promise<ExtractOutcome> {
  const { fetchImpl = fetch, timeoutMs = 120_000 } = request;
  try {
    const response = await fetchImpl(extractUrl(request.supabaseUrl), {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${request.serviceRoleKey}`,
        apikey: request.serviceRoleKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        receipt_id: request.receiptId,
        user_id: request.userId,
        locale: DEFAULT_EXTRACT_LOCALE,
        home_currency: request.homeCurrency,
      }),
      signal: AbortSignal.timeout(timeoutMs),
    });
    if (response.ok) {
      await response.body?.cancel();
      return { receipt_id: request.receiptId, ok: true, status: response.status };
    }
    let code = `HTTP_${response.status}`;
    try {
      const body = await response.json();
      if (typeof body?.error === 'string') code = body.error;
    } catch {
      // Not JSON; the status code is all there is.
    }
    return { receipt_id: request.receiptId, ok: false, status: response.status, error: code };
  } catch (error) {
    const timedOut = error instanceof DOMException && error.name === 'TimeoutError';
    return {
      receipt_id: request.receiptId,
      ok: false,
      status: 0,
      error: timedOut ? 'TIMEOUT' : 'NETWORK_ERROR',
    };
  }
}
