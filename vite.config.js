import { defineConfig } from 'vite';
import { VitePWA } from 'vite-plugin-pwa';

export default defineConfig({
  plugins: [VitePWA({
    registerType: 'autoUpdate',
    includeAssets: ['icons/apple-touch-icon.png'],
    manifest: {
      name: 'Hangbeat · Fingerboard Timer',
      short_name: 'Hangbeat',
      description: 'Offline 7/3 fingerboard repeater timer',
      start_url: './',
      scope: './',
      display: 'standalone',
      background_color: '#0b0d0c',
      theme_color: '#0b0d0c',
      orientation: 'portrait-primary',
      icons: [
        { src: 'icons/icon-192.png', sizes: '192x192', type: 'image/png' },
        { src: 'icons/icon-512.png', sizes: '512x512', type: 'image/png' }
      ]
    },
    workbox: {
      cleanupOutdatedCaches: true,
      globPatterns: ['**/*.{html,js,css,png,webmanifest}']
    }
  })]
});
