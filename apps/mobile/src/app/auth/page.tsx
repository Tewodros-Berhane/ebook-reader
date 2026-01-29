"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { AppShell, PrimaryButton } from "@lumina/ui";
import { createWebTokenStore } from "@lumina/core";
import { Capacitor } from "@capacitor/core";
import { GoogleAuth } from "@codetrix-studio/capacitor-google-auth";

export default function AuthPage() {
  const tokenStore = useMemo(() => createWebTokenStore(), []);
  const [accessToken, setAccessToken] = useState("");
  const [error, setError] = useState<string | null>(null);
  const existing = tokenStore.getTokens();

  useEffect(() => {
    if (!Capacitor.isNativePlatform()) return;
    try {
      GoogleAuth.initialize({
        clientId: "YOUR_ANDROID_CLIENT_ID",
        scopes: ["https://www.googleapis.com/auth/drive.appdata", "https://www.googleapis.com/auth/drive.readonly"],
        grantOfflineAccess: true,
      });
    } catch {
      // ignore init errors in web preview
    }
  }, []);

  const handleSave = () => {
    const token = accessToken.trim();
    if (!token) return;
    tokenStore.setTokens({ accessToken: token });
    setAccessToken("");
    setError(null);
  };

  const handleClear = () => {
    tokenStore.clearTokens();
    setError(null);
  };

  const handleOAuth = async () => {
    try {
      setError(null);
      if (!Capacitor.isNativePlatform()) {
        setError("Native Google Sign-In requires Capacitor on device.");
        return;
      }
      const result = await GoogleAuth.signIn();
      if (!result?.authentication?.accessToken) {
        throw new Error("No access token received.");
      }
      tokenStore.setTokens({
        accessToken: result.authentication.accessToken,
        refreshToken: result.authentication.refreshToken,
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : "OAuth failed.");
    }
  };

  return (
    <AppShell
      title="Connect Google Drive"
      subtitle="Authenticate to list EPUBs and sync progress."
      actions={
        <Link href="/">
          <PrimaryButton>Back to Library</PrimaryButton>
        </Link>
      }
      status={existing ? "Token stored" : "OAuth native ready"}
    >
      <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
        <h2 className="text-lg font-semibold text-slate-900">Android Sign-In</h2>
        <p className="mt-2 text-sm text-slate-600">
          We'll use the native Google account picker via the Capacitor Google Sign-In plugin.
        </p>
        <div className="mt-6 flex flex-col gap-3">
          <PrimaryButton onClick={handleOAuth}>Start mobile sign-in (stub)</PrimaryButton>
          <label className="text-xs uppercase tracking-[0.2em] text-slate-400">Access Token (temporary)</label>
          <input
            value={accessToken}
            onChange={(event) => setAccessToken(event.target.value)}
            placeholder="Paste Google access token"
            className="w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm text-slate-700 focus:border-slate-400 focus:outline-none"
          />
          <div className="flex flex-wrap gap-3">
            <PrimaryButton onClick={handleSave}>Store token</PrimaryButton>
            <button
              type="button"
              onClick={handleClear}
              className="rounded-full border border-slate-200 px-4 py-2 text-sm text-slate-700 hover:border-slate-300"
            >
              Clear token
            </button>
          </div>
          {error ? <p className="text-xs text-rose-600">{error}</p> : null}
          {existing ? (
            <p className="text-xs text-emerald-600">Token stored. Library can now sync with Drive.</p>
          ) : (
            <p className="text-xs text-slate-400">Use this while we build the real OAuth flow.</p>
          )}
        </div>
      </div>
    </AppShell>
  );
}
