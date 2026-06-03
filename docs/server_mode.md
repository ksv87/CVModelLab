# Server Mode

[Русская версия](ru/server_mode.md) | [README](../README.md)

CV Model Lab can run in two modes:

- **Local standalone mode** (default): all datasets, predictions and evaluation
  run on your machine, exactly as before.
- **Optional server mode**: a Python FastAPI backend browses datasets under
  configured allowed roots, parses and evaluates COCO data server-side, serves
  image bytes and thumbnails, computes AP metrics, and serves the Flutter
  Web/PWA build. The Desktop app connects to it; the PWA served by the backend
  talks only to its own origin.

The server is **read-only** with respect to datasets and prediction files. The
only data it writes is its own cache and logs.

## Requirements

- Python 3.9+
- [`uv`](https://docs.astral.sh/uv/) (recommended)

## Installing and running the server

```bash
cd server
uv venv
uv pip install -e ".[dev]"
cp server.example.yaml server.yaml   # then edit allowed_roots
uv run python -m cvmlab_server.main --config server.yaml
```

Or use the helper scripts from the repository root:

```bash
scripts/run_server.sh server/server.yaml     # Linux/macOS
scripts/run_server.ps1 -Config server/server.yaml   # Windows
```

## Configuration

The server reads a YAML config file. Key fields:

```yaml
host: the current version.0
port: 8080

api_key: null            # set to require X-CVML-API-Key on every request

allowed_roots:           # mandatory; the only directories the server may read
  - id: datasets
    path: /data/datasets
    label: Datasets
  - id: experiments
    path: /data/experiments
    label: Experiments

project_manifests:       # optional admin-configured server projects
  enabled: false
  directory: /data/cvmlab-projects

custom_server_paths:     # allow clients to pick files via the server browser
  enabled: true

cache:
  enabled: true
  directory: .cvmlab-server-cache

logs:
  directory: .cvmlab-server-logs

static_web:
  enabled: true
  root: ../build/web

cors:
  enabled: true
  allowed_origins:
    - http://localhost:*
```

`host`, `port` and `api_key` can also be overridden with `--host`, `--port` and
the `CVMLAB_HOST` / `CVMLAB_PORT` / `CVMLAB_API_KEY` environment variables.

### Allowed roots

`allowed_roots` is mandatory. The server only ever reads files inside these
directories. Path traversal (`..`), absolute paths that escape the roots, and
symlinks whose target escapes the roots are all rejected.

## Authentication and the open-access warning

- If `api_key` is set, every `/api/` request must include the header
  `X-CVML-API-Key: <key>` — including `/api/health` and `/api/config`. Only the
  static web app is served without the key.
- If `api_key` is not set, the server runs in **open-access** mode: anyone who
  can reach the host can browse the allowed roots and read dataset files.

To protect against accidental exposure:

- In an interactive terminal the server prints a warning and asks for
  confirmation before starting without an API key. The default answer is **no**.
- When started non-interactively (no TTY), the server refuses to start without
  an API key unless you pass `--allow-unauthenticated`.

The API key value is never written to logs.

## Serving the PWA

Build the Flutter web app and point `static_web.root` at it:

```bash
flutter build web        # produces build/web
```

The PWA is then served at `http://<host>:<port>/`. It automatically uses the
same origin for the API, so a PWA served by a server only talks to that server.
If the web build is missing, the API still runs and the root shows a short help
message.

## Connecting from the Desktop app

1. On the Open screen, choose **Connect to Server**.
2. Enter the server URL and, if required, the API key.
3. Optionally tick **Save API key for this server** to remember it in local
   preferences (it is associated with the server URL and is never written to a
   project file).
4. Press **Test connection**.

Then open a project in one of two ways:

- **Server manifest project** (if manifests are enabled): choose a project from
  the list the administrator configured.
- **Custom server paths** (if enabled): browse the server's allowed roots and
  select the annotations JSON, images directory, and predictions JSON.

### Server manifest mode

An administrator can place JSON manifests in `project_manifests.directory`:

```json
{
  "schema_version": 1,
  "id": "traffic_lights_yolox",
  "name": "Traffic Lights YOLOX",
  "annotations_path": "/data/datasets/traffic/annotations/instances_val.json",
  "images_root_path": "/data/datasets/traffic/images",
  "model_runs": [
    {
      "id": "yolox_s_960_epoch_70",
      "name": "YOLOX-S 960 epoch 70",
      "predictions_path": "/data/experiments/run70/predictions.json",
      "ap_metrics_path": "/data/experiments/run70/ap_metrics.json"
    }
  ]
}
```

All manifest paths are validated against the allowed roots. The server never
modifies manifest files.

## Remote project files

When you open a remote project you can save a local `.cvmlab.json` describing
it. The file stores the server URL and either the manifest id or the custom
server paths, so reopening it does not require re-selecting files. The API key
is never stored in the project file.

Existing local project files continue to load unchanged.

## Cache and logs

The server's only durable writes are:

- parsed/index and evaluation cache,
- lazily generated thumbnails,
- logs.

The cache can be cleared with `POST /api/cache/clear`.

## AP metrics

In server mode, COCO AP metrics run on the server. If a model run defines an
`ap_metrics_path`, the server loads it; otherwise it computes AP with
pycocotools. The Desktop client does not need Python or pycocotools in remote
mode.

## Limitations

- Server mode is read-only: it never edits annotations, predictions, or
  projects, and never uploads datasets.
- The current remote client downloads the parsed dataset, predictions, matches
  and metrics for a project, which is well suited to small and medium datasets.
  Very large datasets (hundreds of thousands of images) are supported by the
  server's paginated and per-image endpoints, which a future client release will
  use directly.
- Multi-tenant accounts, editing, and uploads are out of scope.
