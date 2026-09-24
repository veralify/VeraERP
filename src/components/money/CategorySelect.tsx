import { inputClass } from '@components/member/DashboardPrimitives';

/**
 * Category picker whose values are category keys (contract §3). A stored
 * value that isn't one of the options — an old free-text category — is kept
 * as an extra option so editing that row doesn't silently re-file it.
 */
export function CategorySelect({
  name = 'category',
  options,
  defaultValue,
  allLabel,
  id,
}: {
  name?: string;
  options: { key: string; label: string }[];
  defaultValue?: string;
  /** Adds a leading empty "all" option, for filters. */
  allLabel?: string;
  id?: string;
}) {
  const known = !defaultValue || options.some((o) => o.key === defaultValue);
  return (
    <select id={id} className={inputClass} name={name} defaultValue={defaultValue ?? ''}>
      {allLabel ? <option value="">{allLabel}</option> : null}
      {known ? null : <option value={defaultValue}>{defaultValue}</option>}
      {options.map((option) => (
        <option key={option.key} value={option.key}>
          {option.label}
        </option>
      ))}
    </select>
  );
}
