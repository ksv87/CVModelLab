# Supported Formats

[Русская версия](ru/supported_formats.md) | [README](../README.md)

## COCO Annotations JSON

CV Model Lab supports standard COCO detection annotations:

```json
{
  "images": [
    {"id": 1, "file_name": "image_001.jpg", "width": 1920, "height": 1080}
  ],
  "annotations": [
    {"id": 101, "image_id": 1, "category_id": 3, "bbox": [100, 120, 50, 80], "area": 4000, "iscrowd": 0}
  ],
  "categories": [
    {"id": 3, "name": "red"}
  ]
}
```

Required fields are `images[].id`, `images[].file_name`, `annotations[].image_id`, `annotations[].category_id`, `annotations[].bbox`, `categories[].id`, and `categories[].name`.

## COCO Predictions With `image_id`

```json
[
  {"image_id": 1, "category_id": 3, "bbox": [100, 120, 50, 80], "score": 0.94}
]
```

## COCO Predictions With `file_name`

```json
[
  {"file_name": "image_001.jpg", "category_id": 3, "bbox": [100, 120, 50, 80], "score": 0.94}
]
```

`file_name` predictions are resolved against `images[].file_name`. If a prediction contains both `image_id` and `file_name`, `image_id` is used.

## Image Matching

Supported matches include exact file name, relative path, and basename fallback:

- `image_001.jpg` -> `image_001.jpg`
- `val2017/image_001.jpg` -> `val2017/image_001.jpg`
- `nested/path/image_001.jpg` -> basename fallback to `image_001.jpg` when unambiguous

## Showcase Demo Dataset

`demo/showcase_coco/` contains a synthetic road-scene dataset that ships with
the app. It uses the standard formats above:
- `annotations.json` — COCO annotation JSON with 5 categories
- `predictions_model_a/b/c.json` — three prediction files in `image_id` format
- `ap_metrics_model_a/b/c.json` — precomputed AP metrics JSON

The dataset can be opened through **Open project** by selecting
`demo/showcase_coco/showcase_coco.cvmlab.json`, or by manually loading the files above.

## Limitations

- The app expects COCO XYWH bounding boxes.
- Invalid boxes are reported as parser issues.
- Scores outside `0..1` can be reported as warnings but do not necessarily stop loading.
- Web/PWA mode cannot read arbitrary local paths; the user must select files.
- COCO AP/mAP metrics (pycocotools) run via a Python sidecar on desktop. The web build cannot launch Python, so AP metrics must be imported as precomputed JSON there.
