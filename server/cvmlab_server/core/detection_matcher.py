"""Detection matcher — port of lib/src/core/eval/detection_matcher.dart.

Reproduces the greedy, deterministic matching used by the Dart core so that
server-computed TP/FP/FN are identical to the local mode.
"""

from __future__ import annotations

from typing import List

from .iou import calculate_iou
from .models import (
    CocoDataset,
    DetectionMatch,
    EvalConfig,
    GroundTruthAnnotation,
    MatchReason,
    MatchType,
    ModelRun,
    Prediction,
)


def _prediction_sort_key(p: Prediction):
    # score desc, then category_id asc, then bbox x, y, width, height asc.
    return (-p.score, p.category_id, p.bbox.x, p.bbox.y, p.bbox.width, p.bbox.height)


def _all_image_ids(dataset: CocoDataset, model_run: ModelRun) -> List[int]:
    ids = set(dataset.images_by_id.keys()) | set(
        model_run.predictions_by_image_id.keys()
    )
    return list(ids)


def match(
    dataset: CocoDataset, model_run: ModelRun, config: EvalConfig
) -> List[DetectionMatch]:
    if not config.class_aware_matching:
        return _match_class_agnostic(dataset, model_run, config)

    matches: List[DetectionMatch] = []
    for image_id in _all_image_ids(dataset, model_run):
        ground_truths = _filtered_ground_truths(
            dataset.annotations_by_image_id.get(image_id, []), config, matches
        )
        predictions = _filtered_predictions(
            model_run.predictions_by_image_id.get(image_id, []), config
        )
        category_ids = sorted(
            {gt.category_id for gt in ground_truths}
            | {p.category_id for p in predictions}
        )
        for category_id in category_ids:
            matches.extend(
                _match_category(
                    image_id,
                    category_id,
                    [gt for gt in ground_truths if gt.category_id == category_id],
                    [p for p in predictions if p.category_id == category_id],
                    config,
                )
            )
    return matches


def _match_category(
    image_id: int,
    category_id: int,
    ground_truths: List[GroundTruthAnnotation],
    predictions: List[Prediction],
    config: EvalConfig,
) -> List[DetectionMatch]:
    matches: List[DetectionMatch] = []
    matched_gt: set = set()
    for prediction in sorted(predictions, key=_prediction_sort_key):
        best_unmatched_index = -1
        best_unmatched_iou = 0.0
        best_any_matched = False
        best_any_iou = 0.0
        for gt_index, gt in enumerate(ground_truths):
            iou = calculate_iou(prediction.bbox, gt.bbox)
            if iou > best_any_iou:
                best_any_iou = iou
                best_any_matched = gt_index in matched_gt
            if gt_index not in matched_gt and iou > best_unmatched_iou:
                best_unmatched_iou = iou
                best_unmatched_index = gt_index

        if best_unmatched_index != -1 and best_unmatched_iou >= config.iou_threshold:
            matched_gt.add(best_unmatched_index)
            matches.append(
                DetectionMatch(
                    type=MatchType.TRUE_POSITIVE,
                    image_id=image_id,
                    category_id=category_id,
                    ground_truth=ground_truths[best_unmatched_index],
                    prediction=prediction,
                    iou=best_unmatched_iou,
                    reason=MatchReason.MATCHED,
                )
            )
            continue

        if best_any_matched and best_any_iou >= config.iou_threshold:
            reason = MatchReason.DUPLICATE_PREDICTION
        elif not ground_truths:
            reason = MatchReason.NO_MATCHING_GROUND_TRUTH
        else:
            reason = MatchReason.LOW_IOU
        matches.append(
            DetectionMatch(
                type=MatchType.FALSE_POSITIVE,
                image_id=image_id,
                category_id=category_id,
                prediction=prediction,
                iou=None if best_any_iou == 0 else best_any_iou,
                reason=reason,
            )
        )

    for gt_index, gt in enumerate(ground_truths):
        if gt_index not in matched_gt:
            matches.append(
                DetectionMatch(
                    type=MatchType.FALSE_NEGATIVE,
                    image_id=image_id,
                    category_id=category_id,
                    ground_truth=gt,
                    reason=MatchReason.MISSED_GROUND_TRUTH,
                )
            )
    return matches


def _match_class_agnostic(
    dataset: CocoDataset, model_run: ModelRun, config: EvalConfig
) -> List[DetectionMatch]:
    matches: List[DetectionMatch] = []
    for image_id in _all_image_ids(dataset, model_run):
        ground_truths = _filtered_ground_truths(
            dataset.annotations_by_image_id.get(image_id, []), config, matches
        )
        predictions = sorted(
            _filtered_predictions(
                model_run.predictions_by_image_id.get(image_id, []), config
            ),
            key=_prediction_sort_key,
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
            if best_index == -1 or best_iou < config.iou_threshold:
                matches.append(
                    DetectionMatch(
                        type=MatchType.FALSE_POSITIVE,
                        image_id=image_id,
                        category_id=prediction.category_id,
                        prediction=prediction,
                        iou=None if best_iou == 0 else best_iou,
                        reason=MatchReason.NO_MATCHING_GROUND_TRUTH,
                    )
                )
                continue
            matched_gt.add(best_index)
            gt = ground_truths[best_index]
            same = prediction.category_id == gt.category_id
            matches.append(
                DetectionMatch(
                    type=MatchType.TRUE_POSITIVE if same else MatchType.FALSE_POSITIVE,
                    image_id=image_id,
                    category_id=gt.category_id,
                    ground_truth=gt,
                    prediction=prediction,
                    iou=best_iou,
                    reason=MatchReason.MATCHED if same else MatchReason.WRONG_CLASS,
                )
            )

        for gt_index, gt in enumerate(ground_truths):
            if gt_index not in matched_gt:
                matches.append(
                    DetectionMatch(
                        type=MatchType.FALSE_NEGATIVE,
                        image_id=image_id,
                        category_id=gt.category_id,
                        ground_truth=gt,
                        reason=MatchReason.MISSED_GROUND_TRUTH,
                    )
                )
    return matches


def _filtered_ground_truths(
    ground_truths: List[GroundTruthAnnotation],
    config: EvalConfig,
    matches: List[DetectionMatch],
) -> List[GroundTruthAnnotation]:
    if not config.ignore_crowd:
        return list(ground_truths)
    result: List[GroundTruthAnnotation] = []
    for gt in ground_truths:
        if not gt.is_crowd:
            result.append(gt)
            continue
        matches.append(
            DetectionMatch(
                type=MatchType.IGNORED,
                image_id=gt.image_id,
                category_id=gt.category_id,
                ground_truth=gt,
                reason=MatchReason.IGNORED_CROWD,
            )
        )
    return result


def _filtered_predictions(
    predictions: List[Prediction], config: EvalConfig
) -> List[Prediction]:
    return [p for p in predictions if p.score >= config.confidence_threshold]
