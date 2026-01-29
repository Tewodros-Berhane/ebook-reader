import dotenv from "dotenv";
import { app, BrowserWindow, ipcMain, shell } from "electron";
import path from "node:path";
import { createServer } from "node:http";
import { URL, fileURLToPath } from "node:url";

dotenv.config({ path: path.resolve(process.cwd(), ".env.local") });
dotenv.config({ path: path.resolve(process.cwd(), ".env") });

type OAuthConfig = {
  clientId: string;
  redirectUri: string;
  scopes: string[];
};

type RefreshConfig = {
  clientId: string;
  refreshToken: string;
};

type TokenPayload = {
  accessToken: string;
  refreshToken?: string;
  expiresAt?: number;
};

const TOKEN_FILE = "auth.json";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

function getTokenPath() {
  return path.join(app.getPath("userData"), TOKEN_FILE);
}

async function saveTokens(tokens: TokenPayload) {
  await app.whenReady();
  const fs = await import("node:fs/promises");
  await fs.writeFile(getTokenPath(), JSON.stringify(tokens, null, 2), "utf-8");
}

function buildAuthUrl(config: OAuthConfig) {
  const params = new URLSearchParams({
    client_id: config.clientId,
    redirect_uri: config.redirectUri,
    response_type: "code",
    access_type: "offline",
    prompt: "consent",
    scope: config.scopes.join(" "),
  });
  return `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`;
}

async function exchangeCode(config: OAuthConfig, code: string): Promise<TokenPayload> {
  const clientSecret = process.env.LUMINA_DESKTOP_CLIENT_SECRET;
  if (!clientSecret) {
    throw new Error("Missing LUMINA_DESKTOP_CLIENT_SECRET in env.");
  }
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      code,
      client_id: config.clientId,
      client_secret: clientSecret,
      redirect_uri: config.redirectUri,
      grant_type: "authorization_code",
    }),
  });
  if (!res.ok) {
    const errorText = await res.text();
    throw new Error(`Token exchange failed (${res.status}): ${errorText}`);
  }
  const data = (await res.json()) as {
    access_token: string;
    refresh_token?: string;
    expires_in?: number;
  };
  return {
    accessToken: data.access_token,
    refreshToken: data.refresh_token,
    expiresAt: data.expires_in ? Date.now() + data.expires_in * 1000 : undefined,
  };
}

async function refreshAccessToken(payload: RefreshConfig): Promise<TokenPayload> {
  const clientSecret = process.env.LUMINA_DESKTOP_CLIENT_SECRET;
  if (!clientSecret) {
    throw new Error("Missing LUMINA_DESKTOP_CLIENT_SECRET in env.");
  }
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: payload.clientId,
      client_secret: clientSecret,
      refresh_token: payload.refreshToken,
      grant_type: "refresh_token",
    }),
  });
  if (!res.ok) {
    const errorText = await res.text();
    throw new Error(`Token refresh failed (${res.status}): ${errorText}`);
  }
  const data = (await res.json()) as {
    access_token: string;
    expires_in?: number;
  };
  const tokens: TokenPayload = {
    accessToken: data.access_token,
    refreshToken: payload.refreshToken,
    expiresAt: data.expires_in ? Date.now() + data.expires_in * 1000 : undefined,
  };
  await saveTokens(tokens);
  return tokens;
}

async function startLoopbackOAuth(config: OAuthConfig): Promise<TokenPayload> {
  const redirectUrl = new URL(config.redirectUri);
  const port = Number(redirectUrl.port || "4200");
  const pathName = redirectUrl.pathname || "/oauth2callback";

  return new Promise((resolve, reject) => {
    const server = createServer(async (req, res) => {
      try {
        if (!req.url) return;
        const url = new URL(req.url, config.redirectUri);
        if (url.pathname !== pathName) return;
        const code = url.searchParams.get("code");
        const error = url.searchParams.get("error");
        if (error) throw new Error(error);
        if (!code) throw new Error("Missing OAuth code.");
        const tokens = await exchangeCode(config, code);
        await saveTokens(tokens);
        res.writeHead(200, { "Content-Type": "text/html" });
        res.end("<h1>Auth complete. You can close this window.</h1>");
        server.close();
        resolve(tokens);
      } catch (err) {
        server.close();
        reject(err);
      }
    });

    server.listen(port, () => {
      shell.openExternal(buildAuthUrl(config)).catch(reject);
    });
  });
}

ipcMain.handle("oauth:desktop", async (_event, payload: OAuthConfig) => {
  return startLoopbackOAuth(payload);
});

ipcMain.handle("oauth:refresh", async (_event, payload: RefreshConfig) => {
  return refreshAccessToken(payload);
});

function createWindow() {
  const win = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
    },
  });

  const url = process.env.LUMINA_DESKTOP_URL ?? "http://localhost:3000";
  win.loadURL(url);
}

app.whenReady().then(() => {
  createWindow();
  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});
