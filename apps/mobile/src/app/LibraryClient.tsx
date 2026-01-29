"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { AppShell, BookCard, EmptyState, PrimaryButton } from "@lumina/ui";
import {
  createDriveFolderStore,
  createPickerConfigStore,
  createWebTokenStore,
  GoogleDriveClient,
  listLocalBooks,
  syncWithCloud,
  upsertBooksFromDrive,
} from "@lumina/core";
import type { LocalBook } from "@lumina/core";

const statusFromBook = (book: LocalBook) => {
  if (book.isDirty) return "dirty" as const;
  if (book.downloadStatus === "ready") return "downloaded" as const;
  return "cloud" as const;
};

export function LibraryClient() {
  const tokenStore = useMemo(() => createWebTokenStore(), []);
  const folderStore = useMemo(() => createDriveFolderStore(), []);
  const pickerStore = useMemo(() => createPickerConfigStore(), []);
  const router = useRouter();
  const [books, setBooks] = useState<LocalBook[]>([]);
  const [loading, setLoading] = useState(false);
  const [syncing, setSyncing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [folderId, setFolderId] = useState<string | null>(null);

  const refresh = async () => {
    const local = await listLocalBooks();
    setBooks(local);
  };

  useEffect(() => {
    setFolderId(folderStore.getFolderId());
    refresh();
  }, []);

  const openFolderPicker = async () => {
    const tokens = tokenStore.getTokens();
    if (!tokens?.accessToken) {
      setError("Missing access token.");
      return;
    }
    const pickerConfig = pickerStore.getConfig();
    if (!pickerConfig?.apiKey) {
      setError("Missing Google Picker API key. Set it in Settings.");
      return;
    }

    const loadPicker = () =>
      new Promise<void>((resolve, reject) => {
        const existing = document.getElementById("google-picker");
        if (existing && (window as any).google?.picker) {
          resolve();
          return;
        }
        const script = document.createElement("script");
        script.id = "google-picker";
        script.src = "https://apis.google.com/js/api.js";
        script.onload = () => {
          (window as any).gapi.load("picker", {
            callback: () => resolve(),
            onerror: () => reject(new Error("Failed to load picker.")),
          });
        };
        script.onerror = () => reject(new Error("Failed to load Google API script."));
        document.body.appendChild(script);
      });

    try {
      await loadPicker();
      const google = (window as any).google;
      let builder = new google.picker.PickerBuilder()
        .setOAuthToken(tokens.accessToken)
        .setDeveloperKey(pickerConfig.apiKey)
        .addView(
          new google.picker.DocsView()
            .setIncludeFolders(true)
            .setSelectFolderEnabled(true)
            .setMimeTypes("application/vnd.google-apps.folder"),
        )
        .setCallback((data: any) => {
          if (data.action !== google.picker.Action.PICKED) return;
          const picked = data.docs?.[0];
          if (!picked?.id) return;
          folderStore.setFolderId(picked.id);
          setFolderId(picked.id);
        })
      if (pickerConfig.appId) {
        builder = builder.setAppId(pickerConfig.appId);
      }
      const picker = builder.build();
      picker.setVisible(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Picker failed.");
    }
  };

  const handleSync = async () => {
    const tokens = tokenStore.getTokens();
    if (!tokens?.accessToken) {
      setError("Missing access token.");
      return;
    }
    setError(null);
    setLoading(true);
    try {
      const client = new GoogleDriveClient(tokens.accessToken);
      const files = await client.listEpubFiles(folderStore.getFolderId() ?? undefined);
      await upsertBooksFromDrive(files);
      await refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Sync failed.");
    } finally {
      setLoading(false);
    }
  };

  const handleSyncProgress = async () => {
    const tokens = tokenStore.getTokens();
    if (!tokens?.accessToken) {
      setError("Missing access token.");
      return;
    }
    setError(null);
    setSyncing(true);
    try {
      const client = new GoogleDriveClient(tokens.accessToken);
      await syncWithCloud(client, "Mobile");
      await refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Sync failed.");
    } finally {
      setSyncing(false);
    }
  };

  return (
    <AppShell
      title="Library"
      subtitle="Your Google Drive EPUBs, ready for offline reading."
      actions={
        <>
          <Link href="/settings" className="text-sm text-slate-600 underline-offset-4 hover:underline">
            Settings
          </Link>
          <Link href="/auth">
            <PrimaryButton>Connect Drive</PrimaryButton>
          </Link>
        </>
      }
      status={`${books.length} books • ${loading ? "Syncing..." : "Idle"}`}
    >
      <div className="mb-6 flex flex-wrap items-center gap-3">
        <PrimaryButton onClick={handleSync} disabled={loading}>
          {loading ? "Syncing..." : "Sync Drive"}
        </PrimaryButton>
        <button
          type="button"
          onClick={handleSyncProgress}
          className="rounded-full border border-slate-200 px-4 py-2 text-sm text-slate-700 hover:border-slate-300"
          disabled={syncing}
        >
          {syncing ? "Syncing..." : "Sync Progress"}
        </button>
        <button
          type="button"
          onClick={openFolderPicker}
          className="rounded-full border border-slate-200 px-4 py-2 text-sm text-slate-700 hover:border-slate-300"
        >
          {folderId ? "Change Folder" : "Pick Folder"}
        </button>
        {folderId ? <span className="text-xs text-slate-500">Folder scoped</span> : null}
        {error ? <span className="text-xs text-rose-600">{error}</span> : null}
      </div>
      {books.length === 0 ? (
        <EmptyState
          title="Connect your Drive to start reading."
          description="Sign in to list your EPUBs and download your first book."
          action={
            <Link href="/auth">
              <PrimaryButton>Sign in with Google</PrimaryButton>
            </Link>
          }
        />
      ) : (
        <div className="grid gap-6 sm:grid-cols-2">
          {books.map((book) => (
            <BookCard
              key={book.fileId}
              title={book.title}
              author={book.author}
              status={statusFromBook(book)}
              onClick={() => router.push(`/reader/${book.fileId}`)}
            />
          ))}
        </div>
      )}
    </AppShell>
  );
}
