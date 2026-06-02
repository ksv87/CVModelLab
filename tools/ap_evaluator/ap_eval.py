#!/usr/bin/env python3
# /// script
# requires-python = ">=3.8"
# dependencies = ["pycocotools>=2.0"]
# ///
"""COCO AP evaluator sidecar for CV Model Lab."""

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path


def evaluate(annotations_path: str, predictions_path: str, output_path: str) -> None:
    try:
        from pycocotools.coco import COCO
        from pycocotools.cocoeval import COCOeval
    except ImportError:
        print(json.dumps({
            "error": "pycocotools is not installed. Run: pip install pycocotools"
        }), file=sys.stderr)
        sys.exit(1)

    coco_gt = COCO(annotations_path)

    with open(predictions_path) as f:
        predictions = json.load(f)

    if not predictions:
        result = _empty_result(coco_gt)
        Path(output_path).write_text(json.dumps(result, indent=2))
        return

    coco_dt = coco_gt.loadRes(predictions)

    coco_eval = COCOeval(coco_gt, coco_dt, 'bbox')
    coco_eval.evaluate()
    coco_eval.accumulate()
    coco_eval.summarize()

    stats = coco_eval.stats

    per_class = []
    cat_ids = coco_gt.getCatIds()
    cats = {c['id']: c['name'] for c in coco_gt.loadCats(cat_ids)}

    for cat_id in cat_ids:
        coco_eval_cls = COCOeval(coco_gt, coco_dt, 'bbox')
        coco_eval_cls.params.catIds = [cat_id]
        coco_eval_cls.evaluate()
        coco_eval_cls.accumulate()
        coco_eval_cls.summarize()
        s = coco_eval_cls.stats
        per_class.append({
            "category_id": cat_id,
            "category_name": cats.get(cat_id, str(cat_id)),
            "ap": float(s[0]) if s[0] >= 0 else None,
            "ap50": float(s[1]) if s[1] >= 0 else None,
            "ap75": float(s[2]) if s[2] >= 0 else None,
            "ar": float(s[8]) if s[8] >= 0 else None,
        })

    result = {
        "evaluator_name": "pycocotools",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "ap": float(stats[0]) if stats[0] >= 0 else None,
        "ap50": float(stats[1]) if stats[1] >= 0 else None,
        "ap75": float(stats[2]) if stats[2] >= 0 else None,
        "ap_small": float(stats[3]) if stats[3] >= 0 else None,
        "ap_medium": float(stats[4]) if stats[4] >= 0 else None,
        "ap_large": float(stats[5]) if stats[5] >= 0 else None,
        "ar1": float(stats[6]) if stats[6] >= 0 else None,
        "ar10": float(stats[7]) if stats[7] >= 0 else None,
        "ar100": float(stats[8]) if stats[8] >= 0 else None,
        "ar_small": float(stats[9]) if stats[9] >= 0 else None,
        "ar_medium": float(stats[10]) if stats[10] >= 0 else None,
        "ar_large": float(stats[11]) if stats[11] >= 0 else None,
        "per_class": per_class,
        "warnings": [],
    }

    Path(output_path).write_text(json.dumps(result, indent=2))


def _empty_result(coco_gt) -> dict:
    cat_ids = coco_gt.getCatIds()
    cats = {c['id']: c['name'] for c in coco_gt.loadCats(cat_ids)}
    return {
        "evaluator_name": "pycocotools",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "ap": None, "ap50": None, "ap75": None,
        "ap_small": None, "ap_medium": None, "ap_large": None,
        "ar1": None, "ar10": None, "ar100": None,
        "ar_small": None, "ar_medium": None, "ar_large": None,
        "per_class": [
            {
                "category_id": cid,
                "category_name": cats.get(cid, str(cid)),
                "ap": None, "ap50": None, "ap75": None, "ar": None,
            }
            for cid in cat_ids
        ],
        "warnings": ["No predictions provided."],
    }


def main():
    parser = argparse.ArgumentParser(description='COCO AP evaluator for CV Model Lab')
    parser.add_argument('--annotations', required=True, help='Path to COCO annotations JSON')
    parser.add_argument('--predictions', required=True, help='Path to COCO predictions JSON')
    parser.add_argument('--output', required=True, help='Output path for AP metrics JSON')
    args = parser.parse_args()

    if not Path(args.annotations).exists():
        print(json.dumps({"error": f"Annotations file not found: {args.annotations}"}), file=sys.stderr)
        sys.exit(1)
    if not Path(args.predictions).exists():
        print(json.dumps({"error": f"Predictions file not found: {args.predictions}"}), file=sys.stderr)
        sys.exit(1)

    try:
        evaluate(args.annotations, args.predictions, args.output)
    except Exception as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
