import { db } from "./schema";

export async function saveFileBlob(fileId: string, blob: Blob): Promise<void> {
  await db.files.put({ fileId, blob });
}

export async function getFileBlob(fileId: string): Promise<Blob | undefined> {
  const record = await db.files.get(fileId);
  return record?.blob;
}

export async function deleteFileBlob(fileId: string): Promise<void> {
  await db.files.delete(fileId);
}
