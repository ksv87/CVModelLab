# Showcase Sample Reports

[Русская версия](README.ru.md)
This directory contains generated sample exports from the synthetic Showcase COCO dataset.
They are safe to share as demo/portfolio artifacts: the source images are generated geometric scenes, not real data.

## Directory Layout

```text
reports/
  en/
    all reports/           Full evaluation export for Model A
    pairwise compare/      Pairwise comparison export: Model A vs Model B
    multi-model compare/   Multi-model comparison export: Model A vs Model B vs Model C
  ru/
    all reports/           Same export set with Russian report locale
    pairwise compare/      Pairwise comparison export with Russian report locale
    multi-model compare/   Multi-model comparison export with Russian report locale
```

## Recommended Examples

- `en/all reports/cv_model_lab_report.html` — full evaluation report with metrics, AP, confusion, health, worst cases, and recommendations.
- `en/all reports/cv_model_lab_report.pdf` — print-oriented full evaluation report.
- `en/all reports/cv_model_lab_report.xlsx` — multi-sheet workbook.
- `en/pairwise compare/cv_model_lab_report.html` and `cv_model_lab_comparison.pdf` — pairwise model comparison.
- `en/multi-model compare/cv_model_lab_report.html`, `multi_model_comparison.pdf`, and `multi_model_comparison.xlsx` — multi-model leaderboard, class ranking, image disagreements, and regression matrix.
- `ru/multi-model compare/cv_model_lab_report.html` — Russian multi-model HTML example.

Russian full and pairwise exports are useful technical examples, but some table labels remain English. CSV headers intentionally stay English in both languages for machine-readable compatibility.

## Files Per Export

### Full Evaluation (`all reports/`)

- `cv_model_lab_report.html`
- `cv_model_lab_report.pdf`
- `cv_model_lab_report.xlsx`
- `per_class_metrics.csv`
- `image_errors.csv`
- `matches.csv`
- `small_object_stats.csv`
- `confusion_matrix.csv`
- `confusion_pairs.csv`
- `dataset_health_report.csv`
- `worst_cases.csv`
- `recommendations.csv`
- `ap_metrics.csv`
- `per_class_ap.csv`

### Pairwise Compare (`pairwise compare/`)

- `cv_model_lab_report.html`
- `cv_model_lab_comparison.pdf`
- `comparison_per_class.csv`
- `comparison_images.csv`

### Multi-model Compare (`multi-model compare/`)

- `cv_model_lab_report.html`
- `multi_model_comparison.pdf`
- `multi_model_comparison.xlsx`
- `multi_model_leaderboard.csv`
- `multi_model_per_class.csv`
- `multi_model_image_disagreements.csv`
- `multi_model_regression_matrix.csv`
