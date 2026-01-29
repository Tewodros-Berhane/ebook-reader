import type { LocalBook, SyncFile } from "../types/index";

export interface SyncDecision {
  fileId: string;
  action: "pull" | "push" | "noop";
  cloud?: { cfi: string; ts: number };
  local?: { cfi: string; ts: number };
}

export function mergeSyncFile(
  localBooks: LocalBook[],
  cloud: SyncFile | null,
  deviceName?: string,
): { merged: SyncFile; decisions: SyncDecision[] } {
  const cloudBooks = cloud?.books ?? {};
  const decisions: SyncDecision[] = [];
  const mergedBooks: SyncFile["books"] = { ...cloudBooks };

  for (const book of localBooks) {
    const cloudEntry = cloudBooks[book.fileId];
    if (!cloudEntry) {
      mergedBooks[book.fileId] = { cfi: book.lastCfi, ts: book.timestamp };
      decisions.push({
        fileId: book.fileId,
        action: "push",
        local: { cfi: book.lastCfi, ts: book.timestamp },
      });
      continue;
    }

    if (cloudEntry.ts > book.timestamp) {
      decisions.push({
        fileId: book.fileId,
        action: "pull",
        cloud: cloudEntry,
        local: { cfi: book.lastCfi, ts: book.timestamp },
      });
      mergedBooks[book.fileId] = cloudEntry;
    } else if (cloudEntry.ts < book.timestamp) {
      decisions.push({
        fileId: book.fileId,
        action: "push",
        cloud: cloudEntry,
        local: { cfi: book.lastCfi, ts: book.timestamp },
      });
      mergedBooks[book.fileId] = { cfi: book.lastCfi, ts: book.timestamp };
    } else {
      decisions.push({
        fileId: book.fileId,
        action: "noop",
        cloud: cloudEntry,
        local: { cfi: book.lastCfi, ts: book.timestamp },
      });
    }
  }

  const merged: SyncFile = {
    last_device: deviceName ?? cloud?.last_device,
    last_synced: new Date().toISOString(),
    books: mergedBooks,
  };

  return { merged, decisions };
}
