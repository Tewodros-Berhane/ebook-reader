export type PickerConfig = {
  apiKey: string;
  appId?: string;
};

export interface PickerConfigStore {
  getConfig: () => PickerConfig | null;
  setConfig: (config: PickerConfig) => void;
  clearConfig: () => void;
}

const STORAGE_KEY = "lumina_picker_config";

export function createPickerConfigStore(): PickerConfigStore {
  return {
    getConfig: () => {
      if (typeof window === "undefined") return null;
      const raw = window.localStorage.getItem(STORAGE_KEY);
      if (!raw) return null;
      try {
        return JSON.parse(raw) as PickerConfig;
      } catch {
        return null;
      }
    },
    setConfig: (config) => {
      if (typeof window === "undefined") return;
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(config));
    },
    clearConfig: () => {
      if (typeof window === "undefined") return;
      window.localStorage.removeItem(STORAGE_KEY);
    },
  };
}
