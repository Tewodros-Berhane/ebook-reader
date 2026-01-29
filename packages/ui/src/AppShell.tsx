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
    <div className="min-h-screen bg-[#f4f1ec] text-slate-900">
      <div className="absolute inset-0 -z-10 bg-[radial-gradient(circle_at_top,_rgba(120,113,108,0.18),_transparent_55%),radial-gradient(circle_at_20%_30%,_rgba(34,197,94,0.12),_transparent_40%),radial-gradient(circle_at_80%_10%,_rgba(59,130,246,0.12),_transparent_35%)]" />
      <header className="mx-auto flex w-full max-w-6xl flex-col gap-6 px-6 pt-8">
        <div className="flex flex-col gap-4 rounded-[32px] border border-white/70 bg-white/70 p-6 shadow-[0_20px_60px_-40px_rgba(15,23,42,0.6)] backdrop-blur">
          <div className="flex flex-wrap items-center justify-between gap-6">
            <div>
              <p className="text-xs uppercase tracking-[0.35em] text-slate-500">Lumina Reader</p>
              <h1 className="mt-2 font-[var(--font-playfair)] text-4xl font-semibold tracking-tight text-slate-900">
                {title}
              </h1>
              {subtitle ? <p className="mt-2 max-w-xl text-sm text-slate-600">{subtitle}</p> : null}
            </div>
            <div className="flex flex-wrap items-center gap-3">{actions}</div>
          </div>
          {status ? (
            <div className="inline-flex w-fit items-center gap-2 rounded-full border border-slate-200 bg-white px-3 py-1 text-xs uppercase tracking-[0.2em] text-slate-500">
              <span className="h-2 w-2 rounded-full bg-emerald-500" />
              {status}
            </div>
          ) : null}
        </div>
      </header>
      <main className="mx-auto w-full max-w-6xl px-6 pb-16 pt-10">{children}</main>
    </div>
  );
}
