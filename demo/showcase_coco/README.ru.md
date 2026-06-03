# Showcase COCO Dataset

[English version](README.md)

Синтетический road-scene датасет для демонстрации CV Model Lab и публичных скриншотов.

> **Без реальных изображений.** Все изображения сгенерированы геометрическими формами и градиентами. Фотографии и copyrighted assets не используются.

## Состав

| Файл / директория | Описание |
|-------------------|----------|
| `images/` | 40 синтетических PNG-сцен (960×540) |
| `annotations.json` | COCO ground truth — 5 категорий, 87 annotations |
| `predictions_model_a.json` | Model A (Baseline) predictions — 72 boxes |
| `predictions_model_b.json` | Model B (High Recall) predictions — 106 boxes |
| `predictions_model_c.json` | Model C (High Precision) predictions — 70 boxes |
| `ap_metrics_model_a.json` | Precomputed COCO AP metrics для Model A |
| `ap_metrics_model_b.json` | Precomputed COCO AP metrics для Model B |
| `ap_metrics_model_c.json` | Precomputed COCO AP metrics для Model C |
| `reports/` | Сгенерированные EN/RU примеры full, pairwise и multi-model reports |

## Категории

| ID | Name | Описание |
|----|------|----------|
| 1 | `red_light` | Красный сигнал светофора |
| 2 | `yellow_light` | Жёлтый сигнал светофора |
| 3 | `green_light` | Зелёный сигнал светофора |
| 4 | `pedestrian_sign` | Знак пешеходного перехода |
| 5 | `background_distractor` | Фоновый объект, похожий на дорожный знак или лампу |

## Поведение моделей

| Model | AP | AP50 | Recall | Характеристика |
|-------|----|------|--------|----------------|
| A — Baseline | 0.52 | 0.74 | ~64% | Сбалансированная; есть FP на distractors; пропускает часть small objects |
| B — High Recall | 0.47 | 0.70 | ~75% | Лучший recall; больше FP на background и distractors |
| C — High Precision | 0.61 | 0.82 | ~67% | Лучший AP; high-confidence; пропускает часть small objects |

## Открытие в CV Model Lab

Нажмите **Open project** на стартовом экране приложения и выберите
`demo/showcase_coco/showcase_coco.cvmlab.json`. Сохранённый project загрузит три
model runs и precomputed AP metrics.

Также можно открыть файлы вручную:

1. Открыть `annotations.json` как annotations.
2. Добавить `predictions_model_a.json`, затем model B и model C.
3. Импортировать AP metrics JSON для каждого run через **Import AP metrics JSON**.

## Лицензия датасета

Синтетические файлы датасета в этом каталоге, включая сгенерированные изображения, COCO annotations, prediction files, precomputed metrics, сохранённые project files и сгенерированные примеры отчётов, распространяются по CC0 1.0 Universal, если явно не указано иное.

Исходный код CV Model Lab остаётся под лицензией MIT.
