# Журнал изменений

[English version](CHANGELOG.md)

Этот журнал содержит изменения проекта, доступные к текущему коммиту.

## Серверный режим и remote projects

- Добавлен optional FastAPI server mode с allowed-root browsing, server-side COCO parsing/evaluation, image/thumbnails APIs, cache management, AP metrics и static PWA serving.
- Добавлены desktop и PWA remote project workflows для manifest projects и custom server paths.
- Добавлены API key authentication coverage, saved-key handling, stale-connection clearing и route-auth regression tests.

## Синтетический showcase и доработка export

- Добавлен synthetic Showcase COCO dataset со сгенерированными images, annotations, predictions, AP metrics, saved project file и sample reports.
- Добавлено CC0-лицензирование demo data и report examples.
- Улучшены report fonts, localization, compare viewer zoom/pan controls, Linux icon packaging assets и публичная документация.

## Локализация и multi-model comparison

- Добавлена English/Russian localization для app text, warnings, recommendations, health issues, errors и report headings.
- Добавлено multi-model comparison для 3+ model runs: leaderboard, per-class ranking, disagreement analysis, regression matrix и multi-model exports.
- Улучшены metric formatting, recent project restore behavior, AP persistence, model/project renaming и comparison usability.

## Рекомендации и экспорт отчётов

- Добавлены rule-based recommendations с deterministic evidence и ссылками навигации.
- Добавлены XLSX и PDF reports alongside HTML и CSV exports.
- Добавлены COCO AP metrics через desktop Python sidecar и импорт AP metrics для non-desktop workflows.

## Рабочее пространство анализа и проекты

- Добавлен Flutter workspace для загрузки annotations, predictions и изображений.
- Добавлены image overlays, фильтры, HTML/CSV export, model comparison, project save/load, restore mode, Dataset Health, Worst Cases и annotated image export.
- Добавлены документация проекта, platform folders, demo data, scripts и publishing metadata без bundled CI artifacts.

## Ядро оценки COCO

- Добавлено pure Dart ядро оценки COCO detection с парсерами annotations и predictions.
- Реализованы детерминированный IoU matching, классификация TP/FP/FN, class metrics, confusion data и small-object statistics.
- Добавлены mini COCO test data, unit tests, корневая MIT license и CC0-лицензирование синтетических test fixtures.
