"""In-memory dataclasses mirroring the Dart pure-Dart core models.

These deliberately match the semantics of ``lib/src/core/model/*`` so that the
server's evaluation reproduces the Dart ``MetricsCalculator`` exactly.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List, Optional


@dataclass(frozen=True)
class BBox:
    x: float
    y: float
    width: float
    height: float

    @property
    def x1(self) -> float:
        return self.x

    @property
    def y1(self) -> float:
        return self.y

    @property
    def x2(self) -> float:
        return self.x + self.width

    @property
    def y2(self) -> float:
        return self.y + self.height

    @property
    def area(self) -> float:
        if self.width <= 0 or self.height <= 0:
            return 0.0
        return self.width * self.height


@dataclass(frozen=True)
class GroundTruthAnnotation:
    id: int
    image_id: int
    category_id: int
    bbox: BBox
    area: Optional[float] = None
    is_crowd: bool = False

    @property
    def effective_area(self) -> float:
        return self.area if self.area is not None else self.bbox.area


@dataclass(frozen=True)
class Prediction:
    image_id: int
    category_id: int
    bbox: BBox
    score: float


@dataclass(frozen=True)
class ImageRecord:
    id: int
    file_name: str
    width: Optional[int] = None
    height: Optional[int] = None


@dataclass(frozen=True)
class CategoryRecord:
    id: int
    name: str


@dataclass
class CocoDataset:
    images_by_id: Dict[int, ImageRecord]
    categories_by_id: Dict[int, CategoryRecord]
    annotations: List[GroundTruthAnnotation]
    annotations_by_image_id: Dict[int, List[GroundTruthAnnotation]] = field(
        init=False
    )

    def __post_init__(self) -> None:
        grouped: Dict[int, List[GroundTruthAnnotation]] = {}
        for annotation in self.annotations:
            grouped.setdefault(annotation.image_id, []).append(annotation)
        self.annotations_by_image_id = grouped

    @property
    def image_ids_by_file_name(self) -> Dict[str, int]:
        return {img.file_name: img.id for img in self.images_by_id.values()}


@dataclass
class ModelRun:
    id: str
    name: str
    predictions: List[Prediction]
    predictions_by_image_id: Dict[int, List[Prediction]] = field(init=False)

    def __post_init__(self) -> None:
        grouped: Dict[int, List[Prediction]] = {}
        for prediction in self.predictions:
            grouped.setdefault(prediction.image_id, []).append(prediction)
        self.predictions_by_image_id = grouped


@dataclass(frozen=True)
class EvalConfig:
    iou_threshold: float = 0.5
    confidence_threshold: float = 0.25
    class_aware_matching: bool = True
    ignore_crowd: bool = True
    small_object_mode: str = "coco"


# Detection match types/reasons mirror lib/src/core/model/detection_match.dart
class MatchType:
    TRUE_POSITIVE = "truePositive"
    FALSE_POSITIVE = "falsePositive"
    FALSE_NEGATIVE = "falseNegative"
    IGNORED = "ignored"


class MatchReason:
    MATCHED = "matched"
    NO_MATCHING_GROUND_TRUTH = "no_matching_ground_truth"
    DUPLICATE_PREDICTION = "duplicate_prediction"
    WRONG_CLASS = "wrong_class"
    LOW_IOU = "low_iou"
    MISSED_GROUND_TRUTH = "missed_ground_truth"
    IGNORED_CROWD = "ignored_crowd"


@dataclass(frozen=True)
class DetectionMatch:
    type: str
    image_id: int
    category_id: Optional[int]
    ground_truth: Optional[GroundTruthAnnotation] = None
    prediction: Optional[Prediction] = None
    iou: Optional[float] = None
    reason: Optional[str] = None
