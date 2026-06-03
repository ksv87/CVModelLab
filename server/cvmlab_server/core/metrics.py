"""Metrics calculator — port of lib/src/core/eval/class_stats.dart,
confusion_matrix.dart and small_object_stats.dart.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List, Optional

from . import detection_matcher
from .iou import calculate_iou
from .models import (
    CocoDataset,
    DetectionMatch,
    EvalConfig,
    MatchReason,
    MatchType,
    ModelRun,
)

MISSED_COLUMN = "__missed__"
BACKGROUND_FP_ROW = "__background_fp__"

_BUCKETS = ("small", "medium", "large")


def small_object_bucket(area: float) -> str:
    if area < 32 * 32:
        return "small"
    if area < 96 * 96:
        return "medium"
    return "large"


@dataclass
class ClassStats:
    category_id: int
    category_name: str
    gt_count: int
    pred_count: int
    tp: int
    fp: int
    fn: int
    precision: float
    recall: float
    f1: float


@dataclass
class ImageEvalSummary:
    image_id: int
    tp: int
    fp: int
    fn: int
    has_tp: bool
    has_fp: bool
    has_fn: bool
    has_class_confusion: bool
    has_small_object: bool
    has_only_background_fp: bool
    has_missed_objects: bool


@dataclass
class OverallStats:
    total_images: int
    total_gt: int
    total_predictions_before_threshold: int
    total_predictions_after_threshold: int
    total_tp: int
    total_fp: int
    total_fn: int
    micro_precision: float
    micro_recall: float
    micro_f1: float
    macro_precision: float
    macro_recall: float
    macro_f1: float
    images_with_any_error: int
    images_with_fp: int
    images_with_fn: int


@dataclass
class SmallObjectClassStats:
    gt_count: int
    tp: int
    fn: int
    recall: float


@dataclass
class EvalResult:
    config: EvalConfig
    matches: List[DetectionMatch]
    overall: OverallStats
    per_class: Dict[int, ClassStats]
    image_summaries: Dict[int, ImageEvalSummary]
    confusion: Dict[str, Dict[str, int]]
    small_object: Dict[int, Dict[str, SmallObjectClassStats]] = field(
        default_factory=dict
    )


def _safe_ratio(num: int, den: int) -> float:
    return 0.0 if den == 0 else num / den


def _f1(precision: float, recall: float) -> float:
    if precision + recall == 0:
        return 0.0
    return 2 * precision * recall / (precision + recall)


def _average(values: List[float]) -> float:
    return sum(values) / len(values) if values else 0.0


def evaluate(
    dataset: CocoDataset, model_run: ModelRun, config: EvalConfig
) -> EvalResult:
    matches = detection_matcher.match(dataset, model_run, config)
    per_class = _build_per_class(dataset, model_run, matches, config)
    image_summaries = _build_image_summaries(dataset, model_run, matches, config)
    overall = _build_overall(
        dataset, model_run, config, matches, per_class, image_summaries
    )
    confusion = _build_confusion(dataset, model_run, config)
    small_object = _build_small_object(dataset, matches, config)
    return EvalResult(
        config=config,
        matches=matches,
        overall=overall,
        per_class=per_class,
        image_summaries=image_summaries,
        confusion=confusion,
        small_object=small_object,
    )


def _build_per_class(
    dataset: CocoDataset,
    model_run: ModelRun,
    matches: List[DetectionMatch],
    config: EvalConfig,
) -> Dict[int, ClassStats]:
    gt_count: Dict[int, int] = {cid: 0 for cid in dataset.categories_by_id}
    pred_count: Dict[int, int] = {cid: 0 for cid in dataset.categories_by_id}
    tp: Dict[int, int] = {cid: 0 for cid in dataset.categories_by_id}
    fp: Dict[int, int] = {cid: 0 for cid in dataset.categories_by_id}
    fn: Dict[int, int] = {cid: 0 for cid in dataset.categories_by_id}

    for ann in dataset.annotations:
        if config.ignore_crowd and ann.is_crowd:
            continue
        if ann.category_id in gt_count:
            gt_count[ann.category_id] += 1
    for pred in model_run.predictions:
        if pred.score >= config.confidence_threshold and pred.category_id in pred_count:
            pred_count[pred.category_id] += 1
    for m in matches:
        cid = m.category_id
        if cid is None or cid not in gt_count:
            continue
        if m.type == MatchType.TRUE_POSITIVE:
            tp[cid] += 1
        elif m.type == MatchType.FALSE_POSITIVE:
            fp[cid] += 1
        elif m.type == MatchType.FALSE_NEGATIVE:
            fn[cid] += 1

    result: Dict[int, ClassStats] = {}
    for cid, category in dataset.categories_by_id.items():
        precision = _safe_ratio(tp[cid], tp[cid] + fp[cid])
        recall = _safe_ratio(tp[cid], tp[cid] + fn[cid])
        result[cid] = ClassStats(
            category_id=cid,
            category_name=category.name,
            gt_count=gt_count[cid],
            pred_count=pred_count[cid],
            tp=tp[cid],
            fp=fp[cid],
            fn=fn[cid],
            precision=precision,
            recall=recall,
            f1=_f1(precision, recall),
        )
    return result


def _build_image_summaries(
    dataset: CocoDataset,
    model_run: ModelRun,
    matches: List[DetectionMatch],
    config: EvalConfig,
) -> Dict[int, ImageEvalSummary]:
    image_ids = set(dataset.images_by_id.keys()) | set(
        model_run.predictions_by_image_id.keys()
    )
    by_image: Dict[int, List[DetectionMatch]] = {}
    for m in matches:
        by_image.setdefault(m.image_id, []).append(m)

    summaries: Dict[int, ImageEvalSummary] = {}
    for image_id in image_ids:
        image_matches = by_image.get(image_id, [])
        tp = sum(1 for m in image_matches if m.type == MatchType.TRUE_POSITIVE)
        fp = sum(1 for m in image_matches if m.type == MatchType.FALSE_POSITIVE)
        fn = sum(1 for m in image_matches if m.type == MatchType.FALSE_NEGATIVE)
        has_small = any(
            small_object_bucket(a.effective_area) == "small"
            for a in dataset.annotations_by_image_id.get(image_id, [])
        )
        summaries[image_id] = ImageEvalSummary(
            image_id=image_id,
            tp=tp,
            fp=fp,
            fn=fn,
            has_tp=tp > 0,
            has_fp=fp > 0,
            has_fn=fn > 0,
            has_class_confusion=any(
                m.reason == MatchReason.WRONG_CLASS for m in image_matches
            ),
            has_small_object=has_small,
            has_only_background_fp=fp > 0 and tp == 0 and fn == 0,
            has_missed_objects=fn > 0,
        )
    return summaries


def _build_overall(
    dataset: CocoDataset,
    model_run: ModelRun,
    config: EvalConfig,
    matches: List[DetectionMatch],
    per_class: Dict[int, ClassStats],
    image_summaries: Dict[int, ImageEvalSummary],
) -> OverallStats:
    total_tp = sum(1 for m in matches if m.type == MatchType.TRUE_POSITIVE)
    total_fp = sum(1 for m in matches if m.type == MatchType.FALSE_POSITIVE)
    total_fn = sum(1 for m in matches if m.type == MatchType.FALSE_NEGATIVE)
    micro_p = _safe_ratio(total_tp, total_tp + total_fp)
    micro_r = _safe_ratio(total_tp, total_tp + total_fn)
    stats = list(per_class.values())
    return OverallStats(
        total_images=len(dataset.images_by_id),
        total_gt=sum(
            1
            for a in dataset.annotations
            if not (config.ignore_crowd and a.is_crowd)
        ),
        total_predictions_before_threshold=len(model_run.predictions),
        total_predictions_after_threshold=sum(
            1 for p in model_run.predictions if p.score >= config.confidence_threshold
        ),
        total_tp=total_tp,
        total_fp=total_fp,
        total_fn=total_fn,
        micro_precision=micro_p,
        micro_recall=micro_r,
        micro_f1=_f1(micro_p, micro_r),
        macro_precision=_average([s.precision for s in stats]),
        macro_recall=_average([s.recall for s in stats]),
        macro_f1=_average([s.f1 for s in stats]),
        images_with_any_error=sum(
            1 for s in image_summaries.values() if s.has_fp or s.has_fn
        ),
        images_with_fp=sum(1 for s in image_summaries.values() if s.has_fp),
        images_with_fn=sum(1 for s in image_summaries.values() if s.has_fn),
    )


def _build_confusion(
    dataset: CocoDataset, model_run: ModelRun, config: EvalConfig
) -> Dict[str, Dict[str, int]]:
    counts: Dict[str, Dict[str, int]] = {}

    def increment(row: str, column: str) -> None:
        counts.setdefault(row, {})
        counts[row][column] = counts[row].get(column, 0) + 1

    image_ids = set(dataset.images_by_id.keys()) | set(
        model_run.predictions_by_image_id.keys()
    )
    for image_id in image_ids:
        ground_truths = [
            gt
            for gt in dataset.annotations_by_image_id.get(image_id, [])
            if not (config.ignore_crowd and gt.is_crowd)
        ]
        predictions = sorted(
            [
                p
                for p in model_run.predictions_by_image_id.get(image_id, [])
                if p.score >= config.confidence_threshold
            ],
            key=lambda p: (-p.score, p.category_id),
        )
        matched_gt: set = set()
        for prediction in predictions:
            best_index = -1
            best_iou = 0.0
            for gt_index, gt in enumerate(ground_truths):
                if gt_index in matched_gt:
                    continue
                iou = calculate_iou(prediction.bbox, gt.bbox)
                if iou > best_iou:
                    best_iou = iou
                    best_index = gt_index
            pred_name = dataset.categories_by_id[prediction.category_id].name
            if best_index != -1 and best_iou >= config.iou_threshold:
                matched_gt.add(best_index)
                gt_name = dataset.categories_by_id[
                    ground_truths[best_index].category_id
                ].name
                increment(gt_name, pred_name)
            else:
                increment(BACKGROUND_FP_ROW, pred_name)
        for gt_index, gt in enumerate(ground_truths):
            if gt_index not in matched_gt:
                gt_name = dataset.categories_by_id[gt.category_id].name
                increment(gt_name, MISSED_COLUMN)
    return counts


def _build_small_object(
    dataset: CocoDataset, matches: List[DetectionMatch], config: EvalConfig
) -> Dict[int, Dict[str, SmallObjectClassStats]]:
    mutable: Dict[int, Dict[str, Dict[str, int]]] = {
        cid: {b: {"gt": 0, "tp": 0, "fn": 0} for b in _BUCKETS}
        for cid in dataset.categories_by_id
    }
    for ann in dataset.annotations:
        if config.ignore_crowd and ann.is_crowd:
            continue
        bucket = small_object_bucket(ann.effective_area)
        if ann.category_id in mutable:
            mutable[ann.category_id][bucket]["gt"] += 1

    for m in matches:
        ann = m.ground_truth
        if ann is None or m.type == MatchType.FALSE_POSITIVE:
            continue
        bucket = small_object_bucket(ann.effective_area)
        slot = mutable.get(ann.category_id, {}).get(bucket)
        if slot is None:
            continue
        if m.type == MatchType.TRUE_POSITIVE:
            slot["tp"] += 1
        elif m.type == MatchType.FALSE_NEGATIVE:
            slot["fn"] += 1

    result: Dict[int, Dict[str, SmallObjectClassStats]] = {}
    for cid, buckets in mutable.items():
        result[cid] = {}
        for bucket, slot in buckets.items():
            gt = slot["gt"]
            result[cid][bucket] = SmallObjectClassStats(
                gt_count=gt,
                tp=slot["tp"],
                fn=slot["fn"],
                recall=0.0 if gt == 0 else slot["tp"] / gt,
            )
    return result
