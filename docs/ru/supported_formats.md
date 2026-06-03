# Поддерживаемые форматы

[English version](../supported_formats.md) | [README.ru](../../README.ru.md)

## COCO annotations JSON

CV Model Lab поддерживает стандартный COCO detection annotations формат:

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

Обязательные поля: `images[].id`, `images[].file_name`, `annotations[].image_id`, `annotations[].category_id`, `annotations[].bbox`, `categories[].id`, `categories[].name`.

## COCO predictions с `image_id`

```json
[
  {"image_id": 1, "category_id": 3, "bbox": [100, 120, 50, 80], "score": 0.94}
]
```

## COCO predictions с `file_name`

```json
[
  {"file_name": "image_001.jpg", "category_id": 3, "bbox": [100, 120, 50, 80], "score": 0.94}
]
```

`file_name` сопоставляется с `images[].file_name`. Если prediction содержит и `image_id`, и `file_name`, используется `image_id`.

## Matching изображений

Поддерживаются:

- `image_001.jpg` -> `image_001.jpg`
- `val2017/image_001.jpg` -> `val2017/image_001.jpg`
- `nested/path/image_001.jpg` -> basename fallback к `image_001.jpg`, если имя однозначно

## Демонстрационный датасет (Showcase)

`demo/showcase_coco/` содержит синтетический датасет дорожных сцен, поставляемый
вместе с приложением. Используются стандартные форматы выше:
- `annotations.json` — COCO annotation JSON с 5 категориями
- `predictions_model_a/b/c.json` — три prediction-файла в формате `image_id`
- `ap_metrics_model_a/b/c.json` — precomputed AP metrics JSON

Датасет открывается через **Open project** с выбором
`demo/showcase_coco/showcase_coco.cvmlab.json` или вручную через загрузку файлов по отдельности.

## Ограничения

- Приложение ожидает COCO XYWH bounding boxes.
- Invalid boxes попадают в parser issues.
- Scores вне `0..1` могут давать warnings, но не всегда останавливают загрузку.
- Web/PWA не может читать произвольные локальные paths; пользователь должен выбрать файлы.
- COCO AP/mAP metrics (pycocotools) считаются через Python sidecar на desktop. Web build не может запускать Python, поэтому там AP metrics нужно импортировать как заранее посчитанный JSON.
