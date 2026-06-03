# Changelog

[Русская версия](CHANGELOG.ru.md)

This changelog lists project changes available up to the current commit.

## Synthetic showcase data and export polish

- Added the synthetic Showcase COCO dataset with generated images, annotations, predictions, AP metrics, saved project file, and sample reports.
- Added CC0 dataset licensing for demo data and report examples.
- Improved report fonts, localization, compare viewer zoom/pan controls, Linux icon packaging assets, and public documentation.

## Localization and multi-model comparison

- Added English/Russian localization for app text, warnings, recommendations, health issues, errors, and report headings.
- Added multi-model comparison for 3+ model runs with leaderboard, per-class ranking, disagreement analysis, regression matrix, and multi-model exports.
- Improved metric formatting, recent project restore behavior, AP persistence, model/project renaming, and comparison usability.

## Recommendations and report exports

- Added rule-based recommendations with deterministic evidence and navigation links.
- Added XLSX and PDF report generation alongside HTML and CSV exports.
- Added COCO AP metrics through a desktop Python sidecar and AP metrics import for non-desktop workflows.

## Analysis workspace and project workflow

- Added the Flutter analysis workspace for loading annotations, predictions, and images.
- Added image overlays, filtering, HTML/CSV export, model comparison, project save/load, restore mode, Dataset Health, Worst Cases, and annotated image export.
- Added project documentation, platform folders, demo data, scripts, and publishing metadata without bundled CI artifacts.

## COCO evaluation core

- Added a pure Dart COCO detection evaluation core with annotation and prediction parsers.
- Implemented deterministic IoU matching, TP/FP/FN classification, class metrics, confusion data, and small-object statistics.
- Added mini COCO test data, unit tests, root MIT license text, and CC0 licensing for synthetic test fixtures.
