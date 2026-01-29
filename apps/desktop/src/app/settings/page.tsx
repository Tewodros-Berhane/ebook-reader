"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { AppShell, PrimaryButton } from "@lumina/ui";
import { createPickerConfigStore } from "@lumina/core";

export default function SettingsPage() {
  const pickerStore = useMemo(() => createPickerConfigStore(), []);
  const existing = pickerStore.getConfig();
  const defaultApiKey = process.env.NEXT_PUBLIC_GOOGLE_PICKER_API_KEY ?? "";
  const defaultAppId = process.env.NEXT_PUBLIC_GOOGLE_PICKER_APP_ID ?? "";
  const [apiKey, setApiKey] = useState(existing?.apiKey ?? defaultApiKey);
  const [appId, setAppId] = useState(existing?.appId ?? defaultAppId);

  const handleSavePicker = () => {
    if (!apiKey.trim()) return;
    pickerStore.setConfig({ apiKey: apiKey.trim(), appId: appId.trim() || undefined });
  };

  const handleClearPicker = () => {
    pickerStore.clearConfig();
    setApiKey("");
    setAppId("");
  };

  return (
    <AppShell
      title="Settings"
      subtitle="Account, sync, and storage preferences."
      actions={
        <Link href="/">
          <PrimaryButton>Back to Library</PrimaryButton>
        </Link>
      }
      status="Sync only on Wi-Fi - Clear cache"
    >
      <div className="grid gap-6 md:grid-cols-2">
        <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
          <h2 className="text-lg font-semibold text-slate-900">Account</h2>
          <p className="mt-2 text-sm text-slate-600">
            Signed out. Connect your Google account to sync progress and files.
          </p>
          <div className="mt-4">
            <Link href="/auth">
              <PrimaryButton>Sign in</PrimaryButton>
            </Link>
          </div>
        </section>
        <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
          <h2 className="text-lg font-semibold text-slate-900">Storage</h2>
          <p className="mt-2 text-sm text-slate-600">
            Files download to your local library for offline reading.
          </p>
          <button
            type="button"
            className="mt-4 rounded-full border border-slate-200 px-4 py-2 text-sm text-slate-700 hover:border-slate-300"
          >
            Clear cache
          </button>
        </section>
        <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
          <h2 className="text-lg font-semibold text-slate-900">Google Picker</h2>
          <p className="mt-2 text-sm text-slate-600">
            Provide a Drive API key and (optional) app ID to enable the folder picker.
          </p>
          <div className="mt-4 flex flex-col gap-3">
            <input
              value={apiKey}
              onChange={(event) => setApiKey(event.target.value)}
              placeholder="Google API key"
              className="w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm text-slate-700 focus:border-slate-400 focus:outline-none"
            />
            <input
              value={appId}
              onChange={(event) => setAppId(event.target.value)}
              placeholder="Google App ID (optional)"
              className="w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm text-slate-700 focus:border-slate-400 focus:outline-none"
            />
            <div className="flex flex-wrap gap-3">
              <PrimaryButton onClick={handleSavePicker}>Save Picker Config</PrimaryButton>
              <button
                type="button"
                onClick={handleClearPicker}
                className="rounded-full border border-slate-200 px-4 py-2 text-sm text-slate-700 hover:border-slate-300"
              >
                Clear
              </button>
            </div>
          </div>
        </section>
      </div>
    </AppShell>
  );
}
