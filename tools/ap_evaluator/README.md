# CV Model Lab — AP Evaluator

[Русская версия](README.ru.md)

Python sidecar that runs pycocotools COCO AP evaluation and writes results as JSON.

CV Model Lab invokes this script automatically from the desktop app.
You do not normally need to run it manually.

---

## Running via uv (recommended)

[uv](https://docs.astral.sh/uv/) manages Python and dependencies automatically.
No `pip install`, no venv activation needed.

```bash
uv run ap_eval.py \
  --annotations /path/to/annotations.json \
  --predictions /path/to/predictions.json \
  --output /path/to/ap_metrics.json
```

The script uses [PEP 723](https://peps.python.org/pep-0723/) inline metadata so
`uv run` resolves `pycocotools` automatically on first use and caches it.

---

## Running via plain Python

```bash
pip install pycocotools
python3 ap_eval.py \
  --annotations /path/to/annotations.json \
  --predictions /path/to/predictions.json \
  --output /path/to/ap_metrics.json
```

---

## Detection order in CV Model Lab (desktop)

1. `uv` in PATH → uses `uv run ap_eval.py ...` (preferred)
2. `python3` in PATH with `pycocotools` installed → uses `python3 ap_eval.py ...`
3. Neither available → shows an error with instructions

---

## Output JSON

```json
{
  "evaluator_name": "pycocotools",
  "generated_at": "2026-06-02T10:00:00+00:00",
  "ap": 0.458,
  "ap50": 0.621,
  "ap75": 0.512,
  "ap_small": 0.312,
  "ap_medium": 0.489,
  "ap_large": 0.553,
  "ar1": 0.371,
  "ar10": 0.491,
  "ar100": 0.502,
  "ar_small": 0.389,
  "ar_medium": 0.512,
  "ar_large": 0.589,
  "per_class": [
    {
      "category_id": 1,
      "category_name": "person",
      "ap": 0.412,
      "ap50": 0.598,
      "ap75": 0.441,
      "ar": 0.478
    }
  ],
  "warnings": []
}
```

All metric values are `null` when no predictions are provided or when the
metric cannot be computed (e.g. no ground truth for that size bucket).
