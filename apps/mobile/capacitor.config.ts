import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.example.reader',
  appName: 'ebook-reader',
  webDir: 'out',
  plugins: {
    GoogleAuth: {
      scopes: ['https://www.googleapis.com/auth/drive.appdata', 'https://www.googleapis.com/auth/drive.readonly'],
      serverClientId: 'YOUR_WEB_CLIENT_ID'
    }
  }
};

export default config;
