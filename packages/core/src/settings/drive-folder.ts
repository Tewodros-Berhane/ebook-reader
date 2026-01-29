export interface DriveFolderStore {
  getFolderId: () => string | null;
  setFolderId: (folderId: string) => void;
  clearFolderId: () => void;
}

const STORAGE_KEY = "lumina_drive_folder_id";

export function createDriveFolderStore(): DriveFolderStore {
  return {
    getFolderId: () => {
      if (typeof window === "undefined") return null;
      return window.localStorage.getItem(STORAGE_KEY);
    },
    setFolderId: (folderId) => {
      if (typeof window === "undefined") return;
      window.localStorage.setItem(STORAGE_KEY, folderId);
    },
    clearFolderId: () => {
      if (typeof window === "undefined") return;
      window.localStorage.removeItem(STORAGE_KEY);
    },
  };
}
