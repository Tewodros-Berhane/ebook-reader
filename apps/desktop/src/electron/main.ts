import { app, BrowserWindow, ipcMain, shell } from "electron";
import path from "node:path";
import { createServer } from "node:http";
import { URL } from "node:url";

type OAuthConfig = {
  clientId: string;
  clientSecret: string;
  redirectUri: string;
  scopes: string[];
};

type TokenPayload = {
  accessToken: string;
  refreshToken?: string;
  expiresAt?: number;
};

const TOKEN_FILE = "auth.json";

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
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      code,
      client_id: config.clientId,
      client_secret: config.clientSecret,
      redirect_uri: config.redirectUri,
      grant_type: "authorization_code",
    }),
  });
  if (!res.ok) {
    throw new Error(`Token exchange failed (${res.status}).`);
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
