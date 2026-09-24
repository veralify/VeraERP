import { Reveal, StaggerGroup, StaggerItem } from '@components/generic/Motion';
import { RowActions } from '@components/generic/RowActions';
import {
  Card,
  ErrorMessage,
  Field,
  inputClass,
  PageHeader,
  SubmitButton,
} from '@components/member/DashboardPrimitives';
import { EmptyState } from '@components/member/EmptyState';
import { daysUntil } from '@lib/money/format';
import { fadeUp } from '@lib/motion/variants';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { FileText } from 'lucide-react';
import type { Metadata } from 'next';
import {
  addDocumentAction,
  deleteDocumentAction,
  updateDocumentAction,
} from '../actions/documents';

export const metadata: Metadata = { title: 'Documents · Money' };
type SearchParams = Promise<{ error?: string; saved?: string }>;

function expiryBadge(expiryDate: string | null) {
  const days = daysUntil(expiryDate);
  if (days === null) return null;
  if (days < 0) return { text: 'Expired', tone: 'text-vera-danger' };
  if (days <= 30) return { text: `Expires in ${days}d`, tone: 'text-vera-warning' };
  return null;
}

export default async function DocumentsPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data: rows } = await supabase
    .from('money_documents')
    .select('id, title, document_type, expiry_date, notes')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false });
  const documents = rows ?? [];

  return (
    <main className="px-4 py-8 lg:px-8">
      <PageHeader
        eyebrow="Money"
        title="Documents"
        body="Receipts and important documents — track what you have and what's about to expire."
      />
      <ErrorMessage
        message={
          params.error === 'save'
            ? 'We couldn’t save that change. Please try again.'
            : params.error
              ? 'Enter a title for the document.'
              : undefined
        }
      />

      <div className="mt-4 grid gap-6 xl:grid-cols-[1fr_420px]">
        <Reveal variants={fadeUp}>
          <Card>
            <h2 className="text-xl font-bold">Your documents</h2>
            {documents.length ? (
              <StaggerGroup className="mt-4 divide-y divide-vera-border">
                {documents.map((row) => {
                  const badge = expiryBadge(row.expiry_date);
                  return (
                    <StaggerItem
                      key={row.id}
                      as="div"
                      className="flex items-center justify-between gap-3 py-4"
                    >
                      <div>
                        <p className="font-semibold">{row.title}</p>
                        <p className="text-sm text-vera-fg-muted">
                          {row.document_type}
                          {row.expiry_date ? ` · expires ${row.expiry_date}` : ''}
                          {badge ? (
                            <span className={`ml-2 font-semibold ${badge.tone}`}>{badge.text}</span>
                          ) : null}
                        </p>
                      </div>
                      <RowActions
                        id={row.id}
                        itemLabel={row.title}
                        editTitle="Edit document"
                        updateAction={updateDocumentAction}
                        deleteAction={deleteDocumentAction}
                      >
                        <Field label="Title">
                          <input
                            className={inputClass}
                            name="title"
                            required
                            defaultValue={row.title}
                          />
                        </Field>
                        <Field label="Document type">
                          <input
                            className={inputClass}
                            name="document_type"
                            defaultValue={row.document_type}
                          />
                        </Field>
                        <Field label="Expiry date (optional)">
                          <input
                            className={inputClass}
                            name="expiry_date"
                            type="date"
                            defaultValue={row.expiry_date ?? ''}
                          />
                        </Field>
                        <Field label="Notes">
                          <textarea
                            className={inputClass}
                            name="notes"
                            rows={2}
                            defaultValue={row.notes}
                          />
                        </Field>
                      </RowActions>
                    </StaggerItem>
                  );
                })}
              </StaggerGroup>
            ) : (
              <EmptyState
                icon={<FileText className="h-6 w-6" strokeWidth={1.75} />}
                title="No documents yet"
                body="Log receipts and important documents to track what's coming up for renewal."
              />
            )}
          </Card>
        </Reveal>

        <Reveal variants={fadeUp} delay={0.05}>
          <form
            action={addDocumentAction}
            className="grid gap-4 rounded-vera-2xl border border-vera-border bg-vera-surface p-6"
          >
            <h2 className="text-xl font-bold">Add document</h2>
            <Field label="Title">
              <input className={inputClass} name="title" required placeholder="Passport" />
            </Field>
            <Field label="Document type">
              <input className={inputClass} name="document_type" defaultValue="Receipt" />
            </Field>
            <Field label="Expiry date (optional)">
              <input className={inputClass} name="expiry_date" type="date" />
            </Field>
            <Field label="Notes">
              <textarea className={inputClass} name="notes" rows={2} />
            </Field>
            <SubmitButton>Add document</SubmitButton>
          </form>
        </Reveal>
      </div>
    </main>
  );
}
