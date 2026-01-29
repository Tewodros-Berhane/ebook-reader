"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { AppShell, PrimaryButton, Reader } from "@lumina/ui";
import { createWebTokenStore, downloadAndCacheBook, getBookById, getFileBlob, updateBookProgress } from "@lumina/core";
import type { LocalBook } from "@lumina/core";

type ReaderClientProps = {
  fileId: string;
};

export function ReaderClient({ fileId }: ReaderClientProps) {
  const [book, setBook] = useState<LocalBook | null>(null);
  const [source, setSource] = useState<string | Blob | ArrayBuffer | null>(null);
  const [inputUrl, setInputUrl] = useState("");
  const [loading, setLoading] = useState(false);
  const tokenStore = useMemo(() => createWebTokenStore(), []);

  useEffect(() => {
    let active = true;
    getBookById(fileId).then(async (data) => {
      if (!active) return;
      setBook(data ?? null);
      if (data?.localPath?.startsWith("idb://")) {
        const blob = await getFileBlob(fileId);
        if (!active) return;
        if (blob) setSource(blob);
      } else if (data?.localPath) {
        setSource(data.localPath);
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
    const token = tokenStore.getTokens()?.accessToken;
    if (!token) return;
    setLoading(true);
    try {
      await downloadAndCacheBook(fileId, token);
      const blob = await getFileBlob(fileId);
      if (blob) setSource(blob);
    } finally {
      setLoading(false);
    }
  };

  return (
    <AppShell
      title={book?.title ?? "Reader"}
      subtitle={`Opening book ${fileId}`}
      actions={
        <Link href="/">
          <PrimaryButton>Back to Library</PrimaryButton>
        </Link>
      }
      status={book?.localPath ? "Local file ready" : "No local file yet"}
    >
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
        <div className="rounded-3xl border border-slate-200 bg-white p-3 shadow-sm">
          <div className="h-[60vh] overflow-hidden rounded-2xl border border-slate-200 bg-slate-50">
            <Reader src={source} cfi={book?.lastCfi} onLocationChange={(cfi) => updateBookProgress(fileId, cfi)} />
          </div>
        </div>
      )}
    </AppShell>
  );
}
