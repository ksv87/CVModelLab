# Руководство пользователя

[English version](../user_guide.md) | [README.ru](../../README.ru.md)

## Открыть COCO annotations

На home/open screen выберите COCO annotations JSON. Файл должен содержать `images`, `annotations` и `categories`. CV Model Lab валидирует ссылки, обязательные поля и bounding boxes, затем показывает warnings вместо падения на первом плохом объекте.

## Открыть predictions

Выберите COCO predictions JSON. Predictions могут ссылаться на изображения через `image_id` или `file_name`. Если оба поля есть, приоритет у `image_id`. Позже можно добавить ещё prediction-файлы прямо из workspace для создания multi-run проекта.

## Выбрать images directory

На desktop выберите директорию с изображениями. В Web/PWA выберите файлы или directory/file set, если это поддерживает браузер. Matching поддерживает точный COCO `file_name`, relative paths вроде `val2017/image.jpg` и basename fallback, если он однозначен.

## Анализировать FP/FN

После загрузки откройте dashboard и Error Browser. TP, FP и FN считаются из текущих IoU и confidence thresholds. Image viewer показывает GT boxes, predictions, labels, scores, IoU и match reasons.

## Использовать фильтры

Фильтры сужают список изображений по class, TP/FP/FN, confidence range, IoU threshold, object size, class confusion, missing local image и другим image-level flags. При изменении thresholds evaluation пересчитывается.

## Сравнить модели

### Pairwise

Добавьте второй prediction JSON из workspace (кнопка Add model run). Model Compare в режиме **Pairwise** показывает per-class precision/recall differences и image-level statuses: fixed, broken, improved, regressed. Если у обеих моделей есть COCO AP metrics, появляется вкладка AP diff.

### Multi-model (3+ запусков)

Добавьте три и более model runs в проект, затем откройте Model Compare и переключитесь в режим **Multi-model**. Leaderboard ранжирует каждый запуск по выбираемой метрике; per-class ranking показывает лучшую и худшую модель по классу; анализ расхождений классифицирует каждое изображение; pairwise regression matrix сводит каждую направленную пару; Compare Viewer показывает одно изображение по всем выбранным моделям сеткой.

## Переименовать model run

Нажмите кнопку-карандаш в AppBar workspace, пока активен нужный запуск. Введите новое имя и подтвердите. Дубликаты имён разрешаются автоматически добавлением числа.

## Переименовать проект

Дважды кликните по названию проекта в заголовке AppBar workspace. Введите новое имя и подтвердите. Новое имя сохраняется при следующем сохранении проекта.

## Запустить COCO AP Metrics

На desktop нажмите **Run COCO AP evaluation** на dashboard. Приложение найдёт Python runner (`uv` или `python3` с `pycocotools`) и запустит evaluator в фоне. Результаты появляются в секции метрик dashboard и сохраняются в файл проекта.

В Web/PWA AP evaluation недоступен, потому что браузеры не могут запускать Python-процессы. Используйте **Import AP metrics JSON** для загрузки заранее посчитанного результата из desktop-приложения или из ручного запуска sidecar.

## Экспортировать отчёты

В диалоге Export report можно сохранить отчёты в любом сочетании форматов:

- **HTML** — самодостаточный отчёт со всеми секциями метрик.
- **CSV** — per-class metrics, image errors, matches, small-object stats, confusion data, dataset health, worst cases, AP metrics, recommendations.
- **XLSX** — multi-sheet workbook с теми же данными, что и CSV.
- **PDF** — печатный отчёт с обложкой, таблицами метрик и сводными секциями.

Annotated Image Export сохраняет visual overlays для выбранных изображений.

## Открыть showcase dataset

На экране открытия проекта нажмите **Open project** и выберите
`demo/showcase_coco/showcase_coco.cvmlab.json`. Сохранённый project загружает
синтетический road-scene dataset с тремя model runs (A — Baseline, B — High
Recall, C — High Precision) и предвычисленными COCO AP-метриками для всех трёх.

Датасет создан чтобы демонстрировать все ключевые функции: TP/FP/FN,
классовую путаницу (yellow→green, red→yellow), различия в recall малых объектов,
FP на фоновых дистракторах и multi-model сравнение.

Подробности — в [docs/ru/showcase_demo.md](showcase_demo.md).

## Сохранить и открыть проект

Desktop workflows могут сохранять project file (`.cvmlab.json`) с dataset paths, image root, всеми model runs, evaluation config и COCO AP metrics для каждого запуска. Нажмите **Save** в AppBar.

Открыть снова можно через **Open project** на стартовом экране или через **Recent Projects**. Оба пути загружают все файлы по сохранённым путям автоматически без повторного выбора. Если файл перемещён или недоступен — приложение переходит в restore mode, где можно выбрать файлы заново.
