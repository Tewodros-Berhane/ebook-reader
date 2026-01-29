type EmptyStateProps = {
  title: string;
  description: string;
  action?: React.ReactNode;
};

export function EmptyState({ title, description, action }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-start gap-4 rounded-3xl border border-dashed border-slate-300 bg-white/70 p-8">
      <div>
        <p className="text-xs uppercase tracking-[0.2em] text-slate-400">Library</p>
        <h2 className="text-2xl font-semibold text-slate-900">{title}</h2>
        <p className="mt-2 text-sm text-slate-600">{description}</p>
      </div>
      {action ? <div>{action}</div> : null}
    </div>
  );
}
