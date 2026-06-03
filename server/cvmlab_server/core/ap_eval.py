"""Server-side COCO AP metrics via pycocotools.

Produces the same JSON schema as ``tools/ap_evaluator/ap_eval.py`` (and the
Dart ``ApEvalResultParser``), so the client can consume it unchanged. The
desktop client does not need Python/pycocotools when running in remote mode.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import List, Optional

import orjson


class ApEvalError(Exception):
    pass


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_ap_metrics_file(path: str) -> dict:
    try:
        with open(path, "rb") as handle:
            data = orjson.loads(handle.read())
    except (OSError, orjson.JSONDecodeError) as exc:
        raise ApEvalError(f"Could not read AP metrics file: {exc}") from exc
    if not isinstance(data, dict):
        raise ApEvalError("AP metrics file must contain a JSON object")
    data.setdefault("evaluator_name", "imported")
    data.setdefault("generated_at", _now_iso())
    data.setdefault("warnings", [])
    return data


def run_ap_eval(annotations_path: str, predictions_path: str) -> dict:
    try:
        from pycocotools.coco import COCO
        from pycocotools.cocoeval import COCOeval
    except ImportError as exc:  # pragma: no cover - depends on environment
        raise ApEvalError(
            "pycocotools is not installed. Install it to run AP metrics."
        ) from exc

    coco_gt = COCO(annotations_path)
    with open(predictions_path, "rb") as handle:
        predictions = orjson.loads(handle.read())

    cat_ids = coco_gt.getCatIds()
    cats = {c["id"]: c["name"] for c in coco_gt.loadCats(cat_ids)}

    if not predictions:
        return _empty_result(cat_ids, cats)

    coco_dt = coco_gt.loadRes(predictions)
    coco_eval = COCOeval(coco_gt, coco_dt, "bbox")
    coco_eval.evaluate()
    coco_eval.accumulate()
    coco_eval.summarize()
    stats = coco_eval.stats

    per_class = []
    for cat_id in cat_ids:
        cls_eval = COCOeval(coco_gt, coco_dt, "bbox")
        cls_eval.params.catIds = [cat_id]
        cls_eval.evaluate()
        cls_eval.accumulate()
        cls_eval.summarize()
        s = cls_eval.stats
        per_class.append(
            {
                "category_id": cat_id,
                "category_name": cats.get(cat_id, str(cat_id)),
                "ap": _val(s[0]),
                "ap50": _val(s[1]),
                "ap75": _val(s[2]),
                "ar": _val(s[8]),
            }
        )

    return {
        "evaluator_name": "pycocotools",
        "generated_at": _now_iso(),
        "ap": _val(stats[0]),
        "ap50": _val(stats[1]),
        "ap75": _val(stats[2]),
        "ap_small": _val(stats[3]),
        "ap_medium": _val(stats[4]),
        "ap_large": _val(stats[5]),
        "ar1": _val(stats[6]),
        "ar10": _val(stats[7]),
        "ar100": _val(stats[8]),
        "ar_small": _val(stats[9]),
        "ar_medium": _val(stats[10]),
        "ar_large": _val(stats[11]),
        "per_class": per_class,
        "warnings": [],
    }


def _val(value: float) -> Optional[float]:
    return float(value) if value >= 0 else None


def _empty_result(cat_ids: List[int], cats: dict) -> dict:
    return {
        "evaluator_name": "pycocotools",
        "generated_at": _now_iso(),
        "ap": None,
        "ap50": None,
        "ap75": None,
        "ap_small": None,
        "ap_medium": None,
        "ap_large": None,
        "ar1": None,
        "ar10": None,
        "ar100": None,
        "ar_small": None,
        "ar_medium": None,
        "ar_large": None,
        "per_class": [
            {
                "category_id": cid,
                "category_name": cats.get(cid, str(cid)),
                "ap": None,
                "ap50": None,
                "ap75": None,
                "ar": None,
            }
            for cid in cat_ids
        ],
        "warnings": ["No predictions provided."],
    }
