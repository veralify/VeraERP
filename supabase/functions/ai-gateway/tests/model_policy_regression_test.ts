// @ts-nocheck
import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
async function sha256(text: string) { const data = new TextEncoder().encode(text); const hash = await crypto.subtle.digest('SHA-256', data); return Array.from(new Uint8Array(hash)).map((b) => b.toString(16).padStart(2, '0')).join(''); }
function stable(value: any): string { if (Array.isArray(value)) return `[${value.map(stable).join(',')}]`; if (value && typeof value === 'object') return `{${Object.keys(value).sort().map((k) => `${JSON.stringify(k)}:${stable(value[k])}`).join(',')}}`; return JSON.stringify(value); }
Deno.test('model policy roles and thresholds require model_policy_version bump', async () => {
  const current = JSON.parse(await Deno.readTextFile(new URL('../model-policy.json', import.meta.url)));
  const gate = JSON.parse(await Deno.readTextFile(new URL('../model-policy.regression.json', import.meta.url)));
  const comparable = structuredClone(current);
  delete comparable.model_policy_version;
  const digest = await sha256(stable(comparable));
  if (digest !== gate.policy_without_version_sha256) {
    assertEquals(current.model_policy_version !== gate.model_policy_version, true, 'model-policy.json roles/routes/pricing/thresholds changed; bump model_policy_version and update regression hash intentionally');
  }
});
