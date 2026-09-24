import { Card, inputClass, SubmitButton } from '@components/member/DashboardPrimitives';
import { saveMappingsAction } from '../actions';
import {
  CATEGORY_KEYS,
  type ConnectionRow,
  DEFAULT_KEY,
  type ExternalOption,
  encodeOption,
  type MappingKind,
  type MappingRow,
  normalizeRate,
  optionLabel,
  PROVIDER_INFO,
  type ProviderOptions,
  UNKNOWN_TAX_KEY,
  vatRateKeys,
} from '../lib';

/**
 * Where each expense lands in the ledger: category → expense account, VAT
 * rate → tax code, and the account expenses are paid from. The options are
 * read live from the provider (accounting-accounts); the choices are
 * accounting_mappings rows the worker reads on every sync.
 */
export function MappingEditor({
  connection,
  options,
  mappings,
}: {
  connection: ConnectionRow;
  options: ProviderOptions;
  mappings: MappingRow[];
}) {
  const mapped = (kind: MappingKind, key: string) =>
    mappings.find((m) => m.kind === kind && m.local_key === key) ?? null;
  const rates = vatRateKeys(connection.country, options.tax_codes, mappings);
  const provider = PROVIDER_INFO[connection.provider].name;

  return (
    <Card id="mapping">
      <h2 className="text-xl font-bold">Account mapping · {connection.company_name || provider}</h2>
      <p className="mt-1 text-sm text-vera-fg-muted">
        Choose where each expense goes in {provider}. Categories you leave unmapped use the default
        account.
      </p>
      <form action={saveMappingsAction} className="mt-6 grid gap-8">
        <input type="hidden" name="connection_id" value={connection.id} />

        <fieldset className="grid gap-3">
          <legend className="mb-2 text-sm font-semibold uppercase tracking-[0.12em] text-vera-fg-muted">
            Expense accounts
          </legend>
          <MappingRowSelect
            label="Default (anything not listed)"
            name={`category:${DEFAULT_KEY}`}
            options={options.expense_accounts}
            current={mapped('category', DEFAULT_KEY)}
            emptyLabel="Not mapped"
          />
          {CATEGORY_KEYS.map((category) => (
            <MappingRowSelect
              key={category.key}
              label={category.label}
              name={`category:${category.key}`}
              options={options.expense_accounts}
              current={mapped('category', category.key)}
              emptyLabel="Use default"
            />
          ))}
        </fieldset>

        {options.tax_codes.length ? (
          <fieldset className="grid gap-3">
            <legend className="mb-2 text-sm font-semibold uppercase tracking-[0.12em] text-vera-fg-muted">
              VAT rates
            </legend>
            {rates.map((rate) => (
              <MappingRowSelect
                key={rate}
                label={`VAT ${rate}%`}
                name={`tax_rate:${rate}`}
                options={options.tax_codes}
                current={mapped('tax_rate', rate)}
                suggested={suggestTaxCode(options, rate)}
                emptyLabel={`Let ${provider} decide`}
              />
            ))}
            <MappingRowSelect
              label="VAT not known"
              name={`tax_rate:${UNKNOWN_TAX_KEY}`}
              options={options.tax_codes}
              current={mapped('tax_rate', UNKNOWN_TAX_KEY)}
              emptyLabel={`Let ${provider} decide`}
            />
          </fieldset>
        ) : null}

        {options.payment_accounts.length ? (
          <fieldset className="grid gap-3">
            <legend className="mb-2 text-sm font-semibold uppercase tracking-[0.12em] text-vera-fg-muted">
              Paid from
            </legend>
            <MappingRowSelect
              label="Payment account"
              name={`payment_account:${DEFAULT_KEY}`}
              options={options.payment_accounts}
              current={mapped('payment_account', DEFAULT_KEY)}
              emptyLabel={
                options.requires_payment_account
                  ? 'Choose an account (required)'
                  : 'None — record as an unpaid bill'
              }
            />
          </fieldset>
        ) : null}

        <div>
          <SubmitButton pendingLabel="Saving…">Save mapping</SubmitButton>
        </div>
      </form>
    </Card>
  );
}

/** A provider tax code at exactly this rate, when there is only one. */
function suggestTaxCode(options: ProviderOptions, rate: string): ExternalOption | null {
  const matches = options.tax_codes.filter((code) => normalizeRate(code.rate) === rate);
  return matches.length === 1 ? matches[0] : null;
}

function MappingRowSelect({
  label,
  name,
  options,
  current,
  suggested = null,
  emptyLabel,
}: {
  label: string;
  name: string;
  options: ExternalOption[];
  current: MappingRow | null;
  suggested?: ExternalOption | null;
  emptyLabel: string;
}) {
  // A mapped account that no longer exists at the provider stays visible, so
  // saving the form does not silently drop it.
  const missing =
    current && !options.some((o) => o.id === current.external_id)
      ? {
          id: current.external_id,
          name: `${current.external_name || current.external_id} (not found)`,
        }
      : null;
  const selected = current
    ? (options.find((o) => o.id === current.external_id) ?? missing)
    : suggested;
  const all = missing ? [missing, ...options] : options;

  return (
    <label className="grid items-center gap-2 text-sm font-medium sm:grid-cols-[220px_1fr]">
      <span>
        {label}
        {!current && suggested ? (
          <span className="ml-2 text-xs font-normal text-vera-fg-muted">suggested</span>
        ) : null}
      </span>
      <select
        className={inputClass}
        name={name}
        defaultValue={selected ? encodeOption(selected) : ''}
      >
        <option value="">{emptyLabel}</option>
        {all.map((option) => (
          <option key={option.id} value={encodeOption(option)}>
            {optionLabel(option)}
          </option>
        ))}
      </select>
    </label>
  );
}
