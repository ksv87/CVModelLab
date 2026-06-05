# CV Model Lab

[Русская версия](README.ru.md)

Cross-platform Flutter Desktop + PWA tool for COCO object detection dataset and model error analysis.

CV Model Lab helps inspect dataset quality and object detection inference results without a backend. Load COCO annotations, model predictions, and local images, then review TP/FP/FN matches, class-level metrics, class confusion, worst cases, dataset health signals, model comparison results, and exportable reports.

## Why CV Model Lab

Object detection model failures are hard to understand from aggregate metrics alone. CV Model Lab is built for the practical review loop after inference:

- Find false positives, false negatives, duplicates, and wrong-class predictions.
- Compare two model runs on the same dataset and see what was fixed or broken.
- Check whether failures are caused by model behavior, class imbalance, missing images, suspicious boxes, or small objects.
- Export shareable reports for dataset and model review.

## Features

- COCO annotations loading.
- COCO predictions loading by `image_id` and by `file_name`.
- Deterministic TP/FP/FN matching with configurable IoU and confidence thresholds.
- Error Browser with class, match type, confidence, IoU, object size, and missing-image filters.
- Image viewer with GT and prediction overlays.
- Dataset Health Check for missing images, suspicious boxes, rare classes, and imbalance.
- Confusion Matrix with GT rows, prediction columns, missed objects, and background false positives.
- Worst Cases mining for review queues.
- Rule-based Recommendations with deterministic evidence and suggested actions.
- English/Russian localization for recommendations, Dataset Health issues,
  parser warnings, friendly errors, and report headings.
- Model Comparison with fixed, broken, improved, and regressed image statuses.
- Multi-model comparison for 3+ runs: leaderboard, per-class ranking, image
  disagreement, pairwise regression matrix, consensus summary, and a 3+ model
  Compare Viewer.
- COCO AP metrics (AP@[.5:.95], AP50, AP75, AP/AR by object size, AR1/10/100, per-class AP) via a pycocotools sidecar on desktop, or by importing precomputed AP JSON.
- HTML and CSV export.
- XLSX workbook export.
- PDF report export.
- Annotated Image Export for visual overlays.
- Desktop project save/load with automatic reload from saved paths via Recent Projects.
- Model run renaming and project renaming from the workspace AppBar.
- Desktop Recent Projects and last-used folder preferences.
- Image Browser thumbnail cache with web-safe fallback.
- Web/PWA restore mode for browser workflows.
- Desktop, Web/PWA, and Android/iOS remote-client support from the same app
  experience.

## Sample Reports

Generated sample reports are included for the synthetic Showcase Demo dataset.
They are safe to share: the dataset uses generated geometric scenes, not real data.

Recommended examples:
- Full evaluation: `demo/showcase_coco/reports/en/all reports/cv_model_lab_report.html`
- Pairwise compare: `demo/showcase_coco/reports/en/pairwise compare/cv_model_lab_report.html`
- Multi-model compare: `demo/showcase_coco/reports/en/multi-model compare/cv_model_lab_report.html`
- Russian multi-model example: `demo/showcase_coco/reports/ru/multi-model compare/cv_model_lab_report.html`

The folder also contains CSV, XLSX, and PDF exports. CSV headers intentionally stay English for machine-readable compatibility.
See [docs/showcase_demo.md](docs/showcase_demo.md) and [demo/showcase_coco/reports/README.md](demo/showcase_coco/reports/README.md).

## Supported Platforms

| Platform | Local standalone datasets | Remote server projects |
|----------|---------------------------|------------------------|
| Linux / Windows / macOS desktop | Yes | Yes |
| Web/PWA | Yes, through browser-selected files | Yes |
| Android / iOS apps | No | Yes, remote only |

Desktop builds require the corresponding Flutter desktop toolchain on the target host. The web build runs without a backend and uses browser file selection APIs.

## Android and iOS Apps

Android and iOS apps are remote-only clients for CV Model Lab Server. They start
in **Remote client mode**, connect to a manually entered server URL, and open
server manifest projects or custom server paths through the server file
browser. They do not request broad storage permissions and do not open local
COCO annotations, predictions, image folders, local project files, or the local
AP evaluator from the device.

Details: [Android and iOS Remote Clients](docs/mobile_apps.md) /
[Android и iOS как удалённые клиенты](docs/ru/mobile_apps.md).

## Mobile PWA

The Web/PWA build is responsive and adapts to narrow and mobile screens. On
compact widths it switches to a mobile-first layout with bottom navigation
(Project, Images, Metrics, Compare, Reports, More), a full-screen image viewer
with pinch/pan and overlay options, filters in bottom sheets, a mobile-friendly
Confusion Matrix top-pairs view, and a narrow-screen export dialog. The
desktop layout is preserved on wide screens.

This works on Android Chrome, iOS Safari, an installed PWA, and a resized
desktop browser window. Native Android and iOS apps use the separate remote-only
client mode described above.

Details: [Mobile PWA](docs/mobile_pwa.md) / [Мобильный PWA](docs/ru/mobile_pwa.md).

## Supported Formats

- COCO detection annotations JSON.
- COCO predictions/results JSON with `image_id`.
- COCO predictions/results JSON with `file_name`, resolved against COCO image records.
- Local image directories or selected image files, matched by relative path and basename fallback.

Details and examples: [Supported Formats](docs/supported_formats.md) / [Форматы данных](docs/ru/supported_formats.md).

## Quick Start

1. Download the latest desktop build from the public release page, or open the hosted Web/PWA build if available.
2. Start CV Model Lab.
3. To try the showcase dataset, click **Open project** and select `demo/showcase_coco/showcase_coco.cvmlab.json`.
4. For your own data, open COCO annotations, prediction JSON files, and an image directory or selected image files.

## Typical Workflow

1. Open a COCO annotations JSON file.
2. Open one or more COCO prediction JSON files.
3. Select an image directory or image file set.
4. Review parser warnings and image matching status.
5. Inspect overall and per-class metrics on the dashboard.
6. Use Error Browser filters to analyze FP/FN/TP examples.
7. Check Dataset Health for input-data issues.
8. Open Confusion Matrix and Worst Cases to prioritize review.
9. Compare model runs.
10. Run COCO AP metrics on desktop, or import precomputed AP JSON.
11. Export HTML/CSV/XLSX/PDF reports or annotated images.
12. Save the project on desktop or use Web/PWA restore mode in the browser.

User guide: [User Guide](docs/user_guide.md) / [Руководство пользователя](docs/ru/user_guide.md).

> **Showcase dataset:** click **Open project** on the project open screen and select
> `demo/showcase_coco/showcase_coco.cvmlab.json` to load a synthetic three-model
> road-scene dataset with precomputed AP metrics.
> See [Showcase Demo](docs/showcase_demo.md) for details.

## Metrics

CV Model Lab computes:

- TP, FP, and FN matches.
- Precision, recall, and F1.
- Micro and macro averages.
- Per-class statistics.
- Image-level error flags.
- Small, medium, and large object statistics.
- Confusion matrix entries for correct classes, wrong classes, missed GT, and background FP.
- Model comparison statuses: fixed, broken, improved, and regressed.

More detail: [Metrics](docs/metrics.md) / [Метрики](docs/ru/metrics.md).

## Dataset Health Check

Dataset Health Check focuses on input quality rather than model quality. It can flag missing image files, unused selected files, unknown references, invalid or suspicious boxes, images without GT, rare classes, classes without GT, and class imbalance.

## Error Browser

The Error Browser is the main debugging screen. It combines image-level filters, match-type filters, class filters, confidence threshold changes, IoU threshold changes, object-size filters, and missing-image status. The viewer overlays ground-truth boxes and predictions so failure cases can be inspected directly.

## Confusion Matrix

The confusion matrix uses GT categories as rows and predicted categories as columns. It also includes special missed-object and background-false-positive buckets, making wrong-class predictions and background hallucinations visible.

## Worst Cases

Worst Cases ranks images that deserve review first, such as images with many false positives, many false negatives, severe class confusion, high-confidence false positives, low-IoU true positives, or missing local image files.

## Recommendations

Rule-based Recommendations analyze metrics, Dataset Health, Worst Cases, class confusion, and model comparison results. They explain low recall, low precision, rare classes, class imbalance, small-object issues, high-confidence false positives, dataset health errors, threshold tradeoffs, and candidate regressions without using an LLM.

## Model Comparison

Model Comparison loads two prediction runs for the same COCO dataset and compares per-class precision/recall and image-level behavior. Images are grouped as fixed, broken, improved, regressed, still correct, or still wrong depending on how the candidate run changes the error profile. When both runs have COCO AP metrics, the compare screen also shows an AP diff.

## Multi-model Comparison

For three or more model runs, the Model Compare screen has a Multi-model mode. A leaderboard ranks every run by a selectable metric with deterministic tie-breakers; per-class ranking shows the best and worst model per class with F1/recall/AP spreads; image disagreement analysis classifies each image (all correct, all wrong, only one model correct/wrong, class disagreement, large error spread, …); a pairwise regression matrix summarizes every directional pair and opens any cell in Pairwise mode; and a Compare Viewer shows one image across all selected models in a grid. Multi-model results export to HTML, CSV (`multi_model_leaderboard.csv`, `multi_model_per_class.csv`, `multi_model_image_disagreements.csv`, `multi_model_regression_matrix.csv`), XLSX, and PDF.

## COCO AP Metrics

CV Model Lab can compute standard pycocotools-compatible COCO average precision and recall: AP@[.5:.95], AP50, AP75, AP/AR for small/medium/large objects, AR1/AR10/AR100, and per-class AP/AR.

- **Desktop:** the app runs a bundled Python sidecar (`tools/ap_evaluator/ap_eval.py`) that wraps `pycocotools.COCOeval`. The sidecar runs through [uv](https://docs.astral.sh/uv/) if available (no manual dependency install needed) or through a `python3` that has `pycocotools` installed. The "Run COCO AP evaluation" button appears on the dashboard.
- **Web/PWA:** browsers cannot launch a Python process, so AP evaluation cannot run in the web build. Instead, use **Import AP metrics JSON** to load a precomputed AP result (for example, one produced by the desktop app or by running the sidecar manually). Imported AP metrics drive the same dashboard cards, per-class table, comparison AP diff, and report sections.

AP metrics can be included or excluded explicitly in HTML, CSV (`ap_metrics.csv`, `per_class_ap.csv`), XLSX, and PDF exports when available, and are saved into desktop project files.

Sidecar usage and the AP JSON format: [tools/ap_evaluator/README.md](tools/ap_evaluator/README.md).

## Exports

CV Model Lab supports:

- HTML report export.
- CSV export for per-class metrics, image errors, matches, small-object stats, confusion matrix, confusion pairs, dataset health, worst cases, AP metrics, and per-class AP.
- CSV export for rule-based recommendations.
- XLSX workbook export for metrics, errors, matches, health issues, worst cases, recommendations, AP metrics, and comparison tables.
- PDF report export with overall metrics, per-class tables, confusion matrix, recommendations, AP metrics, and comparison summaries.
- Annotated Image Export with overlay images.

## Server Mode (optional)

CV Model Lab can optionally run against a Python FastAPI backend that browses
datasets under configured allowed roots, evaluates COCO data server-side, serves
images, thumbnails and AP metrics, and serves the Flutter Web/PWA build. The
local standalone mode keeps working unchanged. The server is read-only with
respect to datasets and only writes its own cache and logs.

```bash
cd server
uv venv && uv pip install -e ".[dev]"
cp server.example.yaml server.yaml   # edit allowed_roots
uv run python -m cvmlab_server.main --config server.yaml
```

Then use **Connect to Server** on the Open screen (Desktop), or open the PWA the
server serves at its own origin.

Full guide: [Server Mode](docs/server_mode.md) / [Серверный режим](docs/ru/server_mode.md).

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

This license applies only to the CV Model Lab source code.

Synthetic demo and test datasets stored in `demo/` and `test_data/` are released under CC0 1.0 Universal unless their local dataset README states otherwise.

## Third-party components and data

The bundled DejaVu Sans font files in `assets/fonts/` are distributed under the DejaVu Fonts License; see `assets/fonts/LICENSE.DejaVu`.

This repository may reference or integrate third-party models, datasets, runtimes, SDKs, and dependencies. They are subject to their own licenses.

The MIT License in this repository applies only to the CV Model Lab source code unless explicitly stated otherwise.

Users are responsible for ensuring that they have the necessary rights to use any datasets, models, weights, and artifacts processed with this software.
