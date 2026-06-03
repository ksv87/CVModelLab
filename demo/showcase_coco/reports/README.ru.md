# Showcase Sample Reports

[English version](README.md)

Эта директория содержит сгенерированные примеры export reports для синтетического Showcase COCO dataset.
Их можно показывать публично: исходные изображения сгенерированы геометрическими сценами, без реальных данных.

## Структура

```text
reports/
  en/
    all reports/           Full evaluation export для Model A
    pairwise compare/      Pairwise comparison: Model A vs Model B
    multi-model compare/   Multi-model comparison: Model A vs Model B vs Model C
  ru/
    all reports/           Такой же набор с Russian report locale
    pairwise compare/      Pairwise comparison с Russian report locale
    multi-model compare/   Multi-model comparison с Russian report locale
```

## Рекомендуемые примеры

- `en/all reports/cv_model_lab_report.html` — full evaluation report с metrics, AP, confusion, health, worst cases и recommendations.
- `en/all reports/cv_model_lab_report.pdf` — print-oriented full evaluation report.
- `en/all reports/cv_model_lab_report.xlsx` — multi-sheet workbook.
- `en/pairwise compare/cv_model_lab_report.html` и `cv_model_lab_comparison.pdf` — pairwise model comparison.
- `en/multi-model compare/cv_model_lab_report.html`, `multi_model_comparison.pdf` и `multi_model_comparison.xlsx` — multi-model leaderboard, class ranking, image disagreements и regression matrix.
- `ru/multi-model compare/cv_model_lab_report.html` — русскоязычный multi-model HTML example.

RU full и pairwise exports полезны как технические примеры, но часть table labels остаётся английской. CSV-заголовки намеренно остаются английскими в обеих локалях для machine-readable compatibility.

## Файлы по типам export

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
