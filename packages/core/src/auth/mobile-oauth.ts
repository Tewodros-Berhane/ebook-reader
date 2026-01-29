export type MobileOAuthConfig = {
  clientId: string;
  scopes: string[];
};

export async function startMobileOAuth(_config: MobileOAuthConfig) {
  throw new Error("Mobile OAuth stub. Requires Capacitor Google Sign-In wiring.");
}
