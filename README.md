# Hangbeat PWA

The original SwiftUI timer rebuilt as an installable, offline Web app. It keeps the 7-second hang / 3-second rest rhythm, five hangs per set by default, and spoken cues. A Dashboard shows completed training days, and Max Hang measures and saves continuous hangs. The iOS project is preserved in `finger_train/`.

Install dependencies and run locally with Vite:

```sh
pnpm install
pnpm run dev
```

Open <http://localhost:4173>. Use **Install app** or your mobile browser's **Add to Home Screen** action. PWA installation and offline caching require HTTPS or `localhost`. Preferences and training records are stored only in that browser on that device; they do not sync between devices or domains.

Run tests with `pnpm test`. Build the production PWA with `pnpm run build`; Vite writes the deployable site to `dist/`.

To publish elsewhere, serve `dist/` as a static HTTPS site.
