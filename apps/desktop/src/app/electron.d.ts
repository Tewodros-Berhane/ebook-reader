declare global {
  interface Window {
    electronAPI?: {
      startDesktopOAuth: (payload: {
        clientId: string;
        redirectUri: string;
        scopes: string[];
      }) => Promise<{
        accessToken: string;
        refreshToken?: string;
        expiresAt?: number;
      }>;
      refreshDesktopToken: (payload: {
        clientId: string;
        refreshToken: string;
      }) => Promise<{
        accessToken: string;
        refreshToken?: string;
        expiresAt?: number;
      }>;
    };
  }
}

export {};
