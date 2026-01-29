const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("electronAPI", {
  startDesktopOAuth: (payload) => ipcRenderer.invoke("oauth:desktop", payload),
  refreshDesktopToken: (payload) => ipcRenderer.invoke("oauth:refresh", payload),
});
