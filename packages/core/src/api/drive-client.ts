import type { SyncFile } from "../types/index";

const DRIVE_API_BASE = "https://www.googleapis.com/drive/v3";
const DRIVE_UPLOAD_BASE = "https://www.googleapis.com/upload/drive/v3";

export interface DriveFile {
  id: string;
  name: string;
  mimeType: string;
  modifiedTime?: string;
  size?: string;
}

export class GoogleDriveClient {
  constructor(private readonly accessToken: string) {}

  private async request<T>(url: string, init?: RequestInit): Promise<T> {
    if (!this.accessToken) {
      throw new Error("Missing Google Drive access token.");
    }
    const res = await fetch(url, {
      ...init,
      headers: {
        Authorization: `Bearer ${this.accessToken}`,
        "Content-Type": "application/json",
        ...(init?.headers ?? {}),
      },
    });

    if (!res.ok) {
      const message = await res.text();
      throw new Error(`Drive request failed (${res.status}): ${message}`);
    }
    return (await res.json()) as T;
  }

  async listEpubFiles(folderId?: string): Promise<DriveFile[]> {
    const folderClause = folderId ? ` and '${folderId}' in parents` : "";
    const query = encodeURIComponent(`mimeType='application/epub+zip' and trashed=false${folderClause}`);
    const fields = encodeURIComponent("files(id,name,mimeType,modifiedTime,size)");
    const url = `${DRIVE_API_BASE}/files?q=${query}&fields=${fields}&includeItemsFromAllDrives=true&supportsAllDrives=true`;
    const data = await this.request<{ files: DriveFile[] }>(url);
    return data.files ?? [];
  }

  async downloadFile(fileId: string): Promise<Response> {
    const url = `${DRIVE_API_BASE}/files/${fileId}?alt=media&supportsAllDrives=true`;
    return fetch(url, {
      headers: {
        Authorization: `Bearer ${this.accessToken}`,
      },
    });
  }

  async getAppDataSyncFile(): Promise<{ id: string; content: SyncFile } | null> {
    const query = encodeURIComponent("name='sync.json' and trashed=false");
    const fields = encodeURIComponent("files(id,name)");
    const url = `${DRIVE_API_BASE}/files?q=${query}&spaces=appDataFolder&fields=${fields}`;
    const data = await this.request<{ files: { id: string; name: string }[] }>(url);
    if (!data.files?.length) return null;
    const fileId = data.files[0].id;
    const contentUrl = `${DRIVE_API_BASE}/files/${fileId}?alt=media`;
    const content = await this.request<SyncFile>(contentUrl);
    return { id: fileId, content };
  }

  async upsertAppDataSyncFile(payload: SyncFile, fileId?: string): Promise<string> {
    if (fileId) {
      const url = `${DRIVE_UPLOAD_BASE}/files/${fileId}?uploadType=media`;
      await this.request(url, {
        method: "PATCH",
        body: JSON.stringify(payload),
      });
      return fileId;
    }

    const metadata = {
      name: "sync.json",
      parents: ["appDataFolder"],
    };
    const url = `${DRIVE_UPLOAD_BASE}/files?uploadType=multipart`;
    const boundary = "lumina-sync-boundary";
    const body = [
      `--${boundary}`,
      "Content-Type: application/json; charset=UTF-8",
      "",
      JSON.stringify(metadata),
      `--${boundary}`,
      "Content-Type: application/json",
      "",
      JSON.stringify(payload),
      `--${boundary}--`,
    ].join("\r\n");

    const res = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${this.accessToken}`,
        "Content-Type": `multipart/related; boundary=${boundary}`,
      },
      body,
    });

    if (!res.ok) {
      const message = await res.text();
      throw new Error(`Drive upload failed (${res.status}): ${message}`);
    }
    const data = (await res.json()) as { id: string };
    return data.id;
  }
}
