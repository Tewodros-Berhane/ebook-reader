import { GoogleDriveClient } from "../api/drive-client";
import { saveFileBlob } from "../db/files";
import { setBookDownloadStatus } from "../db/books";

export async function downloadAndCacheBook(
  fileId: string,
  accessToken: string,
): Promise<void> {
  const client = new GoogleDriveClient(accessToken);
  await setBookDownloadStatus(fileId, "downloading");
  const response = await client.downloadFile(fileId);
  if (!response.ok) {
    throw new Error(`Download failed (${response.status}).`);
  }
  const blob = await response.blob();
  await saveFileBlob(fileId, blob);
  await setBookDownloadStatus(fileId, "ready", `idb://${fileId}`);
}
