export type AuthTokens = {
  accessToken: string;
  refreshToken?: string;
  expiresAt?: number;
};

export interface TokenStore {
  getTokens: () => AuthTokens | null;
  setTokens: (tokens: AuthTokens) => void;
  clearTokens: () => void;
}

const STORAGE_KEY = "lumina_auth_tokens";

export function createWebTokenStore(): TokenStore {
  return {
    getTokens: () => {
      if (typeof window === "undefined") return null;
      const raw = window.localStorage.getItem(STORAGE_KEY);
      if (!raw) return null;
      try {
        return JSON.parse(raw) as AuthTokens;
      } catch {
        return null;
      }
    },
    setTokens: (tokens) => {
      if (typeof window === "undefined") return;
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(tokens));
    },
    clearTokens: () => {
      if (typeof window === "undefined") return;
      window.localStorage.removeItem(STORAGE_KEY);
    },
  };
}
