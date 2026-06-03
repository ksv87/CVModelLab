# CV Model Lab — AP Evaluator

[English version](README.md)

Python sidecar, который запускает pycocotools COCO AP evaluation и записывает
результат в JSON.

CV Model Lab вызывает этот script автоматически из desktop app. Обычно запускать
его вручную не нужно.

## Running via uv (recommended)

[uv](https://docs.astral.sh/uv/) управляет Python и dependencies автоматически:
без `pip install` и без ручной activation venv.

```bash
uv run ap_eval.py \
  --annotations /path/to/annotations.json \
  --predictions /path/to/predictions.json \
  --output /path/to/ap_metrics.json
```

Script использует [PEP 723](https://peps.python.org/pep-0723/) inline metadata,
поэтому `uv run` сам resolves `pycocotools` при первом запуске и кеширует его.

## Running via plain Python

```bash
pip install pycocotools
python3 ap_eval.py \
  --annotations /path/to/annotations.json \
  --predictions /path/to/predictions.json \
  --output /path/to/ap_metrics.json
```

## Detection order in CV Model Lab (desktop)

1. `uv` in PATH → uses `uv run ap_eval.py ...` (preferred)
2. `python3` in PATH with `pycocotools` installed → uses `python3 ap_eval.py ...`
3. Neither available → shows an error with instructions

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

Все metric values равны `null`, если predictions отсутствуют или metric cannot
be computed, например для size bucket без ground truth.
