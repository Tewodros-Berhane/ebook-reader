import type { ReactNode } from "react";

type AppShellProps = {
  title: string;
  subtitle?: string;
  actions?: ReactNode;
  status?: ReactNode;
  children: ReactNode;
};

export function AppShell({ title, subtitle, actions, status, children }: AppShellProps) {
  return (
    <div className="min-h-screen bg-[radial-gradient(circle_at_top,_#f8fafc,_#e2e8f0_60%,_#cbd5f5_120%)] text-slate-900">
      <header className="mx-auto flex w-full max-w-6xl flex-col gap-3 px-6 pt-8">
        <div className="flex flex-col gap-3 rounded-3xl border border-white/60 bg-white/80 p-6 shadow-xl shadow-slate-900/10 backdrop-blur">
          <div className="flex flex-wrap items-center justify-between gap-4">
            <div>
              <p className="text-xs uppercase tracking-[0.2em] text-slate-500">Lumina Reader</p>
              <h1 className="text-3xl font-semibold tracking-tight">{title}</h1>
              {subtitle ? <p className="mt-1 text-sm text-slate-600">{subtitle}</p> : null}
            </div>
            <div className="flex items-center gap-3">{actions}</div>
          </div>
          {status ? <div className="text-xs text-slate-500">{status}</div> : null}
        </div>
      </header>
      <main className="mx-auto w-full max-w-6xl px-6 pb-16 pt-10">{children}</main>
    </div>
  );
}
