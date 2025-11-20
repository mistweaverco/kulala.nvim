#!/usr/bin/env electron

import { app, BrowserWindow } from "electron";

const args = process.argv.slice(2);

// Parse named arguments (--key=value) and positional arguments
const argv = args.reduce((acc, arg, index) => {
  const i = arg.indexOf("=");
  if (arg.startsWith("--")) {
    const key = i == -1 ? arg : arg.slice(0, i);
    const value = i == -1 ? true : arg.slice(i + 1);
    const cleanKey = key.slice(2);
    acc[cleanKey] = value;
  } else if (index === 0 && !acc.authorizeUrl) {
    acc.authorizeUrl = arg;
  } else if (index === 1 && !acc.callbackUrl) {
    acc.callbackUrl = arg;
  }
  return acc;
}, {});

async function createWindow() {
  const authorizeUrl = argv.authorizeUrl;
  const callbackUrl = argv.callbackUrl || "http://localhost:8080";
  const resetCookies = argv.resetCookies;
  const url = new URL(authorizeUrl);
  const redirectUrl = url.searchParams.get("redirect_uri");

  const mainWindow = new BrowserWindow({
    width: 900,
    height: 720,
  });

  if (resetCookies) {
    await mainWindow.webContents.session.clearStorageData({
      storages: ["cookies"],
    });
  }

  mainWindow.webContents.on("will-redirect", (event, url) => {
    if (url.startsWith(redirectUrl)) {
      event.preventDefault();
      const interceptedUrl = new URL(url);
      const newCallbackUrl = new URL(callbackUrl);
      interceptedUrl.searchParams.forEach((value, key) => {
        newCallbackUrl.searchParams.append(key, value);
      });
      mainWindow.loadURL(newCallbackUrl.toString());
    }
  });

  mainWindow.webContents.on("did-finish-load", async () => {
    try {
      const content = await mainWindow.webContents.executeJavaScript(
        "document.body.innerText",
      );
      if (content && content.includes("Code/Token received")) {
        setTimeout(() => {
          mainWindow.close();
        }, 1000);
      }
    } catch (error) {
      // Ignore errors from reading page content
    }
  });

  mainWindow.loadURL(authorizeUrl);
}

app.whenReady().then(createWindow);

app.on("window-all-closed", () => {
  app.quit();
});

app.on("activate", () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});
