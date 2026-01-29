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
      className="group flex h-full w-full flex-col gap-4 rounded-3xl border border-slate-200 bg-white p-5 text-left shadow-sm transition hover:-translate-y-1 hover:border-slate-300 hover:shadow-lg focus:outline-none focus:ring-2 focus:ring-slate-400"
    >
      <div className="relative flex h-40 w-full items-center justify-center rounded-2xl bg-gradient-to-br from-slate-900 to-slate-700 text-white shadow-inner">
        <span className="text-sm uppercase tracking-[0.3em] text-white/70">EPUB</span>
      </div>
      <div className="flex flex-col gap-2">
        <h3 className="text-lg font-semibold leading-tight text-slate-900">{title}</h3>
        {author ? <p className="text-sm text-slate-500">{author}</p> : null}
        <div className="mt-2 flex items-center gap-2 text-xs uppercase tracking-[0.2em] text-slate-400">
          <span className={`h-2.5 w-2.5 rounded-full ${statusColor[status]}`} />
          {statusLabel[status]}
        </div>
      </div>
    </button>
  );
}
