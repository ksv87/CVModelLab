# Mobile PWA / Responsive Web

[Русская версия](ru/mobile_pwa.md)

CV Model Lab adapts its Web/PWA build to narrow and mobile screens. The same
application runs as a desktop app, a wide-screen browser app, and a responsive
mobile web app without adding native Android or iOS targets.

## When the mobile layout is used

The UI switches between three layout size classes based on the available width:

| Size class | Width (logical px) | Layout |
|------------|--------------------|--------|
| Compact    | `< 700`            | Mobile-first layout with bottom navigation |
| Medium     | `700 – 1099`       | Desktop layout with reduced side panels |
| Expanded   | `>= 1100`          | Full desktop layout |

"Mobile web" therefore covers Android Chrome, iOS Safari, an installed PWA on a
phone, and a desktop browser window resized to a narrow width — they all use the
same compact layout.

## Browser / PWA workflow

- **Local standalone web** keeps the lightweight browser workflow: open COCO
  annotations, predictions, and images through the browser file picker, and use
  Web/PWA restore mode. The image viewer, metrics, comparison, and report
  exports all work on a phone-sized screen.
- **Remote (server) mode** connects to a self-hosted FastAPI backend and browses
  server-side datasets, exactly as on desktop.

## Compact navigation

On compact width the three-panel desktop workspace is replaced by a bottom
navigation bar with six destinations:

- **Project** — project/server info, active model run selector, evaluation
  thresholds, COCO AP status, and reload.
- **Images** — the image browser. Filters open in a bottom sheet; tapping an
  image opens the full-screen mobile viewer.
- **Metrics** — Dashboard, Dataset Health, Confusion Matrix, Worst Cases, and
  Recommendations, selected with a chip bar.
- **Compare** — opens pairwise / multi-model comparison (requires at least two
  model runs).
- **Reports** — report and annotated-image export.
- **More** — language, theme, server connection info, and project actions.

## Mobile image viewer

The full-screen image viewer supports:

- pinch-to-zoom and pan;
- fit-to-screen;
- next / previous image and next / previous error;
- an overlay-options bottom sheet (GT, predictions, TP, FP, FN, labels, scores,
  IoU);
- a bounding-box details bottom sheet (type, class, score, IoU, bbox, reason,
  model run) when a box is tapped.

Missing images show a readable placeholder.

## Tables and filters on small screens

Wide tables degrade gracefully. The image list uses list tiles, filters move
into a bottom sheet, and the Confusion Matrix defaults to a **Top confused
pairs** list with the full matrix available behind the "Top pairs" toggle (the
full matrix scrolls horizontally when needed). Leaderboards and per-class tables
remain available and scroll horizontally on narrow widths.

## Reports on mobile web

The export dialog fits narrow screens, wraps long labels, keeps AP toggles
accessible, and shows a notice that large exports may take time in a mobile
browser. Report generation itself is unchanged.

## Same-origin PWA behavior

- When the PWA is **served by a CV Model Lab backend**, the app probes
  `/api/config` at its own origin. If a backend is detected (a valid config, or
  a `401` when the server requires a key), the server URL is fixed to that
  origin and cannot be edited; the app asks for an API key if the server
  requires one.
- When the app runs **standalone** (for example `flutter run -d chrome` or
  static hosting without a backend), the `/api/config` probe fails, so the
  server URL stays editable and the local file-picker workflows remain
  available.

## Known limitations

- Native Android and iOS apps are not part of this phase; the mobile experience
  is delivered through responsive Web/PWA only.
- COCO AP evaluation still cannot run inside a browser; import precomputed AP
  metrics JSON, or compute AP on desktop/server.
- Multi-model comparison tables on very narrow screens rely on horizontal
  scrolling rather than a full card layout.
- Very large report exports can be slow in a mobile browser.
