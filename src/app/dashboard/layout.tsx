import { MemberShell } from '@components/member/MemberShell';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { redirect } from 'next/navigation';

export const dynamic = 'force-dynamic';

async function getUserEmail() {
  try {
    const supabase = await createSupabaseServerClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) redirect('/?auth=required');
    return user.email ?? null;
  } catch {
    redirect('/?auth=required');
  }
}

export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
  const email = await getUserEmail();
  return <MemberShell email={email}>{children}</MemberShell>;
}
