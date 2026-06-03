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

## Release the current version Highlights

CV Model Lab the current version delivers bug fixes and UX improvements on top of the multi-model comparison foundation:

- **Recent Projects** now auto-loads all files from their saved paths. Restore mode (re-picking files) only activates when a file has moved or been deleted.
- **AP eval results** are correctly saved and restored for every model run in a multi-run project. A previous bug caused only the last run's metrics to survive a reload.
- **Metric formatting** is consistent across all human-readable reports (PDF, HTML, comparison): Precision, Recall, F1, and AP metrics are shown as `xx.x%`. CSV and XLSX keep raw doubles for machine-readable compatibility.
- **Rename model run**: pencil-icon button in the workspace AppBar renames the active run; duplicate names are resolved automatically.
- **Rename project**: double-click on the project name in the AppBar title.
- **Compare screen fix**: opening the Compare screen no longer crashes when a previously saved ranking metric is not available in the per-class dropdown.
- **CI**: build jobs run only on tag pushes; regular push and pull-request runs execute analyze and tests only.

## Release the current version Highlights

CV Model Lab the current version added multi-model comparison for three or more model runs:

- The Model Compare screen has **Pairwise** and **Multi-model** modes; the
  existing pairwise workflow, reports, and tests are unchanged.
- A leaderboard ranks runs by a selectable metric (AP/AP50/AP75,
  precision/recall/F1, TP/FP/FN, images-with-errors, small-object recall) with
  graceful handling of missing AP metrics.
- Per-class ranking finds the best/worst model per class, image disagreement
  analysis surfaces where models differ, a pairwise regression matrix opens any
  pair in Pairwise mode, and a Compare Viewer shows one image across 3+ models.
- Multi-model reports export to HTML, CSV, XLSX, and PDF, with EN/RU headings.
- EN/RU localization for all new labels and report headings.

The v0.4.x–v0.5.x line covers the full COCO detection review loop:

- Professional COCO AP metrics (AP@[.5:.95], AP50/75, AP/AR by size, per-class AP) computed with a pycocotools sidecar on desktop, or imported as precomputed AP JSON on any platform.
- Report export in HTML, CSV, XLSX, and PDF.
- Rule-based Recommendations, Dataset Health, Worst Cases, and Confusion Matrix analysis.
- Model Comparison, including an AP diff between two runs.
- Annotated Image Export, desktop project save/load, and Web/PWA restore mode.
- English/Russian localization for recommendations, health issues, parser warnings, friendly errors, and report headings.
- Clear empty/error states, progress/cancel for long-running work, Recent Projects, last-folder preferences, thumbnail cache, AP export toggles, and generated app icons.

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
- Desktop + PWA support from the same Flutter UI and pure Dart evaluation core.

## Screenshots

Screenshots are not checked in yet. Placeholder directory: [docs/screenshots](docs/screenshots/).

<!-- TODO: add screenshot: Dashboard -->
<!-- TODO: add screenshot: Error Browser -->
<!-- TODO: add screenshot: Model Compare -->
<!-- TODO: add screenshot: Dataset Health -->
<!-- TODO: add screenshot: Confusion Matrix -->

## Supported Platforms

- Linux desktop.
- Windows desktop.
- macOS desktop.
- Web/PWA in a browser.

Desktop builds require the corresponding Flutter desktop toolchain on the target host. The web build runs without a backend and uses browser file selection APIs.

## Supported Formats

- COCO detection annotations JSON.
- COCO predictions/results JSON with `image_id`.
- COCO predictions/results JSON with `file_name`, resolved against COCO image records.
- Local image directories or selected image files, matched by relative path and basename fallback.

Details and examples: [Supported Formats](docs/supported_formats.md) / [Форматы данных](docs/ru/supported_formats.md).

## Quick Start

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

For desktop on the current host:

```bash
flutter run -d linux
flutter run -d macos
flutter run -d windows
```

Use the command that matches your OS and installed Flutter desktop support.

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

## Architecture

```text
Pure Dart core
  ↓
Platform I/O adapters
  ↓
Flutter UI
```

The core does not import `dart:io`, `dart:html`, or Flutter UI. Parsing, evaluation, matching, metrics, comparison, health checks, worst-case mining, and report generation live in testable pure Dart modules. Platform-specific file picking, image loading, project save/load, report saving, browser downloads, and annotated image saving live behind adapters.

Architecture notes: [Architecture](docs/architecture.md) / [Архитектура](docs/ru/architecture.md).

## Testing

```bash
flutter analyze
flutter test
```

The test suite covers IoU, parsers, matcher behavior, metrics, small-object stats, confusion data, model comparison, project serialization, report/CSV/XLSX/PDF generation, Dataset Health Check, Worst Cases, annotated export selection, AP result parsing, AP export, AP project serialization, and the embedded sidecar script guard.

## Build

```bash
flutter build web
flutter build linux
flutter build windows
flutter build macos
```

Build scripts are available in [scripts](scripts/). Desktop builds must be run on a host that supports that target.

## Roadmap

- Release screenshots and sample exported reports.
- Desktop installers and macOS signing/notarization.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

This license applies only to the CV Model Lab source code.

Synthetic demo and test datasets stored in `demo/` and `test_data/` are released under CC0 1.0 Universal unless their local dataset README states otherwise.

## Third-party components and data

This repository may reference or integrate third-party models, datasets, runtimes, SDKs, and dependencies. They are subject to their own licenses.

The MIT License in this repository applies only to the CV Model Lab source code unless explicitly stated otherwise.

Users are responsible for ensuring that they have the necessary rights to use any datasets, models, weights, and artifacts processed with this software.
