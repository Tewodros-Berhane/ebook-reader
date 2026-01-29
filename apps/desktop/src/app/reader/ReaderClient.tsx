"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";
import { AppShell, PrimaryButton, Reader } from "@lumina/ui";
import {
  createWebTokenStore,
  downloadAndCacheBook,
  getBookById,
  getFileBlob,
  GoogleDriveClient,
  syncWithCloud,
  updateBookProgress,
} from "@lumina/core";
import type { LocalBook } from "@lumina/core";

type ReaderClientProps = {
  fileId: string;
};

export function ReaderClient({ fileId }: ReaderClientProps) {
  const [book, setBook] = useState<LocalBook | null>(null);
  const [source, setSource] = useState<string | ArrayBuffer | null>(null);
  const [inputUrl, setInputUrl] = useState("");
  const [loading, setLoading] = useState(false);
  const [debug, setDebug] = useState<{
    size?: number;
    type?: string;
    error?: string;
    header?: string;
    hasContainer?: boolean;
    isZip?: boolean;
  }>({});
  const tokenStore = useMemo(() => createWebTokenStore(), []);
  const autoDownloadRef = useRef(false);
  const syncTimerRef = useRef<number | null>(null);
  const desktopClientId = process.env.NEXT_PUBLIC_DESKTOP_CLIENT_ID ?? "";

  const inspectBuffer = (buffer: ArrayBuffer) => {
    const bytes = new Uint8Array(buffer);
    const header = Array.from(bytes.slice(0, 4))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join(" ");
    const isZip = header.startsWith("50 4b");
    const needle = new TextEncoder().encode("META-INF/container.xml");
    let hasContainer = false;
    for (let i = 0; i <= bytes.length - needle.length; i += 1) {
      let match = true;
      for (let j = 0; j < needle.length; j += 1) {
        if (bytes[i + j] !== needle[j]) {
          match = false;
          break;
        }
      }
      if (match) {
        hasContainer = true;
        break;
      }
    }
    return { header, isZip, hasContainer };
  };

  useEffect(() => {
    if (!fileId) return;
    let active = true;
    getBookById(fileId).then(async (data) => {
      if (!active) return;
      setBook(data ?? null);
      const localPath = data?.localPath ?? "";
      const isIdb = localPath.startsWith("idb://");
      const isHttp = localPath.startsWith("http://") || localPath.startsWith("https://");
      const isFile = localPath.startsWith("file://");
      if (isIdb) {
        const blob = await getFileBlob(fileId);
        if (!active) return;
        if (blob) {
          const buffer = await blob.arrayBuffer();
          if (!active) return;
          setSource(buffer);
          const info = inspectBuffer(buffer);
          setDebug({ size: buffer.byteLength, type: "ArrayBuffer", ...info });
        }
      } else if (isHttp || isFile) {
        setSource(localPath);
        setDebug({ type: "URL" });
      } else {
        setSource(null);
      }
    });
    return () => {
      active = false;
    };
  }, [fileId]);

  const handleUseUrl = () => {
    const url = inputUrl.trim();
    if (url) setSource(url);
  };

  const handleDownload = async () => {
    const tokens = tokenStore.getTokens();
    if (!tokens?.accessToken || !fileId) return;
    let accessToken = tokens.accessToken;
    if (tokens.expiresAt && Date.now() > tokens.expiresAt - 60_000 && tokens.refreshToken && window.electronAPI) {
      try {
        const refreshed = await window.electronAPI.refreshDesktopToken({
          clientId: desktopClientId,
          refreshToken: tokens.refreshToken,
        });
        tokenStore.setTokens({
          accessToken: refreshed.accessToken,
          refreshToken: refreshed.refreshToken ?? tokens.refreshToken,
          expiresAt: refreshed.expiresAt,
        });
        accessToken = refreshed.accessToken;
      } catch (err) {
        setDebug((prev) => ({ ...prev, error: "Token refresh failed." }));
        return;
      }
    }
    setLoading(true);
    try {
      await downloadAndCacheBook(fileId, accessToken);
      const blob = await getFileBlob(fileId);
      if (blob) {
        const buffer = await blob.arrayBuffer();
        setSource(buffer);
        const info = inspectBuffer(buffer);
        setDebug({ size: buffer.byteLength, type: "ArrayBuffer", ...info });
      }
    } finally {
      setLoading(false);
    }
  };

  const ensureAccessToken = async () => {
    const tokens = tokenStore.getTokens();
    if (!tokens?.accessToken) return null;
    if (tokens.expiresAt && Date.now() > tokens.expiresAt - 60_000 && tokens.refreshToken && window.electronAPI) {
      const refreshed = await window.electronAPI.refreshDesktopToken({
        clientId: desktopClientId,
        refreshToken: tokens.refreshToken,
      });
      tokenStore.setTokens({
        accessToken: refreshed.accessToken,
        refreshToken: refreshed.refreshToken ?? tokens.refreshToken,
        expiresAt: refreshed.expiresAt,
      });
      return refreshed.accessToken;
    }
    return tokens.accessToken;
  };

  const scheduleSync = () => {
    if (syncTimerRef.current) {
      window.clearTimeout(syncTimerRef.current);
    }
    syncTimerRef.current = window.setTimeout(async () => {
      if (!navigator.onLine) return;
      try {
        const accessToken = await ensureAccessToken();
        if (!accessToken) return;
        const client = new GoogleDriveClient(accessToken);
        await syncWithCloud(client, "Desktop");
      } catch (err) {
        setDebug((prev) => ({ ...prev, error: err instanceof Error ? err.message : "Sync failed." }));
      }
    }, 2000);
  };

  useEffect(() => {
    if (!fileId || autoDownloadRef.current) return;
    if (book?.localPath) return;
    const token = tokenStore.getTokens()?.accessToken;
    if (!token) return;
    autoDownloadRef.current = true;
    handleDownload().catch(() => undefined);
  }, [fileId, book?.localPath]);

  if (!fileId) {
    return (
      <AppShell title="Reader" subtitle="Select a book to start reading.">
        <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
          <h2 className="text-lg font-semibold text-slate-900">No book selected</h2>
          <p className="mt-2 text-sm text-slate-600">Go back to the library and pick a book to open.</p>
          <div className="mt-4">
            <Link href="/">
              <PrimaryButton>Back to Library</PrimaryButton>
            </Link>
          </div>
        </div>
      </AppShell>
    );
  }

  return (
    <AppShell
      title={book?.title ?? "Reader"}
      subtitle={`Opening book ${fileId}`}
      actions={
        <Link href="/">
          <PrimaryButton>Back to Library</PrimaryButton>
        </Link>
      }
      status={book?.localPath ? "Offline ready" : "Waiting for download"}
    >
      <div className="mb-6 flex flex-wrap items-center justify-between gap-4 rounded-[24px] border border-slate-200 bg-white/80 px-5 py-3 shadow-[0_16px_35px_-30px_rgba(15,23,42,0.6)]">
        <div className="flex flex-wrap items-center gap-3 text-xs uppercase tracking-[0.2em] text-slate-500">
          <span className="rounded-full border border-slate-200 px-3 py-1">Reflow</span>
          <span className="rounded-full border border-slate-200 px-3 py-1">Serif</span>
          <span className="rounded-full border border-slate-200 px-3 py-1">100%</span>
        </div>
        <div className="flex items-center gap-2 text-xs text-slate-500">
          <span className="rounded-full bg-slate-100 px-3 py-1">Chapter 1</span>
          <span className="rounded-full border border-slate-200 px-3 py-1">0% read</span>
        </div>
      </div>
      {!source ? (
        <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
          <h2 className="text-lg font-semibold text-slate-900">No local file found</h2>
          <p className="mt-2 text-sm text-slate-600">
            Download the book from the library, or paste an EPUB URL to preview the reader.
          </p>
          <div className="mt-4 flex flex-col gap-3">
            <PrimaryButton onClick={handleDownload} disabled={loading}>
              {loading ? "Downloading..." : "Download for offline"}
            </PrimaryButton>
            <input
              value={inputUrl}
              onChange={(event) => setInputUrl(event.target.value)}
              placeholder="https://example.com/book.epub"
              className="w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm text-slate-700 focus:border-slate-400 focus:outline-none"
            />
            <div className="flex flex-wrap gap-3">
              <PrimaryButton onClick={handleUseUrl}>Load preview</PrimaryButton>
            </div>
          </div>
        </div>
      ) : (
        <div className="rounded-3xl border border-slate-200 bg-white p-4 shadow-sm">
          <div className="h-[70vh] overflow-hidden rounded-2xl border border-slate-200 bg-slate-50">
            <Reader
              src={source}
              cfi={book?.lastCfi}
              onLocationChange={(cfi) => {
                updateBookProgress(fileId, cfi);
                scheduleSync();
              }}
              onError={(message) => setDebug((prev) => ({ ...prev, error: message }))}
            />
          </div>
          <div className="mt-3 rounded-2xl border border-dashed border-slate-200 bg-white/70 px-4 py-3 text-xs text-slate-600">
            <div>Debug</div>
            <div>Source: {debug.type ?? "unknown"}</div>
            <div>Size: {debug.size ? `${(debug.size / (1024 * 1024)).toFixed(2)} MB` : "n/a"}</div>
            <div>Header: {debug.header ?? "n/a"}</div>
            <div>ZIP: {debug.isZip ? "yes" : "no"}</div>
            <div>Has container.xml: {debug.hasContainer ? "yes" : "no"}</div>
            <div>Last error: {debug.error ?? "none"}</div>
          </div>
        </div>
      )}
    </AppShell>
  );
}
