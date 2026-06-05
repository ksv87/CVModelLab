# Android and iOS Remote Clients

CV Model Lab Android and iOS apps are remote-only clients for the optional
FastAPI server mode. They do not open local COCO annotations, prediction JSON
files, image folders, or local project files from the device.

The native app name is **CV Model Lab**. Android `applicationId` and iOS bundle
identifier are `ru.ksv87.cvmodellab`.

## Requirements

- A running CV Model Lab Server.
- Network access from the mobile device to the server URL.
- An API key if the server is configured to require one.

Server setup is documented in [Server Mode](server_mode.md).

## Connect to a Server

1. Start the mobile app.
2. The home screen shows **Remote client mode**, **Connect to Server**, and
   **Open Recent Remote Project**.
3. Tap **Connect to Server**.
4. Enter the server URL manually, for example `http://192.168.1.20:8080`.
5. Enter the API key if required.
6. Enable **Remember API key on this device** only when the key should be kept
   in the app preferences on this device.
7. Tap **Test connection**, then open a server project.

Saved API keys can be forgotten from the same connection screen. API keys are
not written to `.cvmlab.json` project files or recent remote project
descriptors.

## Server Manifest Projects

When the server has manifests enabled, the app lists configured server
projects after a successful connection. Opening a manifest project uses the
server-side paths from that manifest. Reopening a recent remote project does not
require selecting server paths again.

## Custom Server Paths

When the server allows custom paths, the app uses the server file browser to
select:

- COCO annotations JSON;
- images root directory;
- one or more prediction JSON files;
- optional AP metrics JSON files when supported by the server workflow.

The file browser shows server-side allowed roots only. It is not a local device
file picker.

## Disabled on Mobile

Android and iOS apps intentionally disable:

- local standalone dataset projects;
- local COCO annotations, predictions, and image selection from the device;
- local project import from device storage;
- local Python COCO AP evaluator;
- broad Android storage permissions and iOS document-picker dataset access.

Desktop local mode and Web/PWA local mode remain available on their respective
platforms.

Theme and language controls remain available in the app bar. There is no
separate mobile settings entry on the startup screen.

## Reports and Exports

Mobile report support is limited in this version. Exports that require local
folder selection are disabled in the native mobile apps. Use Desktop or Web/PWA
for full HTML, CSV, XLSX, PDF, and annotated-image export workflows.

## Troubleshooting

- **Server unreachable:** verify that the phone and server are on the same
  network or that the server URL is reachable from the phone browser.
- **Invalid API key:** re-enter the key, test the connection again, and forget
  any saved key if stale credentials were stored.
- **No server projects:** enable manifests in the server configuration or use
  custom server paths if the server allows them.
- **Custom paths unavailable:** check the server configuration for allowed roots
  and custom-paths support.
