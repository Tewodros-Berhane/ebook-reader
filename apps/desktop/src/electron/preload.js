const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("electronAPI", {
  startDesktopOAuth: (payload) => ipcRenderer.invoke("oauth:desktop", payload),
});
