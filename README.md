# Hangbeat PWA

The original SwiftUI timer rebuilt as an installable, offline Web app. It keeps the 7-second hang / 3-second rest rhythm, five hangs per set by default, spoken cues, and the same compact timer screen. The iOS project is preserved in `finger_train/`.

Install dependencies and run locally with Vite:

```sh
pnpm install
pnpm run dev
```

Open <http://localhost:4173>. Use **Install app** or your mobile browser's **Add to Home Screen** action. PWA installation and offline caching require HTTPS or `localhost`. Timer preferences are stored in the current browser; the app does not collect training history.

Run the timer tests with `pnpm test`. Build the production PWA with `pnpm run build`; Vite writes the deployable site to `dist/`.

To publish elsewhere, serve `dist/` as a static HTTPS site.
