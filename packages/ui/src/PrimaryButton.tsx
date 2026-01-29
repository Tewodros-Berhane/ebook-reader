import type { ButtonHTMLAttributes } from "react";

type PrimaryButtonProps = ButtonHTMLAttributes<HTMLButtonElement>;

export function PrimaryButton({ className = "", ...props }: PrimaryButtonProps) {
  return (
    <button
      {...props}
      className={`rounded-full bg-slate-900 px-5 py-2.5 text-sm font-semibold uppercase tracking-[0.2em] text-white shadow-[0_16px_35px_-24px_rgba(15,23,42,0.9)] transition hover:-translate-y-0.5 hover:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-slate-400 ${className}`}
    />
  );
}
