# User Guide

[Русская версия](ru/user_guide.md) | [README](../README.md)

## Open COCO Annotations

From the home/open screen, choose the COCO annotations JSON. The file should contain `images`, `annotations`, and `categories`. CV Model Lab validates references, required fields, and bounding boxes, then shows warnings instead of failing on the first bad object.

## Open Predictions

Choose a COCO predictions JSON file. Predictions can reference images by `image_id` or by `file_name`. If both are present, `image_id` has priority. You can add another prediction file later for model comparison.

## Select Images

On desktop, select an images directory. On web/PWA, select files or a browser-supported directory/file set. Matching supports exact COCO `file_name`, relative paths such as `val2017/image.jpg`, and basename fallback when possible.

## Analyze FP/FN

After loading, open the workspace dashboard and Error Browser. TP, FP, and FN are computed from the current IoU and confidence thresholds. Use the image viewer to inspect GT boxes, predictions, labels, scores, IoU values, and match reasons.

## Use Filters

Use filters to narrow the image list by class, TP/FP/FN, confidence range, IoU threshold, object size, class confusion, missing local image, and other image-level error flags. Threshold changes recalculate evaluation results.

## Compare Models

Load a second prediction JSON for the same dataset. The Model Compare screen shows per-class precision/recall differences and image-level statuses such as fixed, broken, improved, and regressed.

## Export Reports

Use the export dialog to save HTML and CSV reports. CSV exports include per-class metrics, image errors, matches, small-object stats, confusion matrix data, dataset health, and worst cases. Annotated Image Export saves visual overlays.

## Save Project

Desktop workflows can save and reopen a project file with dataset paths, image root, model runs, and evaluation config. Web/PWA workflows use browser-selected files and restore mode where supported by the browser.
