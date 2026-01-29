export type DesktopOAuthConfig = {
  clientId: string;
  redirectUri: string;
  scopes: string[];
};

export async function startDesktopOAuth(_config: DesktopOAuthConfig) {
  throw new Error("Desktop OAuth loopback not wired. Requires Electron main process.");
}
