# Журнал изменений

[English version](CHANGELOG.md)

Этот журнал содержит изменения проекта, доступные к текущему коммиту.

## Рабочее пространство анализа и проекты

- Добавлен Flutter workspace для загрузки annotations, predictions и изображений.
- Добавлены image overlays, фильтры, HTML/CSV export, model comparison, project save/load, restore mode, Dataset Health, Worst Cases и annotated image export.
- Добавлены документация проекта, platform folders, demo data, scripts и publishing metadata без bundled CI artifacts.

## Ядро оценки COCO

- Добавлено pure Dart ядро оценки COCO detection с парсерами annotations и predictions.
- Реализованы детерминированный IoU matching, классификация TP/FP/FN, class metrics, confusion data и small-object statistics.
- Добавлены mini COCO test data, unit tests, корневая MIT license и CC0-лицензирование синтетических test fixtures.
