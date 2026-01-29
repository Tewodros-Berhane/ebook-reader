import type { ButtonHTMLAttributes } from "react";

type PrimaryButtonProps = ButtonHTMLAttributes<HTMLButtonElement>;

export function PrimaryButton({ className = "", ...props }: PrimaryButtonProps) {
  return (
    <button
      {...props}
      className={`rounded-full bg-slate-900 px-5 py-2 text-sm font-semibold text-white shadow-md shadow-slate-900/20 transition hover:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-slate-400 ${className}`}
    />
  );
}
