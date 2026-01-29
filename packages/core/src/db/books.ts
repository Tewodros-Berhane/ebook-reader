import type { DriveFile } from "../api/drive-client";
import type { LocalBook } from "../types/index";
import { db } from "./schema";

export function driveFileToLocalBook(file: DriveFile): LocalBook {
  const timestamp = file.modifiedTime ? Date.parse(file.modifiedTime) : Date.now();
  return {
    fileId: file.id,
    title: file.name,
    author: "Unknown author",
    localPath: "",
    lastCfi: "epubcfi(/6/2[cover]!/4/1:0)",
    timestamp: Number.isNaN(timestamp) ? Date.now() : timestamp,
    isDirty: false,
    downloadStatus: "pending",
  };
}

export async function upsertBooksFromDrive(files: DriveFile[]): Promise<void> {
  const existing = await db.books.toArray();
  const existingMap = new Map(existing.map((book) => [book.fileId, book]));
  const merged: LocalBook[] = files.map((file) => {
    const current = existingMap.get(file.id);
    if (!current) return driveFileToLocalBook(file);
    return {
      ...current,
      title: file.name ?? current.title,
      timestamp: file.modifiedTime ? Date.parse(file.modifiedTime) : current.timestamp,
    };
  });
  await db.books.bulkPut(merged);
}

export async function listLocalBooks(): Promise<LocalBook[]> {
  return db.books.toArray();
}

export async function getBookById(fileId: string): Promise<LocalBook | undefined> {
  return db.books.get(fileId);
}

export async function setBookDownloadStatus(
  fileId: string,
  status: LocalBook["downloadStatus"],
  localPath?: string,
): Promise<void> {
  await db.books.update(fileId, {
    downloadStatus: status,
    ...(localPath !== undefined ? { localPath } : {}),
  });
}

export async function updateBookProgress(fileId: string, cfi: string): Promise<void> {
  await db.books.update(fileId, {
    lastCfi: cfi,
    timestamp: Date.now(),
    isDirty: true,
  });
}

export async function applyCloudProgress(fileId: string, cfi: string, ts: number): Promise<void> {
  await db.books.update(fileId, {
    lastCfi: cfi,
    timestamp: ts,
    isDirty: false,
  });
}

export async function markBooksClean(fileIds: string[]): Promise<void> {
  await db.transaction("rw", db.books, async () => {
    for (const fileId of fileIds) {
      await db.books.update(fileId, { isDirty: false });
    }
  });
}
