export type DownloadStatus = "pending" | "downloading" | "ready";

export interface LocalBook {
  fileId: string;
  title: string;
  author: string;
  coverBlob?: Blob;
  localPath: string;
  lastCfi: string;
  timestamp: number;
  isDirty: boolean;
  downloadStatus: DownloadStatus;
}

export interface LocalFile {
  fileId: string;
  blob: Blob;
}

export interface SyncBookEntry {
  cfi: string;
  ts: number;
}

export interface SyncFile {
  last_device?: string;
  last_synced?: string;
  books: Record<string, SyncBookEntry>;
}

export interface FileAdapter {
  downloadBook: (fileId: string) => Promise<string>;
  deleteBook: (fileId: string) => Promise<void>;
  exists: (fileId: string) => Promise<boolean>;
}
