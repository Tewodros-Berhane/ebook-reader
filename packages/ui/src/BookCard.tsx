type BookCardProps = {
  title: string;
  author?: string;
  status?: "cloud" | "downloaded" | "dirty";
  onClick?: () => void;
};

const statusLabel: Record<NonNullable<BookCardProps["status"]>, string> = {
  cloud: "Cloud only",
  downloaded: "Downloaded",
  dirty: "Sync pending",
};

const statusColor: Record<NonNullable<BookCardProps["status"]>, string> = {
  cloud: "bg-sky-500",
  downloaded: "bg-emerald-500",
  dirty: "bg-amber-500",
};

export function BookCard({ title, author, status = "cloud", onClick }: BookCardProps) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="group relative flex h-full w-full flex-col gap-5 overflow-hidden rounded-[28px] border border-slate-200 bg-white p-5 text-left shadow-[0_18px_45px_-35px_rgba(15,23,42,0.6)] transition hover:-translate-y-1 hover:border-slate-300 hover:shadow-[0_24px_60px_-35px_rgba(15,23,42,0.7)] focus:outline-none focus:ring-2 focus:ring-slate-400"
    >
      <div className="relative flex h-44 w-full items-end rounded-2xl bg-[conic-gradient(at_top_left,_#0f172a,_#1e293b,_#0f766e,_#0f172a)] p-4 text-white shadow-inner">
        <div className="absolute inset-0 opacity-20 [background-image:radial-gradient(circle_at_top,_rgba(255,255,255,0.35),_transparent_55%)]" />
        <span className="text-xs uppercase tracking-[0.35em] text-white/70">EPUB</span>
      </div>
      <div className="flex flex-col gap-2">
        <h3 className="font-[var(--font-playfair)] text-xl font-semibold leading-tight text-slate-900">{title}</h3>
        {author ? <p className="text-sm text-slate-500">by {author}</p> : null}
        <div className="mt-2 flex items-center gap-2 text-[11px] uppercase tracking-[0.2em] text-slate-400">
          <span className={`h-2.5 w-2.5 rounded-full ${statusColor[status]}`} />
          {statusLabel[status]}
        </div>
      </div>
      <div className="mt-auto flex items-center justify-between text-xs text-slate-400">
        <span>Open</span>
        <span className="rounded-full border border-slate-200 px-2 py-1 text-[10px] uppercase tracking-[0.25em]">
          Ready
        </span>
      </div>
    </button>
  );
}
