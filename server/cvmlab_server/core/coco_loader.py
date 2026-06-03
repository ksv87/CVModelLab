"""COCO annotations + predictions loader.

Faithful port of ``lib/src/core/parser/coco_annotation_parser.dart`` and
``coco_prediction_parser.dart`` so the server's parsed dataset matches the Dart
client exactly (duplicate handling, basename fallback, area/iscrowd semantics).
"""

from __future__ import annotations

from typing import Dict, List, Optional

import orjson

from .models import (
    BBox,
    CategoryRecord,
    CocoDataset,
    GroundTruthAnnotation,
    ImageRecord,
    ModelRun,
    Prediction,
)


def _read_int(value: object) -> Optional[int]:
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, float) and value.is_integer():
        return int(value)
    return None


def _read_double(value: object) -> Optional[float]:
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    return None


def _read_bbox(value: object) -> Optional[BBox]:
    if not isinstance(value, list) or len(value) != 4:
        return None
    numbers: List[float] = []
    for item in value:
        number = _read_double(item)
        if number is None:
            return None
        numbers.append(number)
    if numbers[2] <= 0 or numbers[3] <= 0:
        return None
    return BBox(x=numbers[0], y=numbers[1], width=numbers[2], height=numbers[3])


def _basename(path: str) -> str:
    normalized = path.replace("\\", "/")
    idx = normalized.rfind("/")
    return normalized if idx == -1 else normalized[idx + 1 :]


def load_annotations(raw_bytes: bytes) -> CocoDataset:
    decoded = orjson.loads(raw_bytes)
    if not isinstance(decoded, dict):
        raise ValueError("COCO annotations root must be an object")
    images_raw = decoded.get("images")
    annotations_raw = decoded.get("annotations")
    categories_raw = decoded.get("categories")
    if (
        not isinstance(images_raw, list)
        or not isinstance(annotations_raw, list)
        or not isinstance(categories_raw, list)
    ):
        raise ValueError("images, annotations and categories must be lists")

    images_by_id: Dict[int, ImageRecord] = {}
    for item in images_raw:
        if not isinstance(item, dict):
            continue
        image_id = _read_int(item.get("id"))
        file_name = item.get("file_name")
        if image_id is None or not isinstance(file_name, str) or not file_name:
            continue
        if image_id in images_by_id:
            continue
        images_by_id[image_id] = ImageRecord(
            id=image_id,
            file_name=file_name,
            width=_read_int(item.get("width")),
            height=_read_int(item.get("height")),
        )

    categories_by_id: Dict[int, CategoryRecord] = {}
    for item in categories_raw:
        if not isinstance(item, dict):
            continue
        category_id = _read_int(item.get("id"))
        name = item.get("name")
        if category_id is None or not isinstance(name, str) or not name:
            continue
        if category_id in categories_by_id:
            continue
        categories_by_id[category_id] = CategoryRecord(id=category_id, name=name)

    annotations: List[GroundTruthAnnotation] = []
    for index, item in enumerate(annotations_raw):
        if not isinstance(item, dict):
            continue
        image_id = _read_int(item.get("image_id"))
        category_id = _read_int(item.get("category_id"))
        bbox = _read_bbox(item.get("bbox"))
        if image_id is None or image_id not in images_by_id:
            continue
        if category_id is None or category_id not in categories_by_id:
            continue
        if bbox is None:
            continue
        ann_id = _read_int(item.get("id"))
        if ann_id is None:
            ann_id = index + 1
        is_crowd_raw = item.get("iscrowd")
        is_crowd = is_crowd_raw is True or (
            isinstance(is_crowd_raw, (int, float))
            and not isinstance(is_crowd_raw, bool)
            and is_crowd_raw == 1
        )
        annotations.append(
            GroundTruthAnnotation(
                id=ann_id,
                image_id=image_id,
                category_id=category_id,
                bbox=bbox,
                area=_read_double(item.get("area")),
                is_crowd=is_crowd,
            )
        )

    return CocoDataset(
        images_by_id=images_by_id,
        categories_by_id=categories_by_id,
        annotations=annotations,
    )


def load_predictions(
    raw_bytes: bytes,
    dataset: CocoDataset,
    model_run_id: str,
    model_run_name: str,
) -> ModelRun:
    decoded = orjson.loads(raw_bytes)
    if not isinstance(decoded, list):
        raise ValueError("COCO predictions root must be a list")

    exact_by_name = dataset.image_ids_by_file_name
    basename_to_ids: Dict[str, List[int]] = {}
    for image in dataset.images_by_id.values():
        basename_to_ids.setdefault(_basename(image.file_name), []).append(image.id)

    predictions: List[Prediction] = []
    for item in decoded:
        if not isinstance(item, dict):
            continue
        category_id = _read_int(item.get("category_id"))
        if category_id is None or category_id not in dataset.categories_by_id:
            continue
        image_id = _resolve_image_id(item, dataset, exact_by_name, basename_to_ids)
        if image_id is None:
            continue
        bbox = _read_bbox(item.get("bbox"))
        if bbox is None:
            continue
        score = _read_double(item.get("score"))
        if score is None:
            continue
        predictions.append(
            Prediction(
                image_id=image_id,
                category_id=category_id,
                bbox=bbox,
                score=score,
            )
        )

    return ModelRun(id=model_run_id, name=model_run_name, predictions=predictions)


def _resolve_image_id(
    item: dict,
    dataset: CocoDataset,
    exact_by_name: Dict[str, int],
    basename_to_ids: Dict[str, List[int]],
) -> Optional[int]:
    direct = _read_int(item.get("image_id"))
    if direct is not None:
        return direct if direct in dataset.images_by_id else None
    file_name = item.get("file_name")
    if not isinstance(file_name, str) or not file_name:
        return None
    exact = exact_by_name.get(file_name)
    if exact is not None:
        return exact
    matches = basename_to_ids.get(_basename(file_name), [])
    if len(matches) == 1:
        return matches[0]
    return None
