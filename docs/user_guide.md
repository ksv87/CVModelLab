# User Guide

[Русская версия](ru/user_guide.md) | [README](../README.md)

## Open COCO Annotations

From the home/open screen, choose the COCO annotations JSON. The file should contain `images`, `annotations`, and `categories`. CV Model Lab validates references, required fields, and bounding boxes, then shows warnings instead of failing on the first bad object.

## Open Predictions

Choose a COCO predictions JSON file. Predictions can reference images by `image_id` or by `file_name`. If both are present, `image_id` has priority. You can add more prediction files later from the workspace to build a multi-run project.

## Select Images

On desktop, select an images directory. On web/PWA, select files or a browser-supported directory/file set. Matching supports exact COCO `file_name`, relative paths such as `val2017/image.jpg`, and basename fallback when possible.

## Analyze FP/FN

After loading, open the workspace dashboard and Error Browser. TP, FP, and FN are computed from the current IoU and confidence thresholds. Use the image viewer to inspect GT boxes, predictions, labels, scores, IoU values, and match reasons.

## Use Filters

Use filters to narrow the image list by class, TP/FP/FN, confidence range, IoU threshold, object size, class confusion, missing local image, and other image-level error flags. Threshold changes recalculate evaluation results.

## Compare Models

### Pairwise

Load a second prediction JSON from the workspace (Add model run button). The Model Compare screen in **Pairwise** mode shows per-class precision/recall differences and image-level statuses such as fixed, broken, improved, and regressed. When both runs have COCO AP metrics, an AP diff tab appears.

### Multi-model (3+ runs)

Add three or more model runs to the project, then open Model Compare and switch to **Multi-model** mode. The leaderboard ranks every run by a selectable metric; per-class ranking shows the best and worst model per class; image disagreement analysis classifies each image; the pairwise regression matrix summarizes every directional pair; and Compare Viewer shows one image across all selected models in a grid.

## Rename a Model Run

Click the pencil-icon button in the workspace AppBar while the run you want to rename is active. Enter the new name and confirm. Duplicate names are resolved automatically by appending a number.

## Rename the Project

Double-click the project name in the workspace AppBar title. Enter the new name and confirm. The new name is saved the next time you save the project.

## Run COCO AP Metrics

On desktop, click **Run COCO AP evaluation** on the dashboard. The app locates a Python runner (`uv` or `python3` with `pycocotools`) and runs the evaluation in the background. Results appear in the dashboard metrics section and are saved into the project file.

On web/PWA, AP evaluation cannot run because browsers cannot launch Python processes. Use **Import AP metrics JSON** instead to load a precomputed result produced by the desktop app or the sidecar tool directly.

## Export Reports

Use the Export report dialog to save reports in any combination of formats:

- **HTML** — self-contained report with all metric sections.
- **CSV** — per-class metrics, image errors, matches, small-object stats, confusion data, dataset health, worst cases, AP metrics, recommendations.
- **XLSX** — multi-sheet workbook with the same data as CSV.
- **PDF** — printable report with cover page, metrics tables, and summary sections.

Annotated Image Export saves visual overlays for selected images.

## Save and Reopen a Project

Desktop workflows can save a project file (`.cvmlab.json`) with dataset paths, image root, all model runs, evaluation config, and COCO AP metrics for every run. Click **Save** in the AppBar.

Reopen via **File → Open project** (direct file open) or via **Recent Projects** on the home screen. Both paths auto-load all files from saved absolute paths without asking you to re-pick them. If a file has moved or is missing, the app falls back to restore mode where you can pick the files again.
