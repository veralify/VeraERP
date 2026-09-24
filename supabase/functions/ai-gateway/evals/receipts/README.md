# Receipt reading evals

Measures how well `receipts-extract` reads real receipts, field by field, through the same route the
app calls (normalisation, merchant key, category rules, validation).

## Adding real receipts

1. Anonymise first. Cover or crop out anything that identifies a person: card numbers beyond the
   last four digits, loyalty card numbers, names, e-mail addresses, the customer's own VAT number on
   an invoice. Keep the merchant, dates, amounts, VAT/IVA lines and P.IVA / VAT reg. no. — those are
   what is being measured.
2. Drop the images in `evals/receipts/images/` (JPEG, PNG or PDF; one file per page). That folder is
   git-ignored: receipt images are never committed, anonymised or not.
3. Add one line per receipt to a JSONL file kept next to them, e.g.
   `evals/receipts/images/cases.jsonl` (also ignored), in the format below.
4. Run against the real model:

   ```sh
   cd supabase/functions/ai-gateway
   OPENROUTER_API_KEY=… deno run --allow-read --allow-write --allow-env --allow-net \
     evals/receipts-runner.ts evals/receipts/images/cases.jsonl --real-openrouter
   ```

   The report is written to `evals/out/receipts.report.json` (ignored). Without `--real-openrouter`
   the runner answers every case from its `mock_model_output`, which checks the scoring and the
   server pipeline only; `evals/datasets/receipts_seed.jsonl` is that offline set.

A good starting set is about 20 Italian receipts (supermarket scontrino, bar, pharmacy, motorway
fuel, a fattura) and 20 UK ones (supermarket, café, train ticket, a VAT invoice), plus a few
non-receipts (a menu, a photo of a table) that must come back as unreadable.

## Case format

One JSON object per line; lines starting with `#` are skipped.

```json
{
  "id": "it-bar-001",
  "images": ["it-bar-001.jpg"],
  "locale": "it-IT",
  "home_currency": "EUR",
  "categories": ["groceries", "eating_out", "fuel", "health", "other"],
  "expected": {
    "document_type": "scontrino",
    "merchant_key": "bar centrale",
    "vat_id": "IT01234567890",
    "country": "IT",
    "date": "2026-09-20",
    "currency": "EUR",
    "total": "3.40",
    "tax_total": "0.31",
    "tax_rates": ["10"],
    "category": "eating_out",
    "payment_method": "cash",
    "line_item_count": 2
  }
}
```

- `images`: file names inside `evals/receipts/images/`, one per page, in order.
- `categories`: the user's category keys; the contract's defaults when omitted.
- `expected`: only the fields listed are scored. Money as a decimal string with a dot (`"12.50"`),
  dates as `YYYY-MM-DD`, `merchant_key` as `merchantKey()` makes it, `tax_rates` sorted.
  `"unreadable": true` expects a 422.
- `mock_model_output` (optional): a model answer in the `ReceiptReading` schema, used offline.

The summary reports accuracy per field and `wrong_but_not_flagged` — wrong values the review screen
would not have highlighted (confidence ≥ 0.75). That second number is the one to keep near zero: a
flagged mistake gets checked, an unflagged one gets saved.
