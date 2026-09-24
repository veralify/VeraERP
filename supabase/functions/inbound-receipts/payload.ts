// The normalised inbound e-mail this function accepts, whoever delivers it.
//
//   POST /functions/v1/inbound-receipts
//   Content-Type: application/json
//   X-Inbound-Signature: sha256=<hex HMAC-SHA256 of the raw body, key INBOUND_WEBHOOK_SECRET>
//
//   {
//     "to": "receipts+3f9c…@in.example.com"        // or an array; display names are fine
//     "from": "Shop <orders@shop.example>",
//     "subject": "Your receipt",
//     "attachments": [
//       { "filename": "receipt.pdf", "contentType": "application/pdf", "contentBase64": "JVBERi0…" }
//     ]
//   }
//
// Adapting a provider
// -------------------
// No provider sends exactly this, and none signs it this way, so put a thin
// relay in front (a Cloudflare Worker, a route in the web app, or a copy of
// this function with the provider's own check in place of verifySignature).
// The relay checks the provider's authenticity mechanism, maps the fields,
// signs the mapped JSON with INBOUND_WEBHOOK_SECRET and forwards it here.
//
// Postmark (inbound webhook). Postmark does not sign inbound posts; protect
// the relay URL with HTTP basic auth (https://user:pass@relay/…), which
// Postmark supports in the webhook URL, and set the inbound domain's MX to
// Postmark. Mapping:
//
//   to:          body.OriginalRecipient || body.To
//   from:        body.From
//   subject:     body.Subject
//   attachments: body.Attachments.map((a) => ({
//                  filename: a.Name, contentType: a.ContentType, contentBase64: a.Content }))
//
// Resend (inbound, event `email.received`). Verify the Svix headers
// (svix-id, svix-timestamp, svix-signature: base64 HMAC-SHA256 of
// `${id}.${timestamp}.${body}` keyed with the base64 part of the `whsec_…`
// secret). The event carries metadata only, so the relay then fetches each
// attachment's content through the Resend API before mapping:
//
//   to:          event.data.to            (array)
//   from:        event.data.from
//   subject:     event.data.subject
//   attachments: for each event.data.attachments[i], download its content and
//                emit { filename, contentType: content_type, contentBase64 }
//
// VERIFY: Resend's inbound event shape and the attachment download endpoint
// were not checkable from here (provider docs unreachable); confirm them
// against the current Resend docs when building the relay.

export interface InboundAttachment {
  filename: string;
  contentType: string;
  contentBase64: string;
}

export interface InboundEmail {
  to: string[];
  from: string;
  subject: string;
  attachments: InboundAttachment[];
}

export class PayloadError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'PayloadError';
  }
}

function text(value: unknown, field: string, fallback?: string): string {
  if (typeof value === 'string') return value;
  if ((value === undefined || value === null) && fallback !== undefined) return fallback;
  throw new PayloadError(`${field} must be a string.`);
}

/** Validates the shape of the normalised payload. Content checks happen per attachment later. */
export function parseInboundEmail(raw: unknown): InboundEmail {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) {
    throw new PayloadError('Body must be a JSON object.');
  }
  const body = raw as Record<string, unknown>;

  const toValues = Array.isArray(body.to) ? body.to : [body.to];
  if (toValues.length === 0 || toValues.some((value) => typeof value !== 'string')) {
    throw new PayloadError('to must be a string or an array of strings.');
  }

  const attachmentsRaw = body.attachments ?? [];
  if (!Array.isArray(attachmentsRaw)) throw new PayloadError('attachments must be an array.');
  const attachments = attachmentsRaw.map((item, index): InboundAttachment => {
    if (typeof item !== 'object' || item === null) {
      throw new PayloadError(`attachments[${index}] must be an object.`);
    }
    const attachment = item as Record<string, unknown>;
    return {
      filename: text(attachment.filename, `attachments[${index}].filename`, ''),
      contentType: text(attachment.contentType, `attachments[${index}].contentType`, ''),
      contentBase64: text(attachment.contentBase64, `attachments[${index}].contentBase64`),
    };
  });

  return {
    to: toValues as string[],
    from: text(body.from, 'from', ''),
    subject: text(body.subject, 'subject', ''),
    attachments,
  };
}

const ADDRESS = /[^\s<>,;"'()]+@[^\s<>,;"'()]+/g;
const TOKEN = /^[a-z0-9]{8,64}$/;

/**
 * The token from the first recipient of the form receipts+{token}@{domain}.
 *
 * Case-insensitive throughout: mail systems may change the case of an
 * address, and tokens are issued in lower-case hex. Any other recipient (a
 * CC, the user's own address) is ignored, so a message sent to several people
 * still finds the right one.
 */
export function inboundToken(recipients: string[], domain: string): string | null {
  const wantedDomain = domain.trim().toLowerCase();
  if (!wantedDomain) return null;
  for (const field of recipients) {
    for (const address of field.matchAll(ADDRESS)) {
      const [local, host] = address[0].toLowerCase().split('@');
      if (host !== wantedDomain || !local.startsWith('receipts+')) continue;
      const token = local.slice('receipts+'.length);
      if (TOKEN.test(token)) return token;
    }
  }
  return null;
}
