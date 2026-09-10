import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { DashboardChrome } from "@/components/dashboard/dashboard-chrome";
import { auth } from "@/lib/auth";
import { getBalance } from "@/services/credits";

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const session = await auth.api.getSession({ headers: await headers() });

  if (!session) {
    redirect("/login");
  }

  const creditBalance = await getBalance(session.user.id);
  const impersonatedBy = (
    session.session as { impersonatedBy?: string | null } | undefined
  )?.impersonatedBy;
  const isImpersonating = Boolean(impersonatedBy);

  return (
    <DashboardChrome
      user={{
        name: session.user.name,
        email: session.user.email,
        image: session.user.image ?? null,
      }}
      creditBalance={creditBalance}
      isImpersonating={isImpersonating}
      {...(isImpersonating
        ? {
            impersonationTarget: {
              name: session.user.name,
              email: session.user.email,
            },
          }
        : {})}
    >
      {children}
    </DashboardChrome>
  );
}
