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
- Model Comparison with fixed, broken, improved, and regressed image statuses.
- HTML and CSV export.
- Annotated Image Export for visual overlays.
- Desktop project save/load.
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
10. Export HTML/CSV reports or annotated images.
11. Save the project on desktop or use Web/PWA restore mode in the browser.

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

## Model Comparison

Model Comparison loads two prediction runs for the same COCO dataset and compares per-class precision/recall and image-level behavior. Images are grouped as fixed, broken, improved, regressed, still correct, or still wrong depending on how the candidate run changes the error profile.

## Exports

CV Model Lab supports:

- HTML report export.
- CSV export for per-class metrics, image errors, matches, small-object stats, confusion matrix, confusion pairs, dataset health, and worst cases.
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

The test suite covers IoU, parsers, matcher behavior, metrics, small-object stats, confusion data, model comparison, project serialization, report/CSV generation, Dataset Health Check, Worst Cases, and annotated export selection.

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
- PDF/XLSX export.
- pycocotools-compatible AP metrics.
- Python analyzer sidecar.
- Rule-based and optional LLM recommendations.
- ONNX inference integration.
- Video/frame sequence support.
- Thumbnail cache and recent projects.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

This license applies only to the CV Model Lab source code.

Synthetic demo and test datasets stored in `demo/` and `test_data/` are released under CC0 1.0 Universal unless their local dataset README states otherwise.

## Third-party components and data

This repository may reference or integrate third-party models, datasets, runtimes, SDKs, and dependencies. They are subject to their own licenses.

The MIT License in this repository applies only to the CV Model Lab source code unless explicitly stated otherwise.

Users are responsible for ensuring that they have the necessary rights to use any datasets, models, weights, and artifacts processed with this software.
