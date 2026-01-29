import { GoogleDriveClient } from "../api/drive-client";
import { applyCloudProgress, listLocalBooks, markBooksClean } from "../db/books";
import { mergeSyncFile } from "./sync-service";

export async function syncWithCloud(client: GoogleDriveClient, deviceName?: string) {
  const localBooks = await listLocalBooks();
  const cloudFile = await client.getAppDataSyncFile();
  const cloudContent = cloudFile?.content ?? null;
  const { merged, decisions } = mergeSyncFile(localBooks, cloudContent, deviceName);

  const pulls = decisions.filter((d) => d.action === "pull");
  const pushes = decisions.filter((d) => d.action === "push");

  for (const pull of pulls) {
    if (pull.cloud) {
      await applyCloudProgress(pull.fileId, pull.cloud.cfi, pull.cloud.ts);
    }
  }

  let uploaded = false;
  if (!cloudFile || pushes.length > 0) {
    await client.upsertAppDataSyncFile(merged, cloudFile?.id);
    uploaded = true;
  }

  if (uploaded && pushes.length > 0) {
    await markBooksClean(pushes.map((p) => p.fileId));
  }

  return { decisions, uploaded };
}
