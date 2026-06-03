"""Canonical JSON contract for evaluation results.

The same shape is produced by the Dart side (``evalResultToJson`` in
``lib/src/core/eval/eval_result_json.dart``) and consumed by the remote client.
It is also asserted against by the Python<->Dart parity tests. The compact form
intentionally omits the per-detection match list (which can be huge); per-image
match detail is fetched lazily via :func:`image_detail_json`.
"""

from __future__ import annotations

from typing import Dict, List, Optional

from .metrics import EvalResult
from .models import (
    BBox,
    CocoDataset,
    DetectionMatch,
    EvalConfig,
    GroundTruthAnnotation,
    ModelRun,
    Prediction,
)


def config_to_json(config: EvalConfig) -> dict:
    return {
        "iou_threshold": config.iou_threshold,
        "confidence_threshold": config.confidence_threshold,
        "class_aware_matching": config.class_aware_matching,
        "ignore_crowd": config.ignore_crowd,
        "small_object_mode": config.small_object_mode,
    }


def eval_result_to_compact_json(result: EvalResult) -> dict:
    overall = result.overall
    per_class = [
        {
            "category_id": s.category_id,
            "category_name": s.category_name,
            "gt_count": s.gt_count,
            "pred_count": s.pred_count,
            "tp": s.tp,
            "fp": s.fp,
            "fn": s.fn,
            "precision": s.precision,
            "recall": s.recall,
            "f1": s.f1,
        }
        for s in sorted(result.per_class.values(), key=lambda s: s.category_id)
    ]
    image_summaries = [
        {
            "image_id": s.image_id,
            "tp": s.tp,
            "fp": s.fp,
            "fn": s.fn,
            "has_tp": s.has_tp,
            "has_fp": s.has_fp,
            "has_fn": s.has_fn,
            "has_class_confusion": s.has_class_confusion,
            "has_small_object": s.has_small_object,
            "has_only_background_fp": s.has_only_background_fp,
            "has_missed_objects": s.has_missed_objects,
        }
        for s in sorted(result.image_summaries.values(), key=lambda s: s.image_id)
    ]
    small_object = [
        {
            "category_id": cid,
            "buckets": {
                bucket: {
                    "gt_count": stat.gt_count,
                    "tp": stat.tp,
                    "fn": stat.fn,
                    "recall": stat.recall,
                }
                for bucket, stat in buckets.items()
            },
        }
        for cid, buckets in sorted(result.small_object.items())
    ]
    return {
        "config": config_to_json(result.config),
        "overall": {
            "total_images": overall.total_images,
            "total_gt": overall.total_gt,
            "total_predictions_before_threshold": overall.total_predictions_before_threshold,
            "total_predictions_after_threshold": overall.total_predictions_after_threshold,
            "total_tp": overall.total_tp,
            "total_fp": overall.total_fp,
            "total_fn": overall.total_fn,
            "micro_precision": overall.micro_precision,
            "micro_recall": overall.micro_recall,
            "micro_f1": overall.micro_f1,
            "macro_precision": overall.macro_precision,
            "macro_recall": overall.macro_recall,
            "macro_f1": overall.macro_f1,
            "images_with_any_error": overall.images_with_any_error,
            "images_with_fp": overall.images_with_fp,
            "images_with_fn": overall.images_with_fn,
        },
        "per_class": per_class,
        "image_summaries": image_summaries,
        "confusion": {"counts": result.confusion},
        "small_object": small_object,
    }


def _bbox_json(bbox: BBox) -> List[float]:
    return [bbox.x, bbox.y, bbox.width, bbox.height]


def _category_name(dataset: CocoDataset, category_id: Optional[int]) -> Optional[str]:
    if category_id is None:
        return None
    category = dataset.categories_by_id.get(category_id)
    return category.name if category else None


def _match_json(dataset: CocoDataset, match: DetectionMatch) -> dict:
    bbox = (
        _bbox_json(match.prediction.bbox)
        if match.prediction is not None
        else (_bbox_json(match.ground_truth.bbox) if match.ground_truth else None)
    )
    return {
        "type": match.type,
        "category_id": match.category_id,
        "category_name": _category_name(dataset, match.category_id),
        "bbox": bbox,
        "score": match.prediction.score if match.prediction else None,
        "iou": match.iou,
        "reason": match.reason,
    }


def _gt_json(gt: GroundTruthAnnotation) -> dict:
    return {
        "id": gt.id,
        "image_id": gt.image_id,
        "category_id": gt.category_id,
        "bbox": _bbox_json(gt.bbox),
        "area": gt.area,
        "is_crowd": gt.is_crowd,
    }


def _pred_json(pred: Prediction) -> dict:
    return {
        "image_id": pred.image_id,
        "category_id": pred.category_id,
        "bbox": _bbox_json(pred.bbox),
        "score": pred.score,
    }


def _full_match_json(match: DetectionMatch) -> dict:
    return {
        "type": match.type,
        "image_id": match.image_id,
        "category_id": match.category_id,
        "reason": match.reason,
        "iou": match.iou,
        "ground_truth": _gt_json(match.ground_truth) if match.ground_truth else None,
        "prediction": _pred_json(match.prediction) if match.prediction else None,
    }


def full_workspace_json(
    dataset: CocoDataset, model_run: ModelRun, result: EvalResult
) -> dict:
    """Full parsed payload that lets the client reconstruct in-memory models and
    reuse all existing screens. Suited to moderate datasets; very large datasets
    should use the compact + paginated endpoints instead.
    """
    return {
        "eval": eval_result_to_compact_json(result),
        "dataset": {
            "images": [
                {
                    "id": img.id,
                    "file_name": img.file_name,
                    "width": img.width,
                    "height": img.height,
                }
                for img in dataset.images_by_id.values()
            ],
            "categories": [
                {"id": c.id, "name": c.name}
                for c in dataset.categories_by_id.values()
            ],
            "annotations": [_gt_json(a) for a in dataset.annotations],
        },
        "predictions": [_pred_json(p) for p in model_run.predictions],
        "matches": [_full_match_json(m) for m in result.matches],
    }


def image_detail_json(
    dataset: CocoDataset,
    model_run: ModelRun,
    result: EvalResult,
    image_id: int,
) -> dict:
    image = dataset.images_by_id.get(image_id)
    summary = result.image_summaries.get(image_id)
    image_matches = [m for m in result.matches if m.image_id == image_id]
    ground_truths = dataset.annotations_by_image_id.get(image_id, [])
    predictions = model_run.predictions_by_image_id.get(image_id, [])
    return {
        "image": {
            "id": image_id,
            "file_name": image.file_name if image else None,
            "width": image.width if image else None,
            "height": image.height if image else None,
        },
        "summary": {
            "gt_count": len(ground_truths),
            "pred_count": len(predictions),
            "tp": summary.tp if summary else 0,
            "fp": summary.fp if summary else 0,
            "fn": summary.fn if summary else 0,
            "has_error": bool(summary and (summary.has_fp or summary.has_fn)),
            "has_class_confusion": bool(summary and summary.has_class_confusion),
            "has_small_object": bool(summary and summary.has_small_object),
        },
        "matches": [_match_json(dataset, m) for m in image_matches],
        "ground_truth": [
            {
                "id": gt.id,
                "category_id": gt.category_id,
                "category_name": _category_name(dataset, gt.category_id),
                "bbox": _bbox_json(gt.bbox),
                "is_crowd": gt.is_crowd,
                "area": gt.effective_area,
            }
            for gt in ground_truths
        ],
        "predictions": [
            {
                "category_id": p.category_id,
                "category_name": _category_name(dataset, p.category_id),
                "bbox": _bbox_json(p.bbox),
                "score": p.score,
            }
            for p in predictions
        ],
    }
