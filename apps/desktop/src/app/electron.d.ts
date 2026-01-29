declare global {
  interface Window {
    electronAPI?: {
      startDesktopOAuth: (payload: {
        clientId: string;
        clientSecret: string;
        redirectUri: string;
        scopes: string[];
      }) => Promise<{
        accessToken: string;
        refreshToken?: string;
        expiresAt?: number;
      }>;
    };
  }
}

export {};
