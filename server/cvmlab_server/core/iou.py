"""IoU computation — port of lib/src/core/eval/iou.dart."""

from __future__ import annotations

from .models import BBox


def calculate_iou(a: BBox, b: BBox) -> float:
    area_a = a.area
    area_b = b.area
    if area_a <= 0 or area_b <= 0:
        return 0.0

    ix1 = max(a.x1, b.x1)
    iy1 = max(a.y1, b.y1)
    ix2 = min(a.x2, b.x2)
    iy2 = min(a.y2, b.y2)
    iw = ix2 - ix1
    ih = iy2 - iy1
    if iw <= 0 or ih <= 0:
        return 0.0

    intersection = iw * ih
    union = area_a + area_b - intersection
    if union <= 0:
        return 0.0
    return intersection / union
